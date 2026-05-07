import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/floating_bottom_sheet.dart';
import '../auth/auth_view_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _autoScrolling = true;

  /// 사용자 스크롤 종료 후 자동 재개를 위해 예약해둔 타이머. 새 사용자
  /// 인터랙션이 들어오면 cancel해서 timer가 stack되지 않도록 한다.
  Timer? _resumeTimer;

  static const _creditLines = [
    'A story about us',
    '',
    'Fill the scenes between us',
    'with moments worth keeping.',
    '',
    'Photos we took',
    'Films we saw',
    'Songs we heard',
    'Places we went',
    '',
    'Moments become a scene,',
    'scenes become a story.',
    '',
    'Play back our story.',
    "The moments we've kept together",
    'start to feel',
    'a little more special.',
    '',
    'What scene are we in now?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) _startAutoScroll();
      });
    });
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    final distance = target - _scrollController.offset;
    // 이미 끝(또는 그 너머)이면 자동 스크롤 무의미.
    if (distance <= 0) return;
    final duration = Duration(milliseconds: (distance * 40).toInt());
    _scrollController.animateTo(
      target,
      duration: duration,
      curve: Curves.linear,
    );
  }

  /// 기술적 에러 메시지를 유저 친화적 문구로 정리. 사용자 취소는 toast 자체를
  /// 띄우지 않기 위해 null 반환.
  String? _humanizeAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('cancel')) return null;
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('host')) {
      return 'Check your connection and try again.';
    }
    return 'Sign in failed. Please try again.';
  }

  void _showLoginSheet() {
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _LoginSheet(
        onApple: () {
          Navigator.of(context).pop();
          _showAgreementSheet(_LoginProvider.apple);
        },
        onGoogle: () {
          Navigator.of(context).pop();
          _showAgreementSheet(_LoginProvider.google);
        },
        onKakao: () {
          Navigator.of(context).pop();
          _showAgreementSheet(_LoginProvider.kakao);
        },
      ),
    );
  }

  void _showAgreementSheet(_LoginProvider provider) {
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _AgreementSheet(
        onAgree: () {
          Navigator.of(context).pop();
          // 동의 후 실제 소셜 로그인. 세션 생기면 router가 자동 redirect.
          final notifier = ref.read(authViewModelProvider.notifier);
          switch (provider) {
            case _LoginProvider.apple:
              notifier.signInWithApple();
            case _LoginProvider.google:
              notifier.signInWithGoogle();
            case _LoginProvider.kakao:
              notifier.signInWithKakao();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    // 로그인 실패 시 앱 톤에 맞는 blur toast로 안내. 사용자 취소(cancel)는 무시.
    ref.listen(authViewModelProvider.select((s) => s.error), (prev, next) {
      if (next == null || next.isEmpty) return;
      final humanized = _humanizeAuthError(next);
      if (humanized == null) return;
      AppToast.show(context, humanized);
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) {
                    // 사용자 드래그 시작 — Flutter가 진행 중인 animateTo를
                    // 자동으로 취소해 주므로 우리는 자동 재개 타이머만 정리.
                    _autoScrolling = false;
                    _resumeTimer?.cancel();
                  }
                  if (n is ScrollEndNotification && !_autoScrolling) {
                    _resumeTimer?.cancel();
                    _resumeTimer = Timer(
                      const Duration(seconds: 2),
                      () {
                        if (!mounted) return;
                        _autoScrolling = true;
                        _startAutoScroll();
                      },
                    );
                  }
                  return false;
                },
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
                    stops: [0.0, 0.08, 0.92, 1.0],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        SizedBox(height: padding.top + 80),

                        // 쌍안경 로고. PNG에 배경이 baked-in이라 다크/라이트
                        // 별도 에셋 사용 — 각각의 앱 배경색과 톤이 맞춤.
                        Image.asset(
                          Theme.of(context).brightness == Brightness.dark
                              ? 'assets/logo/logo_dark.png'
                              : 'assets/logo/logo_light.png',
                          width: 96,
                          height: 96,
                        ),
                        const SizedBox(height: 28),

                        // 앱 타이틀
                        Text(
                          'Scenes',
                          style: AppTypography.display(42).copyWith(
                            color: context.colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // 경계선
                        Container(
                          width: 30,
                          height: 0.5,
                          color: context.colors.foreground
                              .withValues(alpha: 0.12),
                        ),

                        const SizedBox(height: 36),

                        // 크레딧 텍스트
                        for (final line in _creditLines)
                          Padding(
                            padding: EdgeInsets.only(bottom: line.isEmpty ? 4 : 6),
                            child: Text(
                              line,
                              textAlign: TextAlign.center,
                              style: AppTypography.display(22).copyWith(
                                color: line.isEmpty
                                    ? Colors.transparent
                                    : context.colors.foregroundMuted,
                                height: 1.45,
                              ),
                            ),
                          ),

                        const SizedBox(height: 48),

                        Container(
                          width: 30,
                          height: 0.5,
                          color: context.colors.foreground
                              .withValues(alpha: 0.12),
                        ),

                        const SizedBox(height: 36),

                        // 시작하기 버튼
                        GestureDetector(
                          onTap: _showLoginSheet,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: AppRadii.lgBorder,
                              color: context.colors.foreground,
                            ),
                            child: Center(
                              child: Text(
                                'Get Started',
                                style: AppTypography.body(15, weight: FontWeight.w600)
                                    .copyWith(color: context.colors.background),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: padding.bottom + 40),
                      ],
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

/// 어떤 소셜 프로바이더로 로그인할지 결정하는 enum. 동의 시트가 닫힌 후
/// 분기 위해 사용.
enum _LoginProvider { apple, google, kakao }

class _LoginSheet extends StatelessWidget {
  const _LoginSheet({
    required this.onApple,
    required this.onGoogle,
    required this.onKakao,
  });

  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onKakao;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Sign In',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _LoginButton(
                icon: FontAwesomeIcons.apple,
                label: 'Continue with Apple',
                onTap: onApple,
              ),
              const SizedBox(height: 10),
              _LoginButton(
                icon: FontAwesomeIcons.google,
                label: 'Continue with Google',
                onTap: onGoogle,
              ),
              const SizedBox(height: 10),
              // TODO: swap to a proper Kakao logo asset when adding the brand
              // mark to assets/.
              _LoginButton(
                icon: FontAwesomeIcons.solidComment,
                label: 'Continue with Kakao',
                onTap: onKakao,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;

  /// null이면 비활성 (반투명 + 탭 무시).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final fg = disabled
        ? context.colors.foreground.withValues(alpha: 0.35)
        : context.colors.foreground;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.sheetInnerBorder,
            color: context.colors.nonClickableArea,
            border: Border.all(
              color: context.colors.foreground.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, size: 16, color: fg),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTypography.body(15, weight: FontWeight.w500)
                    .copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgreementSheet extends StatefulWidget {
  const _AgreementSheet({required this.onAgree});

  final VoidCallback onAgree;

  @override
  State<_AgreementSheet> createState() => _AgreementSheetState();
}

class _AgreementSheetState extends State<_AgreementSheet> {
  bool _privacyChecked = false;
  bool _termsChecked = false;

  bool get _canProceed => _privacyChecked && _termsChecked;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Agreement',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
              children: [
                _AgreementTile(
                  label: 'Privacy Policy',
                  checked: _privacyChecked,
                  onCheck: () => setState(() => _privacyChecked = !_privacyChecked),
                  onView: () => launchUrl(Uri.parse('https://scenes.app/privacy')),
                ),
                _AgreementTile(
                  label: 'Terms of Service',
                  checked: _termsChecked,
                  onCheck: () => setState(() => _termsChecked = !_termsChecked),
                  onView: () => launchUrl(Uri.parse('https://scenes.app/terms')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _canProceed ? widget.onAgree : null,
              child: AnimatedOpacity(
                opacity: _canProceed ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.sheetInnerBorder,
                    color: context.colors.foreground,
                  ),
                  child: Center(
                    child: Text(
                      'Continue',
                      style: AppTypography.body(15, weight: FontWeight.w600)
                          .copyWith(color: context.colors.background),
                    ),
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

class _AgreementTile extends StatelessWidget {
  const _AgreementTile({
    required this.label,
    required this.checked,
    required this.onCheck,
    required this.onView,
  });

  final String label;
  final bool checked;
  final VoidCallback onCheck;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCheck,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            FaIcon(
              checked ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circle,
              size: 16,
              color: checked
                  ? context.colors.foreground
                  : context.colors.foregroundMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body(15, weight: FontWeight.w500)
                    .copyWith(color: context.colors.foreground),
              ),
            ),
            GestureDetector(
              onTap: onView,
              child: FaIcon(
                FontAwesomeIcons.arrowUpRightFromSquare,
                size: 12,
                color: context.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
