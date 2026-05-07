import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../home/home_view_model.dart';
import '../home/widgets/detail_app_bar.dart';
import 'subscription_view_model.dart';

/// Scenes HD 구독 화면.
///
/// 구독 상태는 [subscriptionViewModelProvider]에서 직접 관찰. 호출부에서
/// 따로 주입하지 않는다.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const SubscriptionScreen(),
    );
  }

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final isSubscribed = ref.watch(isSubscribedProvider);
    final subscribedBySelf = ref.watch(subscriptionViewModelProvider
        .select((s) => s.subscribedBySelf));
    final couple = ref.watch(homeViewModelProvider.select((s) => s.couple));
    // 구독 라벨에 들어갈 이름. partnerA = 본인, partnerB = 파트너.
    final subscriberName = subscribedBySelf
        ? couple.partnerAName
        : couple.partnerBName;

    return Scaffold(
      // backgroundColor handled by theme
      body: Stack(
        children: [
          // 스크롤 콘텐츠
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: padding.top + DetailAppBar.barHeight + 76,
                left: 24,
                right: 24,
                bottom: padding.bottom + 200,
              ),
              child: Column(
                children: [
                  Text(
                    'Scenes HD',
                    textAlign: TextAlign.center,
                    style: AppTypography.display(36).copyWith(
                      color: context.colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Make our scenes more vivid.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(16).copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Center(
                    child: Container(
                      width: 30,
                      height: 0.5,
                      color: context.colors.foreground.withValues(alpha: 0.06),
                    ),
                  ),
                  const SizedBox(height: 36),
                  _FeatureCard(
                    title: 'One subscribes, both shine',
                    description:
                        'Scenes HD unlocks for both of you.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: 'More Media Types',
                    description:
                        'Add films, music, and places to your scenes.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: 'More Moments per Scene',
                    description:
                        'Capture up to 100 moments in every scene, instead of 30.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: 'Reorder Scenes',
                    description:
                        'Arrange your scenes in any order you like.',
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: 'Play Multiple Scenes',
                    description:
                        'Relive your memories in a cinematic sequence.',
                  ),
                  // TODO: Web Sharing 혜택 카드. 오픈 스펙에서 제외.
                  // const SizedBox(height: 12),
                  // _FeatureCard(
                  //   title: 'Web Sharing',
                  //   description:
                  //       'Share your scenes as a beautiful webpage.',
                  // ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: 'Playback Filters',
                    description:
                        'Choose from a range of film looks for your playback.',
                  ),
                  const SizedBox(height: 36),
                  Center(
                    child: Container(
                      width: 30,
                      height: 0.5,
                      color: context.colors.foreground.withValues(alpha: 0.06),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Only one of you needs to subscribe — Scenes HD applies to both of you.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scenes HD is a monthly auto-renewing subscription at \$4.99/month, with a 7-day free trial for new subscribers.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Payment will be charged to your Apple ID account at confirmation of purchase.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period at \$4.99/month.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can manage or cancel your subscription in your App Store account settings after purchase. Any unused portion of a free trial will be forfeited when you start a paid subscription.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 고정 영역
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: padding.bottom + 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    context.colors.gradientBase.withValues(alpha: 1.0),
                    context.colors.gradientBase.withValues(alpha: 0.9),
                    context.colors.gradientBase.withValues(alpha: 0.58),
                    context.colors.gradientBase.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        GestureDetector(
                          onTap: isSubscribed
                              ? null
                              : () {
                                  // 구독 결제. UI는 추후.
                                },
                          child: _SubscriptionPrimaryButton(
                            isSubscribed: isSubscribed,
                            label: isSubscribed
                                ? (subscriberName.isEmpty
                                    ? 'Subscribed'
                                    : 'Thanks to $subscriberName')
                                : 'Subscribe for \$4.99/mo',
                          ),
                        ),
                        if (!isSubscribed)
                          Positioned(
                            top: -12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.background,
                                borderRadius: AppRadii.smBorder,
                                border: Border.all(
                                  color: context.colors.foreground
                                      .withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: AnimatedBuilder(
                                animation: _shimmerController,
                                builder: (context, child) {
                                  return ShaderMask(
                                    shaderCallback: (bounds) {
                                      final dx =
                                          _shimmerController.value * 3 - 1;
                                      return LinearGradient(
                                        begin: Alignment(dx, 0),
                                        end: Alignment(dx + 0.6, 0),
                                        colors: const [
                                          Color(0xFF888886),
                                          Color(0xFFFFFFFF),
                                          Color(0xFF888886),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ).createShader(bounds);
                                    },
                                    blendMode: BlendMode.srcIn,
                                    child: child,
                                  );
                                },
                                child: Text(
                                  'Free for 7 days',
                                  style: AppTypography.body(11,
                                          weight: FontWeight.w500)
                                      .copyWith(
                                          color: context.colors.foreground),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // 개인정보처리방침. UI는 추후.
                        },
                        child: Text(
                          'Privacy Policy',
                          style: AppTypography.body(12).copyWith(
                            color: context.colors.foregroundMuted,
                          ),
                        ),
                      ),
                      if (!isSubscribed) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '·',
                            style: AppTypography.body(12).copyWith(
                              color: context.colors.foregroundMuted,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // TODO: RevenueCat / StoreKit restorePurchases 호출.
                          },
                          child: Text(
                            'Restore',
                            style: AppTypography.body(12).copyWith(
                              color: context.colors.foregroundMuted,
                            ),
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '·',
                          style: AppTypography.body(12).copyWith(
                            color: context.colors.foregroundMuted,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // 서비스이용약관. UI는 추후.
                        },
                        child: Text(
                          'Terms of Service',
                          style: AppTypography.body(12).copyWith(
                            color: context.colors.foregroundMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 앱바
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DetailAppBar(
              topInset: padding.top,
              title: 'Scenes HD',
              titleOpacity: 0,
              borderOpacity: 0,
              onClose: () => Navigator.of(context).pop(),
              trailing: const SizedBox.shrink(),
              leading: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: FaIcon(FontAwesomeIcons.chevronLeft,
                        size: 18,
                        color: context.colors.foreground
                            .withValues(alpha: 0.9)),
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

/// 하단 primary 버튼.
///
/// 구독 전: solid foreground CTA. 구독 후: glass-morphism 톤(BackdropFilter
/// blur + 낮은 alpha 흰색 틴트). 코드베이스 공통 glass 톤(`glass_circle_button`)
/// 과 sigma·alpha를 동일하게 맞춰 다른 frosted UI와 일관되게 보이게 한다.
class _SubscriptionPrimaryButton extends StatelessWidget {
  const _SubscriptionPrimaryButton({
    required this.isSubscribed,
    required this.label,
  });

  final bool isSubscribed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: AppTypography.body(15, weight: FontWeight.w600).copyWith(
        color: isSubscribed
            ? context.colors.foregroundMuted
            : context.colors.background,
      ),
    );

    if (!isSubscribed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: AppRadii.mdBorder,
          color: context.colors.foreground,
        ),
        alignment: Alignment.center,
        child: text,
      );
    }

    return ClipRRect(
      borderRadius: AppRadii.mdBorder,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdBorder,
            color: context.colors.foreground.withValues(alpha: 0.06),
            border: Border.all(
              color: context.colors.foreground.withValues(alpha: 0.10),
              width: 0.6,
            ),
          ),
          alignment: Alignment.center,
          child: text,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: AppRadii.mdBorder,
        color: context.colors.clickableArea,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.body(15, weight: FontWeight.w600)
                .copyWith(color: context.colors.foreground),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.body(13).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
        ],
      ),
    );
  }
}
