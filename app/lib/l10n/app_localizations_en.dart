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
  String get sceneDetailPlay => 'Play scene';

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
}
