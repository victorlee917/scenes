import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../upload/upload_queue_view_model.dart';
import '../data/place_search_repository.dart';
import '../models/place_hit.dart';
import '../models/scene.dart';
import '../place_picker_view_model.dart';
import 'scene_detail_screen.dart';
import 'search_picker_scaffold.dart';

/// 장소 검색·선택 화면.
///
/// 입력 → 디바운스 → 검색 (iOS: Apple Maps MKLocalSearch / Android: Mapbox
/// geocoding via Edge Function). 검색 폼·결과 리스트·선택 상태는
/// [SearchPickerScaffold]가 담당하고, 이 위젯은 장소 특화 부분만 연결한다.
class PlacePickerScreen extends ConsumerWidget {
  const PlacePickerScreen({
    super.key,
    this.scene,
    this.momentDate,
    this.landOnSceneDetail = true,
  });

  final Scene? scene;
  final DateTime? momentDate;
  final bool landOnSceneDetail;

  static Route<void> route({
    Scene? scene,
    DateTime? momentDate,
    bool landOnSceneDetail = true,
  }) {
    return searchPickerRoute(
      PlacePickerScreen(
        scene: scene,
        momentDate: momentDate,
        landOnSceneDetail: landOnSceneDetail,
      ),
    );
  }

  /// 검색 언어 hint. 앱 in-app locale을 따름. Apple Maps와 Mapbox 양쪽 모두
  /// ko/en로 결과 우선순위가 달라진다.
  String _searchLocale(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'ko' ? 'ko' : 'en';
  }

  /// 선택된 장소를 큐에 enqueue 후 picker를 즉시 닫고 scene detail로 이동.
  /// 실제 업로드는 background에서 [UploadQueueNotifier]가 처리.
  void _save(BuildContext context, WidgetRef ref, PlaceHit place) {
    final scene = this.scene;
    if (scene == null) return;

    ref.read(uploadQueueProvider.notifier).enqueuePlace(
          sceneId: scene.id,
          sceneTitle: scene.title,
          place: place,
          momentDate: momentDate,
        );

    Navigator.of(context).pop();
    if (landOnSceneDetail) {
      final viewportWidth = MediaQuery.sizeOf(context).width;
      Navigator.of(context).push(
        SceneDetailScreen.fadeRoute(
          scene: scene,
          canisterSize: viewportWidth * 0.5,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final results =
        ref.watch(placePickerViewModelProvider.select((s) => s.results));
    final isLoading =
        ref.watch(placePickerViewModelProvider.select((s) => s.isLoading));
    // 토글 노출 조건: 디바이스 region이 국내(KR)이거나, 앱 표시 언어가 한국어.
    // 후자는 해외 거주 한국어 사용자도 Kakao 검색을 쓸 수 있게 하기 위함.
    // (Localizations는 system 선택 시 디바이스 언어로 해석된 실제 표시 언어.)
    final isKoreanLang =
        Localizations.localeOf(context).languageCode == 'ko';
    final showScopeToggle = isDomesticDeviceLocale() || isKoreanLang;
    final mode = ref.watch(placeSearchModeProvider);

    ref.listen(
      placePickerViewModelProvider.select((s) => s.error),
      (prev, next) {
        if (next != null && next.isNotEmpty) {
          AppToast.show(context, l10n.pickerSearchFailed);
        }
      },
    );

    return SearchPickerScaffold<PlaceHit>(
      title: l10n.placePickerScreenTitle,
      searchHint: l10n.placePickerSearchHint,
      emptyMessage: l10n.placePickerEmpty,
      results: results,
      isLoading: isLoading,
      onQueryChanged: (value) => ref
          .read(placePickerViewModelProvider.notifier)
          .updateQuery(value, locale: _searchLocale(context)),
      modeSelector: showScopeToggle
          ? _ScopeToggle(
              mode: mode,
              onChanged: (next) => ref
                  .read(placePickerViewModelProvider.notifier)
                  .setMode(next, locale: _searchLocale(context)),
            )
          : null,
      attribution: _SearchAttribution(mode: mode),
      idOf: (place) => place.id,
      itemBuilder: (context, place, selected, onTap) =>
          _PlaceTile(place: place, selected: selected, onTap: onTap),
      onSave: (place) => _save(context, ref, place),
    );
  }
}

/// 국내/해외 검색 범위 세그먼트 토글. 국내 로케일에서만 노출된다.
class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({required this.mode, required this.onChanged});

  final PlaceSearchMode mode;
  final ValueChanged<PlaceSearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.colors.nonClickableArea,
          borderRadius: AppRadii.smBorder,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            _ScopeSegment(
              label: l10n.placePickerScopeDomestic,
              selected: mode == PlaceSearchMode.domestic,
              onTap: () => onChanged(PlaceSearchMode.domestic),
            ),
            _ScopeSegment(
              label: l10n.placePickerScopeOverseas,
              selected: mode == PlaceSearchMode.overseas,
              onTap: () => onChanged(PlaceSearchMode.overseas),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeSegment extends StatelessWidget {
  const _ScopeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? colors.clickableArea : Colors.transparent,
            borderRadius: AppRadii.xsBorder,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.body(
              13,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
            ).copyWith(
              color:
                  selected ? colors.foreground : colors.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// 검색 결과 attribution — TOS 의무. 검색에 실제 쓰인 소스에 맞춰 표기한다.
/// 국내 모드는 Kakao, 해외 모드는 iOS=Apple MapKit / 그 외=Mapbox+OpenStreetMap.
class _SearchAttribution extends StatelessWidget {
  const _SearchAttribution({required this.mode});

  final PlaceSearchMode mode;

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.foregroundMuted;
    final mutedFaint = muted.withValues(alpha: 0.3);
    final mutedSoft = muted.withValues(alpha: 0.5);
    final dotStyle = AppTypography.body(10).copyWith(color: mutedFaint);
    final linkStyle = AppTypography.body(10).copyWith(color: mutedSoft);
    final textStyle = AppTypography.body(10).copyWith(color: mutedSoft);

    final List<Widget> children;
    if (mode == PlaceSearchMode.domestic) {
      // Kakao 로컬 검색 출처 표기.
      children = [
        GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://www.kakaocorp.com/'),
            mode: LaunchMode.externalApplication,
          ),
          child: Text('© Kakao', style: linkStyle),
        ),
      ];
    } else if (Platform.isIOS) {
      children = [
        Text(
          AppLocalizations.of(context).placePickerAppleAttribution,
          style: textStyle,
        ),
      ];
    } else {
      children = [
        GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://www.mapbox.com/about/maps/'),
            mode: LaunchMode.externalApplication,
          ),
          child: Text('© Mapbox', style: linkStyle),
        ),
        Text('  ·  ', style: dotStyle),
        GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          ),
          child: Text('© OpenStreetMap', style: linkStyle),
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 8),
      child: Row(children: children),
    );
  }
}

/// 장소 결과 타일 — 위치 아이콘(56×56) + 장소명/시·도/국가.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final PlaceHit place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PickerResultTile(
      thumbWidth: 56,
      thumbHeight: 56,
      // 실제 정적지도는 픽 이후 mapbox-static-cache EF로 1회 캐싱 — 검색
      // 소스와 무관하게 위치 아이콘만 표시.
      thumbnail: Center(
        child: FaIcon(
          FontAwesomeIcons.locationDot,
          size: 18,
          color: context.colors.foregroundMuted,
        ),
      ),
      line1: place.name,
      line2: place.region,
      line3: place.country,
      selected: selected,
      onTap: onTap,
    );
  }
}
