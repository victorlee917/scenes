import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale/locale_provider.dart';
import 'data/place_search_repository.dart';
import 'models/place_hit.dart';
import 'search_picker_view_model.dart';

/// 선택된 장소 검색 모드(국내/해외)를 보관. View는 토글 하이라이트·attribution
/// 표시에 watch하고, [PlacePickerViewModel]은 검색 시 read한다.
///
/// 기본값: 디바이스 region이 국내(KR)이거나 앱 표시 언어가 한국어면
/// [PlaceSearchMode.domestic], 그 외엔 [PlaceSearchMode.overseas]. 토글 노출
/// 조건과 동일하게 맞춰, 한국어 사용자는 진입 시 바로 Kakao(국내)로 시작한다.
/// region/언어 둘 다 아니면 overseas로 고정돼 기존 동작이 유지된다.
/// autoDispose라 picker 재진입마다 기본값을 다시 계산한다.
class PlaceSearchModeNotifier extends AutoDisposeNotifier<PlaceSearchMode> {
  @override
  PlaceSearchMode build() {
    final korean = isDomesticDeviceLocale() || _isKoreanAppLanguage();
    return korean ? PlaceSearchMode.domestic : PlaceSearchMode.overseas;
  }

  /// 앱 표시 언어가 한국어로 해석되는지. 명시적 korean 선택이거나, system이면
  /// 디바이스 언어가 ko인 경우. (appLocaleProvider는 picker 진입 시점엔 보통
  /// 이미 로드돼 있어 read로 충분 — watch하면 늦은 로드에 mode 선택이 리셋됨.)
  bool _isKoreanAppLanguage() {
    final opt =
        ref.read(appLocaleProvider).valueOrNull ?? AppLocaleOption.system;
    switch (opt) {
      case AppLocaleOption.korean:
        return true;
      case AppLocaleOption.english:
        return false;
      case AppLocaleOption.system:
        return ui.PlatformDispatcher.instance.locale.languageCode
            .toLowerCase()
            .startsWith('ko');
    }
  }

  void set(PlaceSearchMode mode) => state = mode;
}

final placeSearchModeProvider =
    NotifierProvider.autoDispose<PlaceSearchModeNotifier, PlaceSearchMode>(
  PlaceSearchModeNotifier.new,
);

/// 장소 검색 화면 ViewModel — Kakao / Apple Maps / Mapbox 검색을
/// [SearchPickerViewModel] 흐름에 연결.
class PlacePickerViewModel extends SearchPickerViewModel<PlaceHit> {
  // Apple native 호출은 외부 비용 0이라 debounce를 짧게 가져가도 부담 없지만
  // UX 안정성(타이핑 중 리스트 깜빡임 최소화)을 위해 300ms 유지.
  @override
  Duration get debounce => const Duration(milliseconds: 300);

  @override
  Future<List<PlaceHit>> search(String query, {required String locale}) {
    final mode = ref.read(placeSearchModeProvider);
    return ref
        .read(placeSearchRepositoryProvider)
        .search(query, locale: locale, mode: mode);
  }

  /// 국내↔해외 토글. 모드를 바꾸고 현재 입력어를 새 소스로 즉시 재검색한다.
  void setMode(PlaceSearchMode mode, {required String locale}) {
    if (ref.read(placeSearchModeProvider) == mode) return;
    ref.read(placeSearchModeProvider.notifier).set(mode);
    rerun(locale: locale);
  }
}

final placePickerViewModelProvider = NotifierProvider.autoDispose<
    PlacePickerViewModel, SearchPickerState<PlaceHit>>(
  PlacePickerViewModel.new,
);
