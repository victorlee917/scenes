import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/credit_event.dart';

/// `get_pair_activity_page` RPC를 호출해 페어 활동 피드를 가져온다.
class CreditRepository {
  CreditRepository(this._client);

  final SupabaseClient _client;

  /// 활성 페어의 활동 피드 한 페이지.
  ///
  /// [cursorAt]가 null이면 최신부터 [limit]개. 아니면 그 시각보다 오래된
  /// 항목들을 [limit]개. 반환 길이가 [limit]보다 작으면 이게 마지막 페이지.
  Future<List<CreditEvent>> getPage({
    required String pairId,
    required DateTime? cursorAt,
    required int limit,
  }) async {
    final result = await _client.rpc(
      'get_pair_activity_page',
      params: {
        'p_pair_id': pairId,
        'p_cursor_at': cursorAt?.toUtc().toIso8601String(),
        'p_limit': limit,
      },
    );
    if (result is! List) return const [];
    return result
        .whereType<Map<String, dynamic>>()
        .map(CreditEvent.fromJson)
        .toList(growable: false);
  }
}

final creditRepositoryProvider = Provider<CreditRepository>((ref) {
  return CreditRepository(Supabase.instance.client);
});
