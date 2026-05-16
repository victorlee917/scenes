/**
 * Legal 문서의 콘텐츠 모델. 마크다운 대신 정형 블록 배열로 표현해 View가 단순한
 * switch 렌더링으로 처리 가능하게 한다. KR 등 로케일 추가 시 같은 shape으로
 * `*.ko.ts` 등을 작성해 ViewModel에서 분기.
 */
export type LegalBlock =
  | { type: "p"; text: string }
  | { type: "h2"; text: string }
  | { type: "h3"; text: string }
  | { type: "ul"; items: string[] };

export type LegalContent = {
  title: string;
  lastUpdated: string;
  blocks: LegalBlock[];
};
