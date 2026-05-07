import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/data/content_repository.dart';
import '../../content/widgets/moment_date_picker_sheet.dart';
import '../../subscription/subscription_screen.dart';
import '../../subscription/subscription_view_model.dart';
import '../../subscription/tier_limits.dart';
import 'film_picker_screen.dart';
import 'music_picker_screen.dart';
import 'photo_picker_screen.dart';
import 'place_picker_screen.dart';
import 'scene_title_fallback.dart';
import '../home_view_model.dart';
import '../models/scene.dart';

/// + 버튼을 눌렀을 때 올라오는 미디어 추가 바텀시트.
class AddMediaSheet extends ConsumerStatefulWidget {
  const AddMediaSheet({
    super.key,
    required this.initialScene,
    this.showSceneHeader = true,
  });

  final Scene initialScene;
  final bool showSceneHeader;

  static Future<void> show({
    required BuildContext context,
    required Scene scene,
    bool showSceneHeader = true,
  }) {
    return FloatingBottomSheet.show(
      context: context,
      builder: (_) =>
          AddMediaSheet(initialScene: scene, showSceneHeader: showSceneHeader),
    );
  }

  @override
  ConsumerState<AddMediaSheet> createState() => _AddMediaSheetState();
}

class _AddMediaSheetState extends ConsumerState<AddMediaSheet> {
  late Scene _selectedScene;
  // 모먼트의 날짜. default는 오늘. 사용자가 picker로 변경 가능. 매체별 picker
  // 화면에 전달돼 콘텐츠의 occurred_at에 반영될 예정 (단계별 wiring 진행).
  late DateTime _momentDate;
  // 현재 선택된 scene의 콘텐츠 개수. null이면 아직 로딩 중. 한도 비교에 사용.
  int? _contentCount;
  // 비구독자 배너의 부 카피. 시트 열릴 때마다 _nextBannerVariant에서 받아 정해
  // 지고, 그 시트가 떠 있는 동안에는 고정. 다음 시트 열기에선 반대 변형.
  late final int _bannerVariant;
  // 다음 인스턴스가 사용할 변형 인덱스. 시트가 dispose되든 push되든 동일 앱
  // 세션 안에서는 0↔1을 번갈아 내보냄. 앱 재시작 시 0부터.
  static int _nextBannerVariant = 0;

  @override
  void initState() {
    super.initState();
    _selectedScene = widget.initialScene;
    _momentDate = DateTime.now();
    _loadCount();
    _bannerVariant = _nextBannerVariant;
    _nextBannerVariant = (_nextBannerVariant + 1) % 2;
  }

  /// 선택된 scene의 콘텐츠 개수 조회. 시트 열기와 scene 교체 시 재호출. 실패는
  /// silently swallow — 한도 표시만 못하고 picker는 정상 동작(서버가 최종
  /// gate).
  Future<void> _loadCount() async {
    final sceneId = _selectedScene.id;
    try {
      final c = await ref.read(contentRepositoryProvider).countByScene(sceneId);
      if (!mounted) return;
      // 응답 도착 사이 사용자가 다른 scene으로 바꿨다면 무시.
      if (_selectedScene.id != sceneId) return;
      setState(() => _contentCount = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _contentCount = null);
    }
  }

  int _limit(bool isHd) => TierLimits.contentsPerScene(isHd: isHd);

  /// scene이 한도에 도달했는지. 카운트 미로딩이면 false(picker는 열고 서버가
  /// 최종 거부) — 사용자 차단 줄이는 보수적 분기.
  bool _isFull(bool isHd) {
    final c = _contentCount;
    if (c == null) return false;
    return c >= _limit(isHd);
  }

  /// 남은 slot. 카운트 미로딩이면 한도 그대로 반환(낙관).
  int _remaining(bool isHd) {
    final c = _contentCount;
    if (c == null) return _limit(isHd);
    return (_limit(isHd) - c).clamp(0, _limit(isHd));
  }

  /// 한도 도달 시 사용자에게 알림 + 무료 페어면 업그레이드 시트 유도.
  /// 반환값이 true면 호출자는 진행, false면 중단.
  bool _gateOrToast(bool isHd) {
    if (!_isFull(isHd)) return true;
    final limit = _limit(isHd);
    if (isHd) {
      AppToast.show(
        context,
        'Scene is full ($limit). Delete some to add more.',
      );
    } else {
      AppToast.show(
        context,
        'Free scenes hold up to $limit moments. Upgrade for more.',
      );
    }
    return false;
  }

  void _showDatePicker() {
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => MomentDatePickerSheet(
        initialDate: _momentDate,
        onConfirm: (date) {
          setState(() => _momentDate = date);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showScenePicker() {
    final scenes = ref.read(homeViewModelProvider).scenes;
    showDialog<Scene>(
      context: context,
      builder: (ctx) =>
          _ScenePickerDialog(scenes: scenes, selectedId: _selectedScene.id),
    ).then((picked) {
      if (picked != null) {
        setState(() {
          _selectedScene = picked;
          _contentCount = null;
        });
        _loadCount();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scene = _selectedScene;
    final isSubscribed = ref.watch(isSubscribedProvider);
    final limit = _limit(isSubscribed);
    final remaining = _remaining(isSubscribed);
    final isFull = _isFull(isSubscribed);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'New Moment',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        if (widget.showSceneHeader) ...[
          // Scene 정보 (중앙 정렬, 세로 배치)
          GestureDetector(
            onTap: _showScenePicker,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: _SceneCoverOrFallback(scene: scene),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '#${scene.number}',
                  style: AppTypography.display(
                    12,
                  ).copyWith(color: context.colors.foregroundMuted),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    scene.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      15,
                      weight: FontWeight.w600,
                    ).copyWith(color: context.colors.foreground),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],

        if (isSubscribed)
          // 구독자: 날짜 버튼 + 1행 Photo, 2행 Film/Music/Place
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _DateButton(date: _momentDate, onTap: _showDatePicker),
                const SizedBox(height: 12),
                // 1행: Photo (전체 폭)
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: _MediaTypeCell(
                    icon: FontAwesomeIcons.solidImage,
                    label: 'Photo',
                    onTap: () {
                      if (!_gateOrToast(isSubscribed)) return;
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        PhotoPickerScreen.route(
                          scene: _selectedScene,
                          momentDate: _momentDate,
                          landOnSceneDetail: widget.showSceneHeader,
                          maxSelection: remaining,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // 2행: Film, Music, Place
                SizedBox(
                  height: 80,
                  child: Row(
                    children: [
                      Expanded(
                        child: _MediaTypeCell(
                          icon: FontAwesomeIcons.film,
                          label: 'Film',
                          onTap: () {
                            if (!_gateOrToast(isSubscribed)) return;
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              FilmPickerScreen.route(
                                scene: _selectedScene,
                                momentDate: _momentDate,
                                landOnSceneDetail: widget.showSceneHeader,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MediaTypeCell(
                          icon: FontAwesomeIcons.music,
                          label: 'Music',
                          onTap: () {
                            if (!_gateOrToast(isSubscribed)) return;
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MusicPickerScreen.route(
                                scene: _selectedScene,
                                momentDate: _momentDate,
                                landOnSceneDetail: widget.showSceneHeader,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MediaTypeCell(
                          icon: FontAwesomeIcons.locationDot,
                          label: 'Place',
                          onTap: () {
                            if (!_gateOrToast(isSubscribed)) return;
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              PlacePickerScreen.route(
                                scene: _selectedScene,
                                momentDate: _momentDate,
                                landOnSceneDetail: widget.showSceneHeader,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _CapacityCaption(
                  count: _contentCount,
                  limit: limit,
                  isFull: isFull,
                ),
              ],
            ),
          )
        else
          // 비구독자: 날짜 버튼 + Photo만 + 구독 배너
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _DateButton(date: _momentDate, onTap: _showDatePicker),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: _MediaTypeCell(
                    icon: FontAwesomeIcons.solidImage,
                    label: 'Photo',
                    onTap: () {
                      if (!_gateOrToast(isSubscribed)) return;
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        PhotoPickerScreen.route(
                          scene: _selectedScene,
                          momentDate: _momentDate,
                          landOnSceneDetail: widget.showSceneHeader,
                          maxSelection: remaining,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _CapacityCaption(
                  count: _contentCount,
                  limit: limit,
                  isFull: isFull,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(SubscriptionScreen.route());
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.sheetInnerBorder,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.colors.surface,
                          context.colors.surfaceElevated,
                        ],
                      ),
                      border: Border.all(
                        color: context.colors.foreground.withValues(
                          alpha: 0.06,
                        ),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scenes HD',
                                style: AppTypography.display(16).copyWith(
                                  color: context.colors.foreground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // 시트 열릴 때 _bannerVariant로 결정된 한 가지 카피
                              // 만 노출. 0=매체 다양성, 1=moments 한도 확장.
                              Text(
                                _bannerVariant == 0
                                    ? AppLocalizations.of(
                                        context,
                                      ).hdBannerBenefitMedia
                                    : AppLocalizations.of(
                                        context,
                                      ).hdBannerBenefitMoments,
                                style: AppTypography.body(12).copyWith(
                                  color: context.colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FaIcon(
                          FontAwesomeIcons.chevronRight,
                          size: 14,
                          color: context.colors.foregroundMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Scene 선택 다이얼로그 ────────────────────────────────────

class _ScenePickerDialog extends StatelessWidget {
  const _ScenePickerDialog({required this.scenes, required this.selectedId});

  final List<Scene> scenes;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: AppRadii.lgBorder,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadii.lgBorder,
          child: Material(
            color: Colors.transparent,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              itemCount: scenes.length,
              itemBuilder: (context, index) {
                final scene = scenes[index];
                final isSelected = scene.id == selectedId;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(scene),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: _SceneCoverOrFallback(scene: scene),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '#${scene.number}  ${scene.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              14,
                            ).copyWith(color: context.colors.foreground),
                          ),
                        ),
                        if (isSelected)
                          FaIcon(
                            FontAwesomeIcons.check,
                            size: 14,
                            color: context.colors.foreground,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// scene_card와 동일한 fallback 정책 — cover URL 없거나 로드 실패 시
/// 타이틀 첫 글자로 채움. 헤더 아바타(48px)와 scene picker dialog(36px)
/// 둘 다 같은 위젯 사용해 일관성 유지.
class _SceneCoverOrFallback extends StatelessWidget {
  const _SceneCoverOrFallback({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final url = scene.coverImageUrl;
    final fallback = SceneTitleFallback(title: scene.title);
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

// ── 날짜 버튼 + 날짜 picker 시트 ──────────────────────────────

/// New Moment 시트 안의 모먼트 날짜 표시·선택 버튼. 매체 cell들 위에 놓여
/// 사용자가 명시적으로 날짜를 고를 수 있게.
class _DateButton extends StatelessWidget {
  const _DateButton({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    final label = isToday ? 'Today' : DateFormat.yMMMd('en').format(date);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.clickableArea,
          borderRadius: AppRadii.sheetInnerBorder,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.solidCalendar,
              size: 14,
              color: context.colors.foregroundMuted,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTypography.body(
                14,
                weight: FontWeight.w500,
              ).copyWith(color: context.colors.foreground),
            ),
            const Spacer(),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 11,
              color: context.colors.foregroundMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 매체 셀 ──────────────────────────────────────────────────

class _MediaTypeCell extends StatelessWidget {
  const _MediaTypeCell({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconSize = 20,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () {
            Navigator.of(context).pop();
          },
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.clickableArea,
          borderRadius: AppRadii.sheetInnerBorder,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              size: iconSize,
              color: context.colors.foreground.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.body(
                12,
              ).copyWith(color: context.colors.foregroundMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시트 하단 미세한 캡션 — "Moments 12/30" 형태로 현재 scene의 모먼트 수와
/// 한도를 보여줌. 카운트 미로딩(null)이면 자리만 잡고 비워둠.
class _CapacityCaption extends StatelessWidget {
  const _CapacityCaption({
    required this.count,
    required this.limit,
    required this.isFull,
  });

  final int? count;
  final int limit;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    final c = count;
    if (c == null) {
      return const SizedBox(height: 16);
    }
    final l = AppLocalizations.of(context);
    return Text(
      l.addMediaCapacityLabel(c, limit),
      style: AppTypography.body(11).copyWith(
        color: isFull
            ? context.colors.foreground.withValues(alpha: 0.7)
            : context.colors.foregroundMuted,
        fontWeight: isFull ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
