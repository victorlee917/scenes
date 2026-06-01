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
import '../couple/couple_view_model.dart';
import '../couple/data/couple_repository.dart';

/// 연결 해지 마지막 확인 시트 — 사용자가 'UNPAIR'를 정확히 타이핑해야 해지
/// 버튼이 활성화. 잘못 누른 한 번의 탭으로 데이터 삭제 카운트다운이 시작되지
/// 않도록 강한 게이트.
class DisconnectConfirmSheet extends ConsumerStatefulWidget {
  const DisconnectConfirmSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return FloatingBottomSheet.show<bool>(
      context: context,
      builder: (_) => const DisconnectConfirmSheet(),
    );
  }

  @override
  ConsumerState<DisconnectConfirmSheet> createState() =>
      _DisconnectConfirmSheetState();
}

class _DisconnectConfirmSheetState
    extends ConsumerState<DisconnectConfirmSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(coupleRepositoryProvider).disconnectCouple();
      if (!mounted) return;
      // activeCoupleProvider null이 되면 라우터가 pairing으로 redirect.
      await ref.read(activeCoupleProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, l10n.disconnectFailedToast);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phrase = l10n.disconnectSignPhrase;
    final matches = _controller.text.trim() == phrase;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            l10n.disconnectSignTitle,
            textAlign: TextAlign.center,
            style: AppTypography.display(17).copyWith(
              color: context.colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.disconnectSignHeading,
            textAlign: TextAlign.center,
            style: AppTypography.body(13).copyWith(
              color: context.colors.foregroundMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
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
                    l10n.disconnectConfirmNotice,
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
          // 페어링 enter-code 폼과 동일한 외관. 키보드 제안/자동수정 모두 비활성
          // — 'UNPAIR' 같은 고정 phrase 입력에 방해가 됨.
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
                hintText: l10n.disconnectSignInputHint,
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
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:
                      _busy ? null : () => Navigator.of(context).pop(false),
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
                  onTap: matches && !_busy ? _onConfirm : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.sheetInnerBorder,
                      color: matches && !_busy
                          ? const Color(0xFFDC3545)
                          : const Color(0xFFDC3545).withValues(alpha: 0.3),
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
                              l10n.disconnectConfirmAction,
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
