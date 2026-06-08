/// 미디어 타입 아이콘 — 앱 홈/상세와 동일하게 FontAwesome **solid** 경로를
/// 인라인 SVG로(fill=currentColor). 공유 페이지 여러 곳에서 재사용.

export type MediaType = "photo" | "film" | "music" | "place";

export function MediaIcon({ type, size = 10 }: { type: MediaType; size?: number }) {
  switch (type) {
    case "photo":
      return (
        <svg width={size} height={size} viewBox="0 0 512 512" fill="currentColor" aria-hidden>
          <path d="M0 96C0 60.7 28.7 32 64 32l384 0c35.3 0 64 28.7 64 64l0 320c0 35.3-28.7 64-64 64L64 480c-35.3 0-64-28.7-64-64L0 96zM323.8 202.5c-4.5-6.6-11.9-10.5-19.8-10.5s-15.4 3.9-19.8 10.5l-87 127.6L170.7 297c-4.6-5.7-11.5-9-18.7-9s-14.2 3.3-18.7 9l-64 80c-5.8 7.2-6.9 17.1-2.9 25.4s12.4 13.6 21.6 13.6l96 0 32 0 208 0c8.9 0 17.1-4.9 21.2-12.8s3.6-17.4-1.4-24.7l-120-176zM112 192a48 48 0 1 0 0-96 48 48 0 1 0 0 96z" />
        </svg>
      );
    case "film":
      // 몸체는 꽉 찬 솔리드, 양옆 스프로킷 구멍만 evenodd로 뚫음.
      return (
        <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
          <path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M4 2.5A1.5 1.5 0 0 0 2.5 4v16A1.5 1.5 0 0 0 4 21.5h16a1.5 1.5 0 0 0 1.5-1.5V4A1.5 1.5 0 0 0 20 2.5H4zm1.5 3h2v2h-2v-2zm0 4h2v2h-2v-2zm0 4h2v2h-2v-2zm0 4h2v2h-2v-2zm11-12h2v2h-2v-2zm0 4h2v2h-2v-2zm0 4h2v2h-2v-2zm0 4h2v2h-2v-2z"
          />
        </svg>
      );
    case "music":
      return (
        <svg width={size} height={size} viewBox="0 0 512 512" fill="currentColor" aria-hidden>
          <path d="M499.1 6.3c8.1 6 12.9 15.6 12.9 25.7l0 72 0 264.4c0 44.2-43 80-96 80s-96-35.8-96-80s43-80 96-80c11.2 0 22 1.6 32 4.6L448 147 192 223.8 192 432c0 44.2-43 80-96 80s-96-35.8-96-80s43-80 96-80c11.2 0 22 1.6 32 4.6L128 200l0-72c0-14.1 9.3-26.6 22.8-30.7l320-96c9.7-2.9 20.2-1.1 28.3 5z" />
        </svg>
      );
    case "place":
      return (
        <svg width={size} height={size} viewBox="0 0 384 512" fill="currentColor" aria-hidden>
          <path d="M215.7 499.2C267 435 384 279.4 384 192C384 86 298 0 192 0S0 86 0 192c0 87.4 117 243 168.3 307.2c12.3 15.3 35.1 15.3 47.4 0zM192 128a64 64 0 1 1 0 128 64 64 0 1 1 0-128z" />
        </svg>
      );
  }
}
