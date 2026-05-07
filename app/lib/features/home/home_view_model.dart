import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../couple/couple_view_model.dart';
import '../profile/profile_view_model.dart';
import '../scene/scenes_view_model.dart';
import 'models/couple.dart';
import 'models/scene.dart';

/// 홈 화면 상태 — 본인 profile + active couple + scenes 합성.
@immutable
class HomeState {
  const HomeState({
    required this.couple,
    required this.scenes,
    required this.currentPageIndex,
    this.isPaired = false,
  });

  final Couple couple;
  final List<Scene> scenes;
  final int currentPageIndex;
  final bool isPaired;

  HomeState copyWith({
    Couple? couple,
    List<Scene>? scenes,
    int? currentPageIndex,
    bool? isPaired,
  }) =>
      HomeState(
        couple: couple ?? this.couple,
        scenes: scenes ?? this.scenes,
        currentPageIndex: currentPageIndex ?? this.currentPageIndex,
        isPaired: isPaired ?? this.isPaired,
      );
}

class HomeViewModel extends Notifier<HomeState> {
  /// 화면이 직접 set한 currentPageIndex. ref.watch 결과로 build가 다시 돌 때
  /// 사용자 페이지 위치를 잃지 않도록 보존.
  int? _stickyPageIndex;

  @override
  HomeState build() {
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    final coupleData = ref.watch(activeCoupleProvider).valueOrNull;
    final scenesAsync = ref.watch(scenesProvider);
    final scenes = scenesAsync.valueOrNull ?? const <Scene>[];

    final partner = coupleData?.partner;
    // pairedAt = couples.linked_at (시스템 자동), sinceDate = couples.since_date
    // (사용자 편집).
    final pairedAt = coupleData?.couple.linkedAt ?? DateTime.now();
    final sinceDate = coupleData?.couple.sinceDate ?? pairedAt;

    // displayName/displayAvatarUrl getter로 마스킹 처리. 본인 profile이 deleted
    // 상태에서 active couple이 살아있는 시나리오는 트리거가 막아줘 실제로는
    // 발생 안 하지만, 옛 콘텐츠가 표시되는 우회 경로 등을 위해 일관 적용.
    final couple = Couple(
      name: (myProfile != null && partner != null)
          ? '${myProfile.displayName} & ${partner.displayName}'
          : '',
      partnerAName: myProfile?.displayName ?? '',
      partnerBName: partner?.displayName ?? '',
      partnerAImageUrl: myProfile?.displayAvatarUrl ?? '',
      partnerBImageUrl: partner?.displayAvatarUrl ?? '',
      pairedAt: pairedAt,
      sinceDate: sinceDate,
    );

    // 최초 진입 시 가장 최신(마지막) scene에 포커스. 사용자가 페이지를 이동
    // 했었으면 그 위치 유지.
    final defaultIndex = scenes.isEmpty ? 0 : scenes.length - 1;
    final pageIndex = _stickyPageIndex == null
        ? defaultIndex
        : _stickyPageIndex!.clamp(0, scenes.isEmpty ? 0 : scenes.length - 1);

    return HomeState(
      couple: couple,
      scenes: scenes,
      currentPageIndex: pageIndex,
      isPaired: coupleData != null,
    );
  }

  void setPageIndex(int index) {
    if (state.currentPageIndex == index) return;
    _stickyPageIndex = index;
    state = state.copyWith(currentPageIndex: index);
  }

  Future<void> updateSinceDate(DateTime date) async {
    await ref.read(activeCoupleProvider.notifier).updateSinceDate(date);
    // build()가 activeCoupleProvider를 watch하므로 state는 자동으로 새 since_date
    // 반영. 추가 setState 불필요.
  }

  Future<void> reorderScenes(List<Scene> newOrder) async {
    await ref.read(scenesProvider.notifier).reorder(newOrder);
  }
}

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);
