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
    this.isLoggedIn = true,
    this.hasProfile = true,
    this.isPaired = true,
  });

  final Couple couple;
  final List<Scene> scenes;
  final int currentPageIndex;
  final bool isLoggedIn;
  final bool hasProfile;
  final bool isPaired;

  HomeState copyWith({
    Couple? couple,
    List<Scene>? scenes,
    int? currentPageIndex,
    bool? isLoggedIn,
    bool? hasProfile,
    bool? isPaired,
  }) =>
      HomeState(
        couple: couple ?? this.couple,
        scenes: scenes ?? this.scenes,
        currentPageIndex: currentPageIndex ?? this.currentPageIndex,
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        hasProfile: hasProfile ?? this.hasProfile,
        isPaired: isPaired ?? this.isPaired,
      );
}

class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() {
    return HomeState(
      couple: _mockCouple,
      scenes: _mockScenes,
      // 최초 진입 시 가장 최신(마지막) Scene에 포커스.
      currentPageIndex:
          _mockScenes.isEmpty ? 0 : _mockScenes.length - 1,
      isLoggedIn: false, // TODO: Supabase 연동 시 실제 로그인 상태로 교체
      hasProfile: true, // TODO: Supabase 연동 시 실제 프로필 상태로 교체
      isPaired: true, // TODO: Supabase 연동 시 실제 페어링 상태로 교체
    );
  }

  void setPageIndex(int index) {
    if (state.currentPageIndex == index) return;
    state = state.copyWith(currentPageIndex: index);
  }

  void updateSinceDate(DateTime date) {
    state = state.copyWith(couple: state.couple.copyWith(sinceDate: date));
  }

  void setLoggedIn(bool loggedIn) {
    state = state.copyWith(isLoggedIn: loggedIn);
  }

  void setProfileComplete(bool complete) {
    state = state.copyWith(hasProfile: complete);
  }

  void setPaired(bool paired) {
    state = state.copyWith(isPaired: paired);
  }

  void reorderScenes(List<Scene> newOrder) {
    final renumbered = [
      for (int i = 0; i < newOrder.length; i++)
        newOrder[i].copyWith(number: i + 1),
    ];
    state = state.copyWith(scenes: renumbered);
  }

  // ── Mock data (Supabase 연결 전 임시) ────────────────────────────
  static final Couple _mockCouple = Couple(
    name: 'Sora & Jun',
    partnerAName: 'Sora',
    partnerBName: 'Jun',
    partnerAImageUrl: 'https://picsum.photos/seed/scenes-partner-a/200/200',
    partnerBImageUrl: 'https://picsum.photos/seed/scenes-partner-b/200/200',
    pairedAt: DateTime(2025, 4, 3),
  );

  // 오래된 것 → 최신 순. 가장 최신 Scene이 배열 맨 뒤(가장 큰 인덱스).
  static final List<Scene> _mockScenes = <Scene>[
    Scene(
      id: 's9',
      number: 9,
      title: 'Long Drive',
      dates: [DateTime(2026, 3, 7)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-9/900/1400',
      media: const SceneMediaCounts(photos: 15, music: 18),
    ),
    Scene(
      id: 's10',
      number: 10,
      title: '자정 너머의 Balcony',
      dates: [DateTime(2026, 3, 14), DateTime(2026, 3, 15)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-10/900/1400',
      media: const SceneMediaCounts(photos: 8, videos: 1, music: 4),
    ),
    Scene(
      id: 's11',
      number: 11,
      title: '페이지 64',
      dates: [DateTime(2026, 3, 22)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-11/900/1400',
      media: const SceneMediaCounts(photos: 3, books: 2),
    ),
    Scene(
      id: 's12',
      number: 12,
      title: 'Golden Hour',
      dates: [DateTime(2026, 3, 29)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-12/900/1400',
      media: const SceneMediaCounts(photos: 5),
    ),
    Scene(
      id: 's13',
      number: 13,
      title: '주말 바다',
      dates: [DateTime(2026, 4, 5), DateTime(2026, 4, 6)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-13/900/1400',
      media: const SceneMediaCounts(photos: 24, videos: 4, films: 1, music: 6, places: 3),
    ),
    Scene(
      id: 's14',
      number: 14,
      title: 'Under the Umbrella',
      dates: [DateTime(2026, 4, 11), DateTime(2026, 4, 12)],
      coverImageUrl: 'https://picsum.photos/seed/scenes-14/900/1400',
      media: const SceneMediaCounts(photos: 12, videos: 2, music: 3),
    ),
  ];
}

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);
