import type { MediaType } from "./media-icon";

/// 외부 매체 출처 배지 — 앱(`source_badge.dart`)과 동일한 형태.
/// 22px dark backdrop circle 위에 공식 로고(2px padding)를 올려, 어떤 콘텐츠
/// 색상 위에서도 dim되지 않게 함. 공식 로고 자산은 앱과 동일 파일을 web/public/
/// logo/에 복사해 사용. (TOS상 출처 표기 의무 충족: Spotify 링크백/TMDB·Mapbox
/// 어트리뷰션)
///   film  → TMDB,  music → Spotify,  place → Mapbox,  photo → 없음
const LOGO: Partial<Record<MediaType, { src: string; alt: string }>> = {
  film: { src: "/logo/tmdb.png", alt: "TMDB" },
  music: { src: "/logo/spotify.png", alt: "Spotify" },
  place: { src: "/logo/mapbox_dark.png", alt: "Mapbox" },
};

export function SourceBadge({ type }: { type: MediaType }) {
  const logo = LOGO[type];
  if (!logo) return null;
  return (
    <div className="pointer-events-none flex h-[22px] w-[22px] items-center justify-center rounded-full bg-black/70">
      <img
        src={logo.src}
        alt={logo.alt}
        draggable={false}
        className="h-full w-full object-contain p-[2px]"
      />
    </div>
  );
}
