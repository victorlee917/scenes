import { useMemo } from "react";

import type { LegalContent } from "./legal-types";
import { privacyEn } from "./content/privacy.en";
import { termsEn } from "./content/terms.en";

/**
 * Legal 문서 종류. 라우트에서 "privacy" 또는 "terms"를 주입.
 */
export type LegalDocument = "privacy" | "terms";

/**
 * 문서 종류 → 현재 로케일에 맞는 콘텐츠 데이터를 반환. 현재는 EN 단일이지만
 * 추후 ko/jp 등이 추가되면 i18n 로케일에 맞춰 분기하기만 하면 됨.
 */
export function useLegalViewModel(document: LegalDocument) {
  return useMemo<{ document: LegalDocument; content: LegalContent }>(() => {
    const content = document === "privacy" ? privacyEn : termsEn;
    return { document, content };
  }, [document]);
}

export type LegalViewModel = ReturnType<typeof useLegalViewModel>;
