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
import '../film_picker_view_model.dart';
import '../models/scene.dart';
import '../models/tmdb_film.dart';
import 'detail_app_bar.dart';
import 'scene_detail_screen.dart';

/// 영화 검색·선택 화면.
///
/// 한 번에 하나의 영화만 선택 가능. 입력 → 300ms 디바운스 → TMDB 검색.
/// 검색·결과·로딩 상태는 [filmPickerViewModelProvider]가 관리.
class FilmPickerScreen extends ConsumerStatefulWidget {
  const FilmPickerScreen({
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
          FilmPickerScreen(
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
  ConsumerState<FilmPickerScreen> createState() => _FilmPickerScreenState();
}

class _FilmPickerScreenState extends ConsumerState<FilmPickerScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  TmdbFilm? _selected;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(filmPickerViewModelProvider.notifier).updateQuery(
          value,
          locale: _tmdbLocale(context),
        );
    setState(() {}); // suffix clear 버튼 노출 갱신
  }

  /// TMDB language 파라미터 결정.
  ///
  /// 앱 UI는 영어 고정이지만 영화 메타는 사용자 디바이스 locale을 따른다.
  /// 한국어 디바이스 → `ko-KR`, 그 외 → `en-US`(default).
  /// MaterialApp의 `locale` 오버라이드 영향을 받지 않도록 PlatformDispatcher
  /// 시스템 locale을 직접 읽음.
  String _tmdbLocale(BuildContext context) {
    final lang = View.of(context).platformDispatcher.locale.languageCode;
    return lang == 'ko' ? 'ko-KR' : 'en-US';
  }

  void _selectFilm(TmdbFilm film) {
    setState(() {
      _selected = _selected?.tmdbId == film.tmdbId ? null : film;
    });
  }

  /// 선택된 영화를 큐에 enqueue 후 picker를 즉시 닫고 scene detail로 이동.
  /// 실제 업로드는 background에서 [UploadQueueNotifier]가 처리.
  void _save() {
    final film = _selected;
    final scene = widget.scene;
    if (film == null || scene == null) return;

    ref.read(uploadQueueProvider.notifier).enqueueFilm(
          sceneId: scene.id,
          sceneTitle: scene.title,
          film: film,
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
    final state = ref.watch(filmPickerViewModelProvider);
    final hasSelection = _selected != null;

    // 검색 실패 시 앱 톤 toast로 안내. 결과 영역은 빈 상태 그대로 둠.
    ref.listen(
      filmPickerViewModelProvider.select((s) => s.error),
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

  Widget _buildResultsBody(FilmPickerState state, EdgeInsets padding) {
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
              ? 'Search for a film to add.'
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
          return const _TmdbAttribution();
        }
        final film = state.results[index - 1];
        final isSelected = _selected?.tmdbId == film.tmdbId;
        return _FilmTile(
          film: film,
          selected: isSelected,
          onTap: () => _selectFilm(film),
        );
      },
    );
  }
}

/// TMDB API 약관상 데이터 노출 화면에 attribution 표시 의무.
/// MapBox 처리 방식(place_picker_screen.dart)과 동일한 패턴.
class _TmdbAttribution extends StatelessWidget {
  const _TmdbAttribution();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 8),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://www.themoviedb.org/'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text(
          'Movie data provided by TMDB',
          style: AppTypography.body(10).copyWith(
            color: context.colors.foregroundMuted.withValues(alpha: 0.5),
          ),
        ),
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

  final TmdbFilm film;
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
                  if (film.director != null) ...[
                    const SizedBox(height: 3),
                    FadeText(
                      film.director!,
                      style: AppTypography.body(13).copyWith(
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  FadeText(
                    film.year != null
                        ? '${film.typeLabel} · ${film.year}'
                        : film.typeLabel,
                    style: AppTypography.body(12).copyWith(
                      color: context.colors.foregroundMuted
                          .withValues(alpha: 0.7),
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
