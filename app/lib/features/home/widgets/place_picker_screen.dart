import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../upload/upload_queue_view_model.dart';
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

  /// 검색 언어 hint. 시스템 locale을 읽어 ko/en로 단순화. Apple Maps와 Mapbox
  /// 양쪽 모두 ko/en로 결과 우선순위가 달라진다.
  String _searchLocale(BuildContext context) {
    final lang = View.of(context).platformDispatcher.locale.languageCode;
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
      attribution: const _SearchAttribution(),
      idOf: (place) => place.id,
      itemBuilder: (context, place, selected, onTap) =>
          _PlaceTile(place: place, selected: selected, onTap: onTap),
      onSave: (place) => _save(context, ref, place),
    );
  }
}

/// 검색 결과 attribution — TOS 의무. iOS는 Apple MapKit guidelines, 그 외는
/// Mapbox + OpenStreetMap 표기.
class _SearchAttribution extends StatelessWidget {
  const _SearchAttribution();

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.foregroundMuted;
    final mutedFaint = muted.withValues(alpha: 0.3);
    final mutedSoft = muted.withValues(alpha: 0.5);
    final dotStyle = AppTypography.body(10).copyWith(color: mutedFaint);
    final linkStyle = AppTypography.body(10).copyWith(color: mutedSoft);
    final textStyle = AppTypography.body(10).copyWith(color: mutedSoft);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 8),
      child: Row(
        children: Platform.isIOS
            ? [
                Text(
                  AppLocalizations.of(context).placePickerAppleAttribution,
                  style: textStyle,
                ),
              ]
            : [
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
              ],
      ),
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
