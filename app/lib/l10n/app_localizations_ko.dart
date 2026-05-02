// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Scenes';

  @override
  String coupleSince(String date) {
    return 'Since $date';
  }

  @override
  String coupleDDay(int days) {
    return 'd+$days';
  }

  @override
  String get sceneListA11yLabel => '씬 목록';

  @override
  String get transportSort => '씬 정렬';

  @override
  String get transportAdd => '씬 추가';

  @override
  String get transportPlay => '씬 재생';

  @override
  String get addSceneCardLabel => '새 Scene 추가';

  @override
  String get detailBack => '뒤로';

  @override
  String get detailMoreActions => '씬 작업';

  @override
  String get sceneListEditOrder => '순서 편집';

  @override
  String get sceneListNewestFirst => '최신 순';

  @override
  String get sceneListOldestFirst => '오래된 순';

  @override
  String get sceneListSave => '저장';

  @override
  String get sceneDetailEdit => '편집';

  @override
  String get sceneDetailDelete => '삭제';

  @override
  String get sceneDetailShare => '씬 공유';

  @override
  String get sceneDetailAddMedia => '미디어 추가';

  @override
  String get profileSettings => '설정';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSectionPreferences => '환경 설정';

  @override
  String get settingsSectionAbout => '정보';

  @override
  String get settingsSectionAccount => '계정';

  @override
  String get settingsTheme => '테마';

  @override
  String get settingsPushNotifications => '알림';

  @override
  String get settingsPrivacyPolicy => '개인정보처리방침';

  @override
  String get settingsTermsOfService => '서비스이용약관';

  @override
  String get settingsInstagram => 'Scenes 인스타그램';

  @override
  String get settingsLogout => '로그아웃';

  @override
  String get settingsDisconnect => '연결 해지';

  @override
  String get settingsDeleteAccount => '탈퇴';

  @override
  String get sceneDetailPlay => '씬 재생';

  @override
  String profileNarrative(
    String partnerA,
    String partnerB,
    String date,
    int count,
  ) {
    return '$partnerA와 $partnerB는 $date에 만나 $count개의 Scene을 찍었다.';
  }

  @override
  String coupleScenesCount(int count) {
    return '$count Scenes';
  }
}
