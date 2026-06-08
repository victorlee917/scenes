import { Fragment } from "react";
import { Link } from "react-router";
import { MediaIcon, type MediaType } from "./media-icon";
import { SourceBadge } from "./source-badge";
import { CoupleTelescope, type ShareCouple } from "./share-view";

/// Scene 상세 — 앱의 콘텐츠 상세(2열 masonry + 타입별 비율 이미지)를 웹으로 옮김.
/// 공유된(shared) moment만 표시.

export type DetailItem = {
  id: string;
  type: MediaType;
  imageUrl: string | null;
  aspect: number;
  name: string | null;
};

export type DetailScene = {
  number: number;
  title: string;
  coverUrl: string | null;
  media: Record<MediaType, number>;
  dateRange: string;
};

export function SceneDetailView({
  slug,
  couple,
  scene,
  items,
}: {
  slug: string;
  couple: ShareCouple;
  scene: DetailScene;
  items: DetailItem[];
}) {
  const types: MediaType[] = ["photo", "film", "music", "place"];
  const metaItems = types.filter((t) => scene.media[t] > 0);

  // 2열 masonry를 JS로 분배(높이 균형). CSS `columns`는 WebKit/인앱 브라우저에서
  // 2번째 열 첫 항목이 클리핑되는 버그가 있어 flex 컬럼으로 직접 구성.
  const cols: DetailItem[][] = [[], []];
  const colHeights = [0, 0];
  for (const item of items) {
    const c = colHeights[0] <= colHeights[1] ? 0 : 1;
    cols[c].push(item);
    colHeights[c] += 1 / (item.aspect || 1); // 세로 비중(폭 동일 가정)
  }

  return (
    <main className="min-h-dvh select-none bg-background text-foreground">
      <header className="px-6 pb-8 pt-6 text-center">
        {/* 페어 망원경 — 누르면 페어 홈(공유 페이지)으로. */}
        <Link to={`/${slug}`} className="mb-20 block pt-2">
          <CoupleTelescope couple={couple} />
        </Link>

        {/* 대표 캐니스터(원형 커버) */}
        <div className="mx-auto mb-7 aspect-square w-40 overflow-hidden rounded-full bg-surface ring-1 ring-foreground/10 shadow-[0_24px_40px_-20px_rgba(0,0,0,0.55)]">
          {scene.coverUrl ? (
            <img
              src={scene.coverUrl}
              alt={scene.title}
              draggable={false}
              className="h-full w-full object-cover"
            />
          ) : (
            <div className="flex h-full w-full items-center justify-center">
              <span className="font-display text-4xl text-muted">
                {[...scene.title.trim()][0]?.toUpperCase() ?? ""}
              </span>
            </div>
          )}
        </div>

        <p className="font-display text-xs tracking-[0.2em] text-muted">
          #{scene.number}
        </p>
        <h1 className="mt-2 font-display text-2xl leading-tight sm:text-3xl">
          {scene.title}
        </h1>

        {metaItems.length > 0 && (
          <div className="mt-4 flex items-center justify-center gap-2 text-foreground/55">
            {metaItems.map((t, i) => (
              <Fragment key={t}>
                {i > 0 && <span className="text-foreground/30">·</span>}
                <span className="inline-flex items-center gap-1">
                  <MediaIcon type={t} />
                  <span className="text-xs">{scene.media[t]}</span>
                </span>
              </Fragment>
            ))}
          </div>
        )}

        {scene.dateRange && (
          <p className="mt-3 text-[10px] uppercase tracking-[0.2em] text-foreground/40">
            {scene.dateRange}
          </p>
        )}
      </header>

      {items.length === 0 ? (
        <p className="px-6 pb-16 text-center text-sm text-muted">
          No shared moments in this scene.
        </p>
      ) : (
        <div className="mx-auto flex max-w-2xl gap-2 px-4 pb-16">
          {cols.map((col, ci) => (
            <div key={ci} className="flex flex-1 flex-col gap-2">
              {col.map((item) => (
                <DetailTile key={item.id} item={item} />
              ))}
            </div>
          ))}
        </div>
      )}
    </main>
  );
}

/// masonry 타일 — 타입별 비율 유지. (2열 분배는 부모가 담당.)
function DetailTile({ item }: { item: DetailItem }) {
  return (
    <div className="relative overflow-hidden rounded-xl bg-surface ring-1 ring-foreground/5">
      {item.imageUrl ? (
        <img
          src={item.imageUrl}
          alt=""
          draggable={false}
          loading="lazy"
          className="w-full object-cover"
          style={{ aspectRatio: item.aspect }}
        />
      ) : (
        <div className="w-full" style={{ aspectRatio: item.aspect }} />
      )}

      {/* 외부 매체 출처 배지 — 앱과 동일하게 우상단(6px). photo는 없음. */}
      <div className="absolute right-1.5 top-1.5">
        <SourceBadge type={item.type} />
      </div>

      {item.type === "place" && item.name && (
        <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/60 to-transparent p-2 text-left text-xs font-medium text-white">
          {item.name}
        </div>
      )}
    </div>
  );
}
