import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_view_model.dart';
import 'data/profile_repository.dart';
import 'models/profile.dart';

/// 현재 로그인 유저의 profile.
///
/// 로그인 상태가 바뀌면 자동 refetch. 미로그인 시 null.
class MyProfileViewModel extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // 세션 변동 감지 — 로그인/로그아웃 시 build 재실행되어 새 profile 로드.
    final session = ref.watch(authViewModelProvider.select((s) => s.session));
    if (session == null) return null;
    return ref.read(profileRepositoryProvider).getMyProfile();
  }

  /// profile-setup 완료. 성공 시 state 갱신 → router의 isOnboarded 셀렉터가 true로 바뀌어
  /// 자동 redirect.
  Future<void> completeOnboarding({
    required String name,
    File? avatarFile,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(profileRepositoryProvider);
      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await repo.uploadAvatar(avatarFile);
      }
      return repo.completeOnboarding(
        name: name,
        avatarUrl: avatarUrl,
      );
    });
  }

  /// 온보딩 이후 프로필 편집. 두 단계로 분리:
  ///
  /// 1. [updateProfileRemote]: 네트워크 호출만. state는 안 건드림.
  /// 2. [applyProfile]: 받아온 결과를 state에 반영 — UI rebuild 트리거.
  ///
  /// 이렇게 분리해야 호출자가 'state 업데이트를 sheet pop 애니메이션 끝난 뒤로'
  /// 같은 시점 제어가 가능. 한 메서드로 합치면 state 변경 직후 watchers가 같은
  /// 프레임에 rebuild되면서 pop 애니메이션이 끊겨 보임.
  Future<Profile> updateProfileRemote({
    String? name,
    File? avatarFile,
  }) async {
    final repo = ref.read(profileRepositoryProvider);
    String? avatarUrl;
    if (avatarFile != null) {
      avatarUrl = await repo.uploadAvatar(avatarFile);
    }
    return repo.updateProfile(name: name, avatarUrl: avatarUrl);
  }

  void applyProfile(Profile profile) {
    state = AsyncValue<Profile?>.data(profile);
  }

  /// 외부 강제 갱신 (예: pull-to-refresh, 파트너의 변경 감지 등).
  Future<void> refresh() async {
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).getMyProfile();
    });
  }
}

final myProfileProvider =
    AsyncNotifierProvider<MyProfileViewModel, Profile?>(MyProfileViewModel.new);

/// 자주 쓰는 셀렉터 — onboarding 완료 여부.
final isOnboardedProvider = Provider<bool>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  return profile != null && profile.isOnboarded;
});
