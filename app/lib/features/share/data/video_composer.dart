import 'package:flutter/services.dart';

/// 진행률 콜백. (current, total) — 둘 다 1-based로 i번째 frame까지 인코딩 끝남.
typedef ComposeProgress = void Function(int current, int total);

/// iOS native `VideoComposer.swift`로 가는 MethodChannel 래퍼.
///
/// Flutter 쪽에서 미리 1080×1920 PNG/JPEG로 굽어둔 frame들을 넘기면 native가
/// `AVAssetWriter`로 H.264 MP4를 만들어 outputPath에 떨어뜨린 뒤 해당 path를
/// 반환. 인코딩 중 매 frame마다 `progress` 콜백이 main isolate에서 호출됨.
class VideoComposer {
  VideoComposer._();
  static final VideoComposer instance = VideoComposer._();

  static const _channel = MethodChannel('scenes/video_composer');

  /// 영상 합성. 동시에 여러 번 호출하면 progress handler 한쪽만 받음 — 한
  /// 번에 하나만 돌리도록 호출자가 직렬화 책임. 우리 use case(공유 시트
  /// 안에서만 트리거)에선 자연스럽게 직렬.
  Future<String> composeVideo({
    required List<String> framePaths,
    required Duration frameDuration,
    required String outputPath,
    ComposeProgress? onProgress,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        final args = call.arguments as Map;
        final current = (args['current'] as num).toInt();
        final total = (args['total'] as num).toInt();
        onProgress?.call(current, total);
      }
    });
    try {
      final result = await _channel.invokeMethod<String>('compose', {
        'framePaths': framePaths,
        'frameDuration': frameDuration.inMicroseconds / 1e6,
        'outputPath': outputPath,
      });
      if (result == null || result.isEmpty) {
        throw StateError('Compose returned empty path');
      }
      return result;
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  /// 스트리밍 인코딩 시작(iOS/Android 공통). native가 encoder를 열어두고
  /// [appendRawFrame]로 들어오는 raw RGBA frame을 즉시 인코딩한다. PNG로 굽어
  /// 디스크에 쌓는 과정을 생략해 render 병목(PNG 압축)을 없앤다.
  Future<void> beginCompose({
    required Duration frameDuration,
    required String outputPath,
  }) async {
    await _channel.invokeMethod<void>('beginCompose', {
      'frameDuration': frameDuration.inMicroseconds / 1e6,
      'outputPath': outputPath,
    });
  }

  /// raw RGBA(straight, top-left origin, width*height*4 bytes) frame 한 장을
  /// 인코더에 밀어넣는다. Dart가 결과를 await하므로 프레임당 backpressure가 걸림.
  Future<void> appendRawFrame({
    required Uint8List bytes,
    required int width,
    required int height,
  }) async {
    await _channel.invokeMethod<void>('appendRawFrame', {
      'bytes': bytes,
      'width': width,
      'height': height,
    });
  }

  /// 스트리밍 인코딩 종료 — EOS flush 후 MP4 finalize. 완성된 영상 path 반환.
  Future<String> endCompose() async {
    final result = await _channel.invokeMethod<String>('endCompose');
    if (result == null || result.isEmpty) {
      throw StateError('endCompose returned empty path');
    }
    return result;
  }

  /// Instagram Stories 직접 attach 시도. native가 비디오 데이터를 UIPasteboard
  /// 메타 키와 함께 세팅한 후 `instagram-stories://share` URL을 연다. IG 미설치
  /// 등으로 열 수 없으면 `unavailable` 코드의 PlatformException이 throw돼 호출자
  /// 가 fallback(예: SharePlus)으로 넘어갈 수 있음.
  Future<bool> shareToInstagramStory({required String videoPath}) async {
    final result = await _channel.invokeMethod<bool>('shareToInstagramStory', {
      'videoPath': videoPath,
    });
    return result ?? false;
  }
}
