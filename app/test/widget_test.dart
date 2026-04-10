import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scenes/core/theme/app_theme.dart';
import 'package:scenes/features/home/home_view.dart';
import 'package:scenes/l10n/app_localizations.dart';

void main() {
  testWidgets('HomeView renders localized greeting', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const HomeView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scenes'), findsOneWidget);
    expect(find.text('Supabase ready.'), findsOneWidget);
  });
}
