import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors_ext.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import '../couple/couple_view_model.dart';
import '../push/noti_prompt_state.dart';
import '../push/push_service.dart';

/// 페어링 직후 한 번 노출되는 푸시 권한 유도 화면.
///
/// 카피에 파트너 이름을 넣어 감정적 동기 부여 — "Don't miss {name}'s
/// moments." Allow / Skip 어느 쪽을 누르든 noti_prompt_shown 플래그가
/// 세팅돼서 라우터가 자동으로 home으로 redirect.
class NotiPromptScreen extends ConsumerStatefulWidget {
  const NotiPromptScreen({super.key});

  @override
  ConsumerState<NotiPromptScreen> createState() => _NotiPromptScreenState();
}

class _NotiPromptScreenState extends ConsumerState<NotiPromptScreen> {
  bool _busy = false;

  Future<void> _onAllow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // OS 다이얼로그를 띄움. 사용자가 Allow/Deny 누르면 status 변환됨.
      // authorized이면 PushService가 prefs row + token 등록까지 수행.
      await ref
          .read(pushServiceProvider)
          .requestPermissionFromOnboarding();
    } finally {
      // 결과와 상관없이 화면은 마침 — denied여도 프롬프트는 한 번 거쳤다.
      await ref.read(notiPromptStateProvider.notifier).markShown();
    }
  }

  Future<void> _onSkip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(notiPromptStateProvider.notifier).markShown();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final l = AppLocalizations.of(context);
    final partnerName =
        ref.watch(activeCoupleProvider).valueOrNull?.partner.displayName ?? '';
    final hasName = partnerName.isNotEmpty;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(
          top: padding.top + 60,
          left: 32,
          right: 32,
          bottom: padding.bottom + 24,
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // 알림 벨 아이콘
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.clickableArea,
                border: Border.all(
                  color: context.colors.foreground.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
              alignment: Alignment.center,
              child: FaIcon(
                FontAwesomeIcons.solidBell,
                size: 32,
                color: context.colors.foreground.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              hasName
                  ? l.notiPromptTitleWithName(partnerName)
                  : l.notiPromptTitleNoName,
              textAlign: TextAlign.center,
              style: AppTypography.display(30, text: partnerName).copyWith(
                color: context.colors.foreground,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasName
                  ? l.notiPromptBodyWithName(partnerName)
                  : l.notiPromptBodyNoName,
              textAlign: TextAlign.center,
              style: AppTypography.body(15).copyWith(
                color: context.colors.foregroundMuted,
                height: 1.5,
              ),
            ),

            const Spacer(flex: 3),

            // 권한 요청 버튼
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _busy ? null : _onAllow,
                child: AnimatedOpacity(
                  opacity: _busy ? 0.6 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.lgBorder,
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
                              l.notiPromptAllow,
                              style: AppTypography.body(15,
                                      weight: FontWeight.w600)
                                  .copyWith(
                                      color: context.colors.background),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // skip
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : _onSkip,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l.notiPromptSkip,
                  style: AppTypography.body(14, weight: FontWeight.w500)
                      .copyWith(color: context.colors.foregroundMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
