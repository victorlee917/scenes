import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

/// 현재 로그인 유저의 profile 행을 읽고/수정하는 Repository.
///
/// 모든 메서드는 `auth.uid() = id` RLS 정책으로 자동 보호됨 (0001).
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  String? get _myId => _client.auth.currentUser?.id;

  /// 현재 유저의 profile. 0021 trigger 덕에 row는 항상 존재.
  Future<Profile?> getMyProfile() async {
    final id = _myId;
    if (id == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  /// name/avatar 업데이트 + onboarding 완료 표시. 한 번에 같이.
  ///
  /// 같은 계정으로 재가입한 케이스(이전에 soft-delete된 profile이 살아있는
  /// 상태)도 이 경로로 처리됨 — `deleted_at`을 null로 풀어 fresh user 상태로
  /// 복귀. 옛 abandoned 커플은 그대로 종료 상태.
  Future<Profile> completeOnboarding({
    required String name,
    String? avatarUrl,
  }) async {
    final id = _myId;
    if (id == null) {
      throw StateError('Cannot complete onboarding while signed out.');
    }
    final patch = <String, dynamic>{
      'name': name,
      'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
      'deleted_at': null,
    };
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    final updated = await _client
        .from('profiles')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Profile.fromJson(updated);
  }

  /// onboarding 완료 후 name/avatar 편집. `onboarding_completed_at`은 건드리지 않음.
  Future<Profile> updateProfile({String? name, String? avatarUrl}) async {
    final id = _myId;
    if (id == null) {
      throw StateError('Cannot update profile while signed out.');
    }
    final patch = <String, dynamic>{};
    if (name != null) patch['name'] = name;
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (patch.isEmpty) {
      // 변경사항 없으면 현재 row 그대로 반환.
      final current = await getMyProfile();
      if (current == null) {
        throw StateError('Profile row missing.');
      }
      return current;
    }
    final updated = await _client
        .from('profiles')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return Profile.fromJson(updated);
  }

  /// 계정 탈퇴 — soft delete. `profiles.deleted_at`을 now()로 set.
  /// 0004 트리거가 active 커플을 자동으로 'abandoned'로 전환하고, deleted_at은
  /// 한 번 set되면 immutable. profiles_update_own RLS가 자기 row update를
  /// 허용하므로 직접 UPDATE 가능 — 별도 RPC 불필요.
  ///
  /// 호출 후 호출자가 supabase signOut + push token 정리까지 책임지면 됨.
  Future<void> softDeleteAccount() async {
    final id = _myId;
    if (id == null) {
      throw StateError('Cannot delete account while signed out.');
    }
    await _client.from('profiles').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// 프로필 이미지를 업로드하고 public URL 반환.
  ///
  /// `upload-avatar` Edge Function 경유. 신형 sb_publishable_... 키로 storage에
  /// 직접 업로드 시 RLS auth.uid()가 null로 평가되는 호환성 이슈가 있어서, EF
  /// 안에서 caller JWT + legacy anon 키로 storage를 호출하는 패턴 사용.
  Future<String> uploadAvatar(File file) async {
    final id = _myId;
    if (id == null) {
      throw StateError('Cannot upload avatar while signed out.');
    }
    final bytes = await file.readAsBytes();
    final response = await _client.functions.invoke(
      'upload-avatar',
      body: bytes,
      headers: {'Content-Type': 'image/jpeg'},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('upload-avatar returned unexpected payload: $data');
    }
    final publicUrl = data['public_url'] as String?;
    if (publicUrl == null || publicUrl.isEmpty) {
      throw StateError('upload-avatar response missing public_url.');
    }
    return publicUrl;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});
