import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/lock_repository.dart';

/// 잠금 상태.
///
/// - [enabled]: PIN이 설정되어 잠금이 ON인지.
/// - [biometricEnabled]: 생체 인증 토글 ON 여부. enabled가 false면 의미 없음.
/// - [biometricAvailable]: 디바이스에 생체 인증이 가용한지(미등록/미지원이면
///   false).
/// - [isLocked]: 지금 잠금 challenge가 필요한지. true면 LockChallengeScreen
///   오버레이가 뜸.
@immutable
class LockState {
  const LockState({
    this.enabled = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.isLocked = false,
  });

  final bool enabled;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final bool isLocked;

  LockState copyWith({
    bool? enabled,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? isLocked,
  }) =>
      LockState(
        enabled: enabled ?? this.enabled,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        biometricAvailable: biometricAvailable ?? this.biometricAvailable,
        isLocked: isLocked ?? this.isLocked,
      );
}

class LockViewModel extends AsyncNotifier<LockState> {
  @override
  Future<LockState> build() async {
    final repo = ref.read(lockRepositoryProvider);
    final enabled = await repo.isEnabled();
    final biometricEnabled = enabled && await repo.isBiometricEnabled();
    final biometricAvailable = await repo.isBiometricAvailable();
    return LockState(
      enabled: enabled,
      biometricEnabled: biometricEnabled,
      biometricAvailable: biometricAvailable,
      // 콜드 스타트: lock이 켜져 있으면 challenge 노출. 사용자가 PIN/생체로
      // 풀고 본 화면 진입.
      isLocked: enabled,
    );
  }

  /// PIN 신규 설정. 기존 잠금이 켜져 있으면 이걸 부르기 전에 verify 필요
  /// (UI 책임).
  Future<void> setPin(String pin) async {
    final repo = ref.read(lockRepositoryProvider);
    await repo.setPin(pin);
    final cur = state.valueOrNull ?? const LockState();
    state = AsyncValue.data(cur.copyWith(enabled: true, isLocked: false));
  }

  /// 입력 PIN 검증. 일치하면 isLocked=false로 푸시.
  Future<bool> verifyPin(String pin) async {
    final repo = ref.read(lockRepositoryProvider);
    final ok = await repo.verifyPin(pin);
    if (ok) {
      final cur = state.valueOrNull ?? const LockState();
      state = AsyncValue.data(cur.copyWith(isLocked: false));
    }
    return ok;
  }

  /// 생체 인증으로 해제 시도. 사용자가 토글로 켜둔 경우만 의미.
  Future<bool> unlockWithBiometric({required String reason}) async {
    final repo = ref.read(lockRepositoryProvider);
    final ok = await repo.authenticateBiometric(reason: reason);
    if (ok) {
      final cur = state.valueOrNull ?? const LockState();
      state = AsyncValue.data(cur.copyWith(isLocked: false));
    }
    return ok;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final repo = ref.read(lockRepositoryProvider);
    await repo.setBiometricEnabled(enabled);
    final cur = state.valueOrNull ?? const LockState();
    state = AsyncValue.data(cur.copyWith(biometricEnabled: enabled));
  }

  /// 잠금 전체 해제 — 사용자가 "잠금 끄기"를 명시적으로 선택.
  Future<void> disable() async {
    final repo = ref.read(lockRepositoryProvider);
    await repo.clear();
    state = AsyncValue.data(
      (state.valueOrNull ?? const LockState()).copyWith(
        enabled: false,
        biometricEnabled: false,
        isLocked: false,
      ),
    );
  }

  /// 로그아웃 / 재로그인 시 호출 — PIN/생체 모두 wipe. 비밀번호 분실 복구 경로.
  Future<void> resetForAuthChange() async {
    final repo = ref.read(lockRepositoryProvider);
    await repo.clear();
    state = AsyncValue.data(
      (state.valueOrNull ?? const LockState()).copyWith(
        enabled: false,
        biometricEnabled: false,
        isLocked: false,
      ),
    );
  }

  /// foreground listener가 background→resume 시 호출. enabled면 잠금 trigger.
  void markLocked() {
    final cur = state.valueOrNull;
    if (cur == null || !cur.enabled) return;
    if (cur.isLocked) return;
    state = AsyncValue.data(cur.copyWith(isLocked: true));
  }
}

final lockViewModelProvider =
    AsyncNotifierProvider<LockViewModel, LockState>(LockViewModel.new);
