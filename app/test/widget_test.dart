import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:scenes/core/theme/app_theme.dart';
import 'package:scenes/features/home/home_view.dart';
import 'package:scenes/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    // Avoid network fetches for fonts during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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
