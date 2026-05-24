import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_urls.dart';
import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_toast.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_view_model.dart';
import '../home/widgets/detail_app_bar.dart';
import 'data/purchases_repository.dart';
import 'purchases_view_model.dart';
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

  // RC가 지역화 가격을 못 줄 때(로딩 중·미설정)만 쓰는 fallback — USD
  // 기준가. 정상 경로에선 storeProduct.priceString(지역 통화)을 쓴다.
  static const _fallbackMonthlyPrice = r'$4.99';

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
    final l10n = AppLocalizations.of(context);
    final isSubscribed = ref.watch(isSubscribedProvider);
    final subscribedBySelf = ref.watch(subscriptionViewModelProvider
        .select((s) => s.valueOrNull?.subscribedBySelf ?? false));
    final couple = ref.watch(homeViewModelProvider.select((s) => s.couple));
    // 구독 라벨에 들어갈 이름. partnerA = 본인, partnerB = 파트너.
    final subscriberName = subscribedBySelf
        ? couple.partnerAName
        : couple.partnerBName;
    final purchaseAction = ref.watch(purchasesViewModelProvider);
    final purchasesNotifier = ref.read(purchasesViewModelProvider.notifier);
    // RC가 주는 지역화 가격(예: "$4.99", "₩6,500"). 로딩 중·미설정이면
    // fallback(USD 기준가)으로 표시.
    final monthlyPrice =
        ref.watch(monthlyPriceProvider).valueOrNull ?? _fallbackMonthlyPrice;

    // 구매 액션 중 발생한 에러는 toast로 1회 노출 후 reset — viewmodel state는
    // 한 번 보여주고 sticky하게 남기지 않음. VM이 저장한 sentinel code를 여기서
    // l10n으로 매핑(raw exception 메시지를 사용자에게 노출하지 않음).
    ref.listen(
      purchasesViewModelProvider.select((s) => s.error),
      (_, next) {
        if (next == null || next.isEmpty) return;
        final message = next == PurchasesErrorCode.unavailable
            ? l10n.subscriptionUnavailableError
            : l10n.subscriptionGenericError;
        AppToast.show(context, message);
        purchasesNotifier.clearError();
      },
    );

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
                    l10n.subscriptionTagline,
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
                    title: l10n.subscriptionFeaturePairTitle,
                    description: l10n.subscriptionFeaturePairDesc,
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: l10n.subscriptionFeatureMomentTypesTitle,
                    description: l10n.subscriptionFeatureMomentTypesDesc,
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: l10n.subscriptionFeatureMomentsPerSceneTitle,
                    description: l10n.subscriptionFeatureMomentsPerSceneDesc,
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: l10n.subscriptionFeatureReactionCommentsTitle,
                    description: l10n.subscriptionFeatureReactionCommentsDesc,
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: l10n.subscriptionFeatureReorderTitle,
                    description: l10n.subscriptionFeatureReorderDesc,
                  ),
                  // TODO: Web Sharing 혜택 카드. 오픈 스펙에서 제외.
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: l10n.subscriptionFeatureFiltersTitle,
                    description: l10n.subscriptionFeatureFiltersDesc,
                  ),
                  const SizedBox(height: 12),
                  _FeatureCard(
                    title: l10n.subscriptionFeatureTemplatesTitle,
                    description: l10n.subscriptionFeatureTemplatesDesc,
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
                    l10n.subscriptionFooterPair,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.subscriptionFooterPlan(monthlyPrice),
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.subscriptionFooterTrialConversion(monthlyPrice),
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.subscriptionFooterTrialEligibility,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.subscriptionFooterCharge,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.subscriptionFooterRenewal(monthlyPrice),
                    textAlign: TextAlign.center,
                    style: AppTypography.body(11).copyWith(
                      color: context.colors.foregroundMuted.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.subscriptionFooterManage,
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
                          onTap: purchaseAction.isBusy
                              ? null
                              : () async {
                                  if (isSubscribed) {
                                    // 가입자: RC Customer Center 진입 — 구독
                                    // 관리/환불 안내/만료일 확인 등 사용자 직접.
                                    await purchasesNotifier.openCustomerCenter();
                                    return;
                                  }
                                  // 무료 회원: StoreKit 결제 시트 직접 호출
                                  // (RC Paywall 사용 안 함 — 우리 SubscriptionScreen이
                                  // 곧 paywall).
                                  final outcome =
                                      await purchasesNotifier.purchaseMonthly();
                                  if (!context.mounted) return;
                                  switch (outcome) {
                                    case PurchaseOutcome.purchased:
                                      AppToast.show(
                                        context,
                                        l10n.subscriptionToastWelcome,
                                      );
                                    case PurchaseOutcome.cancelled:
                                      // 사용자가 시트 닫음 — 알림 없이 무시.
                                      break;
                                    case PurchaseOutcome.unavailable:
                                    case PurchaseOutcome.error:
                                      // error toast는 viewmodel.error listener가
                                      // 처리.
                                      break;
                                  }
                                },
                          child: _SubscriptionPrimaryButton(
                            isSubscribed: isSubscribed,
                            label: isSubscribed
                                ? (subscriberName.isEmpty
                                    ? l10n.subscriptionCtaManage
                                    : l10n.subscriptionCtaThanks(
                                        subscriberName))
                                : l10n.subscriptionCtaSubscribe(monthlyPrice),
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
                                  l10n.subscriptionFreeBadge,
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
                          // ignore: discarded_futures
                          launchUrl(
                            Uri.parse(AppUrls.privacyPolicy),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Text(
                          l10n.subscriptionLinkPrivacy,
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
                          onTap: purchaseAction.isBusy
                              ? null
                              : () async {
                                  final restored = await purchasesNotifier
                                      .restorePurchases();
                                  if (!context.mounted) return;
                                  AppToast.show(
                                    context,
                                    restored
                                        ? l10n.subscriptionToastRestored
                                        : l10n.subscriptionToastNothingToRestore,
                                  );
                                },
                          child: Text(
                            l10n.subscriptionLinkRestore,
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
                          // ignore: discarded_futures
                          launchUrl(
                            Uri.parse(AppUrls.termsOfService),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        child: Text(
                          l10n.subscriptionLinkTerms,
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
