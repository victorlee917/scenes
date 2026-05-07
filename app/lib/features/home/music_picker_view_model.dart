import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/spotify_repository.dart';
import 'models/spotify_hit.dart';

class MusicPickerState {
  const MusicPickerState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  final String query;
  final List<SpotifyHit> results;
  final bool isLoading;
  final String? error;

  MusicPickerState copyWith({
    String? query,
    List<SpotifyHit>? results,
    bool? isLoading,
    Object? error = _sentinel,
  }) {
    return MusicPickerState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

/// 음악 검색 화면 ViewModel.
///
/// 입력 → 300ms 디바운스 → Edge Function 호출 → 상태 업데이트.
/// stale guard로 빠르게 타이핑할 때 늦게 도착한 결과가 새 결과를 덮지 않도록.
class MusicPickerViewModel extends AutoDisposeNotifier<MusicPickerState> {
  static const _debounce = Duration(milliseconds: 300);

  Timer? _debounceTimer;
  int _requestSeq = 0;

  @override
  MusicPickerState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const MusicPickerState();
  }

  void updateQuery(String query, {String locale = 'en'}) {
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
      final repo = ref.read(spotifyRepositoryProvider);
      final results = await repo.search(query, locale: locale);
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

final musicPickerViewModelProvider =
    NotifierProvider.autoDispose<MusicPickerViewModel, MusicPickerState>(
  MusicPickerViewModel.new,
);
