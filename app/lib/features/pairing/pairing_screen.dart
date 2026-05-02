import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/floating_bottom_sheet.dart';
import '../home/home_view_model.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  static const _mockInviteCode = 'SCENES-7X2K9';

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(const ClipboardData(text: _mockInviteCode));
    if (mounted) AppToast.show(context, 'Code copied');
  }

  void _shareCode() {
    SharePlus.instance.share(
      ShareParams(text: 'Join me on Scenes! Use my invite code: $_mockInviteCode'),
    );
  }

  void _showEnterCode() {
    _codeController.clear();
    FloatingBottomSheet.show(
      context: context,
      builder: (_) => _EnterCodeSheet(
        controller: _codeController,
        onSubmit: _submitCode,
      ),
    );
  }

  Future<void> _submitCode(String code) async {
    Navigator.of(context).pop();
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);
    // mock: 페어링 성공
    ref.read(homeViewModelProvider.notifier).setPaired(true);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: padding.top + 60,
                left: 32,
                right: 32,
                bottom: padding.bottom + 32,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // 프로필 + 아이콘
                  SizedBox(
                    width: 80 + 80 - 28,
                    height: 80,
                    child: Stack(
                      children: [
                        // 현재 유저 프로필
                        Positioned(
                          left: 0,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colors.background,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                ref.watch(homeViewModelProvider).couple.partnerAImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: context.colors.nonClickableArea,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 빈 상대 아이콘
                        Positioned(
                          left: 80 - 28,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colors.clickableArea,
                              border: Border.all(
                                color: context.colors.background,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: FaIcon(
                                FontAwesomeIcons.userPlus,
                                size: 28,
                                color: context.colors.foregroundMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 타이틀
                  Text(
                    'Find your\nperson',
                    textAlign: TextAlign.center,
                    style: AppTypography.display(34).copyWith(
                      color: context.colors.foreground,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share your invite code or\nenter your person\'s code to pair.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(15).copyWith(
                      color: context.colors.foregroundMuted,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 초대 코드
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.clickableArea,
                      borderRadius: AppRadii.lgBorder,
                      border: Border.all(
                        color: context.colors.foreground.withValues(alpha: 0.06),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your invite code',
                          style: AppTypography.body(12).copyWith(
                            color: context.colors.foregroundMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _mockInviteCode,
                          style: AppTypography.body(22, weight: FontWeight.w700)
                              .copyWith(
                            color: context.colors.foreground,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _copyCode,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: AppRadii.smBorder,
                                    color: context.colors.nonClickableArea,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FaIcon(
                                        FontAwesomeIcons.copy,
                                        size: 12,
                                        color: context.colors.foreground,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Copy',
                                        style: AppTypography.body(13,
                                                weight: FontWeight.w500)
                                            .copyWith(
                                                color:
                                                    context.colors.foreground),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: _shareCode,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: AppRadii.smBorder,
                                    color: context.colors.nonClickableArea,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FaIcon(
                                        FontAwesomeIcons.arrowUpFromBracket,
                                        size: 12,
                                        color: context.colors.foreground,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Share',
                                        style: AppTypography.body(13,
                                                weight: FontWeight.w500)
                                            .copyWith(
                                                color:
                                                    context.colors.foreground),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // 코드 입력 버튼
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _showEnterCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.lgBorder,
                          color: context.colors.foreground,
                        ),
                        child: Center(
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.background,
                                  ),
                                )
                              : Text(
                                  'Enter person\'s code',
                                  style: AppTypography.body(15,
                                          weight: FontWeight.w600)
                                      .copyWith(
                                          color: context.colors.background),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterCodeSheet extends StatefulWidget {
  const _EnterCodeSheet({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  State<_EnterCodeSheet> createState() => _EnterCodeSheetState();
}

class _EnterCodeSheetState extends State<_EnterCodeSheet> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Enter Code',
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
              color: context.colors.nonClickableArea,
              borderRadius: AppRadii.sheetInnerBorder,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.body(15, weight: FontWeight.w600).copyWith(
                color: context.colors.foreground,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: 'SCENES-XXXXX',
                hintStyle: AppTypography.body(15).copyWith(
                  color: context.colors.foregroundMuted.withValues(alpha: 0.4),
                  letterSpacing: 2,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _hasText
                  ? () => widget.onSubmit(widget.controller.text.trim())
                  : null,
              child: AnimatedOpacity(
                opacity: _hasText ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.sheetInnerBorder,
                    color: context.colors.foreground,
                  ),
                  child: Center(
                    child: Text(
                      'Pair',
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
