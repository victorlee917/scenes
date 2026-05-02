import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/floating_bottom_sheet.dart';
import '../home/home_view_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _autoScrolling = true;

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
    _scrollController.addListener(_onUserScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (mounted) _startAutoScroll();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onUserScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onUserScroll() {
    if (!_autoScrolling) return;
  }

  void _startAutoScroll() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    final distance = target - _scrollController.offset;
    final duration = Duration(milliseconds: (distance * 40).toInt());
    _scrollController.animateTo(
      target,
      duration: duration,
      curve: Curves.linear,
    );
  }

  void _showLoginSheet() {
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _LoginSheet(
        onLogin: () {
          Navigator.of(context).pop();
          _showAgreementSheet();
        },
      ),
    );
  }

  void _showAgreementSheet() {
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _AgreementSheet(
        onAgree: () {
          Navigator.of(context).pop();
          ref.read(homeViewModelProvider.notifier).setLoggedIn(true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) {
                    _autoScrolling = false;
                  }
                  if (n is ScrollEndNotification && !_autoScrolling) {
                    Future<void>.delayed(
                      const Duration(seconds: 2),
                      () {
                        if (mounted) {
                          _autoScrolling = true;
                          _startAutoScroll();
                        }
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

                        // 쌍안경 로고
                        ClipPath(
                          clipper: _BinocularClipper(),
                          child: Container(
                            width: 100,
                            height: 60,
                            color: context.colors.foreground
                                .withValues(alpha: 0.12),
                          ),
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

class _BinocularClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final r = size.height / 2;
    final leftCenter = Offset(r, r);
    final rightCenter = Offset(size.width - r, r);
    final path = Path()
      ..addOval(Rect.fromCircle(center: leftCenter, radius: r))
      ..addOval(Rect.fromCircle(center: rightCenter, radius: r));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LoginSheet extends StatelessWidget {
  const _LoginSheet({required this.onLogin});

  final VoidCallback onLogin;

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
                onTap: onLogin,
              ),
              const SizedBox(height: 10),
              _LoginButton(
                icon: FontAwesomeIcons.google,
                label: 'Continue with Google',
                onTap: onLogin,
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            FaIcon(
              icon,
              size: 16,
              color: context.colors.foreground,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTypography.body(15, weight: FontWeight.w500)
                  .copyWith(color: context.colors.foreground),
            ),
          ],
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
              checked ? FontAwesomeIcons.squareCheck : FontAwesomeIcons.square,
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
