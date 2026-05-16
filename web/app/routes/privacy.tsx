import type { Route } from "./+types/privacy";
import { LegalView } from "../features/legal/legal-view";
import { useLegalViewModel } from "../features/legal/use-legal-view-model";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Privacy Policy — Scenes" },
    { name: "description", content: "Scenes Privacy Policy" },
  ];
}

export default function PrivacyRoute() {
  const viewModel = useLegalViewModel("privacy");
  return <LegalView viewModel={viewModel} />;
}
