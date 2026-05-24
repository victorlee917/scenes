import AVFoundation
import Flutter
import Foundation
import UIKit

/// Scenes 공유용 영상 합성기.
///
/// Flutter가 미리 합성해둔 1080×1920 PNG/JPEG frame들의 경로를 받아 H.264
/// MP4를 produce. 텍스트/그라데이션/필터 등 시각 합성은 모두 Flutter 쪽에서
/// 끝나 있고, 여기서는 순수 인코더 역할만 한다.
///
/// 채널: `scenes/video_composer`
/// - `compose` (Dart→iOS): { framePaths: [String], frameDuration: Double,
///                           outputPath: String } → returns outputPath String
/// - `progress` (iOS→Dart): { current: Int, total: Int } 매 frame append 후
/// - `shareToInstagramStory` (Dart→iOS): { videoPath: String,
///                                         backgroundColor: String? }
///   → 파스트보드에 비디오 데이터 + 메타 키 세팅 후 instagram-stories:// 호출
final class VideoComposer {
  static let channelName = "scenes/video_composer"

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: VideoComposer.channelName, binaryMessenger: messenger)
    self.channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "deinit", message: "Composer released", details: nil))
        return
      }
      self.handle(call: call, result: result)
    }
  }

  // MARK: - Channel handler

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "compose":
      guard let args = call.arguments as? [String: Any],
            let framePaths = args["framePaths"] as? [String],
            let frameDuration = args["frameDuration"] as? Double,
            let outputPath = args["outputPath"] as? String else {
        result(FlutterError(code: "args", message: "Invalid arguments", details: nil))
        return
      }
      compose(
        framePaths: framePaths,
        frameDuration: frameDuration,
        outputPath: outputPath,
        result: result
      )
    case "shareToInstagramStory":
      guard let args = call.arguments as? [String: Any],
            let videoPath = args["videoPath"] as? String else {
        result(FlutterError(code: "args", message: "Invalid arguments", details: nil))
        return
      }
      shareToInstagramStory(videoPath: videoPath, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Compose

  private func compose(
    framePaths: [String],
    frameDuration: Double,
    outputPath: String,
    result: @escaping FlutterResult
  ) {
    // 한 frame이 cover하는 시간(s)을 600 timescale CMTime으로 변환.
    // 600 = HD 비디오 표준 timescale, 24/30/60fps 모두 정수 배수 표현 가능.
    let frameTime = CMTime(seconds: frameDuration, preferredTimescale: 600)

    // 백그라운드에서 진행. AVAssetWriter의 requestMediaDataWhenReady 콜백은
    // 별도 큐에서 돌리고, 외부 dispatch는 글로벌 풀에서 semaphore wait로 대기 —
    // 같은 직렬 큐에서 wait+callback을 둘 다 돌리면 데드락 발생.
    let encodingQueue = DispatchQueue(label: "scenes.video_composer", qos: .userInitiated)
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let outputURL = URL(fileURLWithPath: outputPath)
        // 같은 경로의 기존 파일이 있으면 미리 제거 (AVAssetWriter가 거부함).
        try? FileManager.default.removeItem(at: outputURL)

        let videoSize = CGSize(width: 1080, height: 1920)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        // HEVC(H.265). 같은 비트레이트에서 H.264 대비 50% 효율 — 어두운 평면
        // (검정 backdrop 등)의 banding/blocking에 특히 강함. iOS 11+에서
        // 디코딩 지원, 우리 deployment target(15.0)에선 보편적으로 OK. IG
        // 스토리/카메라롤도 HEVC 자연 처리.
        //
        // 소스 fps는 caller가 frameDuration으로 전달 — 1/frameDuration이 실제
        // 평균 fps. 인코더/플레이어가 일정 frame rate를 인지하도록 expected
        // rate 힌트도 같이 박는다(playback 부드러움).
        let sourceFps = max(1.0, 1.0 / frameDuration)
        let expectedFps = Int(sourceFps.rounded())
        let videoSettings: [String: Any] = [
          AVVideoCodecKey: AVVideoCodecType.hevc,
          AVVideoWidthKey: Int(videoSize.width),
          AVVideoHeightKey: Int(videoSize.height),
          AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 12_000_000,
            // B-frame reordering 끄기 — 일관된 품질 + 시작부 안정.
            AVVideoAllowFrameReorderingKey: false,
            // GOP를 시간 기반(1초)으로 — fps와 무관하게 1초 단위 키프레임이라
            // seeking/디코딩이 일관됨. frame-count GOP는 fps 낮을 때 키프레임
            // 간격이 너무 벌어져 디코더 부담.
            AVVideoMaxKeyFrameIntervalDurationKey: 1.0,
            // 소스 fps 힌트 — 인코더 rate-control과 플레이어 둘 다 활용.
            AVVideoExpectedSourceFrameRateKey: expectedFps,
            AVVideoAverageNonDroppableFrameRateKey: expectedFps,
          ],
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
          assetWriterInput: writerInput,
          sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(videoSize.width),
            kCVPixelBufferHeightKey as String: Int(videoSize.height),
          ]
        )

        guard writer.canAdd(writerInput) else {
          throw NSError(domain: "VideoComposer", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot add writer input"])
        }
        writer.add(writerInput)
        guard writer.startWriting() else {
          throw writer.error ?? NSError(domain: "VideoComposer", code: 2,
                                        userInfo: [NSLocalizedDescriptionKey: "startWriting failed"])
        }
        writer.startSession(atSourceTime: .zero)

        // requestMediaDataWhenReady 콜백이 실행되는 동안에만 append 가능. 끝
        // 까지 append를 마치고 markAsFinished + finishWriting을 호출해야 함.
        // semaphore로 전체 인코딩 완료까지 외부 큐를 wait.
        let semaphore = DispatchSemaphore(value: 0)
        var frameIndex = 0
        var encodingError: Error?

        writerInput.requestMediaDataWhenReady(on: encodingQueue) {
          while writerInput.isReadyForMoreMediaData {
            if frameIndex >= framePaths.count {
              writerInput.markAsFinished()
              writer.finishWriting {
                semaphore.signal()
              }
              return
            }

            let path = framePaths[frameIndex]
            guard let image = UIImage(contentsOfFile: path) else {
              // 잡 한 장 실패해도 전체 인코딩은 진행. 빈 프레임만 skip.
              frameIndex += 1
              continue
            }
            guard let buffer = self.makePixelBuffer(from: image, size: videoSize) else {
              frameIndex += 1
              continue
            }
            let presentationTime = CMTimeMultiply(frameTime, multiplier: Int32(frameIndex))
            if !pixelBufferAdaptor.append(buffer, withPresentationTime: presentationTime) {
              encodingError = writer.error ?? NSError(domain: "VideoComposer", code: 3,
                                                      userInfo: [NSLocalizedDescriptionKey: "append failed"])
              writerInput.markAsFinished()
              writer.finishWriting { semaphore.signal() }
              return
            }

            // 진행률 — Dart에 send. Main thread로 hop.
            let current = frameIndex + 1
            let total = framePaths.count
            DispatchQueue.main.async { [weak self] in
              self?.channel.invokeMethod("progress", arguments: [
                "current": current,
                "total": total,
              ])
            }
            frameIndex += 1
          }
        }

        semaphore.wait()

        if let err = encodingError {
          DispatchQueue.main.async {
            result(FlutterError(code: "encode", message: err.localizedDescription, details: nil))
          }
          return
        }
        if writer.status == .failed {
          let err = writer.error ?? NSError(domain: "VideoComposer", code: 4,
                                            userInfo: [NSLocalizedDescriptionKey: "writer failed"])
          DispatchQueue.main.async {
            result(FlutterError(code: "writer", message: err.localizedDescription, details: nil))
          }
          return
        }
        DispatchQueue.main.async {
          result(outputURL.path)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "compose", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - Pixel buffer

  /// `UIImage` → `CVPixelBuffer` (32BGRA, target size로 리사이즈/letterbox 없이
  /// scale-to-fit). 입력이 이미 1080×1920이면 그대로 1:1 그려짐.
  private func makePixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
    let attrs: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ]
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      Int(size.width),
      Int(size.height),
      kCVPixelFormatType_32BGRA,
      attrs as CFDictionary,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    let pixelData = CVPixelBufferGetBaseAddress(buffer)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
      | CGBitmapInfo.byteOrder32Little.rawValue

    guard let context = CGContext(
      data: pixelData,
      width: Int(size.width),
      height: Int(size.height),
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: rgbColorSpace,
      bitmapInfo: bitmapInfo
    ) else {
      return nil
    }

    // CVPixelBufferCreate는 메모리를 0으로 초기화하지 않으므로(garbage),
    // PNG가 fully opaque가 아니면 이전 frame 버퍼 잔여물이 비쳐 잔상처럼
    // 보일 수 있다. 그리기 전 검정으로 fill해 garbage를 가린다.
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: .zero, size: size))

    if let cgImage = image.cgImage {
      context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    }
    return buffer
  }

  // MARK: - Instagram Story

  /// 합성한 비디오를 UIPasteboard에 Instagram Stories 메타 키로 세팅하고
  /// `instagram-stories://share` URL을 열어 IG 컴포저에 video를 직접 attach.
  /// IG 미설치 또는 scheme 미허용이면 `unavailable` 에러로 Dart에 알려 fallback.
  private func shareToInstagramStory(videoPath: String, result: @escaping FlutterResult) {
    guard let storyURL = URL(string: "instagram-stories://share?source_application=scenes") else {
      result(FlutterError(code: "url", message: "Invalid URL", details: nil))
      return
    }

    DispatchQueue.main.async {
      guard UIApplication.shared.canOpenURL(storyURL) else {
        result(FlutterError(code: "unavailable",
                            message: "Instagram is not installed",
                            details: nil))
        return
      }
      let videoURL = URL(fileURLWithPath: videoPath)
      guard let videoData = try? Data(contentsOf: videoURL) else {
        result(FlutterError(code: "read", message: "Cannot read video", details: nil))
        return
      }
      let pasteboardItems: [[String: Any]] = [[
        "com.instagram.sharedSticker.backgroundVideo": videoData,
      ]]
      let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
        .expirationDate: Date(timeIntervalSinceNow: 60 * 5),
      ]
      UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
      UIApplication.shared.open(storyURL, options: [:]) { opened in
        if opened {
          result(true)
        } else {
          result(FlutterError(code: "open", message: "Failed to open Instagram", details: nil))
        }
      }
    }
  }
}
