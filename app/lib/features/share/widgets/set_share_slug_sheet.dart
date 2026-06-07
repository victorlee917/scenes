import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_urls.dart';
import '../../../core/theme/app_colors_ext.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/floating_bottom_sheet.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/share_repository.dart';
import '../share_view_model.dart';

/// 공유 닉네임(slug)을 설정/변경하는 바텀시트.
///
/// `scenes.id/` prefix 뒤에 들어갈 닉네임을 입력받고, 입력 중 실시간으로
/// 전역 사용 가능 여부를 확인한다. active 커플만 저장 가능(RLS).
class SetShareSlugSheet extends ConsumerStatefulWidget {
  const SetShareSlugSheet({super.key, this.currentSlug});

  /// 기존 닉네임(편집 모드). 신규 설정이면 null.
  final String? currentSlug;

  static Future<void> show({
    required BuildContext context,
    String? currentSlug,
  }) {
    return FloatingBottomSheet.show(
      context: context,
      builder: (_) => SetShareSlugSheet(currentSlug: currentSlug),
    );
  }

  @override
  ConsumerState<SetShareSlugSheet> createState() => _SetShareSlugSheetState();
}

enum _SlugStatus { idle, checking, available, taken, invalid, unchanged }

class _SetShareSlugSheetState extends ConsumerState<SetShareSlugSheet> {
  // slug 형식: 소문자 영숫자, 중간 하이픈, 3~30자, 양끝 영숫자. DB check와 동일.
  static final RegExp _slugFormat =
      RegExp(r'^[a-z0-9]([a-z0-9-]{1,28}[a-z0-9])$');

  final _controller = TextEditingController();
  Timer? _debounce;
  _SlugStatus _status = _SlugStatus.idle;
  bool _saving = false;
  // 디바운스된 가용성 체크가 늦게 도착했을 때 최신 입력과 어긋나지 않도록
  // 요청 시점의 값을 기억.
  String _inFlightQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.currentSlug != null) {
      _controller.text = widget.currentSlug!;
      _status = _SlugStatus.unchanged;
    }
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final value = _controller.text.trim();

    if (value == widget.currentSlug) {
      setState(() => _status = _SlugStatus.unchanged);
      return;
    }
    if (value.isEmpty) {
      setState(() => _status = _SlugStatus.idle);
      return;
    }
    if (!_slugFormat.hasMatch(value)) {
      setState(() => _status = _SlugStatus.invalid);
      return;
    }
    setState(() => _status = _SlugStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 400), () => _check(value));
  }

  Future<void> _check(String value) async {
    _inFlightQuery = value;
    try {
      final available =
          await ref.read(shareRepositoryProvider).isSlugAvailable(value);
      // 응답 도착 시점에 입력이 또 바뀌었으면 무시.
      if (!mounted || _inFlightQuery != value) return;
      setState(() =>
          _status = available ? _SlugStatus.available : _SlugStatus.taken);
    } catch (_) {
      if (!mounted || _inFlightQuery != value) return;
      // 네트워크 실패는 차단하지 않음 — 저장 시 최종 검증(RLS/unique)이 잡는다.
      setState(() => _status = _SlugStatus.idle);
    }
  }

  bool get _canSave =>
      !_saving &&
      (_status == _SlugStatus.available || _status == _SlugStatus.unchanged);

  Future<void> _save() async {
    if (!_canSave) return;
    final value = _controller.text.trim();
    if (value == widget.currentSlug) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(shareSlugProvider.notifier).setSlug(value);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on SlugTakenException {
      if (mounted) setState(() => _status = _SlugStatus.taken);
    } on SlugInvalidException {
      if (mounted) setState(() => _status = _SlugStatus.invalid);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, AppLocalizations.of(context).shareNicknameSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefix = AppUrls.shareDisplayUrl(''); // 'scenes.id/'

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          'Share ID',
          style: AppTypography.display(20).copyWith(
            color: context.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.shareNicknameSheetDesc,
          style: AppTypography.body(13).copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
        const SizedBox(height: 20),

        // 입력 필드 — prefix(고정) + 닉네임 입력.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.nonClickableArea,
              borderRadius: AppRadii.sheetInnerBorder,
              border: Border.all(
                color: context.colors.foreground.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Text(
                  prefix,
                  style: AppTypography.body(15).copyWith(
                    color: context.colors.foregroundMuted,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: [
                      // 소문자 영숫자 + 하이픈만, 최대 30자.
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9-]')),
                      LengthLimitingTextInputFormatter(30),
                    ],
                    style: AppTypography.body(15).copyWith(
                      color: context.colors.foreground,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'sora-jun',
                      hintStyle: AppTypography.body(15).copyWith(
                        color:
                            context.colors.foregroundMuted.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                _StatusIndicator(status: _status),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        // 상태/안내 문구 — 높이 고정으로 등장/소멸 시 레이아웃 흔들림 방지.
        SizedBox(
          height: 18,
          child: Center(child: _statusText(context, l10n)),
        ),

        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PrimaryActionButton(
            label: l10n.actionSave,
            enabled: _canSave,
            loading: _saving,
            onTap: _save,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _statusText(BuildContext context, AppLocalizations l10n) {
    final (text, color) = switch (_status) {
      _SlugStatus.available => (
          l10n.shareNicknameAvailable,
          context.colors.foregroundMuted,
        ),
      _SlugStatus.taken => (
          l10n.shareNicknameTaken,
          context.colors.danger,
        ),
      _SlugStatus.invalid => (
          l10n.shareNicknameInvalid,
          context.colors.foregroundMuted,
        ),
      _SlugStatus.unchanged => (
          widget.currentSlug != null ? l10n.shareNicknameChangeWarning : '',
          context.colors.foregroundMuted,
        ),
      _ => ('', context.colors.foregroundMuted),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: AppTypography.body(12).copyWith(color: color),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final _SlugStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _SlugStatus.checking => SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colors.foregroundMuted,
          ),
        ),
      _SlugStatus.available => Icon(
          Icons.check_circle,
          size: 18,
          color: context.colors.foreground.withValues(alpha: 0.7),
        ),
      _SlugStatus.taken => Icon(
          Icons.cancel,
          size: 18,
          color: context.colors.danger,
        ),
      _ => const SizedBox(width: 18),
    };
  }
}
