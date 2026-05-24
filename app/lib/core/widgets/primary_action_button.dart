import 'package:flutter/material.dart';

import '../theme/app_colors_ext.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

/// 시트 하단의 전체폭 1차 액션 버튼 (생성·저장 등).
///
/// spinner ↔ 라벨 전환 시 버튼 높이가 변하지 않도록 콘텐츠를 고정 높이로
/// 감싼다 — 높이가 변하면 시트 전체 layout이 한 번 덜컹인다.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.enabled,
    required this.loading,
  });

  final String label;
  final VoidCallback onTap;

  /// 입력 조건 충족 여부 — false면 흐리게 + 탭 비활성.
  final bool enabled;

  /// 비동기 작업 진행 중 — true면 spinner 표시 + 탭 비활성.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: (enabled && !loading) ? onTap : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: AppRadii.sheetInnerBorder,
              color: context.colors.foreground,
            ),
            alignment: Alignment.center,
            child: SizedBox(
              height: 22,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.background,
                        ),
                      )
                    : Text(
                        label,
                        style: AppTypography.body(16, weight: FontWeight.w600)
                            .copyWith(color: context.colors.background),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
