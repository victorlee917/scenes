import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home 화면의 상태. 로케일 의존적인 기본값은 View가 l10n에서 해결하므로,
/// 여기서는 override된 문자열(null = 기본값 사용)만 보유한다.
class HomeState {
  const HomeState({this.greeting});

  final String? greeting;

  HomeState copyWith({String? greeting}) => HomeState(greeting: greeting ?? this.greeting);
}

/// Home 화면의 ViewModel (Riverpod `Notifier`).
class HomeViewModel extends Notifier<HomeState> {
  @override
  HomeState build() => const HomeState();

  void updateGreeting(String? value) {
    if (state.greeting == value) return;
    state = HomeState(greeting: value);
  }
}

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(
  HomeViewModel.new,
);
