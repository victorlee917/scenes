import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'home_view_model.dart';

/// Home 화면의 View. 상태는 `homeViewModelProvider`에서만 가져온다.
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(homeViewModelProvider);
    final greeting = state.greeting ?? l10n.homeGreeting;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Text(greeting, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
