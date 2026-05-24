import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/place_search_repository.dart';
import 'models/place_hit.dart';
import 'search_picker_view_model.dart';

/// 장소 검색 화면 ViewModel — Apple Maps / Mapbox 검색을
/// [SearchPickerViewModel] 흐름에 연결.
class PlacePickerViewModel extends SearchPickerViewModel<PlaceHit> {
  // Apple native 호출은 외부 비용 0이라 debounce를 짧게 가져가도 부담 없지만
  // UX 안정성(타이핑 중 리스트 깜빡임 최소화)을 위해 300ms 유지.
  @override
  Duration get debounce => const Duration(milliseconds: 300);

  @override
  Future<List<PlaceHit>> search(String query, {required String locale}) {
    return ref
        .read(placeSearchRepositoryProvider)
        .search(query, locale: locale);
  }
}

final placePickerViewModelProvider = NotifierProvider.autoDispose<
    PlacePickerViewModel, SearchPickerState<PlaceHit>>(
  PlacePickerViewModel.new,
);
