import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

/**
 * 루트 도메인 서빙(Vercel: *.vercel.app, 추후 scenes.app). asset/route 모두
 * 루트(`/`) 기준이라 `base`를 따로 지정하지 않는다. (GH Pages 서브패스
 * `/scenes/`로 되돌릴 경우 여기 base + react-router.config basename을 함께 복구.)
 */
export default defineConfig({
  plugins: [tailwindcss(), reactRouter()],
  resolve: {
    tsconfigPaths: true,
  },
});
