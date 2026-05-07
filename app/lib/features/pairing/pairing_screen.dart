import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/floating_action_sheet.dart';
import '../../core/widgets/floating_bottom_sheet.dart';
import '../auth/auth_view_model.dart';
import '../couple/couple_view_model.dart';
import '../couple/data/couple_repository.dart';
import '../couple/invite_view_model.dart';
import '../couple/models/couple_invite.dart';
import '../home/home_view_model.dart';
import '../home/widgets/scene_title_fallback.dart';
import '../profile/account_deletion.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  /// 1초 간격 ticker — 만료 카운트다운 라벨이 살아있게 한다.
  Timer? _tickTimer;

  /// 파트너가 내 코드를 redeem하는 순간 즉시 home으로 redirect되도록 couples
  /// row insert를 listen. 화면이 살아있는 동안만 유효.
  StreamSubscription<void>? _coupleSub;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _coupleSub = ref
        .read(coupleRepositoryProvider)
        .watchActiveCoupleInserts()
        .listen((_) {
      // 새 couples row가 들어왔다 = 페어링 성공. activeCoupleProvider 강제
      // refetch → 라우터의 redirect가 home으로 보냄.
      ref.read(activeCoupleProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _coupleSub?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) AppToast.show(context, 'Code copied');
  }

  void _shareCode(String code) {
    SharePlus.instance.share(
      ShareParams(
        text: 'Join me on Scenes! Use my invite code: $code',
      ),
    );
  }

  /// 우상단 더보기 → 로그아웃 또는 탈퇴 옵션. 둘 다 confirm 다이얼로그를 거친
  /// 뒤 실행되며, 성공 시 라우터가 자동으로 onboarding 화면으로 이동.
  void _showMoreActions() {
    FloatingActionSheet.show(
      context: context,
      items: [
        FloatingActionItem(
          label: 'Sign out',
          onTap: () async {
            final confirmed = await ConfirmDialog.show(
              context: context,
              title: 'Sign out?',
              message: 'You will need to sign in again to use Scenes.',
              confirmLabel: 'Sign out',
            );
            if (!confirmed || !mounted) return;
            await ref.read(authViewModelProvider.notifier).signOut();
          },
        ),
        FloatingActionItem(
          label: 'Delete account',
          isDestructive: true,
          onTap: () => AccountDeletion.confirmAndDelete(
            context: context,
            ref: ref,
          ),
        ),
      ],
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
    try {
      await ref.read(coupleRepositoryProvider).redeemInvite(code);
      // 성공 시 activeCoupleProvider refresh → 라우터 자동 home redirect.
      // realtime listener도 동일 트리거를 일으킬 수 있으나 idempotent하므로 OK.
      await ref.read(activeCoupleProvider.notifier).refresh();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      AppToast.show(context, _redeemErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, 'Failed to pair. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// `redeem_couple_invite` RPC가 던지는 에러 메시지를 사용자용으로 매핑.
  /// P0001 = raise exception, 23505 = single-active 트리거의 unique violation.
  String _redeemErrorMessage(PostgrestException e) {
    final msg = e.message;
    if (msg.contains('invalid invite code')) return 'Invalid code.';
    if (msg.contains('already redeemed')) return 'This code has already been used.';
    if (msg.contains('expired')) return 'This code has expired.';
    if (msg.contains('cannot redeem own invite')) return 'You can\'t use your own code.';
    if (msg.contains('inviter no longer available')) return 'This code is no longer available.';
    if (e.code == '23505') return 'You\'re already paired with someone.';
    return 'Failed to pair. Please try again.';
  }

  /// 만료까지 남은 시간 — 24h형식 H/M로 표시. 만료 후엔 "Expired".
  String _formatExpiry(CoupleInvite invite) {
    final now = DateTime.now();
    final diff = invite.expiresAt.difference(now);
    if (diff.isNegative) return 'Expired';
    if (diff.inHours >= 1) {
      return 'Expires in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    if (diff.inMinutes >= 1) {
      return 'Expires in ${diff.inMinutes}m';
    }
    return 'Expires in ${diff.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final inviteAsync = ref.watch(myInviteProvider);

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
                        // 현재 유저 프로필 — URL 없거나 로드 실패 시 이름 첫
                        // 글자 fallback (다른 화면들과 동일 패턴).
                        Positioned(
                          left: 0,
                          child: Builder(builder: (ctx) {
                            final couple = ref
                                .watch(homeViewModelProvider)
                                .couple;
                            final imageUrl = couple.partnerAImageUrl;
                            final myName = couple.partnerAName;
                            final fallback =
                                SceneTitleFallback(title: myName);
                            return Container(
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
                                child: imageUrl.isEmpty
                                    ? fallback
                                    : Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => fallback,
                                      ),
                              ),
                            );
                          }),
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

                  // 초대 코드 카드 — async 상태별 분기.
                  inviteAsync.when(
                    data: (invite) => _InviteCard(
                      code: invite.code,
                      expiryLabel: _formatExpiry(invite),
                      onCopy: () => _copyCode(invite.code),
                      onShare: () => _shareCode(invite.code),
                    ),
                    loading: () => const _InviteCardSkeleton(),
                    error: (_, _) => _InviteErrorCard(
                      onRetry: () =>
                          ref.read(myInviteProvider.notifier).regenerate(),
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

          // 우상단 더보기 버튼 — 로그아웃/탈퇴.
          Positioned(
            top: padding.top + 8,
            right: 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showMoreActions,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.ellipsis,
                    size: 18,
                    color: context.colors.foreground.withValues(alpha: 0.9),
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

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.code,
    required this.expiryLabel,
    required this.onCopy,
    required this.onShare,
  });

  final String code;
  final String expiryLabel;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            code,
            style: AppTypography.body(22, weight: FontWeight.w700).copyWith(
              color: context.colors.foreground,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            expiryLabel,
            style: AppTypography.body(11).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionPill(
                  icon: FontAwesomeIcons.copy,
                  label: 'Copy',
                  onTap: onCopy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionPill(
                  icon: FontAwesomeIcons.arrowUpFromBracket,
                  label: 'Share',
                  onTap: onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteCardSkeleton extends StatelessWidget {
  const _InviteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: context.colors.clickableArea,
        borderRadius: AppRadii.lgBorder,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: context.colors.foregroundMuted,
          ),
        ),
      ),
    );
  }
}

class _InviteErrorCard extends StatelessWidget {
  const _InviteErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: context.colors.clickableArea,
          borderRadius: AppRadii.lgBorder,
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            'Could not load code. Tap to retry.',
            textAlign: TextAlign.center,
            style: AppTypography.body(13).copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: AppRadii.smBorder,
          color: context.colors.nonClickableArea,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              icon,
              size: 12,
              color: context.colors.foreground,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.body(13, weight: FontWeight.w500)
                  .copyWith(color: context.colors.foreground),
            ),
          ],
        ),
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
              // 발급 코드 길이는 6자 고정. 그 이상 못 치도록 inputFormatter로
              // 차단(maxLength는 카운터 노출돼서 회피).
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
              ],
              style: AppTypography.body(15, weight: FontWeight.w600).copyWith(
                color: context.colors.foreground,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: 'A4F7K9',
                hintStyle: AppTypography.body(15).copyWith(
                  color: context.colors.foregroundMuted.withValues(alpha: 0.4),
                  letterSpacing: 4,
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
                  ? () => widget.onSubmit(
                      widget.controller.text.trim().toUpperCase())
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
