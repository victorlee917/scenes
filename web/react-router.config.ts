import type { Config } from "@react-router/dev/config";

/**
 * GitHub Pages는 정적 호스팅이라 SPA 모드로 빌드. 추후 Cloudflare/Vercel 등
 * SSR 가능한 호스팅으로 옮길 때 `ssr: true`로 되돌리면 됨.
 *
 * `basename`은 GH Pages가 `https://<user>.github.io/<repo>/` sub-path로 서빙
 * 하기 때문에 필요. Vite의 `base`는 asset URL에만 적용되고 React Router 런타임
 * 의 basename은 별개로 설정해야 sub-path 라우트(`/scenes/privacy` 등)가 매칭됨.
 * 추후 custom 도메인이나 user/org Pages(루트 서빙)로 옮기면 `/`로 변경.
 */
export default {
  ssr: false,
  basename: "/scenes/",
} satisfies Config;
