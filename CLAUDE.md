# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture principles

- **MVVM 전면 적용**: `app/`(Flutter)과 `web/`(React Router) 모두 Model / View / ViewModel 레이어를 명확히 분리한다. View는 상태와 비즈니스 로직을 직접 보유하지 않고 ViewModel을 관찰한다. 단일 파일에 UI·상태·데이터 접근을 섞지 않는다.
  - Flutter: ViewModel은 `Notifier<State>` / `AsyncNotifier`로 작성하고 `NotifierProvider`로 노출. View는 `ConsumerWidget`에서 `ref.watch(...)`로 관찰.
  - Web: ViewModel은 `useXxxViewModel` 훅으로 작성하고 View에 prop 주입.
- **유지보수 우선**: 작은 단위로 분리, 명확한 네이밍, 레이어 간 의존 방향(View → ViewModel → Model/Repository) 준수.
- **중앙화된 스타일 + 다크/라이트 테마**: 색상·타이포·간격 등 디자인 토큰은 한 곳에서 정의하고 재사용한다. 컴포넌트 안에 색상/사이즈를 하드코딩하지 않는다.
  - Flutter: `app/lib/core/theme/`에 `lightTheme` / `darkTheme`(`ThemeData`)를 정의하고 `MaterialApp`의 `theme` / `darkTheme`에 주입. 위젯은 `Theme.of(context)`로만 참조.
  - Web: Tailwind v4 `@theme` 디렉티브로 `web/app/app.css`에 토큰 정의, 다크 모드는 CSS 변수 + `prefers-color-scheme`(또는 `.dark` class)로 전환. 컴포넌트에서는 토큰화된 utility만 사용.

## Repository layout

Two independent sub-projects share a Supabase backend but have separate toolchains, dependencies, and deploy targets. There is no root-level package manager — run commands from inside the relevant sub-directory.

- `app/` — Flutter 3.11+ 모바일 클라이언트. 스택: `supabase_flutter`, `flutter_riverpod`, `go_router`, `flutter_localizations`. Entry: `app/lib/main.dart` → `ProviderScope` → `MaterialApp.router`(라우트는 `lib/core/router/app_router.dart`).
- `web/` — React Router v7 SSR app with Vite, React 19, Tailwind v4, and `@supabase/ssr`. Entry: `web/app/root.tsx`; routes registered in `web/app/routes.ts`.

## Common commands

### Flutter (`app/`)
```bash
# Supabase creds are passed as compile-time constants (see app/.env.example)
flutter run --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
flutter test                         # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter analyze                      # lint (uses analysis_options.yaml / flutter_lints)
flutter pub get
```

### Web (`web/`)
```bash
npm install
npm run dev         # Vite dev server with HMR at http://localhost:5173
npm run build       # react-router build → build/client + build/server
npm run start       # serve production build via @react-router/serve
npm run typecheck   # react-router typegen && tsc
```

Docker build is available via `web/Dockerfile`.

## Supabase wiring (important — differs per sub-project)

Both clients read the same Supabase project but through different env mechanisms:

- **Flutter** (`app/lib/main.dart`): keys come from `String.fromEnvironment(...)` — they must be passed via `--dart-define` at build/run time, *not* a `.env` file.
- **Web server** (`web/app/lib/supabase.server.ts`): reads `SUPABASE_URL` / `SUPABASE_ANON_KEY` from `process.env`; creates a per-request `createServerClient` that threads cookies through a returned `headers` object — loaders/actions that call it must merge those headers into the Response for auth cookies to persist.
- **Web browser** (`web/app/lib/supabase.client.ts`): uses `VITE_SUPABASE_*` (Vite-exposed) so it is safe to ship to the client bundle.

When adding authed routes on the web side, always use `createSupabaseServerClient(request)` and propagate its `headers`; do not instantiate the browser client on the server.
