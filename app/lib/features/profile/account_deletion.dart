import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/app_toast.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../auth/auth_view_model.dart';
import '../profile/data/profile_repository.dart';
import '../profile/profile_view_model.dart';
import '../push/push_service.dart';

/// 계정 탈퇴 흐름 공용 헬퍼. Settings의 Danger Zone과 페어링 화면의 더보기
/// 시트가 동일 경로로 호출하도록 모음.
///
/// **App Store/Google Play 자동 갱신 구독 처리**: Apple Review Guideline
/// 3.1.2에 의해 앱이 사용자 대신 구독을 자동 취소할 수 없음. 즉 탈퇴해도
/// 시스템 설정에서 별도 취소 안 하면 결제 계속 됨. 그래서:
///   - 활성 구독이 있으면 confirm 다이얼로그를 한 번 더 띄워 사용자에게 명시
///     적으로 인지시키고, "Manage subscription" 버튼으로 시스템 설정으로 안내
///   - 그래도 진행하면 soft-delete + signOut. 결제 취소는 사용자 책임
class AccountDeletion {
  AccountDeletion._();

  /// 탈퇴 confirm + 실행. context는 라이브 위젯의 것이어야 — async gap에서
  /// `mounted` 가드 반복.
  static Future<void> confirmAndDelete({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    // 1) 첫 confirm — 일반 케이스
    final firstConfirm = await ConfirmDialog.show(
      context: context,
      title: 'Delete account?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!firstConfirm || !context.mounted) return;

    // 2) 활성 구독이 있으면 추가 안내 + Manage subscription 옵션
    final myProfile = ref.read(myProfileProvider).valueOrNull;
    if (myProfile?.hasActiveSubscription ?? false) {
      final shouldProceed = await _showSubscriptionWarning(context);
      if (!shouldProceed || !context.mounted) return;
    }

    // 3) 실행 — push 토큰 정리 → softDelete → signOut. 라우터가 session 변화로
    // onboarding으로 자동 이동.
    try {
      await ref.read(pushServiceProvider).clearForCurrentDevice();
      await ref.read(profileRepositoryProvider).softDeleteAccount();
      await ref.read(authViewModelProvider.notifier).signOut();
    } catch (_) {
      if (!context.mounted) return;
      AppToast.show(context, 'Failed to delete account.');
    }
  }

  /// 활성 구독 안내 다이얼로그. true 반환 = "Delete anyway" 진행, false =
  /// 취소(또는 Manage subscription으로 이동해 시스템 설정 열림).
  static Future<bool> _showSubscriptionWarning(BuildContext context) async {
    // ConfirmDialog는 두 버튼만 지원해 3-way 분기엔 부족. showModalBottomSheet
    // 또는 showDialog로 직접 그리거나, 단계 나눠서 두 번 띄우는 방법. 여기선
    // 가장 단순한 패턴 — Manage subscription 안내 → 사용자가 "Delete anyway"
    // 누르면 진행, 아니면 시스템 설정 열고 종료.
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Active subscription',
      message:
          'Cancel your subscription in System Settings to stop being charged. '
          'Deleting your account here does not cancel it.',
      confirmLabel: 'Delete anyway',
      cancelLabel: 'Manage subscription',
      isDestructive: true,
    );
    if (confirmed) return true;
    // Cancel 측 버튼이 Manage subscription 역할 — 시스템 설정 구독 페이지 열기.
    await _openSubscriptionsSettings();
    return false;
  }

  /// iOS는 Safari가 https URL을 받아 Subscriptions 화면을 열어줌.
  /// Android는 Play Store 앱이 동일 패턴.
  static Future<void> _openSubscriptionsSettings() async {
    final url = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // launch 실패해도 사용자가 수동으로 설정 열 수 있음 — 별도 처리 X.
    }
  }
}
