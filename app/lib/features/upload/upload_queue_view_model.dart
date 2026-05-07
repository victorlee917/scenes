import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';

import '../content/contents_view_model.dart';
import '../content/data/content_repository.dart';
import '../content/data/photo_metadata_extractor.dart';
import '../home/models/place_hit.dart';
import '../home/models/spotify_hit.dart';
import '../home/models/tmdb_film.dart';
import '../scene/scenes_view_model.dart';
import 'upload_task.dart';

/// 백그라운드 업로드 큐.
///
/// 각 picker는 Save 버튼을 누르는 즉시 enqueue 후 닫히고, 실제 압축·전송은
/// 이 notifier가 main isolate에서 비동기로 처리. UI는 [uploadQueueProvider]를
/// watch하는 [UploadProgressChip]이 표시.
///
/// 영속성은 의도적으로 안 둠(in-memory only) — 앱 강제 종료/스왑아웃 시
/// 진행 중인 task 손실. 이는 "Light" 백그라운드 패스의 트레이드오프
/// (memory: project_backlog 참고). 진정한 OS 백그라운드는 별개 작업.
class UploadQueueNotifier extends Notifier<List<UploadTask>> {
  /// task id별 in-flight HTTP 클라이언트. cancel 호출 시 close()로 즉시 abort.
  final Map<String, http.Client> _clients = {};

  /// cancel 요청된 task id 집합. 배치 루프가 매 iteration 시작 전에 체크.
  final Set<String> _cancelled = {};

  /// task id별 photo 잡 큐. 진행 중 task에 새 batch가 들어오면 여기에 append
  /// 되고 runner의 while 루프가 자연스럽게 픽업. 잡마다 자기 isHd/momentDate를
  /// 들고 있어 batch 사이 설정이 바뀌어도 정확히 적용됨.
  final Map<String, List<_PhotoJob>> _photoQueues = {};

  @override
  List<UploadTask> build() => const [];

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 16)}';

  void _add(UploadTask t) {
    state = [...state, t];
  }

  void _patch(String id, UploadTask Function(UploadTask) f) {
    state = [
      for (final t in state)
        if (t.id == id) f(t) else t,
    ];
  }

  void _remove(String id) {
    state = state.where((t) => t.id != id).toList(growable: false);
    _clients.remove(id);
    _cancelled.remove(id);
    _photoQueues.remove(id);
  }

  /// done은 잠깐 체크 표시 후, failed는 사용자가 인지할 시간을 더 두고 dismiss.
  /// 캐니스터 오버레이에는 명시적 dismiss UI가 없어 둘 다 시간 기반으로 정리.
  void _scheduleAutoDismiss(String id, {Duration? after}) {
    Future.delayed(after ?? const Duration(milliseconds: 1600), () {
      if (state.any((t) => t.id == id)) _remove(id);
    });
  }

  /// 진행 중 task 취소. cancel은 photo batch에 대해서만 의미가 있음
  /// (film/music/place는 단일 빠른 호출이라 cancel UI 미노출).
  void cancel(String id) {
    if (_cancelled.contains(id)) return;
    _cancelled.add(id);
    _clients[id]?.close();
    _patch(id, (t) => t.copyWith(status: UploadStatus.cancelling));
  }

  /// 사용자가 chip의 X를 눌러 done/failed 상태 task를 명시적으로 제거.
  void dismiss(String id) {
    _remove(id);
  }

  // ── photo (batch) ───────────────────────────────────────────

  /// thumb 변형 — grid/list 표시용. 모든 tier 동일.
  static const _thumbLongEdge = 600;
  static const _thumbQuality = 75;

  /// full 변형 — 모든 tier 동일하게 1920px / q85. 폰 화면(보통 1080–1440px)
  /// 에서 가장 크게 표시되는 play 화면도 1920이면 retina 다운샘플링 후 동일
  /// 한 결과 — 3000px은 in-app 효용 0이고 egress 비용만 6–10배. HD tier의
  /// 차별화는 count/media types/reorder/multi-play/filters 등 features에 있음.
  static const _fullLongEdge = 1920;
  static const _fullQuality = 85;

  /// 사진 batch enqueue. 같은 scene에 active photo task가 이미 있으면 그
  /// task의 큐에 append + totalCount만 증가 — 사용자가 "추가로 더 올림"을
  /// 단일 진행률로 볼 수 있게.
  ///
  /// active가 아닌 (cancelling/done/failed) task와는 머지하지 않고 새 task
  /// 생성.
  void enqueuePhotos({
    required String sceneId,
    required String sceneTitle,
    required List<AssetEntity> assets,
    DateTime? momentDate,
  }) {
    if (assets.isEmpty) return;
    final newJobs = [
      for (final a in assets) _PhotoJob(asset: a, momentDate: momentDate),
    ];

    for (final t in state) {
      if (t.sceneId == sceneId &&
          t.kind == UploadKind.photo &&
          t.status == UploadStatus.active) {
        // 머지 — 기존 큐에 잡 추가 + totalCount 증가. runner는 while-loop
        // 이라 다음 iteration에서 자동으로 픽업.
        _photoQueues[t.id]?.addAll(newJobs);
        _patch(
          t.id,
          (cur) => cur.copyWith(totalCount: cur.totalCount + newJobs.length),
        );
        return;
      }
    }

    final id = _newId();
    _photoQueues[id] = List.of(newJobs);
    _add(
      UploadTask(
        id: id,
        sceneId: sceneId,
        sceneTitle: sceneTitle,
        kind: UploadKind.photo,
        totalCount: newJobs.length,
        completedCount: 0,
        status: UploadStatus.active,
      ),
    );
    // ignore: discarded_futures
    _runPhotos(id: id, sceneId: sceneId);
  }

  Future<void> _runPhotos({
    required String id,
    required String sceneId,
  }) async {
    final client = http.Client();
    _clients[id] = client;
    final repo = ref.read(contentRepositoryProvider);
    final notifier =
        ref.read(contentsForSceneProvider(sceneId).notifier);
    final queue = _photoQueues[id]!;

    var uploaded = 0;
    var failed = 0;

    // while-loop으로 큐가 빌 때까지 — 진행 중에 enqueuePhotos가 머지로 잡을
    // 더 넣어도 자동으로 픽업. Dart 단일 스레드 모델 상 await 사이에만 머지가
    // 일어날 수 있고, 매 iteration 시작 전 isNotEmpty 재평가로 race 없음.
    while (queue.isNotEmpty) {
      if (_cancelled.contains(id)) break;
      final job = queue.removeAt(0);
      try {
        final originBytes = await job.asset.originBytes;
        if (_cancelled.contains(id)) break;
        if (originBytes == null || originBytes.isEmpty) {
          failed++;
        } else {
          final meta = await PhotoMetadataExtractor.extract(
            asset: job.asset,
            originBytes: originBytes,
          );
          final thumbBytes = await _resizeJpeg(
            originBytes: originBytes,
            srcW: job.asset.width,
            srcH: job.asset.height,
            targetLongEdge: _thumbLongEdge,
            quality: _thumbQuality,
          );
          if (_cancelled.contains(id)) break;
          final fullBytes = await _resizeJpeg(
            originBytes: originBytes,
            srcW: job.asset.width,
            srcH: job.asset.height,
            targetLongEdge: _fullLongEdge,
            quality: _fullQuality,
          );
          if (_cancelled.contains(id)) break;
          final content = await repo.uploadPhoto(
            sceneId: sceneId,
            fullBytes: fullBytes,
            thumbBytes: thumbBytes,
            payloadMeta: meta.toPayloadJson(),
            occurredAt: job.momentDate,
            client: client,
          );
          notifier.appendUploaded(content);
          uploaded++;
        }
      } catch (e) {
        // cancel 누른 직후엔 client.close()로 in-flight 요청이 끊겨 throw됨.
        // 이건 실패가 아니라 취소이므로 카운트 안 하고 break.
        if (_cancelled.contains(id)) break;
        debugPrint('photo upload failed: $e');
        failed++;
      }
      _patch(id, (t) => t.copyWith(completedCount: t.completedCount + 1));
    }

    client.close();
    _clients.remove(id);
    _photoQueues.remove(id);

    // 한 장이라도 commit 됐으면 홈/리스트의 type별 count(scene_summary 뷰
    // → scenesProvider)를 fire-and-forget으로 갱신.
    if (uploaded > 0) {
      // ignore: discarded_futures
      ref.read(scenesProvider.notifier).softRefresh();
    }

    final wasCancelled = _cancelled.contains(id);
    if (wasCancelled) {
      // 일부 commit됐을 수 있음 — done 처리해 chip을 정리.
      _patch(
        id,
        (t) => t.copyWith(
          status: UploadStatus.done,
          completedCount: uploaded,
        ),
      );
      _scheduleAutoDismiss(id);
    } else if (failed > 0 && uploaded == 0) {
      _patch(
        id,
        (t) => t.copyWith(status: UploadStatus.failed),
      );
      _scheduleAutoDismiss(id, after: const Duration(milliseconds: 4000));
    } else {
      _patch(
        id,
        (t) => t.copyWith(
          status: UploadStatus.done,
          completedCount: uploaded,
        ),
      );
      _scheduleAutoDismiss(id);
    }
  }

  // ── film / music / place (single) ───────────────────────────

  void enqueueFilm({
    required String sceneId,
    required String sceneTitle,
    required TmdbFilm film,
    DateTime? momentDate,
  }) {
    final id = _newId();
    _add(
      UploadTask(
        id: id,
        sceneId: sceneId,
        sceneTitle: sceneTitle,
        kind: UploadKind.film,
        totalCount: 1,
        completedCount: 0,
        status: UploadStatus.active,
      ),
    );
    // ignore: discarded_futures
    _runSingle(
      id: id,
      sceneId: sceneId,
      doUpload: () => ref.read(contentRepositoryProvider).uploadFilm(
            sceneId: sceneId,
            film: film,
            occurredAt: momentDate,
          ),
    );
  }

  void enqueueMusic({
    required String sceneId,
    required String sceneTitle,
    required SpotifyHit hit,
    DateTime? momentDate,
  }) {
    final id = _newId();
    _add(
      UploadTask(
        id: id,
        sceneId: sceneId,
        sceneTitle: sceneTitle,
        kind: UploadKind.music,
        totalCount: 1,
        completedCount: 0,
        status: UploadStatus.active,
      ),
    );
    // ignore: discarded_futures
    _runSingle(
      id: id,
      sceneId: sceneId,
      doUpload: () => ref.read(contentRepositoryProvider).uploadMusic(
            sceneId: sceneId,
            hit: hit,
            occurredAt: momentDate,
          ),
    );
  }

  void enqueuePlace({
    required String sceneId,
    required String sceneTitle,
    required PlaceHit place,
    DateTime? momentDate,
  }) {
    final id = _newId();
    _add(
      UploadTask(
        id: id,
        sceneId: sceneId,
        sceneTitle: sceneTitle,
        kind: UploadKind.place,
        totalCount: 1,
        completedCount: 0,
        status: UploadStatus.active,
      ),
    );
    // ignore: discarded_futures
    _runSingle(
      id: id,
      sceneId: sceneId,
      doUpload: () => ref.read(contentRepositoryProvider).uploadPlace(
            sceneId: sceneId,
            place: place,
            occurredAt: momentDate,
          ),
    );
  }

  Future<void> _runSingle({
    required String id,
    required String sceneId,
    required Future<dynamic> Function() doUpload,
  }) async {
    final notifier =
        ref.read(contentsForSceneProvider(sceneId).notifier);
    try {
      final content = await doUpload();
      notifier.appendUploaded(content);
      // ignore: discarded_futures
      ref.read(scenesProvider.notifier).softRefresh();
      _patch(
        id,
        (t) => t.copyWith(
          completedCount: 1,
          status: UploadStatus.done,
        ),
      );
      _scheduleAutoDismiss(id);
    } catch (e) {
      debugPrint('upload failed: $e');
      _patch(id, (t) => t.copyWith(status: UploadStatus.failed));
      _scheduleAutoDismiss(id, after: const Duration(milliseconds: 4000));
    }
  }
}

/// long edge target에 종횡비 보존 리사이즈. photo_picker에서 옮겨옴.
/// HEIC 포함 모든 입력을 native에서 디코딩해 JPEG으로 재인코딩.
/// EXIF는 payload로만 보내고 JPEG에 안 박지만 [autoCorrectionAngle]로 픽셀
/// 자체를 미리 회전시켜 orientation 태그가 사라져도 표시 어긋남 방지.
Future<Uint8List> _resizeJpeg({
  required Uint8List originBytes,
  required int srcW,
  required int srcH,
  required int targetLongEdge,
  required int quality,
}) async {
  final longEdge = math.max(srcW, srcH);
  final shortEdge = math.min(srcW, srcH);
  int targetShort;
  if (longEdge == 0 || shortEdge == 0) {
    targetShort = targetLongEdge;
  } else if (longEdge <= targetLongEdge) {
    targetShort = shortEdge;
  } else {
    final scale = targetLongEdge / longEdge;
    targetShort = (shortEdge * scale).round();
  }
  return FlutterImageCompress.compressWithList(
    originBytes,
    minWidth: targetShort,
    minHeight: targetShort,
    quality: quality,
    format: CompressFormat.jpeg,
    keepExif: false,
    autoCorrectionAngle: true,
  );
}

/// photo 큐의 한 잡. momentDate를 잡 단위로 들고 있어 머지된 batch들이
/// 다른 날짜로 들어와도 각자 정확히 적용됨.
class _PhotoJob {
  const _PhotoJob({
    required this.asset,
    this.momentDate,
  });
  final AssetEntity asset;
  final DateTime? momentDate;
}

final uploadQueueProvider =
    NotifierProvider<UploadQueueNotifier, List<UploadTask>>(
  UploadQueueNotifier.new,
);
