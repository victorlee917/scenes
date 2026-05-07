import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_repository.dart';

/// 앱 전반의 인증 상태.
///
/// Supabase의 `AuthState`와 이름이 겹쳐서 우리 클래스는 [AppAuthState]로 명명.
class AppAuthState {
  const AppAuthState({this.session, this.isLoading = false, this.error});

  final sb.Session? session;
  final bool isLoading;
  final String? error;

  bool get isLoggedIn => session != null;

  AppAuthState copyWith({
    sb.Session? session,
    bool clearSession = false,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return AppAuthState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

class AuthViewModel extends Notifier<AppAuthState> {
  StreamSubscription<sb.AuthState>? _sub;

  @override
  AppAuthState build() {
    final repo = ref.read(authRepositoryProvider);
    final initial = AppAuthState(session: repo.currentSession);

    // Supabase 세션 변동 구독 (signIn / signOut / tokenRefreshed 등).
    _sub = repo.authStateChanges.listen((event) {
      state = state.copyWith(
        session: event.session,
        clearSession: event.session == null,
        isLoading: false,
      );
    });
    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  Future<void> signInWithKakao() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).signInWithKakao();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithApple() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AppAuthState>(
  AuthViewModel.new,
);

/// 자주 쓰는 셀렉터.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authViewModelProvider.select((s) => s.isLoggedIn));
});
