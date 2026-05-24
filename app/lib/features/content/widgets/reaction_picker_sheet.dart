import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../subscription/subscription_screen.dart';
import '../../subscription/subscription_view_model.dart';
import '../models/reaction.dart';

/// 콘텐츠에 리액션을 추가/수정하는 바텀시트.
///
/// - 6개 이모지 row — 현재 선택된 이모지가 강조
/// - HD pair: 코멘트 input(최대 200자)
/// - Free pair: comment input 자리에 Scenes HD 유도 배너
/// - Save 버튼: 이모지 선택 시 활성화. 기존 reaction이 있으면 "Update"
/// - Remove 버튼: 기존 reaction 있을 때만 노출
class ReactionPickerSheet extends ConsumerStatefulWidget {
  const ReactionPickerSheet({
    super.key,
    required this.initialEmoji,
    required this.initialComment,
    required this.onSubmit,
    required this.onRemove,
  });

  /// 사용자가 이미 단 리액션의 emoji. 신규면 null.
  final String? initialEmoji;

  /// 기존 코멘트. HD에서만 의미.
  final String? initialComment;

  /// (emoji, comment) — comment는 free pair에선 항상 null로 들어옴.
  final Future<void> Function(String emoji, String? comment) onSubmit;

  /// 기존 reaction이 있을 때 사용자가 명시적으로 제거하는 경로.
  final Future<void> Function() onRemove;

  @override
  ConsumerState<ReactionPickerSheet> createState() =>
      _ReactionPickerSheetState();
}

class _ReactionPickerSheetState extends ConsumerState<ReactionPickerSheet> {
  late String? _selectedEmoji;
  late TextEditingController _commentController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 신규 리액션이면 ❤️ 디폴트 선택 — 가장 흔한 액션이라 한 번 탭으로 저장
    // 가능. 기존 리액션 수정이면 그 emoji 그대로 prefilled.
    _selectedEmoji = widget.initialEmoji ?? ReactionEmojis.all.first;
    _commentController = TextEditingController(text: widget.initialComment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _hasExisting => widget.initialEmoji != null;

  Future<void> _onSave() async {
    if (_busy) return;
    final emoji = _selectedEmoji;
    if (emoji == null) return;
    final isSubscribed = ref.read(isSubscribedProvider);
    final comment = isSubscribed ? _commentController.text.trim() : null;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        emoji,
        (comment != null && comment.isNotEmpty) ? comment : null,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRemove() async {
    if (_busy) return;
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Remove this reaction?',
      confirmLabel: AppLocalizations.of(context).actionRemove,
      isDestructive: true,
    );
    if (!mounted || !confirmed) return;
    setState(() => _busy = true);
    try {
      await widget.onRemove();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSubscribed = ref.watch(isSubscribedProvider);
    // FloatingBottomSheet가 이미 viewInsets.bottom을 외곽 padding으로 더해
    // 시트 전체를 키보드 높이만큼 올려준다 — 여기서 또 더하면 이중 padding
    // 으로 bottom overflow 발생. picker는 그냥 Column intrinsic 그대로 두면
    // 시트가 키보드 위로 자연스럽게 떠오름.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          const SizedBox(height: 8),
          Text(
            'React',
            style: AppTypography.display(20).copyWith(
              color: context.colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          // 이모지 row — play filter 행의 라디오 스타일과 동일.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final e in ReactionEmojis.all) ...[
                  if (e != ReactionEmojis.all.first)
                    const SizedBox(width: 6),
                  Expanded(
                    child: _EmojiButton(
                      emoji: e,
                      selected: _selectedEmoji == e,
                      onTap: () => setState(() => _selectedEmoji = e),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // HD: comment input / Free: 업셀 배너
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: isSubscribed
                ? _CommentField(controller: _commentController)
                : const _HdUpsellBanner(),
          ),
          const SizedBox(height: 16),
          // 저장/제거 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (_hasExisting) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: _busy ? null : _onRemove,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.sheetInnerBorder,
                          color: context.colors.clickableArea,
                          border: Border.all(
                            color: context.colors.foreground
                                .withValues(alpha: 0.06),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            l10n.actionRemove,
                            style: AppTypography.body(
                              15,
                              weight: FontWeight.w600,
                            ).copyWith(color: context.colors.foregroundMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: _hasExisting ? 1 : 1,
                  child: GestureDetector(
                    onTap: (_selectedEmoji == null || _busy) ? null : _onSave,
                    child: AnimatedOpacity(
                      opacity: _selectedEmoji == null ? 0.4 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.sheetInnerBorder,
                          color: context.colors.foreground,
                        ),
                        child: Center(
                          child: _busy
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.background,
                                  ),
                                )
                              : Text(
                                  _hasExisting
                                      ? l10n.reactionPickerUpdate
                                      : l10n.actionSave,
                                  style: AppTypography.body(
                                    15,
                                    weight: FontWeight.w600,
                                  ).copyWith(color: context.colors.background),
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
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: AppRadii.sheetInnerBorder,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.surface,
              context.colors.surfaceElevated,
            ],
          ),
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Center(
          // 선택되지 않은 항목은 dim 처리 (play filter의 텍스트 톤과 같은
          // 패턴) — emoji는 색을 바꿀 수 없어 opacity로 표현.
          child: AnimatedOpacity(
            opacity: selected ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 150),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

class _CommentField extends StatelessWidget {
  const _CommentField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.clickableArea,
        borderRadius: AppRadii.sheetInnerBorder,
        border: Border.all(
          color: context.colors.foreground.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLength: ReactionEmojis.maxCommentLength,
        maxLines: 3,
        minLines: 1,
        style: AppTypography.body(14).copyWith(
          color: context.colors.foreground,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).reactionPickerCommentHint,
          hintStyle: AppTypography.body(14).copyWith(
            color: context.colors.foregroundMuted,
          ),
          border: InputBorder.none,
          counterStyle: AppTypography.body(11).copyWith(
            color: context.colors.foregroundMuted.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _HdUpsellBanner extends StatelessWidget {
  const _HdUpsellBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(SubscriptionScreen.route());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: AppRadii.sheetInnerBorder,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.surface,
              context.colors.surfaceElevated,
            ],
          ),
          border: Border.all(
            color: context.colors.foreground.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scenes HD',
                    style: AppTypography.display(16).copyWith(
                      color: context.colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).reactionPickerHdUpsellSubtitle,
                    style: AppTypography.body(12).copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: context.colors.foregroundMuted,
            ),
          ],
        ),
      ),
    );
  }
}
