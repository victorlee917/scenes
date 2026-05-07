import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/tmdb_repository.dart';
import 'models/tmdb_film.dart';

/// 영화 검색 화면의 상태.
///
/// - [query]: 현재 입력값(원본). 디바운스가 끝나야 [results]로 반영.
/// - [results]: 마지막으로 성공한 검색 결과(또는 비어있음/로딩 중 직전 값).
/// - [isLoading]: 디바운스가 끝나고 실제 네트워크 요청이 진행 중인지.
/// - [error]: 마지막 요청에서 발생한 에러 메시지(없으면 null).
class FilmPickerState {
  const FilmPickerState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  final String query;
  final List<TmdbFilm> results;
  final bool isLoading;
  final String? error;

  FilmPickerState copyWith({
    String? query,
    List<TmdbFilm>? results,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return FilmPickerState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// 영화 검색 화면 ViewModel.
///
/// 입력 → 300ms 디바운스 → Edge Function 호출 → 상태 업데이트.
/// 같은 키워드 재호출은 무시(in-flight 방지) 하며, 새 키워드 입력이 들어오면
/// 직전 요청은 결과를 무시한다(stale guard).
class FilmPickerViewModel extends AutoDisposeNotifier<FilmPickerState> {
  static const _debounce = Duration(milliseconds: 300);

  Timer? _debounceTimer;
  int _requestSeq = 0;

  @override
  FilmPickerState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const FilmPickerState();
  }

  /// 텍스트 필드 onChanged에서 호출. 디바운스 후 자동 검색 실행.
  void updateQuery(String query, {String locale = 'en-US'}) {
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

    _debounceTimer = Timer(_debounce, () {
      _runSearch(trimmed, locale: locale);
    });
  }

  Future<void> _runSearch(String query, {required String locale}) async {
    final seq = ++_requestSeq;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repo = ref.read(tmdbRepositoryProvider);
      final results = await repo.search(query, locale: locale);
      // stale guard: 더 새로운 요청이 시작됐으면 이 결과는 버린다.
      if (seq != _requestSeq) return;
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      if (seq != _requestSeq) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final filmPickerViewModelProvider =
    NotifierProvider.autoDispose<FilmPickerViewModel, FilmPickerState>(
  FilmPickerViewModel.new,
);
