import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../couple/couple_view_model.dart';
import 'data/credit_repository.dart';
import 'models/credit_event.dart';

/// Credit 피드 상태.
///
/// - [events]: 지금까지 로드된 항목들(누적, 최신순).
/// - [isLoadingMore]: 다음 페이지 fetch 중인지(중복 호출 가드).
/// - [hasMore]: 추가로 받을 수 있는 항목이 남아 있는지.
@immutable
class CreditFeedState {
  const CreditFeedState({
    this.events = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  final List<CreditEvent> events;
  final bool isLoadingMore;
  final bool hasMore;

  CreditFeedState copyWith({
    List<CreditEvent>? events,
    bool? isLoadingMore,
    bool? hasMore,
  }) =>
      CreditFeedState(
        events: events ?? this.events,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
      );
}

/// 페어 활동 피드 ViewModel — 첫 페이지를 build에서 받고, 이후 [loadMore]로
/// cursor 기반 페이지네이션. pair가 바뀌면 build가 재실행되어 처음부터 다시.
class CreditFeedViewModel extends AsyncNotifier<CreditFeedState> {
  static const _pageSize = 10;

  @override
  Future<CreditFeedState> build() async {
    final pairId = ref.watch(myActivePairIdProvider);
    if (pairId == null) {
      return const CreditFeedState(hasMore: false);
    }
    final page = await ref.read(creditRepositoryProvider).getPage(
          pairId: pairId,
          cursorAt: null,
          limit: _pageSize,
        );
    return CreditFeedState(
      events: page,
      hasMore: page.length >= _pageSize,
    );
  }

  /// 다음 페이지 로드. hasMore=false거나 진행 중이면 noop.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final pairId = ref.read(myActivePairIdProvider);
    if (pairId == null) return;
    // server가 collapse한 그룹의 tail 시각을 cursor로 — 다음 페이지는 그룹
     // 경계 밖(더 오래된 그룹)만 가져와 중복/스터터 없음.
    final lastAt =
        current.events.isEmpty ? null : current.events.last.minCreatedAt;
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(creditRepositoryProvider).getPage(
            pairId: pairId,
            cursorAt: lastAt,
            limit: _pageSize,
          );
      state = AsyncValue.data(
        CreditFeedState(
          events: [...current.events, ...page],
          isLoadingMore: false,
          hasMore: page.length >= _pageSize,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final creditFeedProvider =
    AsyncNotifierProvider<CreditFeedViewModel, CreditFeedState>(
  CreditFeedViewModel.new,
);
