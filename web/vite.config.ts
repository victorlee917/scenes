import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

/**
 * GitHub Pages는 `https://<user>.github.io/<repo>/` sub-path로 서빙되므로
 * Vite의 `base`에 repo 이름을 박아둔다. 추후 custom 도메인 또는 user/org
 * Pages(루트 서빙)으로 옮기면 `/`로 변경.
 *
 * `base`만 설정하면 React Router v7이 동일 base를 router basename으로
 * 자동 인식 — 별도 basename 지정 불필요.
 */
export default defineConfig({
  base: "/scenes/",
  plugins: [tailwindcss(), reactRouter()],
  resolve: {
    tsconfigPaths: true,
  },
});
