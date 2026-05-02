import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../../core/theme/app_typography.dart';
import '../models/scene.dart';
import '../../settings/settings_screen.dart';
import 'edit_profile_sheet.dart';
import '../../share/share_settings_screen.dart';
import '../../subscription/subscription_screen.dart';
import '../home_view_model.dart';
import 'detail_app_bar.dart';

/// Couple 프로필 화면.
///
/// 홈 상단 strip의 두 아바타를 눌렀을 때 Hero flight로 크게 확대되어
/// 이동한다. 배경은 홈과 동일한 `context.colors.background`.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static String partnerAHeroTag = 'couple-profile-a';
  static String partnerBHeroTag = 'couple-profile-b';

  static Route<void> route() {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 440),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const ProfileScreen();
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  /// Hero flight용 createRectTween. 기본 MaterialRectArcTween은
  /// 곡선 arc path여서 크기 보간이 방정맞게 느껴진다. 직선 RectTween으로
  /// 바꾸면 자연스럽게 커진다.
  static Tween<Rect?> straightRectTween(Rect? begin, Rect? end) =>
      RectTween(begin: begin, end: end);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _shareEnabled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // TODO: Supabase에서 프로필 데이터 다시 로드
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  void _showDatePicker(DateTime current) {
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _SinceDatePicker(
        initialDate: current,
        onConfirm: (date) {
          ref.read(homeViewModelProvider.notifier).updateSinceDate(date);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final state = ref.watch(homeViewModelProvider);
    final couple = state.couple;
    final sceneCount = state.scenes.length;
    final padding = MediaQuery.paddingOf(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final avatarSize = (viewportWidth * 0.16).clamp(48.0, 70.0);
    final overlap = avatarSize * 0.28;

    final sinceDate = DateFormat.yMMMMd('en').format(couple.sinceDate);
    final totalMedia = state.scenes.fold<SceneMediaCounts>(
      const SceneMediaCounts(),
      (sum, s) => sum + s.media,
    );
    final routeAnim = ModalRoute.of(context)?.animation ??
        const AlwaysStoppedAnimation<double>(1);

    return Scaffold(
      // backgroundColor handled by theme
      body: Stack(
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.18, 0.82, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final topPad = padding.top + DetailAppBar.barHeight + 80;
                  final bottomPad = padding.bottom + 80;
                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: context.colors.foreground,
                    backgroundColor: context.colors.nonClickableArea,
                    displacement: padding.top + 48 + 10,
                    edgeOffset: 0,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: topPad,
                      left: 24,
                      right: 24,
                      bottom: bottomPad,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - topPad - bottomPad,
                      ),
                      child: Column(
                children: [
                  SizedBox(
                    width: avatarSize + (avatarSize - overlap),
                    height: avatarSize,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          child: GestureDetector(
                            onTap: () => EditProfileSheet.show(
                              context: context,
                              currentName: couple.partnerAName,
                              currentImageUrl: couple.partnerAImageUrl,
                            ),
                            child: Hero(
                              tag: ProfileScreen.partnerAHeroTag,
                              createRectTween: ProfileScreen.straightRectTween,
                              child: _Avatar(
                                url: couple.partnerAImageUrl,
                                size: avatarSize,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: avatarSize - overlap,
                          child: GestureDetector(
                            onTap: () => EditProfileSheet.show(
                              context: context,
                              currentName: couple.partnerBName,
                              currentImageUrl: couple.partnerBImageUrl,
                            ),
                            child: Hero(
                              tag: ProfileScreen.partnerBHeroTag,
                              createRectTween: ProfileScreen.straightRectTween,
                              child: _Avatar(
                                url: couple.partnerBImageUrl,
                                size: avatarSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: routeAnim,
                    child: Text(
                      '${couple.partnerAName} · ${couple.partnerBName}',
                      textAlign: TextAlign.center,
                      style: AppTypography.display(22).copyWith(
                        color: context.colors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  _divider(context),
                  const SizedBox(height: 36),
                  FadeTransition(
                    opacity: routeAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            ..._buildNarrativeSpans(
                              context,
                              sinceDate,
                              sceneCount,
                              totalMedia,
                              onDateTap: () => _showDatePicker(couple.sinceDate),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: AppTypography.display(30)
                            .copyWith(
                          color: context.colors.foregroundMuted,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  // TODO: Share our Scenes 섹션. 오픈 스펙에서 제외.
                  // const SizedBox(height: 36),
                  // _divider(context),
                  // const SizedBox(height: 36),
                  // FadeTransition(
                  //   opacity: routeAnim,
                  //   child: _ShareSection(
                  //     enabled: _shareEnabled,
                  //     onToggle: (v) => setState(() => _shareEnabled = v),
                  //   ),
                  // ),
                  const SizedBox(height: 36),
                  _divider(context),
                  const SizedBox(height: 36),
                  FadeTransition(
                    opacity: routeAnim,
                    child: const _ScenesMaxBanner(),
                  ),
                    ],
                  ),
                ),
                ),
              );
            },
          ),
          ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: routeAnim,
              child: DetailAppBar(
                topInset: padding.top,
                title: '',
                titleOpacity: 0,
                borderOpacity: 0,
                onClose: () => Navigator.of(context).pop(),
                trailing: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).push(SettingsScreen.route());
                  },
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: FaIcon(FontAwesomeIcons.gear,
                          size: 18,
                          color: context.colors.foreground
                              .withValues(alpha: 0.9)),
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

TextStyle _highlight(BuildContext context) => TextStyle(
      fontWeight: FontWeight.w700,
      color: context.colors.foreground,
    );

List<InlineSpan> _buildNarrativeSpans(
  BuildContext context,
  String date,
  int sceneCount,
  SceneMediaCounts media, {
  VoidCallback? onDateTap,
}) {
  final hl = _highlight(context);
  final dateRecognizer = onDateTap != null
      ? (TapGestureRecognizer()..onTap = onDateTap)
      : null;
  if (sceneCount == 0) {
    return [
      const TextSpan(text: 'Since '),
      TextSpan(text: '$date,', style: hl, recognizer: dateRecognizer),
      const TextSpan(
        text: '\nwe have just begun.\n\n'
            'Together we will\ntake photos,\n'
            'watch films, listen to music,\n'
            'and visit places.',
      ),
    ];
  }

  final spans = <InlineSpan>[
    const TextSpan(text: 'Since '),
    TextSpan(text: '$date,', style: hl, recognizer: dateRecognizer),
    const TextSpan(text: '\nwe have kept\n'),
    TextSpan(text: '$sceneCount Scenes', style: hl),
    const TextSpan(text: ' between us.'),
  ];

  final mediaParts = <({String verb, int count, String noun})>[];
  if (media.photos > 0) {
    mediaParts.add((
      verb: 'took',
      count: media.photos,
      noun: media.photos == 1 ? 'photo' : 'photos',
    ));
  }
  if (media.films > 0) {
    mediaParts.add((
      verb: 'watched',
      count: media.films,
      noun: media.films == 1 ? 'film' : 'films',
    ));
  }
  if (media.music > 0) {
    mediaParts.add((
      verb: 'listened to',
      count: media.music,
      noun: media.music == 1 ? 'song' : 'songs',
    ));
  }
  if (media.places > 0) {
    mediaParts.add((
      verb: 'visited',
      count: media.places,
      noun: media.places == 1 ? 'place' : 'places',
    ));
  }

  if (mediaParts.isNotEmpty) {
    spans.add(const TextSpan(text: '\n\nWe '));
    for (int i = 0; i < mediaParts.length; i++) {
      final p = mediaParts[i];
      if (i > 0 && i == mediaParts.length - 1) {
        spans.add(const TextSpan(text: ', and '));
      } else if (i > 0) {
        spans.add(const TextSpan(text: ', '));
      }
      spans.add(TextSpan(text: '${p.verb} '));
      spans.add(TextSpan(text: '${p.count} ${p.noun}', style: hl));
    }
    spans.add(const TextSpan(text: '.'));
  }

  // 아직 기록하지 않은 매체 → 미래형 문장.
  final futureParts = <String>[];
  if (media.photos == 0) futureParts.add('take photos');
  if (media.films == 0) futureParts.add('watch films');
  if (media.music == 0) futureParts.add('listen to music');
  if (media.places == 0) futureParts.add('visit places');

  if (futureParts.isNotEmpty) {
    spans.add(const TextSpan(text: '\n\nWe could also '));
    for (int i = 0; i < futureParts.length; i++) {
      if (i > 0 && i == futureParts.length - 1) {
        spans.add(const TextSpan(text: ', and '));
      } else if (i > 0) {
        spans.add(const TextSpan(text: ', '));
      }
      spans.add(TextSpan(text: futureParts[i]));
    }
    spans.add(const TextSpan(text: '.'));
  }

  return spans;
}

Widget _divider(BuildContext context) => Center(
      child: Container(
        width: 30,
        height: 0.5,
        color: context.colors.foreground.withValues(alpha: 0.06),
      ),
    );

class _ShareSection extends StatelessWidget {
  const _ShareSection({
    required this.enabled,
    required this.onToggle,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.clickableArea,
        borderRadius: AppRadii.mdBorder,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share our Scenes',
                      style: AppTypography.body(16, weight: FontWeight.w600)
                          .copyWith(color: context.colors.foreground),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Show friends our story.',
                      style: AppTypography.body(13).copyWith(
                        color: context.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: enabled,
                onChanged: onToggle,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.smBorder,
                color: context.colors.foreground.withValues(alpha: 0.04),
                border: Border.all(
                  color: context.colors.foreground.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        launchUrl(
                          Uri.parse('https://scenes.app/s/sora-jun'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Text(
                        'scenes.app/s/sora-jun',
                        style: AppTypography.body(14).copyWith(
                          color: context.colors.foreground,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      SharePlus.instance.share(
                        ShareParams(
                          uri: Uri.parse('https://scenes.app/s/sora-jun'),
                        ),
                      );
                    },
                    child: FaIcon(
                      FontAwesomeIcons.shareFromSquare,
                      size: 16,
                      color: context.colors.foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(ShareSettingsScreen.route());
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.smBorder,
                  color: context.colors.foreground.withValues(alpha: 0.06),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Manage visibility',
                  style: AppTypography.body(13, weight: FontWeight.w500)
                      .copyWith(color: context.colors.foreground),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SinceDatePicker extends StatefulWidget {
  const _SinceDatePicker({
    required this.initialDate,
    required this.onConfirm,
  });

  final DateTime initialDate;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<_SinceDatePicker> createState() => _SinceDatePickerState();
}

class _SinceDatePickerState extends State<_SinceDatePicker> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMMd('en').format(_selected);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Since',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          dateStr,
          style: AppTypography.body(14).copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: AppTypography.body(16).copyWith(
                  color: context.colors.foreground,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selected,
              maximumDate: DateTime.now(),
              minimumDate: DateTime(2000),
              onDateTimeChanged: (date) {
                setState(() => _selected = date);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => widget.onConfirm(_selected),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.sheetInnerBorder,
                  color: context.colors.foreground,
                ),
                child: Center(
                  child: Text(
                    'Confirm',
                    style: AppTypography.body(15, weight: FontWeight.w600)
                        .copyWith(color: context.colors.background),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ScenesMaxBanner extends StatelessWidget {
  const _ScenesMaxBanner({this.isSubscribed = false});

  final bool isSubscribed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(SubscriptionScreen.route());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          borderRadius: AppRadii.lgBorder,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.surface,
              context.colors.surfaceElevated,
            ],
          ),
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scenes HD',
              style: AppTypography.display(20).copyWith(
                color: context.colors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSubscribed
                  ? 'Making our scenes more vivid.'
                  : 'Make our scenes more vivid.',
              style: AppTypography.body(14).copyWith(
                color: context.colors.foregroundMuted,
              ),
            ),
            if (!isSubscribed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.smBorder,
                  color: context.colors.foreground.withValues(alpha: 0.08),
                ),
                child: Text(
                  'Learn more',
                  style: AppTypography.body(13, weight: FontWeight.w600)
                      .copyWith(color: context.colors.foreground),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.nonClickableArea,
        border: Border.all(color: context.colors.background, width: 3),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              ColoredBox(color: context.colors.nonClickableArea),
        ),
      ),
    );
  }
}
