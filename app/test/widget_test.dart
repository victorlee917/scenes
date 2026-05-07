import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scenes/core/theme/app_theme.dart';
import 'package:scenes/features/home/home_view.dart';
import 'package:scenes/l10n/app_localizations.dart';

void main() {
  // 폰트는 모두 fonts/에 번들되어 런타임 fetch가 없으므로 setUpAll에서 별도
  // 다운로드 차단 설정 불필요.

  testWidgets('HomeView renders couple strip and first scene card',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const HomeView(),
        ),
      ),
    );
    // Network images are stubbed to errorBuilder; avoid pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Under the Umbrella'), findsWidgets);
  });
}
