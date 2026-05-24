import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 푸시 알림 탭으로부터 들어온 딥링크 의도.
///
/// 알림 발송 시 트리거가 박아 둔 data payload(scene_id / content_id / kind)를
/// 그대로 옮긴다. 라우팅 측(`HomeView`)이 이 인텐트를 watch해 적절한 화면으로
/// 이동시킨 뒤 [PushDeeplinkController.consume]으로 비운다.
class PushDeeplink {
  const PushDeeplink({
    required this.kind,
    this.sceneId,
    this.contentId,
  });

  /// 'scene' | 'photo' | 'video' | 'film' | 'music' | 'place' | 'reaction'.
  final String kind;
  final String? sceneId;
  final String? contentId;

  /// FCM RemoteMessage의 data map에서 파싱.
  static PushDeeplink? fromRemote(RemoteMessage msg) =>
      fromMap(msg.data);

  /// 평탄한 map(scene_id / content_id / kind)에서 파싱. 네이티브에서 직접
  /// 받아온 userInfo도 같은 키 구조라 그대로 통과.
  static PushDeeplink? fromMap(Map<String, dynamic> data) {
    final kind = data['kind'];
    final sceneId = data['scene_id'];
    if (kind is! String || sceneId is! String || sceneId.isEmpty) {
      return null;
    }
    final contentId = data['content_id'];
    return PushDeeplink(
      kind: kind,
      sceneId: sceneId,
      contentId: (contentId is String && contentId.isNotEmpty)
          ? contentId
          : null,
    );
  }
}

class PushDeeplinkController extends Notifier<PushDeeplink?> {
  @override
  PushDeeplink? build() => null;

  void set(PushDeeplink? intent) => state = intent;

  /// 라우팅 후 호출 — 다음 알림까지 비워둔다.
  void consume() => state = null;
}

final pushDeeplinkProvider =
    NotifierProvider<PushDeeplinkController, PushDeeplink?>(
  PushDeeplinkController.new,
);
