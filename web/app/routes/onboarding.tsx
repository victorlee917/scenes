import type { Route } from "./+types/onboarding";
import { OnboardingView } from "../features/onboarding/onboarding-view";
import { useOnboardingViewModel } from "../features/onboarding/use-onboarding-view-model";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Scenes" },
    { name: "description", content: "Memories you keep, together." },
  ];
}

export default function OnboardingRoute() {
  const viewModel = useOnboardingViewModel();
  return <OnboardingView viewModel={viewModel} />;
}
