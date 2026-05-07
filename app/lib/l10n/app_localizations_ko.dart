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
  String get homeEmptyTaglinePrefix => '우리가 함께 한 ';

  @override
  String get homeEmptyTaglineBrand => 'Scene';

  @override
  String get homeEmptyTaglineSuffix => '을\n간직해 보세요.';

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
  String get settingsDangerZone => '위험 구역';

  @override
  String get dangerZoneTitle => '위험 구역';

  @override
  String get dangerZoneSubtitle => '이 영역의 작업은 되돌릴 수 없습니다.';

  @override
  String uploadChipPhotosProgress(int current, int total) {
    return '$current / $total 업로드 중';
  }

  @override
  String get uploadChipFilmActive => '영화 추가 중…';

  @override
  String get uploadChipMusicActive => '음악 추가 중…';

  @override
  String get uploadChipPlaceActive => '장소 추가 중…';

  @override
  String uploadChipPhotosDone(int count) {
    return '사진 $count장 추가됨';
  }

  @override
  String get uploadChipFilmDone => '영화 추가됨';

  @override
  String get uploadChipMusicDone => '음악 추가됨';

  @override
  String get uploadChipPlaceDone => '장소 추가됨';

  @override
  String get uploadChipFailed => '업로드 실패';

  @override
  String get uploadChipCancelling => '취소 중…';

  @override
  String get profileDeletedUserName => '탈퇴한 사용자';

  @override
  String get sceneDetailPlay => '씬 재생';

  @override
  String get sceneDetailEmptyMedia => 'Scene을 소중한 순간들로 채워 보세요';

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

  @override
  String notiPromptTitleWithName(String name) {
    return '$name님의 소식을\n놓치지 마세요';
  }

  @override
  String get notiPromptTitleNoName => '소중한 소식을\n놓치지 마세요';

  @override
  String notiPromptBodyWithName(String name) {
    return '$name님이 새로운 Scene을 추가하거나\n반응을 남길 때 알려드릴게요.';
  }

  @override
  String get notiPromptBodyNoName => '파트너가 새로운 Scene을 추가하거나\n반응을 남길 때 알려드릴게요.';

  @override
  String get notiPromptAllow => '알림 허용';

  @override
  String get notiPromptSkip => '나중에 하기';

  @override
  String addMediaCapacityLabel(int count, int limit) {
    return '모먼트 $count/$limit';
  }

  @override
  String get hdBannerBenefitMedia => '영화, 음악, 장소까지 담아보세요.';

  @override
  String get hdBannerBenefitMoments => '한 Scene에 모먼트를 100개까지.';
}
