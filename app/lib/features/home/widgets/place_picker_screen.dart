import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/widgets/fade_text.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../models/scene.dart';
import 'detail_app_bar.dart';
import 'scene_detail_screen.dart';

// TODO: project rule says no external API keys in client — migrate to an
// Edge Function (e.g., `mapbox-geocode`). For dev, pass the token via
// `flutter run --dart-define=MAPBOX_TOKEN=...`.
const _mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

/// 장소 검색·선택 화면.
class PlacePickerScreen extends StatefulWidget {
  const PlacePickerScreen({super.key, this.scene});

  final Scene? scene;

  static Route<void> route({Scene? scene}) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          PlacePickerScreen(scene: scene),
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
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<_PlaceResult> _results = [];
  _PlaceResult? _selected;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    _focusNode.unfocus();
    setState(() => _searching = true);

    try {
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
        '?access_token=$_mapboxToken&limit=10&language=en,ko',
      );
      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final features = json['features'] as List<dynamic>;
        setState(() {
          _searching = false;
          _results = features.map((f) {
            final props = f as Map<String, dynamic>;
            final center = props['center'] as List<dynamic>;
            return _PlaceResult(
              name: props['text'] as String? ?? '',
              address: props['place_name'] as String? ?? '',
              lat: (center[1] as num).toDouble(),
              lng: (center[0] as num).toDouble(),
            );
          }).toList();
        });
      } else {
        setState(() {
          _searching = false;
          _results = [];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searching = false;
          _results = [];
        });
      }
    }
  }

  void _selectPlace(_PlaceResult place) {
    setState(() {
      _selected = _selected == place ? null : place;
    });
  }

  Future<void> _save() async {
    if (_selected == null) return;
    Navigator.of(context).pop();
    if (widget.scene != null) {
      final viewportWidth = MediaQuery.sizeOf(context).width;
      Navigator.of(context).push(
        SceneDetailScreen.fadeRoute(
          scene: widget.scene!,
          canisterSize: viewportWidth * 0.5,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final hasSelection = _selected != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    onSubmitted: (_) => _search(),
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
                                setState(() {});
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
                    onChanged: (_) => setState(() {}),
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
                  child: _searching
                      ? Center(
                          child: CircularProgressIndicator(
                            color: context.colors.foreground,
                            strokeWidth: 1.5,
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty
                                    ? 'Search for a place to add.'
                                    : 'No results found.',
                                style: AppTypography.body(14).copyWith(
                                  color: context.colors.foregroundMuted,
                                ),
                              ),
                            )
                          : ListView.builder(
                            padding: EdgeInsets.only(
                              bottom: padding.bottom + 24,
                            ),
                            itemCount: _results.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 20,
                                    right: 20,
                                    bottom: 8,
                                    top: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => launchUrl(
                                          Uri.parse(
                                              'https://www.mapbox.com/about/maps/'),
                                          mode: LaunchMode
                                              .externalApplication,
                                        ),
                                        child: Text(
                                          '© Mapbox',
                                          style: AppTypography.body(10)
                                              .copyWith(
                                            color: context
                                                .colors.foregroundMuted
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '  ·  ',
                                        style: AppTypography.body(10)
                                            .copyWith(
                                          color: context
                                              .colors.foregroundMuted
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => launchUrl(
                                          Uri.parse(
                                              'https://www.openstreetmap.org/copyright'),
                                          mode: LaunchMode
                                              .externalApplication,
                                        ),
                                        child: Text(
                                          '© OpenStreetMap',
                                          style: AppTypography.body(10)
                                              .copyWith(
                                            color: context
                                                .colors.foregroundMuted
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              final place = _results[index - 1];
                              final isSelected = _selected == place;
                              return _PlaceTile(
                                place: place,
                                selected: isSelected,
                                isDark: isDark,
                                onTap: () => _selectPlace(place),
                              );
                            },
                          ),
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
                      style: AppTypography.body(15, weight: FontWeight.w600)
                          .copyWith(color: context.colors.foreground),
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
}

// ── 장소 결과 타일 ───────────────────────────────────────────

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final _PlaceResult place;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  String get _staticMapUrl {
    final style = isDark ? 'dark-v11' : 'light-v11';
    return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/'
        'pin-s+888888(${place.lng},${place.lat})/'
        '${place.lng},${place.lat},14,0/120x120@2x'
        '?access_token=$_mapboxToken&attribution=false&logo=false';
  }

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
            // 지도 미리보기 썸네일
            ClipRRect(
              borderRadius: AppRadii.xsBorder,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Image.network(
                  _staticMapUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: context.colors.nonClickableArea,
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.locationDot,
                        size: 18,
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ),
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                              color: context.colors.nonClickableArea,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: context.colors.foregroundMuted,
                                    strokeWidth: 1,
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeText(
                    place.name,
                    style: AppTypography.body(15, weight: FontWeight.w500)
                        .copyWith(color: context.colors.foreground),
                  ),
                  const SizedBox(height: 4),
                  FadeText(
                    place.address,
                    style: AppTypography.body(12).copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
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

// ── 데이터 모델 ──────────────────────────────────────────────

class _PlaceResult {
  const _PlaceResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
}
