import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
  index("routes/onboarding.tsx"),
  route("privacy", "routes/privacy.tsx"),
  route("terms", "routes/terms.tsx"),
  // 공유 페이지: scenes.id/<slug> (= pair 닉네임). 정적 라우트(privacy/terms)가
  // 우선 매칭되므로 그 단어들은 slug로 쓰면 안 됨(예약어).
  route(":slug", "routes/share.tsx"),
  route(":slug/:sceneNumber", "routes/scene-detail.tsx"),
] satisfies RouteConfig;
