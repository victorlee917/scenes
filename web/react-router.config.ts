import type { Config } from "@react-router/dev/config";

/**
 * GitHub Pages는 정적 호스팅이라 SPA 모드로 빌드. 추후 Cloudflare/Vercel 등
 * SSR 가능한 호스팅으로 옮길 때 `ssr: true`로 되돌리기만 하면 됨.
 */
export default {
  ssr: false,
} satisfies Config;
