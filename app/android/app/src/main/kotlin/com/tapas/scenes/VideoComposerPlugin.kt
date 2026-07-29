package com.tapas.scenes

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/// Scenes 공유용 영상 합성기의 Android 구현.
///
/// iOS `VideoComposer.swift`(AVAssetWriter)와 동일 계약. Flutter가 미리 구운
/// 1080×1920 PNG/JPEG frame 경로들을 받아 H.264 MP4를 만든다. 시각 합성은 전부
/// Flutter에서 끝났고 여기선 순수 인코더 역할만.
///
/// 인코딩은 MediaCodec의 **input Surface + EGL**로 한다(YUV 색상 포맷/스트라이드가
/// 기기마다 달라 ByteBuffer 방식은 파편화가 심함 — Surface는 인코더가 색변환을
/// 담당해 이식성이 좋다). 각 frame bitmap을 GL 텍스처로 올려 full-screen quad로
/// 그리고, `eglPresentationTimeANDROID`로 정확한 PTS를 박은 뒤 swapBuffers.
class VideoComposerPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "scenes/video_composer"
        private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val WIDTH = 1080
        private const val HEIGHT = 1920
        private const val BITRATE = 12_000_000
        private const val EGL_RECORDABLE_ANDROID = 0x3142
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    // 스트리밍 세션(begin/append/end). Android 전용 fast-path — Flutter가 raw
    // RGBA frame을 한 장씩 밀어넣어 디스크에 PNG를 쌓지 않고 바로 인코딩한다.
    private var session: ComposeSession? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "compose" -> {
                val framePaths = call.argument<List<String>>("framePaths")
                val frameDuration = call.argument<Double>("frameDuration")
                val outputPath = call.argument<String>("outputPath")
                if (framePaths == null || frameDuration == null || outputPath == null) {
                    result.error("args", "Invalid arguments", null)
                    return
                }
                // 인코딩은 무거우니 별도 스레드. result/progress는 main으로 hop.
                Thread {
                    compose(framePaths, frameDuration, outputPath, result)
                }.start()
            }
            "beginCompose" -> {
                val outputPath = call.argument<String>("outputPath")
                val frameDuration = call.argument<Double>("frameDuration")
                if (outputPath == null || frameDuration == null) {
                    result.error("args", "Invalid arguments", null)
                    return
                }
                if (session != null) {
                    result.error("state", "Session already active", null)
                    return
                }
                val frameDurUs = (frameDuration * 1_000_000.0).toLong()
                val s = ComposeSession(outputPath, frameDurUs)
                session = s
                s.begin(result)
            }
            "appendRawFrame" -> {
                val bytes = call.argument<ByteArray>("bytes")
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                val s = session
                if (bytes == null || width == null || height == null) {
                    result.error("args", "Invalid arguments", null)
                    return
                }
                if (s == null) {
                    result.error("state", "No active session", null)
                    return
                }
                s.append(bytes, width, height, result)
            }
            "endCompose" -> {
                val s = session
                if (s == null) {
                    result.error("state", "No active session", null)
                    return
                }
                session = null
                s.end(result)
            }
            "shareToInstagramStory" -> {
                val videoPath = call.argument<String>("videoPath")
                if (videoPath == null) {
                    result.error("args", "Invalid arguments", null)
                    return
                }
                shareToInstagramStory(videoPath, result)
            }
            else -> result.notImplemented()
        }
    }

    // MARK: - Compose

    private fun compose(
        framePaths: List<String>,
        frameDuration: Double,
        outputPath: String,
        result: MethodChannel.Result,
    ) {
        var codec: MediaCodec? = null
        var muxer: MediaMuxer? = null
        var inputSurface: InputSurface? = null
        try {
            File(outputPath).let { if (it.exists()) it.delete() }

            val fps = Math.max(1.0, 1.0 / frameDuration)
            val format = MediaFormat.createVideoFormat(MIME, WIDTH, HEIGHT).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
                )
                setInteger(MediaFormat.KEY_BIT_RATE, BITRATE)
                setInteger(MediaFormat.KEY_FRAME_RATE, Math.round(fps).toInt())
                // 1초 단위 키프레임 — fps와 무관하게 seeking/디코딩 일관.
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }

            codec = MediaCodec.createEncoderByType(MIME)
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = InputSurface(codec.createInputSurface())
            codec.start()
            inputSurface.makeCurrent()

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxState = MuxState()

            val renderer = TextureRenderer()
            val bufferInfo = MediaCodec.BufferInfo()
            val total = framePaths.size
            val frameDurUs = (frameDuration * 1_000_000.0).toLong()

            var appended = 0
            for (i in 0 until total) {
                val bitmap = decodeFrame(framePaths[i])
                if (bitmap == null) {
                    // 한 장 실패해도 전체 인코딩은 진행 — 빈 frame만 skip.
                    postProgress(i + 1, total)
                    continue
                }
                renderer.draw(bitmap)
                bitmap.recycle()
                val ptsUs = appended * frameDurUs
                inputSurface.setPresentationTime(ptsUs * 1000L) // ns
                inputSurface.swapBuffers()
                appended++
                drainEncoder(codec, muxer, muxState, bufferInfo, endOfStream = false)
                postProgress(i + 1, total)
            }

            // EOS 신호 후 남은 출력 flush.
            codec.signalEndOfInputStream()
            drainEncoder(codec, muxer, muxState, bufferInfo, endOfStream = true)

            renderer.release()

            // result.success 전에 인코더/muxer를 확정한다. muxer.stop()이 moov를
            // 써야 MP4가 완성되므로, 이 순서가 아니면 Dart가 미완성 파일을 읽는
            // 레이스가 난다(main.post는 비동기라 finally와 경합).
            inputSurface.release(); inputSurface = null
            codec.stop(); codec.release(); codec = null
            muxer.stop(); muxer.release(); muxer = null

            postResult { result.success(outputPath) }
        } catch (e: Exception) {
            postResult { result.error("compose", e.message ?: "compose failed", null) }
        } finally {
            // 정상 경로에선 위에서 null로 비워 no-op. 예외 경로 정리용.
            try { codec?.stop() } catch (_: Exception) {}
            try { codec?.release() } catch (_: Exception) {}
            try { inputSurface?.release() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
        }
    }

    private class MuxState {
        var trackIndex = -1
        var started = false
    }

    /// 스트리밍 인코딩 세션. begin으로 encoder/surface/EGL/muxer를 세우고, append로
    /// raw RGBA frame을 한 장씩 인코딩, end로 flush+finalize한다. 모든 EGL/GL 호출은
    /// EGL context가 바인딩된 **단일 전용 스레드**에서만 실행해야 하므로 전 작업을
    /// 하나의 single-thread executor에 태운다. Dart가 각 append 결과를 await하므로
    /// 큐가 쌓이지 않고 자연스러운 backpressure가 걸린다.
    private inner class ComposeSession(
        private val outputPath: String,
        private val frameDurUs: Long,
    ) {
        private val executor: ExecutorService = Executors.newSingleThreadExecutor()
        private var codec: MediaCodec? = null
        private var muxer: MediaMuxer? = null
        private var inputSurface: InputSurface? = null
        private var renderer: TextureRenderer? = null
        private val muxState = MuxState()
        private val bufferInfo = MediaCodec.BufferInfo()
        private var appended = 0
        private var pixelBuf: ByteBuffer? = null

        fun begin(result: MethodChannel.Result) {
            executor.submit {
                try {
                    File(outputPath).let { if (it.exists()) it.delete() }
                    val fps = Math.max(1.0, 1_000_000.0 / frameDurUs)
                    val format = MediaFormat.createVideoFormat(MIME, WIDTH, HEIGHT).apply {
                        setInteger(
                            MediaFormat.KEY_COLOR_FORMAT,
                            MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
                        )
                        setInteger(MediaFormat.KEY_BIT_RATE, BITRATE)
                        setInteger(MediaFormat.KEY_FRAME_RATE, Math.round(fps).toInt())
                        setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                    }
                    val c = MediaCodec.createEncoderByType(MIME)
                    c.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                    val surf = InputSurface(c.createInputSurface())
                    c.start()
                    surf.makeCurrent()
                    codec = c
                    inputSurface = surf
                    muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                    renderer = TextureRenderer()
                    postResult { result.success(null) }
                } catch (e: Exception) {
                    releaseQuietly()
                    postResult { result.error("beginCompose", e.message ?: "begin failed", null) }
                }
            }
        }

        fun append(bytes: ByteArray, width: Int, height: Int, result: MethodChannel.Result) {
            executor.submit {
                try {
                    val c = codec ?: throw IllegalStateException("no codec")
                    val surf = inputSurface ?: throw IllegalStateException("no surface")
                    val r = renderer ?: throw IllegalStateException("no renderer")
                    var buf = pixelBuf
                    if (buf == null || buf.capacity() < bytes.size) {
                        buf = ByteBuffer.allocateDirect(bytes.size)
                        pixelBuf = buf
                    }
                    buf.clear()
                    buf.put(bytes)
                    buf.position(0)
                    r.drawRaw(buf, width, height)
                    surf.setPresentationTime(appended * frameDurUs * 1000L) // ns
                    surf.swapBuffers()
                    appended++
                    drainEncoder(c, muxer!!, muxState, bufferInfo, endOfStream = false)
                    postResult { result.success(null) }
                } catch (e: Exception) {
                    postResult { result.error("appendRawFrame", e.message ?: "append failed", null) }
                }
            }
        }

        fun end(result: MethodChannel.Result) {
            executor.submit {
                try {
                    val c = codec ?: throw IllegalStateException("no codec")
                    c.signalEndOfInputStream()
                    drainEncoder(c, muxer!!, muxState, bufferInfo, endOfStream = true)
                    renderer?.release(); renderer = null
                    inputSurface?.release(); inputSurface = null
                    c.stop(); c.release(); codec = null
                    muxer?.stop(); muxer?.release(); muxer = null
                    postResult { result.success(outputPath) }
                } catch (e: Exception) {
                    releaseQuietly()
                    postResult { result.error("endCompose", e.message ?: "end failed", null) }
                } finally {
                    executor.shutdown()
                }
            }
        }

        private fun releaseQuietly() {
            try { renderer?.release() } catch (_: Exception) {}
            try { inputSurface?.release() } catch (_: Exception) {}
            try { codec?.stop() } catch (_: Exception) {}
            try { codec?.release() } catch (_: Exception) {}
            try { muxer?.release() } catch (_: Exception) {}
            renderer = null; inputSurface = null; codec = null; muxer = null
        }
    }

    /// 인코더 출력을 muxer로 흘려보낸다. endOfStream이면 EOS flag를 만날 때까지 대기.
    private fun drainEncoder(
        codec: MediaCodec,
        muxer: MediaMuxer,
        state: MuxState,
        bufferInfo: MediaCodec.BufferInfo,
        endOfStream: Boolean,
    ) {
        val timeoutUs = 10_000L
        while (true) {
            val outIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
            if (outIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!endOfStream) return
                // EOS 대기 중이면 계속 폴링.
                continue
            } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (state.started) throw IllegalStateException("format changed twice")
                state.trackIndex = muxer.addTrack(codec.outputFormat)
                muxer.start()
                state.started = true
            } else if (outIndex >= 0) {
                val encoded = codec.getOutputBuffer(outIndex)
                    ?: throw IllegalStateException("null output buffer")
                // codec config(SPS/PPS)는 muxer가 addTrack에서 이미 처리 — skip.
                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                    bufferInfo.size = 0
                }
                if (bufferInfo.size > 0 && state.started) {
                    encoded.position(bufferInfo.offset)
                    encoded.limit(bufferInfo.offset + bufferInfo.size)
                    muxer.writeSampleData(state.trackIndex, encoded, bufferInfo)
                }
                codec.releaseOutputBuffer(outIndex, false)
                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                    return
                }
            }
        }
    }

    /// frame 파일을 1080×1920 ARGB bitmap으로 로드. 이미 그 크기면 그대로,
    /// 아니면 채워 그리도록 스케일. iOS는 full rect에 stretch — 동일하게 처리.
    private fun decodeFrame(path: String): Bitmap? {
        val raw = try {
            BitmapFactory.decodeFile(path)
        } catch (_: Exception) {
            null
        } ?: return null
        if (raw.width == WIDTH && raw.height == HEIGHT) return raw
        return try {
            val scaled = Bitmap.createScaledBitmap(raw, WIDTH, HEIGHT, true)
            if (scaled !== raw) raw.recycle()
            scaled
        } catch (_: Exception) {
            raw
        }
    }

    private fun postProgress(current: Int, total: Int) {
        main.post {
            channel.invokeMethod("progress", mapOf("current" to current, "total" to total))
        }
    }

    private fun postResult(block: () -> Unit) {
        main.post(block)
    }

    // MARK: - Instagram Story

    /// `com.instagram.share.ADD_TO_STORY` intent로 배경 비디오 attach. IG 미설치
    /// 또는 intent resolve 실패면 `unavailable`로 Dart에 알려 일반 공유로 fallback.
    ///
    /// NOTE: IG는 `source_application`에 등록된 Facebook App ID를 요구할 수 있다.
    /// 없으면 IG가 자체적으로 거부할 수 있어, 그 경우 Dart fallback(일반 공유
    /// 시트)로 대응. 현재는 applicationId를 넣고 best-effort.
    private fun shareToInstagramStory(videoPath: String, result: MethodChannel.Result) {
        main.post {
            try {
                val file = File(videoPath)
                if (!file.exists()) {
                    result.error("read", "Video not found", null)
                    return@post
                }
                val uri: Uri = FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    file,
                )
                val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                    setDataAndType(uri, "video/mp4")
                    putExtra("source_application", context.packageName)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(context.packageManager) == null) {
                    result.error("unavailable", "Instagram is not installed", null)
                    return@post
                }
                context.grantUriPermission(
                    "com.instagram.android",
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
                context.startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                result.error("open", e.message ?: "Failed to open Instagram", null)
            }
        }
    }

    // MARK: - EGL input surface

    /// MediaCodec input Surface를 감싼 EGL window surface. GLES2 컨텍스트를 만들고
    /// PTS를 박은 뒤 swapBuffers로 인코더에 frame을 밀어넣는다.
    private class InputSurface(private val surface: Surface) {
        private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
        private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
        private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

        init {
            eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (eglDisplay === EGL14.EGL_NO_DISPLAY) {
                throw RuntimeException("eglGetDisplay failed")
            }
            val version = IntArray(2)
            if (!EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
                throw RuntimeException("eglInitialize failed")
            }
            val configAttrs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL_RECORDABLE_ANDROID, 1,
                EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            if (!EGL14.eglChooseConfig(
                    eglDisplay, configAttrs, 0, configs, 0, 1, numConfigs, 0,
                ) || numConfigs[0] == 0
            ) {
                throw RuntimeException("eglChooseConfig failed")
            }
            val ctxAttrs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
            eglContext = EGL14.eglCreateContext(
                eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, ctxAttrs, 0,
            )
            if (eglContext === EGL14.EGL_NO_CONTEXT) {
                throw RuntimeException("eglCreateContext failed")
            }
            val surfaceAttrs = intArrayOf(EGL14.EGL_NONE)
            eglSurface = EGL14.eglCreateWindowSurface(
                eglDisplay, configs[0], surface, surfaceAttrs, 0,
            )
            if (eglSurface === EGL14.EGL_NO_SURFACE) {
                throw RuntimeException("eglCreateWindowSurface failed")
            }
        }

        fun makeCurrent() {
            if (!EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)) {
                throw RuntimeException("eglMakeCurrent failed")
            }
        }

        fun setPresentationTime(nsecs: Long) {
            EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, nsecs)
        }

        fun swapBuffers(): Boolean = EGL14.eglSwapBuffers(eglDisplay, eglSurface)

        fun release() {
            if (eglDisplay !== EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(
                    eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_CONTEXT,
                )
                EGL14.eglDestroySurface(eglDisplay, eglSurface)
                EGL14.eglDestroyContext(eglDisplay, eglContext)
                EGL14.eglReleaseThread()
                EGL14.eglTerminate(eglDisplay)
            }
            eglDisplay = EGL14.EGL_NO_DISPLAY
            eglContext = EGL14.EGL_NO_CONTEXT
            eglSurface = EGL14.EGL_NO_SURFACE
            surface.release()
        }
    }

    /// bitmap을 텍스처로 올려 full-screen quad로 그리는 최소 GLES2 렌더러.
    private class TextureRenderer {
        // (x, y, s, t) — s,t는 bitmap(top-left origin)이 화면에 바로 서도록 매핑.
        private val vertexData = floatArrayOf(
            -1f, -1f, 0f, 1f,
            1f, -1f, 1f, 1f,
            -1f, 1f, 0f, 0f,
            1f, 1f, 1f, 0f,
        )
        private val vertexBuffer: FloatBuffer = ByteBuffer
            .allocateDirect(vertexData.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply { put(vertexData); position(0) }

        private val program: Int
        private val aPosition: Int
        private val aTexCoord: Int
        private val uTexture: Int
        private val textureId: Int

        init {
            val vs = """
                attribute vec4 aPosition;
                attribute vec2 aTexCoord;
                varying vec2 vTexCoord;
                void main() {
                    gl_Position = aPosition;
                    vTexCoord = aTexCoord;
                }
            """.trimIndent()
            val fs = """
                precision mediump float;
                varying vec2 vTexCoord;
                uniform sampler2D uTexture;
                void main() {
                    gl_FragColor = texture2D(uTexture, vTexCoord);
                }
            """.trimIndent()
            program = linkProgram(vs, fs)
            aPosition = GLES20.glGetAttribLocation(program, "aPosition")
            aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
            uTexture = GLES20.glGetUniformLocation(program, "uTexture")
            val tex = IntArray(1)
            GLES20.glGenTextures(1, tex, 0)
            textureId = tex[0]
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
            )
        }

        fun draw(bitmap: Bitmap) {
            beginDraw()
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
            finishDraw()
        }

        /// raw RGBA(top-left origin, tightly packed) 픽셀을 텍스처로 올려 그린다.
        /// src 크기가 WIDTH×HEIGHT와 다르면 GL_LINEAR 샘플링으로 quad에 스케일된다.
        fun drawRaw(pixels: ByteBuffer, w: Int, h: Int) {
            beginDraw()
            GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
            GLES20.glTexImage2D(
                GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, w, h, 0,
                GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, pixels,
            )
            finishDraw()
        }

        private fun beginDraw() {
            GLES20.glViewport(0, 0, WIDTH, HEIGHT)
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)

            GLES20.glUseProgram(program)
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        }

        private fun finishDraw() {
            GLES20.glUniform1i(uTexture, 0)

            vertexBuffer.position(0)
            GLES20.glEnableVertexAttribArray(aPosition)
            GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
            vertexBuffer.position(2)
            GLES20.glEnableVertexAttribArray(aTexCoord)
            GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)

            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

            GLES20.glDisableVertexAttribArray(aPosition)
            GLES20.glDisableVertexAttribArray(aTexCoord)
        }

        fun release() {
            GLES20.glDeleteProgram(program)
            GLES20.glDeleteTextures(1, intArrayOf(textureId), 0)
        }

        private fun linkProgram(vsSource: String, fsSource: String): Int {
            val vs = compileShader(GLES20.GL_VERTEX_SHADER, vsSource)
            val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, fsSource)
            val program = GLES20.glCreateProgram()
            GLES20.glAttachShader(program, vs)
            GLES20.glAttachShader(program, fs)
            GLES20.glLinkProgram(program)
            val status = IntArray(1)
            GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, status, 0)
            if (status[0] == 0) {
                val log = GLES20.glGetProgramInfoLog(program)
                GLES20.glDeleteProgram(program)
                throw RuntimeException("Program link failed: $log")
            }
            GLES20.glDeleteShader(vs)
            GLES20.glDeleteShader(fs)
            return program
        }

        private fun compileShader(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, source)
            GLES20.glCompileShader(shader)
            val status = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
            if (status[0] == 0) {
                val log = GLES20.glGetShaderInfoLog(shader)
                GLES20.glDeleteShader(shader)
                throw RuntimeException("Shader compile failed: $log")
            }
            return shader
        }
    }
}
