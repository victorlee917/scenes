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
    return 'since $date';
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
}
