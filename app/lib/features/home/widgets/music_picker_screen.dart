import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/widgets/fade_text.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../models/scene.dart';
import 'detail_app_bar.dart';
import 'scene_detail_screen.dart';

/// 음악 검색·선택 화면.
///
/// 한 번에 하나의 곡만 선택 가능. 검색 → 리스트 → 선택 → 저장.
class MusicPickerScreen extends StatefulWidget {
  const MusicPickerScreen({super.key, this.scene});

  final Scene? scene;

  static Route<void> route({Scene? scene}) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) =>
          MusicPickerScreen(scene: scene),
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
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<_MusicResult> _results = [];
  _MusicResult? _selected;
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

    // TODO: 실제 API(Spotify/Apple Music 등) 연동. 현재는 mock.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _searching = false;
        _results = _mockSearch(query);
      });
    }
  }

  void _selectMusic(_MusicResult music) {
    setState(() {
      _selected = _selected == music ? null : music;
    });
  }

  Future<void> _save() async {
    if (_selected == null) return;
    // TODO: 음악 저장 로직.
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
                      hintText: 'Search music...',
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
                                    ? 'Search for music to add.'
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
                              final music = _results[index];
                              final isSelected = _selected == music;
                              return _MusicTile(
                                music: music,
                                selected: isSelected,
                                onTap: () => _selectMusic(music),
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
              title: 'Add Music',
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

// ── 음악 결과 타일 ───────────────────────────────────────────

class _MusicTile extends StatelessWidget {
  const _MusicTile({
    required this.music,
    required this.selected,
    required this.onTap,
  });

  final _MusicResult music;
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
            // 앨범 커버
            ClipRRect(
              borderRadius: AppRadii.xsBorder,
              child: Container(
                width: 56,
                height: 56,
                color: context.colors.nonClickableArea,
                child: music.coverUrl != null
                    ? Image.network(
                        music.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: FaIcon(
                            FontAwesomeIcons.music,
                            size: 18,
                            color: context.colors.foregroundMuted,
                          ),
                        ),
                      )
                    : Center(
                        child: FaIcon(
                          FontAwesomeIcons.music,
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
                    music.title,
                    style: AppTypography.body(15, weight: FontWeight.w500)
                        .copyWith(color: context.colors.foreground),
                  ),
                  const SizedBox(height: 3),
                  FadeText(
                    music.artist,
                    style: AppTypography.body(13).copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FadeText(
                    music.album,
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

// ── Mock 데이터 ──────────────────────────────────────────────

class _MusicResult {
  const _MusicResult({
    required this.title,
    required this.artist,
    required this.album,
    this.coverUrl,
  });

  final String title;
  final String artist;
  final String album;
  final String? coverUrl;
}

List<_MusicResult> _mockSearch(String query) {
  final all = [
    const _MusicResult(
      title: 'golden hour',
      artist: 'JVKE',
      album: 'this is what ____ feels like',
      coverUrl: 'https://picsum.photos/seed/music-golden/200/200',
    ),
    const _MusicResult(
      title: 'Lover',
      artist: 'Taylor Swift',
      album: 'Lover',
      coverUrl: 'https://picsum.photos/seed/music-lover/200/200',
    ),
    const _MusicResult(
      title: 'Perfect',
      artist: 'Ed Sheeran',
      album: '÷ (Divide)',
      coverUrl: 'https://picsum.photos/seed/music-perfect/200/200',
    ),
    const _MusicResult(
      title: 'La Vie en Rose',
      artist: 'Édith Piaf',
      album: 'La Vie en Rose',
      coverUrl: 'https://picsum.photos/seed/music-lavie/200/200',
    ),
    const _MusicResult(
      title: 'Moon River',
      artist: 'Audrey Hepburn',
      album: 'Breakfast at Tiffany\'s',
      coverUrl: 'https://picsum.photos/seed/music-moon/200/200',
    ),
    const _MusicResult(
      title: 'Can\'t Help Falling in Love',
      artist: 'Elvis Presley',
      album: 'Blue Hawaii',
      coverUrl: 'https://picsum.photos/seed/music-elvis/200/200',
    ),
  ];
  final q = query.toLowerCase();
  return all
      .where((m) =>
          m.title.toLowerCase().contains(q) ||
          m.artist.toLowerCase().contains(q) ||
          m.album.toLowerCase().contains(q))
      .toList();
}
