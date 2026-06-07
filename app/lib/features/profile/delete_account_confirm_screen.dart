import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/floating_bottom_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_view_model.dart';
import '../couple/couple_view_model.dart';
import '../push/push_service.dart';
import 'data/profile_repository.dart';
import '../profile/profile_view_model.dart';

/// 계정 탈퇴 마지막 확인 시트 — 사용자가 'DELETE'를 정확히 타이핑해야 영구
/// 삭제 버튼이 활성화. 실수 클릭으로 계정이 날아가는 일을 막는 강한 게이트.
///
/// 통과 시 [ProfileRepository.deleteAccount]가 service-role EF를 호출해
/// auth.users + 사용자의 모든 pair_id 데이터를 즉시 hard delete.
class DeleteAccountConfirmSheet extends ConsumerStatefulWidget {
  const DeleteAccountConfirmSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return FloatingBottomSheet.show<bool>(
      context: context,
      builder: (_) => const DeleteAccountConfirmSheet(),
    );
  }

  @override
  ConsumerState<DeleteAccountConfirmSheet> createState() =>
      _DeleteAccountConfirmSheetState();
}

class _DeleteAccountConfirmSheetState
    extends ConsumerState<DeleteAccountConfirmSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDelete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(pushServiceProvider).clearForCurrentDevice();
      await ref.read(profileRepositoryProvider).deleteAccount();
      // signOut 전에 deleted uid로 stale refetch가 일어나지 않도록 의존 provider
      // 들을 명시적으로 invalidate. 그렇지 않으면 라우터 redirect 중에도 옛 uid
      // 기준 fetch가 돌아 onboarding 전환이 멈추는 케이스 발생.
      ref.invalidate(activeCoupleProvider);
      ref.invalidate(myProfileProvider);
      await ref.read(authViewModelProvider.notifier).signOut();
      if (!mounted) return;
      // 모든 nested route/시트를 root로 pop — go_router redirect가 단일
      // route(onboarding)로 깔끔히 stack을 재구성하도록.
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        AppLocalizations.of(context).deleteAccountFailedToast,
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phrase = l10n.deleteAccountSignPhrase;
    final matches = _controller.text.trim() == phrase;

    // SingleChildScrollView로 감싸 키보드가 올라와 시트 컨텐츠 + 인셋이 화면을
    // 초과해도 NOT NORMALIZED constraint 에러 없이 자연스럽게 스크롤되도록.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            l10n.deleteAccountSignTitle,
            textAlign: TextAlign.center,
            style: AppTypography.display(17).copyWith(
              color: context.colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.deleteAccountSignHeading,
            textAlign: TextAlign.center,
            style: AppTypography.body(13).copyWith(
              color: context.colors.foregroundMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // 경고 박스 — ConfirmDialog의 notice 영역과 동일 톤.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.foreground.withValues(alpha: 0.04),
              borderRadius: AppRadii.mdBorder,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.circleExclamation,
                  size: 13,
                  color: context.colors.foregroundMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.deleteAccountConfirmNotice,
                    textAlign: TextAlign.start,
                    style: AppTypography.body(12).copyWith(
                      color: context.colors.foregroundMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 페어링 enter-code 폼과 동일한 외관 — outer Container + InputBorder
          // .none. 입력은 강제 대문자 변환(서명용 phrase 'DELETE' 매칭 일관성).
          Container(
            decoration: BoxDecoration(
              color: context.colors.nonClickableArea,
              borderRadius: AppRadii.sheetInnerBorder,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              enabled: !_busy,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return TextEditingValue(
                    text: newValue.text.toUpperCase(),
                    selection: newValue.selection,
                  );
                }),
              ],
              style: AppTypography.body(15, weight: FontWeight.w600).copyWith(
                color: context.colors.foreground,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: l10n.deleteAccountSignInputHint,
                hintStyle: AppTypography.body(15).copyWith(
                  color:
                      context.colors.foregroundMuted.withValues(alpha: 0.4),
                  letterSpacing: 0,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 두 버튼 가로 배치 — ConfirmDialog 톤과 일치.
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.sheetInnerBorder,
                      color: context.colors.nonClickableArea,
                    ),
                    child: Center(
                      child: Text(
                        l10n.commonCancel,
                        style: AppTypography.body(15,
                                weight: FontWeight.w600)
                            .copyWith(color: context.colors.foreground),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: matches && !_busy ? _onDelete : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.sheetInnerBorder,
                      color: matches && !_busy
                          ? context.colors.danger
                          : context.colors.danger.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: _busy
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            )
                          : Text(
                              l10n.deleteAccountSignAction,
                              style: AppTypography.body(15,
                                      weight: FontWeight.w600)
                                  .copyWith(color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
