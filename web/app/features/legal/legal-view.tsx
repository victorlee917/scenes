import { Link } from "react-router";
import { useTranslation } from "react-i18next";

import type { LegalBlock } from "./legal-types";
import type { LegalViewModel } from "./use-legal-view-model";

/**
 * Privacy/Terms 공통 Legal View. ViewModel이 주는 LegalContent의 블록을
 * 순차 렌더 — 마크다운/MDX 빌드 의존성 없이 정형 콘텐츠를 가독성 좋게 표시.
 */
export function LegalView({ viewModel }: { viewModel: LegalViewModel }) {
  const { t } = useTranslation();
  const { content } = viewModel;

  return (
    <main className="min-h-dvh flex flex-col bg-background text-foreground">
      <header className="px-6 pt-8 pb-4 max-w-2xl w-full mx-auto">
        <Link
          to="/"
          className="text-sm text-muted hover:text-foreground transition-colors"
        >
          ← {t("legal.back")}
        </Link>
      </header>
      <article className="flex-1 px-6 max-w-2xl w-full mx-auto pb-16">
        <h1 className="font-display text-4xl font-semibold tracking-tight">
          {content.title}
        </h1>
        <p className="mt-2 text-sm text-muted">{content.lastUpdated}</p>
        <div className="mt-8 space-y-4 text-base leading-relaxed">
          {content.blocks.map((block, i) => (
            <Block key={i} block={block} />
          ))}
        </div>
      </article>
    </main>
  );
}

function Block({ block }: { block: LegalBlock }) {
  switch (block.type) {
    case "h2":
      return (
        <h2 className="font-display text-2xl font-semibold mt-10 mb-2 tracking-tight">
          {block.text}
        </h2>
      );
    case "h3":
      return (
        <h3 className="text-lg font-semibold mt-6 mb-1">{block.text}</h3>
      );
    case "p":
      return <p className="text-muted">{block.text}</p>;
    case "ul":
      return (
        <ul className="list-disc list-outside ml-6 space-y-2 text-muted">
          {block.items.map((item, i) => (
            <li key={i}>{item}</li>
          ))}
        </ul>
      );
  }
}
