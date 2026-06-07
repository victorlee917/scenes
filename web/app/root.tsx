import {
  isRouteErrorResponse,
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from "react-router";

import type { Route } from "./+types/root";
import "./app.css";
import "./lib/i18n/i18n";

// 폰트는 Flutter 앱과 톤을 통일.
//   - 본문(sans): Pretendard — 한글/영문 모두 균형 좋은 변형. 정식 CDN(jsdelivr)
//     에서 variable 버전 로드.
//   - 디스플레이(display): Playfair Display — 영문 제목용 세리프. 향후 KR 로케일
//     추가 시 Hahmlet도 같이 등록할 예정.
export const links: Route.LinksFunction = () => [
  // GH Pages가 /scenes/ sub-path로 서빙하므로 base path 명시. import.meta.env.BASE_URL
  // 은 Vite의 `base`(=/scenes/)를 그대로 반환 — 환경별 자동 매칭.
  { rel: "icon", type: "image/png", href: `${import.meta.env.BASE_URL}favicon.png` },
  { rel: "preconnect", href: "https://cdn.jsdelivr.net", crossOrigin: "anonymous" },
  { rel: "preconnect", href: "https://fonts.googleapis.com" },
  {
    rel: "preconnect",
    href: "https://fonts.gstatic.com",
    crossOrigin: "anonymous",
  },
  {
    rel: "stylesheet",
    href: "https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable.min.css",
  },
  {
    rel: "stylesheet",
    href: "https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,400..900;1,400..900&display=swap",
  },
];

// 소셜 미디어 카드용 절대 URL. og:image 등은 path가 아니라 풀 URL이라야
// 스크래퍼(페이스북·트위터·슬랙 등)가 이미지를 가져갈 수 있음. 추후 커스텀
// 도메인으로 옮기면 여기만 바꾸면 됨.
const _siteOrigin = "https://scenes.id";
const _ogImageUrl = `${_siteOrigin}/og-image.png`;

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        {/* Open Graph / Twitter card 공통 메타. og:title / og:description은
            라우트별 meta()가 덮어쓸 수 있도록 <Meta /> 위에 둠. */}
        <meta property="og:type" content="website" />
        <meta property="og:site_name" content="Scenes" />
        <meta property="og:image" content={_ogImageUrl} />
        <meta property="og:image:width" content="1200" />
        <meta property="og:image:height" content="630" />
        <meta name="twitter:card" content="summary_large_image" />
        <meta name="twitter:image" content={_ogImageUrl} />
        <Meta />
        <Links />
      </head>
      <body>
        {children}
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function App() {
  return <Outlet />;
}

export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
  let message = "Oops!";
  let details = "An unexpected error occurred.";
  let stack: string | undefined;

  if (isRouteErrorResponse(error)) {
    message = error.status === 404 ? "404" : "Error";
    details =
      error.status === 404
        ? "The requested page could not be found."
        : error.statusText || details;
  } else if (import.meta.env.DEV && error && error instanceof Error) {
    details = error.message;
    stack = error.stack;
  }

  return (
    <main className="pt-16 p-4 container mx-auto">
      <h1>{message}</h1>
      <p>{details}</p>
      {stack && (
        <pre className="w-full p-4 overflow-x-auto">
          <code>{stack}</code>
        </pre>
      )}
    </main>
  );
}
