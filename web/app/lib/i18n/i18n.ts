import i18n from "i18next";
import { initReactI18next } from "react-i18next";

import en from "./locales/en.json";

/**
 * i18n 초기화. 1차 출시 단계에서는 영어 단일 — i18n 인프라는 유지해 콘텐츠를
 * 컴포넌트에 하드코딩하지 않는다. 다국어가 추가될 때(예: ko) 이 파일과
 * locales/ 디렉터리에 등록만 하면 되도록 구조 보존.
 *
 * LanguageDetector는 의도적으로 사용하지 않음 — 현재 지원 로케일이 1개이고,
 * 미래에 KR 추가될 때 의도적 선택 UX(헤더 토글 등)를 별도 설계할 예정.
 */
export const SUPPORTED_LOCALES = ["en"] as const;
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number];
export const DEFAULT_LOCALE: SupportedLocale = "en";

if (!i18n.isInitialized) {
  i18n.use(initReactI18next).init({
    resources: {
      en: { translation: en },
    },
    lng: DEFAULT_LOCALE,
    fallbackLng: DEFAULT_LOCALE,
    supportedLngs: SUPPORTED_LOCALES,
    interpolation: { escapeValue: false },
    react: { useSuspense: false },
  });
}

export default i18n;
