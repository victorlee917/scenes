import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/fade_text.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../upload/upload_queue_view_model.dart';
import '../models/place_hit.dart';
import '../models/scene.dart';
import '../place_picker_view_model.dart';
import 'detail_app_bar.dart';
import 'scene_detail_screen.dart';

/// 장소 검색·선택 화면.
///
/// 입력 → 300ms 디바운스 → Mapbox geocoding. 검색·결과·로딩 상태는
/// [placePickerViewModelProvider]가 관리.
class PlacePickerScreen extends ConsumerStatefulWidget {
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
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          PlacePickerScreen(
        scene: scene,
        momentDate: momentDate,
        landOnSceneDetail: landOnSceneDetail,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends ConsumerState<PlacePickerScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  PlaceHit? _selected;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(placePickerViewModelProvider.notifier).updateQuery(
          value,
          locale: _mapboxLocale(context),
        );
    setState(() {}); // suffix clear 버튼 노출 갱신
  }

  /// Mapbox geocoding language 결정. 시스템 locale 직접 읽음.
  String _mapboxLocale(BuildContext context) {
    final lang = View.of(context).platformDispatcher.locale.languageCode;
    return lang == 'ko' ? 'ko' : 'en';
  }

  void _selectPlace(PlaceHit hit) {
    setState(() {
      _selected = _selected?.id == hit.id ? null : hit;
    });
  }

  /// 선택된 장소를 큐에 enqueue 후 picker를 즉시 닫고 scene detail로 이동.
  /// 실제 업로드는 background에서 [UploadQueueNotifier]가 처리.
  void _save() {
    final place = _selected;
    final scene = widget.scene;
    if (place == null || scene == null) return;

    ref.read(uploadQueueProvider.notifier).enqueuePlace(
          sceneId: scene.id,
          sceneTitle: scene.title,
          place: place,
          momentDate: widget.momentDate,
        );

    Navigator.of(context).pop();
    if (widget.landOnSceneDetail) {
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
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final state = ref.watch(placePickerViewModelProvider);
    final hasSelection = _selected != null;

    ref.listen(
      placePickerViewModelProvider.select((s) => s.error),
      (prev, next) {
        if (next != null && next.isNotEmpty) {
          AppToast.show(context, 'Search failed. Please try again.');
        }
      },
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: padding.top + DetailAppBar.barHeight),

              // 검색 폼
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.nonClickableArea,
                    borderRadius: AppRadii.smBorder,
                    border: Border.all(
                      color:
                          context.colors.foreground.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.search,
                    style: AppTypography.body(15).copyWith(
                      color: context.colors.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search places...',
                      hintStyle: AppTypography.body(15).copyWith(
                        color: context.colors.foregroundMuted
                            .withValues(alpha: 0.5),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          size: 16,
                          color: context.colors.foregroundMuted,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onChanged('');
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: context.colors.foregroundMuted
                                        .withValues(alpha: 0.3),
                                  ),
                                  child: Center(
                                    child: FaIcon(
                                      FontAwesomeIcons.xmark,
                                      size: 9,
                                      color: context.colors.background,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: _onChanged,
                  ),
                ),
              ),

              // 검색 결과
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                    ],
                    stops: [0.0, 0.015, 1.0],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: _buildResultsBody(state, padding),
                ),
              ),
            ],
          ),

          // 앱바
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: 'Add Place',
              titleOpacity: 1.0,
              useGradient: false,
              onClose: () => Navigator.of(context).pop(),
              trailing: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasSelection ? _save : null,
                child: AnimatedOpacity(
                  opacity: hasSelection ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Text(
                      'Save',
                      style: AppTypography.body(
                        15,
                        weight: FontWeight.w600,
                      ).copyWith(
                        color: context.colors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBody(PlacePickerState state, EdgeInsets padding) {
    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colors.foreground,
          strokeWidth: 1.5,
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Text(
          state.query.trim().isEmpty
              ? 'Search for a place to add.'
              : 'No results found.',
          style: AppTypography.body(14).copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: padding.bottom + 24),
      itemCount: state.results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _MapboxAttribution();
        }
        final place = state.results[index - 1];
        final isSelected = _selected?.id == place.id;
        return _PlaceTile(
          place: place,
          selected: isSelected,
          onTap: () => _selectPlace(place),
        );
      },
    );
  }
}

/// Mapbox + OpenStreetMap attribution. TOS 의무.
class _MapboxAttribution extends StatelessWidget {
  const _MapboxAttribution();

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.foregroundMuted;
    final mutedFaint = muted.withValues(alpha: 0.3);
    final mutedSoft = muted.withValues(alpha: 0.5);
    final dotStyle = AppTypography.body(10).copyWith(color: mutedFaint);
    final linkStyle = AppTypography.body(10).copyWith(color: mutedSoft);

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 8),
      child: Row(
        children: [
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

// ── 장소 결과 타일 ───────────────────────────────────────────

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected
            ? context.colors.foreground.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // 위치 아이콘 (실제 정적지도는 픽 이후 mapbox-static-cache로 캐싱)
            ClipRRect(
              borderRadius: AppRadii.xsBorder,
              child: Container(
                width: 56,
                height: 56,
                color: context.colors.nonClickableArea,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.locationDot,
                    size: 18,
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // 정보 (3줄: 장소명 / 시·도 / 국가)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeText(
                    place.name,
                    style: AppTypography.body(15, weight: FontWeight.w500)
                        .copyWith(color: context.colors.foreground),
                  ),
                  if (place.region != null) ...[
                    const SizedBox(height: 3),
                    FadeText(
                      place.region!,
                      style: AppTypography.body(13).copyWith(
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ],
                  if (place.country != null) ...[
                    const SizedBox(height: 2),
                    FadeText(
                      place.country!,
                      style: AppTypography.body(12).copyWith(
                        color: context.colors.foregroundMuted
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (selected)
              FaIcon(
                FontAwesomeIcons.check,
                size: 16,
                color: context.colors.foreground,
              ),
          ],
        ),
      ),
    );
  }
}
