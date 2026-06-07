import type { Route } from "./+types/share";
import { createSupabaseAdminClient } from "../lib/supabase.server";
import { ShareView } from "../features/share/share-view";
import { contentImageRef } from "../lib/share-media";

export function meta({ data }: Route.MetaArgs) {
  const title = data?.title ?? "Scenes";
  return [
    { title },
    { name: "description", content: "Our story, scene by scene." },
    // 커플의 사적 공유 페이지 — 검색엔진 색인 방지.
    { name: "robots", content: "noindex, nofollow" },
    { property: "og:title", content: title },
    { property: "og:description", content: "Our story, scene by scene." },
  ];
}

const BUCKET = "scene_media";
const SIGN_TTL = 60 * 60; // 1h

/// 앱 formatSceneDateRange의 영문 포맷을 옮긴 것. 공유 moment의 occurred_at
/// min/max로 날짜 범위 문자열 생성(소문자).
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

/// 공개 공유 페이지 로더. slug → pair → "공유된 moment가 있는" scene들을
/// 캐니스터용 데이터로 반환. service-role로 RLS 우회 + private 버킷 cover를
/// signed URL로 변환(서버에서만 수행, 키는 브라우저로 안 나감).
export async function loader({ params }: Route.LoaderArgs) {
  const slug = (params.slug ?? "").toLowerCase();
  const admin = createSupabaseAdminClient();

  const { data: share } = await admin
    .from("pair_shares")
    .select("pair_id")
    .eq("slug", slug)
    .maybeSingle();
  if (!share) {
    throw new Response("Not Found", { status: 404 });
  }
  const pairId = share.pair_id as string;

  // 커플 아바타/이름 — avatar_url은 public 버킷 URL이라 서명 불필요. active
  // 커플 우선('active' < 'ended' 알파벳순 → ascending 첫 행).
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
  const person = (p: ProfileRow) => {
    if (!p || p.deleted_at) return { name: "", avatarUrl: null as string | null };
    return { name: p.name ?? "", avatarUrl: (p.avatar_url ?? null) as string | null };
  };
  // 임베드 조인은 supabase-js 타입 추론이 약해 명시 캐스팅.
  const row = coupleRow as { a: ProfileRow; b: ProfileRow } | null;
  const couple = row ? { a: person(row.a), b: person(row.b) } : null;

  // 캐니스터 이미지는 scene의 대표 이미지(cover_storage_path)를 쓴다(사용자
  // 요구). 단 노출되는 scene은 "공유된 moment가 1개 이상 있는" scene으로 한정.
  // ⚠️ cover는 공유 대상 moment가 아닐 수 있어, 공유한 scene의 cover가 공개
  //    노출된다. cover 없으면 첫 공유 moment 이미지로 fallback.
  // number 오름차순 → 최신 scene이 배열 끝(오른쪽)에 오도록.
  const { data: scenesRaw } = await admin
    .from("scenes")
    .select("id, number, title, cover_storage_path")
    .eq("pair_id", pairId)
    .order("number", { ascending: true });
  const scenes = scenesRaw ?? [];
  const sceneIds = scenes.map((s) => s.id as string);
  if (sceneIds.length === 0) {
    return { couple, scenes: [], title: "Scenes", slug };
  }

  // 공유된 콘텐츠 — 메타(타입별 개수, 날짜 범위)도 공유 moment 기준으로 집계.
  const { data: sharedContents } = await admin
    .from("contents")
    .select("scene_id, position, type, occurred_at, payload")
    .eq("shared", true)
    .in("scene_id", sceneIds)
    .order("position", { ascending: true });

  type Agg = {
    photo: number;
    film: number;
    music: number;
    place: number;
    firstPath?: string; // 서명할 scene_media 경로
    firstUrl?: string; // 외부 CDN URL(음악 앨범아트 등)
    dates: number[];
  };
  const agg = new Map<string, Agg>();
  for (const c of sharedContents ?? []) {
    const sid = c.scene_id as string;
    let a = agg.get(sid);
    if (!a) {
      a = { photo: 0, film: 0, music: 0, place: 0, dates: [] };
      agg.set(sid, a);
    }
    const type = c.type as string;
    if (type === "photo" || type === "film" || type === "music" || type === "place") {
      a[type] += 1;
    }
    if (c.occurred_at) a.dates.push(new Date(c.occurred_at as string).getTime());
    if (!a.firstPath && !a.firstUrl) {
      const ref = contentImageRef(type, (c.payload ?? {}) as Record<string, unknown>);
      if (ref.path) a.firstPath = ref.path;
      else if (ref.url) a.firstUrl = ref.url;
    }
  }

  const sharedScenes = scenes.filter((s) => agg.has(s.id as string));

  const result = await Promise.all(
    sharedScenes.map(async (s) => {
      const a = agg.get(s.id as string)!;
      let coverUrl: string | null = a.firstUrl ?? null; // 외부 URL fallback
      // 대표 이미지(cover) 우선, 없으면 첫 공유 moment의 scene_media 경로.
      const path = (s.cover_storage_path as string | null) ?? a.firstPath ?? null;
      if (path) {
        const { data } = await admin.storage
          .from(BUCKET)
          .createSignedUrl(path, SIGN_TTL);
        if (data?.signedUrl) coverUrl = data.signedUrl;
      }
      return {
        id: s.id as string,
        number: s.number as number,
        title: s.title as string,
        coverUrl,
        media: { photo: a.photo, film: a.film, music: a.music, place: a.place },
        dateRange: formatDateRange(a.dates),
      };
    })
  );

  const title =
    couple && couple.a.name && couple.b.name
      ? `${couple.a.name} & ${couple.b.name}`
      : "Scenes";

  return { couple, scenes: result, title, slug };
}

export default function ShareRoute({ loaderData }: Route.ComponentProps) {
  return (
    <ShareView
      couple={loaderData.couple}
      scenes={loaderData.scenes}
      slug={loaderData.slug}
    />
  );
}
