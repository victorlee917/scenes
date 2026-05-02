import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';

/// 콘텐츠 풀스크린 뷰어. 인스타 스토리 형태.
///
/// 좌우 스와이프로 같은 Scene의 콘텐츠 간 이동.
/// 아래로 드래그하면 화면이 따라 내려가며 임계점 넘으면 닫힘.
class ContentViewer extends StatefulWidget {
  const ContentViewer({
    super.key,
    required this.totalCount,
    required this.initialIndex,
    this.sceneImageUrl,
    this.sceneName,
    this.uploaderName,
    this.partnerNames = const [],
    this.mediaType = 'photo',
    this.uploadedAt,
  });

  final int totalCount;
  final int initialIndex;
  final String? sceneImageUrl;
  final String? sceneName;
  final String? uploaderName;
  final List<String> partnerNames;
  final String mediaType;
  final DateTime? uploadedAt;

  static Future<void> show({
    required BuildContext context,
    required int totalCount,
    required int initialIndex,
    String? sceneImageUrl,
    String? sceneName,
    String? uploaderName,
    List<String> partnerNames = const [],
    String mediaType = 'photo',
    DateTime? uploadedAt,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            ContentViewer(
          totalCount: totalCount,
          initialIndex: initialIndex,
          sceneImageUrl: sceneImageUrl,
          sceneName: sceneName,
          uploaderName: uploaderName,
          partnerNames: partnerNames,
          mediaType: mediaType,
          uploadedAt: uploadedAt,
        ),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
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
      ),
    );
  }

  @override
  State<ContentViewer> createState() => _ContentViewerState();
}

class _ContentViewerState extends State<ContentViewer> {
  late int _currentIndex;
  double _dragOffset = 0;
  bool _dragging = false;
  bool _creditMode = false;
  final Set<String> _likedBy = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleCreditMode() {
    setState(() => _creditMode = !_creditMode);
    if (_creditMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0 || _dragOffset > 0) {
      setState(() {
        _dragging = true;
        _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 400.0);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset > 120 ||
        (details.primaryVelocity != null && details.primaryVelocity! > 800)) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragging = false;
        _dragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final progress = (_dragOffset / 300).clamp(0.0, 1.0);
    final scale = 1.0 - progress * 0.1;
    final radius = progress * AppRadii.lg;

    return Stack(
      children: [
        // 배경 dim
        AnimatedContainer(
          duration: _dragging
              ? Duration.zero
              : const Duration(milliseconds: 250),
          color: Colors.black.withValues(alpha: 0.5 * (1 - progress)),
        ),
        GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: AnimatedContainer(
        duration: _dragging
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transformAlignment: Alignment.topCenter,
        transform: Matrix4.identity()
          // ignore: deprecated_member_use
          ..translate(0.0, _dragOffset)
          // ignore: deprecated_member_use
          ..scale(scale),
        child: Opacity(
          opacity: (1.0 - progress).clamp(0.0, 1.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Scaffold(
            backgroundColor: context.colors.background,
            body: Stack(
              children: [
                // 콘텐츠 페이지 + 좌우 탭 영역
                _ContentPage(
                  index: _currentIndex,
                  mediaType: widget.mediaType,
                ),

                // 좌측 탭 → 이전
                if (_currentIndex > 0)
                  Positioned(
                    left: 0,
                    top: padding.top + 80,
                    bottom: 0,
                    width: MediaQuery.sizeOf(context).width * 0.3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => _currentIndex--),
                    ),
                  ),

                // 우측 탭 → 다음
                if (_currentIndex < widget.totalCount - 1)
                  Positioned(
                    right: 0,
                    top: padding.top + 80,
                    bottom: 0,
                    width: MediaQuery.sizeOf(context).width * 0.3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => _currentIndex++),
                    ),
                  ),

                // 상단 그라데이션 scrim
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: padding.top + 100,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 하단 그라데이션 scrim
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: padding.bottom + 80,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 상단: 캐니스터 정보 | 인덱스 + 닫기 (credit 모드에서 숨김)
                if (!_creditMode)
                Positioned(
                  top: padding.top + 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      // 좌: 캐니스터 대표 사진 + 제목 + 매체 타입
                      if (widget.sceneImageUrl != null)
                        ClipOval(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: Image.network(
                              widget.sceneImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: context.colors.nonClickableArea,
                              ),
                            ),
                          ),
                        ),
                      if (widget.sceneImageUrl != null)
                        const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.sceneName != null)
                            Text(
                              widget.sceneName!,
                              style: AppTypography.body(13,
                                      weight: FontWeight.w600)
                                  .copyWith(
                                      color: context.colors.foreground),
                            ),
                          Text(
                            widget.mediaType,
                            style: AppTypography.body(11).copyWith(
                              color: context.colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // 우: 인덱스 · X (blur pill)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                                sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black
                                    .withValues(alpha: 0.3),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_currentIndex + 1}/${widget.totalCount}',
                                    style: AppTypography.body(11)
                                        .copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8),
                                    child: Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white
                                            .withValues(
                                                alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                  FaIcon(
                                    FontAwesomeIcons.xmark,
                                    size: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 하단: credit 버튼
                if (!_creditMode)
                  Positioned(
                    bottom: padding.bottom + 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        // 좌: 공유
                        _BottomPillButton(
                          icon: FontAwesomeIcons.shareFromSquare,
                          onTap: () {
                            // 공유. UI는 추후.
                          },
                        ),
                        const Spacer(),
                        // 중앙: credits
                        GestureDetector(
                          onTap: () =>
                              _toggleCreditMode(),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                  sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withValues(alpha: 0.3),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'credits',
                                  style:
                                      AppTypography.body(12).copyWith(
                                    color: Colors.white
                                        .withValues(alpha: 0.7),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // 우: 좋아요 (현재 유저 = 첫 번째 파트너)
                        _BottomPillButton(
                          icon: _likedBy.isNotEmpty
                              ? FontAwesomeIcons.solidHeart
                              : FontAwesomeIcons.heart,
                          onTap: () {
                            final me = widget.partnerNames.isNotEmpty
                                ? widget.partnerNames.first
                                : 'You';
                            setState(() {
                              if (_likedBy.contains(me)) {
                                _likedBy.remove(me);
                              } else {
                                _likedBy.add(me);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // credit 오버레이
                if (_creditMode)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleCreditMode,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.75),
                        child: SafeArea(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 40,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'scene #${_currentIndex + 1}',
                                    style: AppTypography.body(12).copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.5),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.sceneName ?? '',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.display(
                                      28,
                                      text: widget.sceneName,
                                    ).copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                  _CreditEntry(
                                    label: _mediaVerb(widget.mediaType),
                                    value: widget.uploaderName ?? '',
                                  ),
                                  if (widget.uploadedAt != null) ...[
                                    const SizedBox(height: 32),
                                    _CreditEntry(
                                      label: 'on',
                                      value: DateFormat.yMMMMd('en')
                                          .format(widget.uploadedAt!),
                                    ),
                                  ],
                                  if (_likedBy.isNotEmpty) ...[
                                    const SizedBox(height: 32),
                                    _CreditEntry(
                                      label: 'loved by',
                                      value: _likedBy.join(' · '),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ),
        ),
        ),
      ],
    );
  }
}

// ── 사진 콘텐츠 페이지 (풀스크린) ────────────────────────────

class _ContentPage extends StatelessWidget {
  const _ContentPage({
    required this.index,
    required this.mediaType,
  });

  final int index;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'photo') {
      return _PhotoContentPage(index: index);
    }
    // TODO: film, music, places 타입별 페이지.
    return Center(
      child: Text(
        '$mediaType #${index + 1}',
        style: AppTypography.display(24).copyWith(
          color: context.colors.foregroundMuted,
        ),
      ),
    );
  }
}

class _PhotoContentPage extends StatelessWidget {
  const _PhotoContentPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Image.network(
        'https://picsum.photos/seed/content-$index/800/1200',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => Center(
          child: Text(
            'Photo #${index + 1}',
            style: AppTypography.display(24).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
        ),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Center(
                child: CircularProgressIndicator(
                  color: context.colors.foreground,
                  strokeWidth: 1.5,
                ),
              ),
      ),
    );
  }
}

String _mediaVerb(String mediaType) {
  switch (mediaType) {
    case 'photo':
      return 'took by';
    case 'film':
      return 'watched by';
    case 'music':
      return 'listened to by';
    case 'place':
      return 'visited by';
    default:
      return 'added by';
  }
}

class _BottomPillButton extends StatelessWidget {
  const _BottomPillButton({
    required this.icon,
    required this.onTap,
  });

  final FaIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: Center(
              child: FaIcon(
                icon,
                size: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditEntry extends StatelessWidget {
  const _CreditEntry({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.body(12).copyWith(
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppTypography.display(22, text: value).copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
