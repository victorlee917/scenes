package com.tapas.scenes

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // 공유용 영상 합성 채널(scenes/video_composer)의 Android 구현 등록.
    // iOS는 AppDelegate에서 VideoComposer를 붙임 — 여기가 그 대응.
    private var videoComposer: VideoComposerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoComposer = VideoComposerPlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }
}
