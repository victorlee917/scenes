import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import '../widgets/share_frame_view.dart';
import '../widgets/snake_share_view.dart';
import '../widgets/stack_share_view.dart';
import 'video_composer.dart';

/// 진행률 콜백. (current, total) — 둘 다 1-based.
typedef RenderProgress = void Function(int current, int total);

/// 렌더된 frame(ui.Image)의 소비자. 캡처 파이프라인을 출력 방식과 분리한다.
/// - [PngFileSink]: PNG로 굽어 디스크에 저장(iOS 인코더가 파일 경로로 읽음).
/// - [NativeStreamSink]: raw RGBA로 뽑아 Android native encoder로 즉시 스트리밍
///   (PNG 압축·디스크 적재를 모두 생략 — render 병목 제거).
///
/// 구현은 [add]에서 넘어온 [ui.Image]의 dispose 책임을 진다.
abstract class ShareFrameSink {
  Future<void> add(ui.Image image, int index);

  /// 남은 비동기 작업(파이프라인 in-flight frame 등) 완료 대기. 렌더 루프가
  /// 끝난 뒤, 인코딩 finalize(endCompose) 전에 반드시 호출.
  Future<void> finish();
}

/// frame을 [outputDir]에 `<prefix>_NNNN.png`로 굽어 [paths]에 경로를 모은다.
class PngFileSink implements ShareFrameSink {
  PngFileSink(this.outputDir, {this.prefix = 'frame', this.pad = 4});
  final Directory outputDir;
  final String prefix;
  final int pad;
  final List<String> paths = [];

  @override
  Future<void> add(ui.Image image, int index) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return;
    final path =
        '${outputDir.path}/${prefix}_${index.toString().padLeft(pad, '0')}.png';
    await File(path).writeAsBytes(byteData.buffer.asUint8List());
    paths.add(path);
  }

  @override
  Future<void> finish() async {}
}

/// frame을 raw RGBA(straight)로 뽑아 native streaming encoder로 append.
/// 호출 전 [VideoComposer.beginCompose]가 호출돼 있어야 하고, 모든 frame append
/// 후 호출자가 [VideoComposer.endCompose]로 마무리한다. Dart가 append를
/// await하므로 프레임당 backpressure가 걸려 메모리에 한 장씩만 존재.
class NativeStreamSink implements ShareFrameSink {
  int _count = 0;
  int get count => _count;

  // 직전 프레임의 native append. 다음 프레임 render(paint+toImage+readback,
  // UI isolate) 동안 native encoder(별도 스레드)가 인코딩을 병렬로 진행하도록,
  // append를 await하지 않고 걸어둔다. in-flight는 최대 1프레임(다음 add에서
  // 대기)이라 메모리는 ~2 buffer로 한정.
  Future<void> _pending = Future<void>.value();

  @override
  Future<void> add(ui.Image image, int index) async {
    final width = image.width;
    final height = image.height;
    // rawRgba(premultiplied, GPU 네이티브 포맷) — rawStraightRgba는 un-premultiply
    // 변환이 들어가 리드백이 느리다. frame이 불투명(alpha=255)이라 두 포맷의
    // RGB 값이 동일하므로 변환 없는 rawRgba를 써서 리드백을 단축한다.
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();
    // 이전 프레임 append 완료 대기(backpressure) → 이번 프레임은 걸어두고 반환.
    await _pending;
    _pending = VideoComposer.instance.appendRawFrame(
      bytes: bytes,
      width: width,
      height: height,
    );
    _count++;
  }

  @override
  Future<void> finish() => _pending;
}

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

  Future<void> renderFrames({
    required BuildContext context,
    required List<ShareFrame> frames,
    required ColorFilter? colorFilter,
    required ShareFrameSink sink,
    RenderProgress? onProgress,
    http.Client? client,
  }) async {
    final ownClient = client ?? http.Client();
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
        final image = await _captureFrame(
          context: context,
          frame: frame,
          imageBytes: bytes,
          colorFilter: colorFilter,
        );
        await sink.add(image, i);
        onProgress?.call(i + 1, frames.length);
      }
      return;
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

  /// 컨택트 시트 animation(reveal → hold → hide → hold)을 매 frame PNG로
  /// 굽어 슬라이드쇼 video pipeline에 그대로 넘긴다. 사진 수에 따라 cycle
  /// 총 길이가 동적이라 영상 길이도 자동 비례.
  Future<void> renderContactSheetAnimation({
    required BuildContext context,
    required List<ShareFrame> frames,
    required ColorFilter? colorFilter,
    required ShareFrameSink sink,
    required String sceneCoverUrl,
    required int sceneNumber,
    required String sceneTitle,
    int fps = 10,
    int maxOutputMs = 10000,
    RenderProgress? onProgress,
    http.Client? client,
  }) async {
    final ownClient = client ?? http.Client();
    final providers = <MemoryImage>[];
    try {
      // 모든 frame thumb 다운로드 + precache (memory + network 모두).
      // ContactSheetView는 NetworkImage(frame.url)로 그리고 그리드 셀이
      // 작아 thumb(600 long-edge)으로 충분. 같은 URL을 precache해야 view의
      // ImageCache hit. renderUrl(full)을 받으면 thumb이 또 다운로드되는 데다
      // 풀 화질을 작은 셀에서 못 보여 egress만 폭증.
      for (var i = 0; i < frames.length; i++) {
        if (!context.mounted) {
          throw StateError('Context unmounted during contact sheet render');
        }
        final bytes = await _download(frames[i].url, ownClient);
        if (!context.mounted) break;
        final provider = MemoryImage(bytes);
        await precacheImage(provider, context);
        providers.add(provider);
        if (!context.mounted) break;
        try {
          await precacheImage(NetworkImage(frames[i].url), context);
        } catch (_) {}
      }
      if (!context.mounted) {
        throw StateError('Context unmounted before contact sheet capture');
      }

      final naturalMs = ContactSheetView.totalCycleMs(frames.length);
      // 사진이 많으면 자연 cycle이 매우 길어지므로(N=100 ≈ 38s) maxOutputMs로
      // 영상 길이를 캡. progress 0..1은 그대로 cycle 전체를 sweep하니까 큰
      // N에서는 frame 간격이 커져 animation이 빠르게 흐름.
      final outputMs = math.min(naturalMs, maxOutputMs);
      final frameCount = (outputMs * fps / 1000).round().clamp(1, 2000);

      final progressNotifier = ValueNotifier<double>(0.0);
      final boundaryKey = GlobalKey();
      final overlay = Overlay.of(context);
      final mediaQuery = MediaQuery.of(context);
      final theme = Theme.of(context);
      final entry = OverlayEntry(
        builder: (_) {
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
                        child: ValueListenableBuilder<double>(
                          valueListenable: progressNotifier,
                          builder: (_, value, _) {
                            return ContactSheetView(
                              frames: frames,
                              colorFilter: colorFilter,
                              sceneCoverUrl: sceneCoverUrl,
                              sceneNumber: sceneNumber,
                              sceneTitle: sceneTitle,
                              isPlaying: false,
                              overrideProgress: value,
                            );
                          },
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
        // 첫 paint 대기.
        await SchedulerBinding.instance.endOfFrame;
        await SchedulerBinding.instance.endOfFrame;
        for (var i = 0; i < frameCount; i++) {
          if (!context.mounted) break;
          progressNotifier.value =
              frameCount == 1 ? 1.0 : i / (frameCount - 1);
          await SchedulerBinding.instance.endOfFrame;
          await SchedulerBinding.instance.endOfFrame;
          final renderObject = boundaryKey.currentContext?.findRenderObject();
          if (renderObject is! RenderRepaintBoundary) continue;
          final image = await renderObject.toImage(pixelRatio: _pixelRatio);
          await sink.add(image, i);
          onProgress?.call(i + 1, frameCount);
        }
      } finally {
        entry.remove();
      }
      return;
    } finally {
      if (client == null) ownClient.close();
      for (final p in providers) {
        PaintingBinding.instance.imageCache.evict(p);
      }
    }
  }

  /// Stack 템플릿 animation(좌→우 사진 등장 → canister reveal → fade out)을 매
  /// frame PNG로 굽어 video pipeline에 넘긴다. 사진 수에 따라 cycle 총 길이가
  /// 동적이라 영상 길이도 자동 비례. 구조는 [renderContactSheetAnimation]과
  /// 동일 — 다른 점은 mount하는 View와 totalCycleMs 산출만.
  Future<void> renderStackAnimation({
    required BuildContext context,
    required List<ShareFrame> frames,
    required ColorFilter? colorFilter,
    required ShareFrameSink sink,
    required String sceneCoverUrl,
    required int sceneNumber,
    required String sceneTitle,
    int fps = 12,
    // Stack 사이클은 reveal(가속) + disappear(가속)로 N에 거의 선형 비례.
    // stagger 하한 80ms 적용 후 N=30 ≈ 10s, N=50 ≈ 14s, N=100 ≈ 30s. 22s cap
    // 이면 N=80 이하는 자연 속도, 100은 ~1.4배 압축.
    int maxOutputMs = 22000,
    RenderProgress? onProgress,
    http.Client? client,
  }) async {
    final ownClient = client ?? http.Client();
    final providers = <MemoryImage>[];
    try {
      // StackShareView도 NetworkImage(frame.url)로 그리니까 같은 URL을 받아
      // ImageCache hit 되게.
      for (var i = 0; i < frames.length; i++) {
        if (!context.mounted) {
          throw StateError('Context unmounted during stack render');
        }
        final bytes = await _download(frames[i].url, ownClient);
        if (!context.mounted) break;
        final provider = MemoryImage(bytes);
        await precacheImage(provider, context);
        providers.add(provider);
        if (!context.mounted) break;
        try {
          await precacheImage(NetworkImage(frames[i].url), context);
        } catch (_) {}
      }
      if (!context.mounted) {
        throw StateError('Context unmounted before stack capture');
      }

      final naturalMs = StackShareView.totalCycleMs(frames.length);
      final outputMs = math.min(naturalMs, maxOutputMs);
      final frameCount = (outputMs * fps / 1000).round().clamp(1, 2000);

      final progressNotifier = ValueNotifier<double>(0.0);
      final boundaryKey = GlobalKey();
      final overlay = Overlay.of(context);
      final mediaQuery = MediaQuery.of(context);
      final theme = Theme.of(context);
      final entry = OverlayEntry(
        builder: (_) {
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
                        child: ValueListenableBuilder<double>(
                          valueListenable: progressNotifier,
                          builder: (_, value, _) {
                            return StackShareView(
                              frames: frames,
                              colorFilter: colorFilter,
                              sceneCoverUrl: sceneCoverUrl,
                              sceneNumber: sceneNumber,
                              sceneTitle: sceneTitle,
                              isPlaying: false,
                              overrideProgress: value,
                            );
                          },
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
        await SchedulerBinding.instance.endOfFrame;
        await SchedulerBinding.instance.endOfFrame;
        for (var i = 0; i < frameCount; i++) {
          if (!context.mounted) break;
          progressNotifier.value =
              frameCount == 1 ? 1.0 : i / (frameCount - 1);
          await SchedulerBinding.instance.endOfFrame;
          await SchedulerBinding.instance.endOfFrame;
          final renderObject = boundaryKey.currentContext?.findRenderObject();
          if (renderObject is! RenderRepaintBoundary) continue;
          final image = await renderObject.toImage(pixelRatio: _pixelRatio);
          await sink.add(image, i);
          onProgress?.call(i + 1, frameCount);
        }
      } finally {
        entry.remove();
      }
      return;
    } finally {
      if (client == null) ownClient.close();
      for (final p in providers) {
        PaintingBinding.instance.imageCache.evict(p);
      }
    }
  }

  /// Snake animation — 화면 중심을 도는 5장 trail. renderStackAnimation과
  /// 구조 동일, mount하는 View와 totalCycleMs만 다름.
  Future<void> renderSnakeAnimation({
    required BuildContext context,
    required List<ShareFrame> frames,
    required ColorFilter? colorFilter,
    required ShareFrameSink sink,
    required String sceneCoverUrl,
    required int sceneNumber,
    required String sceneTitle,
    int fps = 12,
    int maxOutputMs = 18000,
    RenderProgress? onProgress,
    http.Client? client,
  }) async {
    final ownClient = client ?? http.Client();
    final providers = <MemoryImage>[];
    try {
      for (var i = 0; i < frames.length; i++) {
        if (!context.mounted) {
          throw StateError('Context unmounted during snake render');
        }
        final bytes = await _download(frames[i].url, ownClient);
        if (!context.mounted) break;
        final provider = MemoryImage(bytes);
        await precacheImage(provider, context);
        providers.add(provider);
        if (!context.mounted) break;
        try {
          await precacheImage(NetworkImage(frames[i].url), context);
        } catch (_) {}
      }
      if (!context.mounted) {
        throw StateError('Context unmounted before snake capture');
      }

      final naturalMs = SnakeShareView.totalCycleMs(frames.length);
      final outputMs = math.min(naturalMs, maxOutputMs);
      final frameCount = (outputMs * fps / 1000).round().clamp(1, 2000);

      final progressNotifier = ValueNotifier<double>(0.0);
      final boundaryKey = GlobalKey();
      final overlay = Overlay.of(context);
      final mediaQuery = MediaQuery.of(context);
      final theme = Theme.of(context);
      final entry = OverlayEntry(
        builder: (_) {
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
                        child: ValueListenableBuilder<double>(
                          valueListenable: progressNotifier,
                          builder: (_, value, _) {
                            return SnakeShareView(
                              frames: frames,
                              colorFilter: colorFilter,
                              sceneCoverUrl: sceneCoverUrl,
                              sceneNumber: sceneNumber,
                              sceneTitle: sceneTitle,
                              isPlaying: false,
                              overrideProgress: value,
                            );
                          },
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
        await SchedulerBinding.instance.endOfFrame;
        await SchedulerBinding.instance.endOfFrame;
        for (var i = 0; i < frameCount; i++) {
          if (!context.mounted) break;
          progressNotifier.value =
              frameCount == 1 ? 1.0 : i / (frameCount - 1);
          await SchedulerBinding.instance.endOfFrame;
          await SchedulerBinding.instance.endOfFrame;
          final renderObject = boundaryKey.currentContext?.findRenderObject();
          if (renderObject is! RenderRepaintBoundary) continue;
          final image = await renderObject.toImage(pixelRatio: _pixelRatio);
          await sink.add(image, i);
          onProgress?.call(i + 1, frameCount);
        }
      } finally {
        entry.remove();
      }
      return;
    } finally {
      if (client == null) ownClient.close();
      for (final p in providers) {
        PaintingBinding.instance.imageCache.evict(p);
      }
    }
  }

  Future<ui.Image> _captureFrame({
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
      // toImage로 뽑은 ui.Image를 그대로 반환 — 직렬화(PNG/raw)는 sink가 담당.
      // 호출자(sink)가 dispose 책임.
      return await renderObject.toImage(pixelRatio: _pixelRatio);
    } finally {
      entry.remove();
      // 100장 batch 동안 ImageCache(100MB / 1000 entries)가 가득 차면 LRU
      // 축출이 다음 frame의 디코딩 중에 끼어들어 미완성 상태로 paint될 수 있음.
      // 매 frame 후 우리 entry를 즉시 비워 cache pressure 누적을 방지.
      PaintingBinding.instance.imageCache.evict(imageProvider);
    }
  }
}
