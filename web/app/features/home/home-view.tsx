import { useTranslation } from "react-i18next";

import type { HomeViewModel } from "./use-home-view-model";

/**
 * Home 화면의 View. 상태는 ViewModel에서만 받고 문자열은 i18n에서만 가져온다.
 */
export function HomeView({ viewModel }: { viewModel: HomeViewModel }) {
  const { t } = useTranslation();

  return (
    <main className="min-h-dvh flex items-center justify-center bg-background text-foreground">
      <section className="flex flex-col items-center gap-4">
        <h1 className="text-3xl font-semibold">{t("app.title")}</h1>
        <p className="text-muted">{viewModel.greeting ?? t("home.greeting")}</p>
      </section>
    </main>
  );
}
