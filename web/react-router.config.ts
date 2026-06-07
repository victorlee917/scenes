import type { Config } from "@react-router/dev/config";
import { vercelPreset } from "@vercel/react-router/vite";

/**
 * SSR 모드 + Vercel 배포. 공개 공유 페이지(/s/:slug)가 서버 loader에서
 * service-role로 공유 데이터 + private 버킷 signed URL을 만들어야 하므로 SSR이
 * 필요하다. Vercel preset이 빌드를 Vercel Functions 형태로 분할/출력한다.
 *
 * 루트 도메인 서빙 기준(*.vercel.app, 추후 scenes.app). basename은 `/`(기본)
 * 이라 별도 지정하지 않는다 — 그래야 앱의 공유 URL(scenes.app/s/<id>)과 경로가
 * 맞는다. (GH Pages 서브패스 `/scenes/`로 되돌릴 일이 있으면 vite base +
 * basename을 함께 복구.)
 */
export default {
  ssr: true,
  presets: [vercelPreset()],
} satisfies Config;
