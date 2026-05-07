import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/models/profile.dart';
import '../models/couple_invite.dart';
import '../models/couple_record.dart';

/// 현재 사용자의 active couple + 상대방 프로필을 묶어 반환.
///
/// 상대방 프로필은 0002 마이그레이션의 `profiles_select_partner` 정책으로
/// 활성 페어 기간엔 자동 read 가능.
class ActiveCoupleAndPartner {
  const ActiveCoupleAndPartner({
    required this.couple,
    required this.partner,
  });

  final CoupleRecord couple;
  final Profile partner;
}

class CoupleRepository {
  CoupleRepository(this._client);

  final SupabaseClient _client;

  String? get _myId => _client.auth.currentUser?.id;

  /// 본인이 멤버인 active couple 한 건 + 상대방 profile.
  /// 페어가 없으면 null.
  Future<ActiveCoupleAndPartner?> getMyActiveCouple() async {
    final myId = _myId;
    if (myId == null) return null;

    final coupleRow = await _client
        .from('couples')
        .select()
        .or('partner_a_id.eq.$myId,partner_b_id.eq.$myId')
        .eq('status', 'active')
        .maybeSingle();
    if (coupleRow == null) return null;

    final couple = CoupleRecord.fromJson(coupleRow);
    final partnerId = couple.partnerIdFor(myId);

    final partnerRow = await _client
        .from('profiles')
        .select()
        .eq('id', partnerId)
        .maybeSingle();
    if (partnerRow == null) return null;

    return ActiveCoupleAndPartner(
      couple: couple,
      partner: Profile.fromJson(partnerRow),
    );
  }

  /// `since_date` 변경. 두 partner 모두 update 권한 있음 (RLS active 멤버).
  Future<CoupleRecord> updateSinceDate(String coupleId, DateTime date) async {
    final iso = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final updated = await _client
        .from('couples')
        .update({'since_date': iso})
        .eq('id', coupleId)
        .select()
        .single();
    return CoupleRecord.fromJson(updated);
  }

  // ── invite ─────────────────────────────────────────────────

  /// 현재 active 커플을 disconnect. SECURITY DEFINER RPC가 status='ended',
  /// ended_at, ended_by를 atomically 기록. 호출 후 클라가
  /// activeCoupleProvider를 refresh하면 라우터가 pairing 화면으로 redirect.
  /// 옛 scene/content는 pair_id에 묶여 보존돼 재페어링 시 그대로 돌아옴.
  Future<String> disconnectCouple() async {
    final result = await _client.rpc('disconnect_couple');
    return result as String;
  }

  /// 본인의 active(만료 전 + 미사용) invite를 가져오거나 새로 발급.
  ///
  /// RLS의 `couple_invites_select_inviter` 정책 덕에 본인 invite는 select 가능.
  /// 새 코드는 6자 영숫자(혼동 글자 제외). 유니크 충돌은 매우 드물지만 한
  /// 번까지 retry. 코드 길이는 0002 마이그레이션 check(6–12자)에 부합.
  Future<CoupleInvite> getOrCreateMyInvite() async {
    final myId = _myId;
    if (myId == null) {
      throw StateError('Cannot create invite while signed out.');
    }

    // 기존 invite 중 만료 안 됐고 redeemed_at이 null인 row 한 건 재사용.
    final existing = await _client
        .from('couple_invites')
        .select()
        .eq('inviter_id', myId)
        .filter('redeemed_at', 'is', null)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      return CoupleInvite.fromJson(existing);
    }

    // 새 코드 생성 후 insert. unique 충돌 시 한 번 retry.
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = _generateInviteCode();
      try {
        final inserted = await _client
            .from('couple_invites')
            .insert({'code': code, 'inviter_id': myId})
            .select()
            .single();
        return CoupleInvite.fromJson(inserted);
      } on PostgrestException catch (e) {
        // 23505 = unique_violation — 매우 드물지만 다른 코드로 재시도.
        if (e.code == '23505') continue;
        rethrow;
      }
    }
    throw StateError('Failed to allocate unique invite code.');
  }

  /// 상대 코드 redeem. SECURITY DEFINER RPC가 invite 검증 + couples insert +
  /// invite redeem 표시를 atomically 수행. couple_id 반환.
  /// 에러는 PostgrestException으로 propagate (P0001/23505 등 — 호출자가 분기).
  Future<String> redeemInvite(String code) async {
    final result = await _client.rpc(
      'redeem_couple_invite',
      params: {'invite_code': code},
    );
    return result as String;
  }

  /// 내가 partner_a 또는 partner_b로 들어가는 새 couples row가 INSERT될 때
  /// 이벤트를 흘려줌 — 페어링 화면에서 파트너가 내 코드를 redeem한 순간 즉시
  /// home으로 redirect 트리거에 사용.
  ///
  /// Supabase Realtime은 row 단위 filter에서 OR을 직접 못 거는 한계가 있어
  /// partner_a/partner_b 두 개 채널을 합쳐 단일 stream으로 노출. 어느 쪽이
  /// 먼저 도착해도 한 번만 트리거되도록 구독자가 idempotent하게 처리해야 함.
  Stream<void> watchActiveCoupleInserts() {
    return _watchCoupleEvents(
      keyPrefix: 'couple_insert',
      event: PostgresChangeEvent.insert,
    );
  }

  /// 본인이 멤버인 couples row의 UPDATE 이벤트. since_date 변경, status 전이
  /// (active → ended/abandoned) 등을 파트너 클라가 실시간 반영하기 위함.
  Stream<void> watchActiveCoupleUpdates() {
    return _watchCoupleEvents(
      keyPrefix: 'couple_update',
      event: PostgresChangeEvent.update,
    );
  }

  /// 특정 partner profile row의 UPDATE 이벤트. 파트너의 name/avatar 변경,
  /// deleted_at 전이를 실시간 반영. profile id를 직접 알아야 채널을 걸 수 있어
  /// 호출자가 active couple에서 partner.id를 알아낸 뒤 호출.
  Stream<void> watchPartnerProfileUpdates(String partnerId) {
    final controller = StreamController<void>.broadcast();
    final channel = _client
        .channel('partner_profile_$partnerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: partnerId,
          ),
          callback: (_) => controller.add(null),
        )
        .subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }

  Stream<void> _watchCoupleEvents({
    required String keyPrefix,
    required PostgresChangeEvent event,
  }) {
    final myId = _myId;
    if (myId == null) return const Stream.empty();
    final controller = StreamController<void>.broadcast();
    final channelA = _client
        .channel('${keyPrefix}_a_$myId')
        .onPostgresChanges(
          event: event,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'partner_a_id',
            value: myId,
          ),
          callback: (_) => controller.add(null),
        )
        .subscribe();
    final channelB = _client
        .channel('${keyPrefix}_b_$myId')
        .onPostgresChanges(
          event: event,
          schema: 'public',
          table: 'couples',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'partner_b_id',
            value: myId,
          ),
          callback: (_) => controller.add(null),
        )
        .subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channelA);
      await _client.removeChannel(channelB);
    };
    return controller.stream;
  }

  // ── helpers ────────────────────────────────────────────────

  static const _inviteAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static final _rng = math.Random.secure();

  /// 혼동 글자(0/O/1/I/L) 제외한 32자 alphabet에서 6자 랜덤. 32^6 ≈ 10억
  /// 조합이라 24h TTL 내 동시 active invite 충돌은 사실상 무시 가능.
  String _generateInviteCode() {
    return List.generate(
      6,
      (_) => _inviteAlphabet[_rng.nextInt(_inviteAlphabet.length)],
    ).join();
  }
}

final coupleRepositoryProvider = Provider<CoupleRepository>((ref) {
  return CoupleRepository(Supabase.instance.client);
});
