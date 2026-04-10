import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import LanguageDetector from "i18next-browser-languagedetector";

import en from "./locales/en.json";
import ko from "./locales/ko.json";

/**
 * i18n 초기화. 리소스는 한 곳에서만 import하고, 지원 로케일은 en/ko 두 개로 고정.
 * 새 문자열이 생기면 en/ko 양쪽 json에 동시에 추가한다.
 */
export const SUPPORTED_LOCALES = ["en", "ko"] as const;
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number];
export const DEFAULT_LOCALE: SupportedLocale = "en";

if (!i18n.isInitialized) {
  i18n
    .use(LanguageDetector)
    .use(initReactI18next)
    .init({
      resources: {
        en: { translation: en },
        ko: { translation: ko },
      },
      fallbackLng: DEFAULT_LOCALE,
      supportedLngs: SUPPORTED_LOCALES,
      interpolation: { escapeValue: false },
      react: { useSuspense: false },
    });
}

export default i18n;
