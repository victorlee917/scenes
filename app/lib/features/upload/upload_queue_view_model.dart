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
import '../home/models/photo_metadata.dart';
import '../home/models/place_hit.dart';
import '../home/models/spotify_hit.dart';
import '../home/models/tmdb_film.dart';
import '../scene/scenes_view_model.dart';
import '../subscription/subscription_view_model.dart';
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

  /// thumb 변형은 OS 캐시 thumbnail(JPEG)을 직접 사용 — 인코드 비용 ~0,
  /// 파일 사이즈는 WebP 대비 10~20% 큼(50KB→60KB 수준이라 무시 가능).

  /// full 변형 — tier별 차등. free는 retina 폰 화면에서 1.3~1.5x 업스케일이
  /// 일어나도 무난한 1920/q80, HD는 폰 native 해상도(2500~2800px) 매칭 + q82
  /// 로 디테일/링잉 모두 개선. q82는 q85 대비 시각 차이 미세하면서 인코드 +
  /// 파일 모두 ~15% 절감. HD pair 한 명이라도 있으면 페어 전체 적용.
  static const _fullLongEdgeFree = 1920;
  static const _fullQualityFree = 80;
  static const _fullLongEdgeHd = 2560;
  static const _fullQualityHd = 82;

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
    // 구독 상태는 enqueue 시점 스냅샷 — 잡이 큐에서 도는 동안 바뀌어도 일관.
    // 미로드/null이면 free로 안전 fallback.
    final isHd =
        ref.read(subscriptionViewModelProvider).valueOrNull?.isSubscribed ??
            false;
    final newJobs = [
      for (final a in assets)
        _PhotoJob(asset: a, isHd: isHd, momentDate: momentDate),
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

  /// 한 사진의 byte 준비 — thumb은 OS 캐시 thumbnail(JPEG, ~즉시), full은 WebP
  /// 인코드. 둘은 서로 독립이라 originBytes 로드와 동시에 thumb fetch가 흐름.
  /// originBytes/thumbnail 실패는 null 반환 → 호출자가 failed로 카운트.
  Future<_PreparedPhoto?> _preparePhoto(_PhotoJob job) async {
    // thumb 요청은 originBytes 로드와 무관 — iOS Photos가 이미 캐시한 JPEG
    // 썸네일을 native에서 즉시 돌려줌. 가능한 한 이른 시점에 시작.
    final thumbFuture = job.asset.thumbnailDataWithSize(
      const ThumbnailSize(600, 600),
      format: ThumbnailFormat.jpeg,
      quality: 85,
    );
    final originBytes = await job.asset.originBytes;
    if (originBytes == null || originBytes.isEmpty) {
      // pending future를 그냥 두면 native에서 unhandled로 남으니 drain.
      await thumbFuture;
      return null;
    }
    final meta = await PhotoMetadataExtractor.extract(
      asset: job.asset,
      originBytes: originBytes,
    );
    final fullBytes = await _resizeWebp(
      originBytes: originBytes,
      srcW: job.asset.width,
      srcH: job.asset.height,
      targetLongEdge: job.isHd ? _fullLongEdgeHd : _fullLongEdgeFree,
      quality: job.isHd ? _fullQualityHd : _fullQualityFree,
    );
    final thumbBytes = await thumbFuture;
    if (thumbBytes == null || thumbBytes.isEmpty) return null;
    return _PreparedPhoto(
      fullBytes: fullBytes,
      thumbBytes: thumbBytes,
      meta: meta,
      momentDate: job.momentDate,
    );
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

    // 파이프라이닝: 현재 사진이 네트워크 업로드 중일 때 다음 사진의 byte
    // 준비(decode + WebP encode)가 백그라운드로 동시 진행. 동시 CPU 부하는
    // 한 사진 prep으로 제한 — 둘 이상이 동시에 인코드 돌면 contention. 큐가
    // 비어 nextPrep이 null이면 그대로 직렬 동작과 동일.
    Future<_PreparedPhoto?>? nextPrep;
    while (true) {
      if (_cancelled.contains(id)) break;
      Future<_PreparedPhoto?> currentPrep;
      if (nextPrep != null) {
        currentPrep = nextPrep;
        nextPrep = null;
      } else if (queue.isNotEmpty) {
        currentPrep = _preparePhoto(queue.removeAt(0));
      } else {
        break;
      }

      try {
        final prepared = await currentPrep;
        if (_cancelled.contains(id)) break;
        if (prepared == null) {
          failed++;
        } else {
          // 다음 사진의 prep을 *지금* kick off — 이 사진의 upload(네트워크
          // wait) 동안 백그라운드 CPU에서 인코드 진행.
          if (queue.isNotEmpty && nextPrep == null) {
            nextPrep = _preparePhoto(queue.removeAt(0));
          }
          final content = await repo.uploadPhoto(
            sceneId: sceneId,
            fullBytes: prepared.fullBytes,
            thumbBytes: prepared.thumbBytes,
            payloadMeta: prepared.meta.toPayloadJson(),
            occurredAt: prepared.momentDate,
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
    // 사진 batch 통합 푸시는 옛 빌드 호환성 문제로 trigger per-row 발송으로
    // 환원됨(notify_partner_activity가 photo도 직접 발송). 여기서 RPC는 안
    // 부른다 — 부르면 trigger와 중복 발송됨.

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

/// long edge target에 종횡비 보존 리사이즈. HEIC 포함 모든 입력을 native에서
/// 디코딩해 WebP로 재인코딩. JPEG 대비 동일 시각 품질에 30~40% 작은 파일.
/// EXIF는 payload로만 보내고 인코딩 결과엔 안 박지만 [autoCorrectionAngle]로
/// 픽셀 자체를 미리 회전시켜 orientation 태그가 사라져도 표시 어긋남 방지.
Future<Uint8List> _resizeWebp({
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
    format: CompressFormat.webp,
    keepExif: false,
    autoCorrectionAngle: true,
  );
}

/// 한 사진의 byte 준비 결과 — `_runPhotos`의 파이프라이닝에서 prep과 upload
/// 사이에 byte/meta를 옮기는 그릇.
class _PreparedPhoto {
  const _PreparedPhoto({
    required this.fullBytes,
    required this.thumbBytes,
    required this.meta,
    required this.momentDate,
  });
  final Uint8List fullBytes;
  final Uint8List thumbBytes;
  final PhotoMetadata meta;
  final DateTime? momentDate;
}

/// photo 큐의 한 잡. momentDate / isHd 모두 잡 단위 스냅샷 — 머지된 batch
/// 들이 다른 날짜로 들어오거나 도중에 구독 상태가 바뀌어도 각 잡은 enqueue
/// 시점의 결정 사항을 그대로 따라감.
class _PhotoJob {
  const _PhotoJob({
    required this.asset,
    required this.isHd,
    this.momentDate,
  });
  final AssetEntity asset;
  final bool isHd;
  final DateTime? momentDate;
}

final uploadQueueProvider =
    NotifierProvider<UploadQueueNotifier, List<UploadTask>>(
  UploadQueueNotifier.new,
);
