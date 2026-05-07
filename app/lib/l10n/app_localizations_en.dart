// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

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
  String get sceneListA11yLabel => 'Scenes';

  @override
  String get transportSort => 'Sort scenes';

  @override
  String get transportAdd => 'Add scene';

  @override
  String get transportPlay => 'Play scenes';

  @override
  String get addSceneCardLabel => 'add new scene';

  @override
  String get homeEmptyTaglinePrefix => 'Keep the ';

  @override
  String get homeEmptyTaglineBrand => 'Scenes';

  @override
  String get homeEmptyTaglineSuffix => '\nwe shared together.';

  @override
  String get detailBack => 'Back';

  @override
  String get detailMoreActions => 'Scene actions';

  @override
  String get sceneListEditOrder => 'Edit order';

  @override
  String get sceneListNewestFirst => 'Newest first';

  @override
  String get sceneListOldestFirst => 'Oldest first';

  @override
  String get sceneListSave => 'Save';

  @override
  String get sceneDetailEdit => 'Edit';

  @override
  String get sceneDetailDelete => 'Delete';

  @override
  String get sceneDetailShare => 'Share scene';

  @override
  String get sceneDetailAddMedia => 'Add to scene';

  @override
  String get profileSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsPushNotifications => 'Notifications';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsTermsOfService => 'Terms of service';

  @override
  String get settingsInstagram => 'Scenes on Instagram';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsDisconnect => 'Disconnect';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get dangerZoneTitle => 'Danger zone';

  @override
  String get dangerZoneSubtitle => 'Actions in this area can\'t be undone.';

  @override
  String uploadChipPhotosProgress(int current, int total) {
    return 'Uploading $current of $total';
  }

  @override
  String get uploadChipFilmActive => 'Adding film…';

  @override
  String get uploadChipMusicActive => 'Adding music…';

  @override
  String get uploadChipPlaceActive => 'Adding place…';

  @override
  String uploadChipPhotosDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos added',
      one: '1 photo added',
    );
    return '$_temp0';
  }

  @override
  String get uploadChipFilmDone => 'Film added';

  @override
  String get uploadChipMusicDone => 'Music added';

  @override
  String get uploadChipPlaceDone => 'Place added';

  @override
  String get uploadChipFailed => 'Upload failed';

  @override
  String get uploadChipCancelling => 'Cancelling…';

  @override
  String get profileDeletedUserName => 'Deleted user';

  @override
  String get sceneDetailPlay => 'Play scene';

  @override
  String get sceneDetailEmptyMedia =>
      'Fill this Scene with moments that matter.';

  @override
  String profileNarrative(
    String partnerA,
    String partnerB,
    String date,
    int count,
  ) {
    return 'Since $date, we have captured $count Scenes together.';
  }

  @override
  String coupleScenesCount(int count) {
    return '$count Scenes';
  }

  @override
  String notiPromptTitleWithName(String name) {
    return 'Don\'t miss\n$name\'s updates';
  }

  @override
  String get notiPromptTitleNoName => 'Don\'t miss\na single update';

  @override
  String notiPromptBodyWithName(String name) {
    return 'Get notified when $name adds scenes,\nmoments, or reacts to yours.';
  }

  @override
  String get notiPromptBodyNoName =>
      'Get notified when your person adds scenes,\nmoments, or reacts to yours.';

  @override
  String get notiPromptAllow => 'Allow notifications';

  @override
  String get notiPromptSkip => 'Maybe later';

  @override
  String addMediaCapacityLabel(int count, int limit) {
    return 'Moments $count/$limit';
  }

  @override
  String get hdBannerBenefitMedia => 'Unlock films, music, and places.';

  @override
  String get hdBannerBenefitMoments => 'Up to 100 moments in every scene.';
}
