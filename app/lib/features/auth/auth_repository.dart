import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart' show googleIosClientId, googleWebClientId;

/// 카카오 로그인 → Supabase 세션 발급 플로우.
///
/// 흐름:
///   1. KakaoTalk 앱 설치돼있으면 앱으로, 아니면 카카오 계정 웹뷰로 로그인
///   2. Kakao OIDC `idToken` 획득 (scope: openid + email + profile_nickname)
///   3. `Supabase.auth.signInWithIdToken(provider: kakao, idToken: ...)`
///   4. Supabase가 auth.users row 생성/업데이트 → trigger가 profiles row 자동 생성
class AuthRepository {
  AuthRepository(this._supabase);

  final SupabaseClient _supabase;

  /// 카카오로 로그인 후 Supabase 세션 생성. 성공 시 [Session] 반환.
  ///
  /// **Nonce 흐름** (Apple/Kakao와 동일 패턴):
  ///   1. raw nonce 생성
  ///   2. Kakao엔 `SHA256(rawNonce)` 송신 → idToken에 그 해시값이 nonce claim으로 들어감
  ///   3. Supabase엔 raw nonce 송신 → Supabase가 SHA256 후 idToken claim과 비교
  ///   → 양쪽 모두 SHA256(rawNonce) 값으로 매칭됨
  Future<Session> signInWithKakao() async {
    final rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    // 1) Kakao로 idToken 받기.
    final installed = await kakao.isKakaoTalkInstalled();
    final kakao.OAuthToken token = installed
        ? await _kakaoLoginWithFallback(hashedNonce)
        : await kakao.UserApi.instance
            .loginWithKakaoAccount(nonce: hashedNonce);

    final idToken = token.idToken;
    if (idToken == null) {
      throw const AuthException(
        'Kakao login succeeded but idToken is null. '
        'Check OpenID Connect is enabled in Kakao Developers.',
      );
    }

    // 2) Supabase에 idToken + raw nonce 전달 → 세션 발급.
    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.kakao,
      idToken: idToken,
      nonce: rawNonce,
    );
    final session = response.session;
    if (session == null) {
      throw const AuthException('Supabase did not return a session.');
    }
    return session;
  }

  /// KakaoTalk 앱으로 시도하고 실패 시(앱은 있는데 권한 거부 등)
  /// 카카오 계정 로그인으로 폴백.
  Future<kakao.OAuthToken> _kakaoLoginWithFallback(String nonce) async {
    try {
      return await kakao.UserApi.instance.loginWithKakaoTalk(nonce: nonce);
    } catch (_) {
      return await kakao.UserApi.instance.loginWithKakaoAccount(nonce: nonce);
    }
  }

  /// 충분한 길이의 random nonce 생성. Apple OIDC 권장(32자 이상).
  String _generateRawNonce() {
    final now = DateTime.now().microsecondsSinceEpoch;
    // microsecondsSinceEpoch + random suffix로 16자+ 보장.
    final rand =
        (now ^ identityHashCode(Object())).toRadixString(36);
    return '${now.toRadixString(36)}$rand'.padRight(32, '0');
  }

  /// Google로 로그인 후 Supabase 세션 생성.
  ///
  /// google_sign_in 7.x의 `initialize(nonce: ...)`로 instance-level nonce를
  /// 설정 가능 → Apple/Kakao와 동일한 SHA256 패턴 적용:
  ///   1. raw nonce 생성
  ///   2. Google엔 SHA256(rawNonce) 송신 → idToken에 그 해시값이 nonce claim
  ///   3. Supabase엔 raw nonce 송신 → SHA256 후 비교 → 통과
  ///
  /// audience 매칭: `serverClientId: googleWebClientId`로 idToken aud=Web Client ID
  /// → Supabase Google provider가 같은 Web Client ID로 검증.
  Future<Session> signInWithGoogle() async {
    final rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    // 7.x는 instance singleton — 매 로그인마다 nonce 갱신 위해 re-initialize.
    await GoogleSignIn.instance.initialize(
      clientId: googleIosClientId,
      serverClientId: googleWebClientId,
      nonce: hashedNonce,
    );

    // 직전 세션 정리해 계정 선택 화면 보이게.
    await GoogleSignIn.instance.signOut();

    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'profile'],
    );

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google idToken is null.');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: rawNonce,
    );
    final session = response.session;
    if (session == null) {
      throw const AuthException('Supabase did not return a session.');
    }
    return session;
  }

  /// Apple로 로그인 후 Supabase 세션 생성.
  ///
  /// Apple 표준 SHA256 nonce 패턴:
  ///   1. raw nonce 생성
  ///   2. Apple Sign In에 SHA256(rawNonce) 송신 → idToken nonce claim에 그 해시
  ///   3. Supabase엔 raw nonce 송신 → SHA256 후 claim과 비교 → 통과
  ///
  /// audience: idToken aud=Bundle ID (com.tapas.scenes). Supabase Apple
  /// provider의 "Authorized Client IDs"에 같은 값 등록 필수.
  ///
  /// **iOS Only**: sign_in_with_apple는 Android에선 web redirect로 동작 —
  /// 추후 Android 지원 시 webAuthenticationOptions 추가.
  Future<Session> signInWithApple() async {
    final rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple identityToken is null.');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    final session = response.session;
    if (session == null) {
      throw const AuthException('Supabase did not return a session.');
    }
    return session;
  }

  /// 로그아웃. Kakao + Google + Supabase 세션 모두 종료.
  Future<void> signOut() async {
    try {
      await kakao.UserApi.instance.logout();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _supabase.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Session? get currentSession => _supabase.auth.currentSession;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});
