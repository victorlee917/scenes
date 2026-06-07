import type { Route } from "./+types/scene-detail";
import { createSupabaseAdminClient } from "../lib/supabase.server";
import {
  SceneDetailView,
  type DetailItem,
} from "../features/share/scene-detail-view";
import type { MediaType } from "../features/share/media-icon";

const BUCKET = "scene_media";
const SIGN_TTL = 60 * 60; // 1h

export function meta({ data }: Route.MetaArgs) {
  const title = data?.scene
    ? `#${data.scene.number} ${data.scene.title}`
    : "Scenes";
  return [
    { title },
    { name: "description", content: "Our story, scene by scene." },
    // 커플의 사적 공유 페이지 — 검색엔진 색인 방지.
    { name: "robots", content: "noindex, nofollow" },
  ];
}

function formatDateRange(times: number[]): string {
  if (times.length === 0) return "";
  const sorted = [...times].sort((a, b) => a - b);
  const f = new Date(sorted[0]);
  const l = new Date(sorted[sorted.length - 1]);
  const mon = (d: Date) => d.toLocaleString("en-US", { month: "short" }).toLowerCase();
  const sameDay = f.toDateString() === l.toDateString();
  const sameMonth = f.getFullYear() === l.getFullYear() && f.getMonth() === l.getMonth();
  const sameYear = f.getFullYear() === l.getFullYear();
  if (sameDay) return `${f.getDate()} ${mon(f)} ${f.getFullYear()}`;
  if (sameMonth) return `${f.getDate()}–${l.getDate()} ${mon(f)} ${f.getFullYear()}`;
  if (sameYear)
    return `${f.getDate()} ${mon(f)} – ${l.getDate()} ${mon(l)} ${f.getFullYear()}`;
  return `${f.getDate()} ${mon(f)} ${f.getFullYear()} – ${l.getDate()} ${mon(l)} ${l.getFullYear()}`;
}

/// 단일 scene의 공유된 moment들을 콘텐츠 상세용으로 반환. service-role로
/// RLS 우회 + private 버킷 signed URL. sceneId가 그 slug의 pair에 속하는지
/// 반드시 검증(다른 pair의 scene 열람 방지).
export async function loader({ params }: Route.LoaderArgs) {
  const slug = (params.slug ?? "").toLowerCase();
  const sceneNumber = Number(params.sceneNumber);
  if (!Number.isInteger(sceneNumber)) {
    throw new Response("Not Found", { status: 404 });
  }
  const admin = createSupabaseAdminClient();

  const { data: share } = await admin
    .from("pair_shares")
    .select("pair_id")
    .eq("slug", slug)
    .maybeSingle();
  if (!share) throw new Response("Not Found", { status: 404 });
  const pairId = share.pair_id as string;

  // 상단 망원경용 커플 아바타 (avatar_url은 public).
  const { data: coupleRow } = await admin
    .from("couples")
    .select(
      "status, a:profiles!partner_a_id(name, avatar_url, deleted_at), " +
        "b:profiles!partner_b_id(name, avatar_url, deleted_at)"
    )
    .eq("pair_id", pairId)
    .order("status", { ascending: true })
    .limit(1)
    .maybeSingle();
  type ProfileRow = {
    name?: string;
    avatar_url?: string | null;
    deleted_at?: string | null;
  } | null;
  const person = (p: ProfileRow) =>
    !p || p.deleted_at
      ? { name: "", avatarUrl: null as string | null }
      : { name: p.name ?? "", avatarUrl: (p.avatar_url ?? null) as string | null };
  const cr = coupleRow as { a: ProfileRow; b: ProfileRow } | null;
  const couple = cr ? { a: person(cr.a), b: person(cr.b) } : null;

  const { data: scene } = await admin
    .from("scenes")
    .select("id, number, title, cover_storage_path")
    .eq("pair_id", pairId)
    .eq("number", sceneNumber)
    .maybeSingle();
  if (!scene) throw new Response("Not Found", { status: 404 });
  const sceneId = scene.id as string;

  const { data: contentsRaw } = await admin
    .from("contents")
    .select("id, type, payload, occurred_at, position")
    .eq("scene_id", sceneId)
    .eq("shared", true)
    .order("position", { ascending: true });
  const contents = contentsRaw ?? [];

  // 상단 캐니스터용 대표 이미지: cover 우선, 없으면 첫 공유 moment 이미지.
  let coverUrl: string | null = null;
  let coverPath = (scene.cover_storage_path as string | null) ?? null;
  if (!coverPath) {
    for (const c of contents) {
      const p = (c.payload ?? {}) as Record<string, unknown>;
      const cand = (p.thumb_path ?? p.storage_path) as string | undefined;
      if (typeof cand === "string" && cand.length > 0) {
        coverPath = cand;
        break;
      }
    }
  }
  if (coverPath) {
    const { data } = await admin.storage.from(BUCKET).createSignedUrl(coverPath, SIGN_TTL);
    coverUrl = data?.signedUrl ?? null;
  }

  const dates: number[] = [];
  const counts: Record<MediaType, number> = { photo: 0, film: 0, music: 0, place: 0 };

  const items: DetailItem[] = await Promise.all(
    contents.map(async (c) => {
      const type = c.type as MediaType;
      if (type in counts) counts[type] += 1;
      if (c.occurred_at) dates.push(new Date(c.occurred_at as string).getTime());

      const payload = (c.payload ?? {}) as Record<string, unknown>;

      // 이미지 URL: scene_media 버킷 경로면 서명, 아니면 외부 CDN URL(예: 음악
      // 앨범아트) 사용.
      let imageUrl: string | null = null;
      const path = (payload.thumb_path ?? payload.storage_path) as string | undefined;
      if (typeof path === "string" && path.length > 0) {
        const { data } = await admin.storage.from(BUCKET).createSignedUrl(path, SIGN_TTL);
        imageUrl = data?.signedUrl ?? null;
      } else {
        for (const k of ["image_url", "album_image", "cover_url", "thumbnail_url", "image", "url"]) {
          const v = payload[k];
          if (typeof v === "string" && v.startsWith("http")) {
            imageUrl = v;
            break;
          }
        }
      }

      let aspect = 1;
      if (type === "photo") {
        const w = Number(payload.width);
        const h = Number(payload.height);
        aspect = w > 0 && h > 0 ? w / h : 0.75;
      } else if (type === "film") {
        aspect = 2 / 3;
      }

      return {
        id: c.id as string,
        type,
        imageUrl,
        aspect,
        name: (payload.name as string | undefined) ?? null,
      };
    })
  );

  return {
    slug,
    couple,
    scene: {
      number: scene.number as number,
      title: scene.title as string,
      coverUrl,
      media: counts,
      dateRange: formatDateRange(dates),
    },
    items,
  };
}

export default function SceneDetailRoute({ loaderData }: Route.ComponentProps) {
  return (
    <SceneDetailView
      slug={loaderData.slug}
      couple={loaderData.couple}
      scene={loaderData.scene}
      items={loaderData.items}
    />
  );
}
