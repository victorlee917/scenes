import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/widgets/fade_text.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../models/scene.dart';
import 'detail_app_bar.dart';
import 'scene_detail_screen.dart';

/// 영화 검색·선택 화면.
///
/// 한 번에 하나의 영화만 선택 가능. 검색 → 리스트 → 선택 → 저장.
class FilmPickerScreen extends StatefulWidget {
  const FilmPickerScreen({super.key, this.scene});

  final Scene? scene;

  static Route<void> route({Scene? scene}) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          FilmPickerScreen(scene: scene),
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
  State<FilmPickerScreen> createState() => _FilmPickerScreenState();
}

class _FilmPickerScreenState extends State<FilmPickerScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<_FilmResult> _results = [];
  _FilmResult? _selected;
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

    // TODO: 실제 API(TMDB 등) 연동. 현재는 mock.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _searching = false;
        _results = _mockSearch(query);
      });
    }
  }

  void _selectFilm(_FilmResult film) {
    setState(() {
      _selected = _selected == film ? null : film;
    });
  }

  Future<void> _save() async {
    if (_selected == null) return;
    // TODO: 영화 저장 로직.
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
                      hintText: 'Search films...',
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
                                    ? 'Search for a film to add.'
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
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final film = _results[index];
                              final isSelected = _selected == film;
                              return _FilmTile(
                                film: film,
                                selected: isSelected,
                                onTap: () => _selectFilm(film),
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
              title: 'Add Film',
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

// ── 영화 결과 타일 ───────────────────────────────────────────

class _FilmTile extends StatelessWidget {
  const _FilmTile({
    required this.film,
    required this.selected,
    required this.onTap,
  });

  final _FilmResult film;
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
            // 포스터
            ClipRRect(
              borderRadius: AppRadii.xsBorder,
              child: Container(
                width: 48,
                height: 72,
                color: context.colors.nonClickableArea,
                child: film.posterUrl != null
                    ? Image.network(
                        film.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: FaIcon(
                            FontAwesomeIcons.film,
                            size: 18,
                            color: context.colors.foregroundMuted,
                          ),
                        ),
                      )
                    : Center(
                        child: FaIcon(
                          FontAwesomeIcons.film,
                          size: 18,
                          color: context.colors.foregroundMuted,
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
                    film.title,
                    style: AppTypography.body(15, weight: FontWeight.w500)
                        .copyWith(color: context.colors.foreground),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: context.colors.foreground
                              .withValues(alpha: 0.06),
                        ),
                        child: Text(
                          film.type,
                          style: AppTypography.body(10).copyWith(
                            color: context.colors.foregroundMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        film.year,
                        style: AppTypography.body(12).copyWith(
                          color: context.colors.foregroundMuted,
                        ),
                      ),
                    ],
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

// ── Mock 데이터 ──────────────────────────────────────────────

class _FilmResult {
  const _FilmResult({
    required this.title,
    required this.type,
    required this.year,
    this.posterUrl,
  });

  final String title;
  final String type; // 'Movie' or 'TV Series'
  final String year;
  final String? posterUrl;
}

List<_FilmResult> _mockSearch(String query) {
  final all = [
    const _FilmResult(
      title: 'Past Lives',
      type: 'Movie',
      year: '2023',
      posterUrl: 'https://picsum.photos/seed/film-past-lives/200/300',
    ),
    const _FilmResult(
      title: 'Before Sunrise',
      type: 'Movie',
      year: '1995',
      posterUrl: 'https://picsum.photos/seed/film-before-sunrise/200/300',
    ),
    const _FilmResult(
      title: 'Normal People',
      type: 'TV Series',
      year: '2020',
      posterUrl: 'https://picsum.photos/seed/film-normal-people/200/300',
    ),
    const _FilmResult(
      title: 'In the Mood for Love',
      type: 'Movie',
      year: '2000',
      posterUrl: 'https://picsum.photos/seed/film-mood-love/200/300',
    ),
    const _FilmResult(
      title: 'Eternal Sunshine of the Spotless Mind',
      type: 'Movie',
      year: '2004',
      posterUrl: 'https://picsum.photos/seed/film-eternal/200/300',
    ),
    const _FilmResult(
      title: 'Fleabag',
      type: 'TV Series',
      year: '2016',
      posterUrl: 'https://picsum.photos/seed/film-fleabag/200/300',
    ),
  ];
  final q = query.toLowerCase();
  return all.where((f) => f.title.toLowerCase().contains(q)).toList();
}
