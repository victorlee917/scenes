import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 검색 픽커(영화·음악·장소)의 공통 상태.
///
/// - [query]: 현재 입력값(원본). 디바운스가 끝나야 [results]로 반영.
/// - [results]: 마지막으로 성공한 검색 결과(또는 비어있음/로딩 직전 값).
/// - [isLoading]: 디바운스가 끝나고 실제 검색이 진행 중인지.
/// - [error]: 마지막 요청에서 발생한 에러 메시지(없으면 null).
class SearchPickerState<T> {
  const SearchPickerState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  final String query;
  final List<T> results;
  final bool isLoading;
  final String? error;

  SearchPickerState<T> copyWith({
    String? query,
    List<T>? results,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return SearchPickerState<T>(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// 검색 픽커 ViewModel의 공통 베이스.
///
/// 입력 → [debounce] → [search] 호출 → 상태 업데이트. 새 입력이 들어오면
/// 직전 요청의 결과는 버린다(stale guard). 서브클래스는 [debounce]와 [search]
/// 두 가지만 구현하면 된다.
abstract class SearchPickerViewModel<T>
    extends AutoDisposeNotifier<SearchPickerState<T>> {
  /// 외부 API + EF 호출 비용에 맞춘 디바운스 시간.
  Duration get debounce;

  /// 실제 검색 수행. 디바운스 이후 호출된다.
  Future<List<T>> search(String query, {required String locale});

  Timer? _debounceTimer;
  int _requestSeq = 0;

  @override
  SearchPickerState<T> build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return SearchPickerState<T>();
  }

  /// 텍스트 필드 onChanged에서 호출. 디바운스 후 자동 검색 실행.
  void updateQuery(String query, {required String locale}) {
    state = state.copyWith(query: query);
    _debounceTimer?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        results: const [],
        isLoading: false,
        error: null,
      );
      return;
    }

    _debounceTimer = Timer(debounce, () {
      _runSearch(trimmed, locale: locale);
    });
  }

  Future<void> _runSearch(String query, {required String locale}) async {
    final seq = ++_requestSeq;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await search(query, locale: locale);
      // stale guard: 더 새로운 요청이 시작됐으면 이 결과는 버린다.
      if (seq != _requestSeq) return;
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      if (seq != _requestSeq) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
