import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자가 선택한 앱 표시 언어.
///
/// - [system]: 디바이스 시스템 언어를 그대로 따름 (기본값).
/// - [english] / [korean]: 시스템 설정과 무관하게 해당 언어로 고정.
///
/// 추후 새 로케일 추가 시 enum case + [persistKey] 매핑만 늘리면 됨 — view나
/// MaterialApp 쪽 코드는 변경 불필요.
enum AppLocaleOption {
  system,
  english,
  korean;

  /// SharedPreferences에 저장할 식별자.
  String get persistKey => name;

  static AppLocaleOption fromPersistKey(String? value) {
    switch (value) {
      case 'english':
        return AppLocaleOption.english;
      case 'korean':
        return AppLocaleOption.korean;
      default:
        return AppLocaleOption.system;
    }
  }

  /// MaterialApp.locale로 넘길 Locale. null이면 Flutter가 supportedLocales 중
  /// 디바이스 언어와 매칭해 자동 선택.
  Locale? toLocale() {
    switch (this) {
      case AppLocaleOption.system:
        return null;
      case AppLocaleOption.english:
        return const Locale('en');
      case AppLocaleOption.korean:
        return const Locale('ko');
    }
  }
}

const _key = 'app_locale_option';

/// 앱 표시 언어 ViewModel. SharedPreferences로 영속.
class AppLocaleNotifier extends AsyncNotifier<AppLocaleOption> {
  @override
  Future<AppLocaleOption> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLocaleOption.fromPersistKey(prefs.getString(_key));
  }

  Future<void> set(AppLocaleOption option) async {
    state = AsyncData(option);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, option.persistKey);
  }
}

final appLocaleProvider =
    AsyncNotifierProvider<AppLocaleNotifier, AppLocaleOption>(
  AppLocaleNotifier.new,
);
