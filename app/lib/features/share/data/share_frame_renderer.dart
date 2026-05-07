import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import '../widgets/share_frame_view.dart';

/// 진행률 콜백. (current, total) — 둘 다 1-based.
typedef RenderProgress = void Function(int current, int total);

/// 공유 영상의 frame들을 1080×1920 PNG로 굽어 디스크에 저장.
///
/// 각 frame마다:
///   1. URL에서 bytes 다운로드
///   2. `precacheImage`로 데코딩까지 완료시켜 paint 시 동기로 그려지게
///   3. `Overlay`에 ShareFrameView를 (-100000, -100000) 오프셋으로 mount
///      (laid out + painted, 화면엔 안 보임)
///   4. 다음 프레임을 기다린 후 `RepaintBoundary.toImage(pixelRatio: 6.0)`로
///      1080×1920 ui.Image 추출
///   5. PNG로 인코딩해 `outputDir/frame_NNN.png` 에 저장
///
/// 호출자(공유 시트)는 화면에 살아있어야 함 — Overlay 사용을 위해 [context]가
/// 필요하고 mount/unmount가 한 framework tick 안에 안 끝나면 의미 없음.
class ShareFrameRenderer {
  ShareFrameRenderer._();
  static final ShareFrameRenderer instance = ShareFrameRenderer._();

  /// ShareFrameView가 디자인된 logical size. 출력 pixelRatio = 1080 / logical
  /// 로 동적 계산해 항상 1080×1920 영상이 나오게.
  static final double _logicalWidth = kShareFrameLogicalWidth;
  static final double _logicalHeight = kShareFrameLogicalHeight;
  static final double _pixelRatio =
      kShareFrameOutputWidth / kShareFrameLogicalWidth;

  Future<List<String>> renderFrames({
    required BuildContext context,
    required List<ShareFrame> frames,
    required ColorFilter? colorFilter,
    required Directory outputDir,
    RenderProgress? onProgress,
    http.Client? client,
  }) async {
    final ownClient = client ?? http.Client();
    final paths = <String>[];
    try {
      for (var i = 0; i < frames.length; i++) {
        final frame = frames[i];
        // frame.renderUrl은 photo의 경우 thumb URL — egress 60배 감소.
        // 출력은 1080×1920 캔버스에 BoxFit.cover로 그려져 약간의 upscaling
        // 발생하지만 IG Story 포맷에서는 수용 가능 수준.
        final bytes = await _download(frame.renderUrl, ownClient);
        if (!context.mounted) {
          throw StateError('Context unmounted during render');
        }
        final pngBytes = await _captureFrame(
          context: context,
          frame: frame,
          imageBytes: bytes,
          colorFilter: colorFilter,
        );
        final path =
            '${outputDir.path}/frame_${i.toString().padLeft(3, '0')}.png';
        await File(path).writeAsBytes(pngBytes);
        paths.add(path);
        onProgress?.call(i + 1, frames.length);
      }
      return paths;
    } finally {
      if (client == null) ownClient.close();
    }
  }

  Future<Uint8List> _download(String url, http.Client client) async {
    final response = await client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw StateError('Frame download failed (${response.statusCode}) for $url');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> _captureFrame({
    required BuildContext context,
    required ShareFrame frame,
    required Uint8List imageBytes,
    required ColorFilter? colorFilter,
  }) async {
    // MemoryImage 데코딩을 먼저 끝내 ShareFrameView가 paint될 때 동기로 그려
    // 지게. precacheImage가 끝나면 Image 위젯은 즉시 첫 frame을 그릴 수 있음.
    final imageProvider = MemoryImage(imageBytes);
    await precacheImage(imageProvider, context);
    if (!context.mounted) {
      throw StateError('Context unmounted before capture');
    }

    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final entry = OverlayEntry(
      builder: (_) {
        // Material 한 겹 — Theme만 있는 트리에서는 DefaultTextStyle 조상이
        // 없어서 Text가 노란 더블 언더라인(디버그 마커) + 잘못된 fallback 폰트
        // 로 그려진다. Material(type: transparency)는 배경엔 영향 없이 적절한
        // DefaultTextStyle을 주입.
        return Positioned(
          left: -100000,
          top: -100000,
          child: MediaQuery(
            data: mediaQuery,
            child: Theme(
              data: theme,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Material(
                  type: MaterialType.transparency,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: SizedBox(
                      width: _logicalWidth,
                      height: _logicalHeight,
                      child: ShareFrameView(
                        frame: frame,
                        image: imageProvider,
                        colorFilter: colorFilter,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);

    try {
      // 두 frame paint를 기다린 후 capture. 한 frame이면 디코딩이 막 끝난
      // 이미지의 첫 paint만 잡혀서 일부 시점에 미완성 frame이 캡처될 수 있음.
      await SchedulerBinding.instance.endOfFrame;
      await SchedulerBinding.instance.endOfFrame;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('RepaintBoundary not found');
      }
      final image = await renderObject.toImage(pixelRatio: _pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Failed to encode frame to PNG');
      }
      return byteData.buffer.asUint8List();
    } finally {
      entry.remove();
      // 100장 batch 동안 ImageCache(100MB / 1000 entries)가 가득 차면 LRU
      // 축출이 다음 frame의 디코딩 중에 끼어들어 미완성 상태로 paint될 수 있음.
      // 매 frame 후 우리 entry를 즉시 비워 cache pressure 누적을 방지.
      PaintingBinding.instance.imageCache.evict(imageProvider);
    }
  }
}
