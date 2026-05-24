import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/tmdb_repository.dart';
import 'models/tmdb_film.dart';
import 'search_picker_view_model.dart';

/// 영화 검색 화면 ViewModel — TMDB 검색을 [SearchPickerViewModel] 흐름에 연결.
class FilmPickerViewModel extends SearchPickerViewModel<TmdbFilm> {
  // 외부 API + EF 호출 비용 압축을 위해 500ms debounce. 빠른 타이핑이어도
  // 한 검색에 1~2번만 fire.
  @override
  Duration get debounce => const Duration(milliseconds: 500);

  @override
  Future<List<TmdbFilm>> search(String query, {required String locale}) {
    return ref.read(tmdbRepositoryProvider).search(query, locale: locale);
  }
}

final filmPickerViewModelProvider = NotifierProvider.autoDispose<
    FilmPickerViewModel, SearchPickerState<TmdbFilm>>(
  FilmPickerViewModel.new,
);
