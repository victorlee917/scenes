import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scenes/core/theme/app_theme.dart';
import 'package:scenes/features/couple/couple_view_model.dart';
import 'package:scenes/features/couple/data/couple_repository.dart';
import 'package:scenes/features/couple/models/couple_record.dart';
import 'package:scenes/features/home/home_view.dart';
import 'package:scenes/features/home/widgets/couple_strip.dart';
import 'package:scenes/features/home/models/scene.dart';
import 'package:scenes/features/profile/models/profile.dart';
import 'package:scenes/features/profile/profile_view_model.dart';
import 'package:scenes/features/scene/scenes_view_model.dart';
import 'package:scenes/l10n/app_localizations.dart';

/// HomeView는 profile/couple/scenes 세 provider가 모두 값을 낼 때까지
/// SplashView만 그린다. 실제 Supabase를 태우지 않고 그 화면에 도달하려면
/// 세 ViewModel을 fixture로 갈아끼워야 한다 — 아래 Fake들은 각 AsyncNotifier를
/// 상속해 build()만 동기 값으로 덮는다(네트워크 호출 자체가 사라짐).
///
/// ⚠️ 이미지 URL은 전부 비워 둔다. HomeView._precacheImages가 URL 집합이
/// 비면 즉시 return하므로, 테스트에서 NetworkImage가 뜨지 않아 HTTP 400
/// 스텁에 걸리는 일이 없다.

const _myId = 'user-a';
const _partnerId = 'user-b';

Profile _profile(String id, String name) => Profile(
      id: id,
      name: name,
      avatarUrl: null,
      locale: 'en',
      onboardingCompletedAt: DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
    );

final _scenes = <Scene>[
  Scene(
    id: 'scene-1',
    number: 1,
    position: 0,
    title: 'Under the Umbrella',
    dates: [DateTime.utc(2026, 5, 4)],
    coverImageUrl: '',
    createdBy: _myId,
  ),
  Scene(
    id: 'scene-2',
    number: 2,
    position: 1,
    title: 'Midnight Drive',
    dates: [DateTime.utc(2026, 6, 12)],
    coverImageUrl: '',
    createdBy: _partnerId,
  ),
];

class _FakeMyProfileViewModel extends MyProfileViewModel {
  @override
  Future<Profile?> build() async => _profile(_myId, 'Ari');
}

class _FakeActiveCoupleViewModel extends ActiveCoupleViewModel {
  @override
  Future<ActiveCoupleAndPartner?> build() async => ActiveCoupleAndPartner(
        couple: CoupleRecord(
          id: 'couple-1',
          pairId: 'pair-1',
          partnerAId: _myId,
          partnerBId: _partnerId,
          sinceDate: DateTime.utc(2025, 3, 1),
          status: 'active',
          linkedAt: DateTime.utc(2025, 3, 1),
        ),
        partner: _profile(_partnerId, 'Bo'),
      );
}

class _FakeScenesViewModel extends ScenesViewModel {
  @override
  Future<List<Scene>> build() async => _scenes;
}

Widget _app() => ProviderScope(
      overrides: [
        myProfileProvider.overrideWith(_FakeMyProfileViewModel.new),
        activeCoupleProvider.overrideWith(_FakeActiveCoupleViewModel.new),
        scenesProvider.overrideWith(_FakeScenesViewModel.new),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const HomeView(),
      ),
    );

void main() {
  // 폰트는 모두 fonts/에 번들되어 런타임 fetch가 없으므로 setUpAll에서 별도
  // 다운로드 차단 설정 불필요.

  testWidgets('HomeView shows the splash gate until data arrives',
      (tester) async {
    await tester.pumpWidget(_app());
    // 첫 프레임에서는 세 provider가 아직 loading — 콘텐츠 대신 splash.
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.text('Under the Umbrella'), findsNothing);
  });

  testWidgets('HomeView renders couple strip and focused scene', (tester) async {
    await tester.pumpWidget(_app());
    // provider 해소(microtask) → precache post-frame 콜백 → _firstLoadComplete
    // setState까지 프레임이 여러 번 필요. 네트워크 이미지가 없어 settle 가능.
    await tester.pumpAndSettle();

    // 커플 스트립: avatarUrl이 비어 있으면 이름 첫 글자 fallback을 그린다.
    final strip = find.byType(CoupleStrip);
    expect(strip, findsOneWidget);
    expect(
      find.descendant(of: strip, matching: find.text('A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('B')),
      findsOneWidget,
    );

    // 포커스는 가장 최신 scene(마지막 인덱스)에서 시작 — 번호와 타이틀 노출.
    expect(find.text('#2'), findsWidgets);
    expect(find.text('Midnight Drive'), findsWidgets);
  });
}
