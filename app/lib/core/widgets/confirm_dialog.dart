import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors_ext.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';
import 'glass_panel.dart';

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.noticeText,
    required this.confirmLabel,
    this.cancelLabel,
    this.isDestructive = false,
  });

  final String title;
  final String? message;

  /// 메시지 아래에 info 아이콘 + muted body 톤의 안내 박스를 추가. 데이터
  /// 보존 정책처럼 사용자가 액션 직전에 인지해야 할 내용을 전달할 때 사용.
  final String? noticeText;

  final String confirmLabel;
  // null이면 빌드 시 l10n.commonCancel("Cancel"/"취소")로 fallback. 호출부가
  // 매번 "Cancel"을 박지 않아도 로케일 따라 자동 번역됨.
  final String? cancelLabel;
  final bool isDestructive;

  static Future<bool> show({
    required BuildContext context,
    required String title,
    String? message,
    String? noticeText,
    required String confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        noticeText: noticeText,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final resolvedCancelLabel =
        cancelLabel ?? AppLocalizations.of(context).commonCancel;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        // 플로팅 카드라 좌우(12)와 대칭되는 기본 하단 여백을 준다. 안전영역
        // inset만 쓰면 Android(padding.bottom==0)에서 소프트바에 바로 붙는다.
        bottom: padding.bottom + 12,
      ),
      child: GlassPanel(
        borderRadius: AppRadii.sheetBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTypography.display(17).copyWith(
                color: context.colors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(14).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
            if (noticeText != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.foreground.withValues(alpha: 0.04),
                    borderRadius: AppRadii.mdBorder,
                    border: Border.all(
                      color: context.colors.foreground.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.circleInfo,
                        size: 13,
                        color: context.colors.foregroundMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          noticeText!,
                          style: AppTypography.body(12).copyWith(
                            color: context.colors.foregroundMuted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.sheetInnerBorder,
                          color: context.colors.nonClickableArea,
                        ),
                        child: Center(
                          child: Text(
                            resolvedCancelLabel,
                            style: AppTypography.body(15,
                                    weight: FontWeight.w600)
                                .copyWith(
                                    color: context.colors.foreground),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.sheetInnerBorder,
                          color: isDestructive
                              ? const Color(0xFFDC3545)
                              : context.colors.foreground,
                        ),
                        child: Center(
                          child: Text(
                            confirmLabel,
                            style: AppTypography.body(15,
                                    weight: FontWeight.w600)
                                .copyWith(
                              color: isDestructive
                                  ? Colors.white
                                  : context.colors.background,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
