import { useMemo } from "react";

/**
 * Onboarding(랜딩) 화면의 ViewModel. 정적 데이터(외부 다운로드 링크 등)를
 * View에서 직접 하드코딩하지 않고 ViewModel에서 노출 — 추후 환경별 분기
 * (예: TestFlight 링크 vs 정식 App Store 링크) 시 한 곳에서만 갱신.
 *
 * App Store URL은 앱 ID(id6767381832) 직링크 — 국가코드/슬러그 없이 두면 Apple이
 * 방문자 지역 스토어로 자동 리다이렉트.
 */
export function useOnboardingViewModel() {
  return useMemo(
    () =>
      ({
        appStoreUrl: "https://apps.apple.com/app/id6767381832",
        playStoreUrl: null as string | null, // 출시 후 등록
      }) as const,
    [],
  );
}

export type OnboardingViewModel = ReturnType<typeof useOnboardingViewModel>;
