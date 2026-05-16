import type { Route } from "./+types/terms";
import { LegalView } from "../features/legal/legal-view";
import { useLegalViewModel } from "../features/legal/use-legal-view-model";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Terms of Service — Scenes" },
    { name: "description", content: "Scenes Terms of Service" },
  ];
}

export default function TermsRoute() {
  const viewModel = useLegalViewModel("terms");
  return <LegalView viewModel={viewModel} />;
}
