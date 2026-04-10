import type { Route } from "./+types/home";
import { HomeView } from "../features/home/home-view";
import { useHomeViewModel } from "../features/home/use-home-view-model";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Scenes" },
    { name: "description", content: "Scenes" },
  ];
}

export default function HomeRoute() {
  const viewModel = useHomeViewModel();
  return <HomeView viewModel={viewModel} />;
}
