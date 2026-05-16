import { Link } from "react-router";
import { useTranslation } from "react-i18next";

import type { OnboardingViewModel } from "./use-onboarding-view-model";

/**
 * Onboarding(랜딩) View. 콘텐츠는 i18n에서, 외부 링크는 ViewModel에서.
 *
 * 레이아웃: 화면 중앙 정렬 단일 컬럼 — 제목 + 태그라인 + 다운로드 CTA. 푸터는
 * 페이지 하단 고정으로 Privacy / Terms 링크.
 */
export function OnboardingView({
  viewModel,
}: {
  viewModel: OnboardingViewModel;
}) {
  const { t } = useTranslation();

  return (
    <main className="min-h-dvh flex flex-col bg-background text-foreground">
      <section className="flex-1 flex flex-col items-center justify-center px-6 text-center">
        <h1 className="font-display text-5xl font-semibold tracking-tight">
          {t("app.title")}
        </h1>
        <p className="mt-3 text-sm text-muted max-w-md">
          {t("onboarding.tagline")}
        </p>

        <div className="mt-12 flex flex-col items-center gap-3">
          <a
            href={viewModel.appStoreUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 rounded-full bg-foreground text-background px-6 py-3 text-sm font-medium hover:opacity-90 transition-opacity"
          >
            {t("onboarding.downloadAppStore")}
          </a>
          <p className="text-xs text-muted">
            {t("onboarding.playStoreComingSoon")}
          </p>
        </div>
      </section>

      <footer className="px-6 py-8 flex items-center justify-center gap-6 text-sm text-muted">
        <Link to="/privacy" className="hover:text-foreground transition-colors">
          {t("footer.privacy")}
        </Link>
        <span aria-hidden>·</span>
        <Link to="/terms" className="hover:text-foreground transition-colors">
          {t("footer.terms")}
        </Link>
      </footer>
    </main>
  );
}
