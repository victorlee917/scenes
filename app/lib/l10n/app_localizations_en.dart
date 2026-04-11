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
    return 'since $date';
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
}
