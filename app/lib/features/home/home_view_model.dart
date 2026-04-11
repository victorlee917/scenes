import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/couple.dart';
import 'models/scene.dart';

/// 홈 화면 상태. 네트워크/영속 소스는 아직 붙지 않았고 mock으로 초기화된다.
@immutable
class HomeState {
  const HomeState({
    required this.couple,
    required this.scenes,
    required this.currentPageIndex,
  });

  final Couple couple;
  final List<Scene> scenes;
  final int currentPageIndex;

  HomeState copyWith({
    Couple? couple,
    List<Scene>? scenes,
    int? currentPageIndex,
  }) =>
      HomeState(
        couple: couple ?? this.couple,
        scenes: scenes ?? this.scenes,
        currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      );
}

class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() {
    return HomeState(
      couple: _mockCouple,
      scenes: _mockScenes,
      currentPageIndex: 0,
    );
  }

  void setPageIndex(int index) {
    if (state.currentPageIndex == index) return;
    state = state.copyWith(currentPageIndex: index);
  }

  // ── Mock data (Supabase 연결 전 임시) ────────────────────────────
  static final Couple _mockCouple = Couple(
    partnerAImageUrl: 'https://picsum.photos/seed/scenes-partner-a/200/200',
    partnerBImageUrl: 'https://picsum.photos/seed/scenes-partner-b/200/200',
    sinceDate: DateTime(2025, 4, 3),
  );

  static final List<Scene> _mockScenes = <Scene>[
    Scene(
      id: 's14',
      number: 14,
      title: '저 우산 아래서',
      dates: [DateTime(2026, 4, 11), DateTime(2026, 4, 12)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-14/900/1400',
    ),
    Scene(
      id: 's13',
      number: 13,
      title: '주말 바다',
      dates: [DateTime(2026, 4, 5), DateTime(2026, 4, 6)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-13/900/1400',
    ),
    Scene(
      id: 's12',
      number: 12,
      title: '7시 42분의 부엌',
      dates: [DateTime(2026, 3, 29)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-12/900/1400',
    ),
    Scene(
      id: 's11',
      number: 11,
      title: '페이지 64',
      dates: [DateTime(2026, 3, 22)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-11/900/1400',
    ),
    Scene(
      id: 's10',
      number: 10,
      title: '자정 너머의 발코니',
      dates: [DateTime(2026, 3, 14), DateTime(2026, 3, 15)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-10/900/1400',
    ),
    Scene(
      id: 's9',
      number: 9,
      title: '긴 드라이브',
      dates: [DateTime(2026, 3, 7)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-9/900/1400',
    ),
  ];
}

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);
