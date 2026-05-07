import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';

/// Moment의 occurred_at 날짜를 고르는 floating 바텀시트 본문.
///
/// AddMediaSheet(업로드 시)와 ContentViewerV2(작성자 후수정)가 공유. 시트
/// 표시 자체는 호출자가 `FloatingBottomSheet.show`로 띄우고, 이 위젯은 본문만.
class MomentDatePickerSheet extends StatefulWidget {
  const MomentDatePickerSheet({
    super.key,
    required this.initialDate,
    required this.onConfirm,
  });

  final DateTime initialDate;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<MomentDatePickerSheet> createState() => _MomentDatePickerSheetState();
}

class _MomentDatePickerSheetState extends State<MomentDatePickerSheet> {
  late DateTime _selected;
  // 시트가 열린 시점의 now를 고정값으로 — build 안에서 DateTime.now()를 매번
  // 부르면 initState 때 클램프한 _selected와 어긋날 수 있어 assertion 위험.
  late final DateTime _max;
  static final DateTime _min = DateTime(2000);

  @override
  void initState() {
    super.initState();
    // DB의 occurred_at이 UTC로 들어오면 local과 timezone이 섞여서
    // CupertinoDatePicker의 initial<=max assertion이 KST 같은 +UTC zone에서
    // 깨짐. 둘 다 local로 통일 + 미래 시각이면 now로 클램프.
    _max = DateTime.now();
    final initialLocal = widget.initialDate.toLocal();
    _selected = initialLocal.isAfter(_max) ? _max : initialLocal;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMMd('en').format(_selected);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Moment Date',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          dateStr,
          style: AppTypography.body(14).copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: AppTypography.body(16).copyWith(
                  color: context.colors.foreground,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selected,
              maximumDate: _max,
              minimumDate: _min,
              onDateTimeChanged: (date) {
                setState(() => _selected = date);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => widget.onConfirm(_selected),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.sheetInnerBorder,
                  color: context.colors.foreground,
                ),
                child: Center(
                  child: Text(
                    'Confirm',
                    style: AppTypography.body(15, weight: FontWeight.w600)
                        .copyWith(color: context.colors.background),
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
