import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/spotify_repository.dart';
import 'models/spotify_hit.dart';
import 'search_picker_view_model.dart';

/// 음악 검색 화면 ViewModel — Spotify 검색을 [SearchPickerViewModel] 흐름에
/// 연결.
class MusicPickerViewModel extends SearchPickerViewModel<SpotifyHit> {
  // 외부 API + EF 호출 비용 압축을 위해 500ms debounce.
  @override
  Duration get debounce => const Duration(milliseconds: 500);

  @override
  Future<List<SpotifyHit>> search(String query, {required String locale}) {
    return ref.read(spotifyRepositoryProvider).search(query, locale: locale);
  }
}

final musicPickerViewModelProvider = NotifierProvider.autoDispose<
    MusicPickerViewModel, SearchPickerState<SpotifyHit>>(
  MusicPickerViewModel.new,
);
