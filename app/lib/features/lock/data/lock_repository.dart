import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// 앱 잠금 데이터 레이어.
///
/// PIN은 hash로만 저장 — `SHA256(salt + pin)`. salt는 설치 시 1회 생성해
/// secure storage(iOS keychain / Android Keystore)에 같이 저장. PIN 자체는
/// 절대 평문으로 남기지 않는다. 4자리라 brute-force 자체는 어렵지 않지만,
/// PIN 시도는 UI 측 lock screen이 attempt 제한으로 보호 + secure storage
/// 가 keychain에 묶여 있어 디바이스 락스크린을 우회하지 않는 한 접근 불가.
///
/// 생체 인증 활성화 플래그도 secure storage에 둠 — PIN과 함께 통째로 wipe
/// 하기 쉬워서.
class LockRepository {
  LockRepository(this._storage, this._localAuth);

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _kPinHash = 'lock.pin_hash';
  static const _kPinSalt = 'lock.pin_salt';
  static const _kBiometricEnabled = 'lock.biometric_enabled';

  /// PIN이 한 번이라도 설정된 적 있으면 true → 잠금 ON 상태.
  Future<bool> isEnabled() async {
    final h = await _storage.read(key: _kPinHash);
    return h != null && h.isNotEmpty;
  }

  /// 생체 인증 활성화 여부. PIN이 켜져 있을 때만 유효.
  Future<bool> isBiometricEnabled() async {
    final v = await _storage.read(key: _kBiometricEnabled);
    return v == '1';
  }

  /// 디바이스가 생체 인증을 지원하는지(=등록된 지문/얼굴이 있는지) 체크.
  /// FaceID 권한 거부 / 미등록 등이면 false라 토글 UI를 비활성화하는 데 사용.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final avail = await _localAuth.getAvailableBiometrics();
      return avail.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// PIN 신규 설정. 기존 PIN이 있어도 덮어쓴다(상위에서 verify 후 호출 가정).
  /// salt는 새로 생성해 PIN을 절대 동일 hash로 두지 않음(서로 다른 install/
  /// 재설정 간 분리).
  Future<void> setPin(String pin) async {
    final salt = _randomSaltB64();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _kPinSalt, value: salt);
    await _storage.write(key: _kPinHash, value: hash);
  }

  /// 입력 PIN이 저장 PIN과 일치하는지. 일치하면 true.
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kPinSalt);
    final stored = await _storage.read(key: _kPinHash);
    if (salt == null || stored == null) return false;
    final hash = _hashPin(pin, salt);
    // constant-time compare — 짧은 hex라 timing attack 의미 낮지만 hygiene.
    return _constTimeEq(hash, stored);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _kBiometricEnabled,
      value: enabled ? '1' : '0',
    );
  }

  /// 디바이스 생체 인증 prompt를 띄우고 성공 여부 반환.
  /// reason: 잠금 화면 등에서 사용자에게 보일 텍스트.
  Future<bool> authenticateBiometric({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// 잠금 전체 해제 — PIN/salt/biometric 모두 wipe. 로그아웃 또는 사용자가
  /// "잠금 해제" 선택 시.
  Future<void> clear() async {
    await _storage.delete(key: _kPinHash);
    await _storage.delete(key: _kPinSalt);
    await _storage.delete(key: _kBiometricEnabled);
  }

  static String _randomSaltB64() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static bool _constTimeEq(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

final lockRepositoryProvider = Provider<LockRepository>((ref) {
  // AccessibilityAfterFirstUnlock — 디바이스가 한 번 잠금 해제된 뒤부터
  // 우리 앱이 backgrounded여도 접근 가능. firstUnlockThisDevice는 백업으로 못
  // 풀어 너무 빡빡. 사용자 잠금 PIN이 보호 레이어라 이 정도면 충분.
  const storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // Android는 v10에서 EncryptedSharedPreferences가 제거되고 자동 마이그레이션.
    // 별도 옵션 불필요.
  );
  return LockRepository(storage, LocalAuthentication());
});
