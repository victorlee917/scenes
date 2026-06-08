import { Fragment, useEffect, useRef, useState } from "react";
import { Link, useNavigate } from "react-router";
import { MediaIcon, type MediaType } from "./media-icon";

/// 공개 공유 페이지 View — 앱 홈을 웹으로 옮긴 형태.
///   - 상단: 커플 두 아바타가 겹친 "망원경" 형태.
///   - 가운데: 캐니스터가 **원호(arc) 다이얼**로 배열돼 돌아간다. 중앙이 포커스
///     (크게/위로), 양옆은 호를 따라 아래로 내려가며 작아지고 흐려진다(드럼 회전).
///     포인터 드래그/스와이프로 회전, 놓으면 가장 가까운 캐니스터로 스냅.
///   - 아래: 포커스된 scene의 #번호·제목.

type Person = { name: string; avatarUrl: string | null };
export type ShareCouple = { a: Person; b: Person } | null;

export type ShareScene = {
  id: string;
  number: number;
  title: string;
  coverUrl: string | null;
  media: Record<MediaType, number>;
  dateRange: string;
};

export function ShareView({
  couple,
  scenes,
  slug,
}: {
  couple: ShareCouple;
  scenes: ShareScene[];
  slug: string;
}) {
  if (scenes.length === 0) {
    return (
      <main className="flex min-h-dvh select-none flex-col bg-background text-foreground">
        <div className="pt-12">
          <CoupleTelescope couple={couple} />
        </div>
        <div className="flex flex-1 items-center justify-center">
          <p className="text-sm text-muted">No shared scenes yet.</p>
        </div>
        <ScenesHomeButton />
      </main>
    );
  }
  return (
    <main className="flex min-h-dvh select-none flex-col bg-background text-foreground">
      <SceneDial couple={couple} scenes={scenes} slug={slug} />
      <ScenesHomeButton />
    </main>
  );
}

/// Scenes 홈페이지(랜딩)로 이동하는 하단 버튼.
function ScenesHomeButton() {
  return (
    <div className="flex justify-center pb-10 pt-2">
      <Link
        to="/"
        className="rounded-full border border-foreground/10 px-3 py-1 font-display text-[10px] tracking-tight text-muted transition-colors hover:text-foreground"
      >
        Scenes
      </Link>
    </div>
  );
}

/// 두 아바타가 살짝 겹친 망원경 형태.
export function CoupleTelescope({ couple }: { couple: ShareCouple }) {
  const size = 30;
  const overlap = size * 0.35;
  return (
    <div className="flex justify-center">
      <div className="relative" style={{ width: size * 2 - overlap, height: size }}>
        <div className="absolute left-0 top-0">
          <Avatar person={couple?.a} size={size} />
        </div>
        <div className="absolute top-0" style={{ left: size - overlap }}>
          <Avatar person={couple?.b} size={size} />
        </div>
      </div>
    </div>
  );
}

function Avatar({ person, size }: { person?: Person | null; size: number }) {
  return (
    <div
      className="overflow-hidden rounded-full bg-surface ring-2 ring-background"
      style={{ width: size, height: size }}
    >
      {person?.avatarUrl ? (
        <img
          src={person.avatarUrl}
          alt={person.name}
          draggable={false}
          className="h-full w-full object-cover"
        />
      ) : (
        <div className="flex h-full w-full items-center justify-center">
          <span className="font-display text-lg text-muted">{firstChar(person?.name ?? "")}</span>
        </div>
      )}
    </div>
  );
}

const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v));

/// 캐니스터 원호 다이얼. 앱 home_view의 PageView+arc 변환을 웹으로 옮김.
/// 커플 스트립까지 감싸 화면 전체가 스와이프 영역이 된다.
function SceneDial({
  couple,
  scenes,
  slug,
}: {
  couple: ShareCouple;
  scenes: ShareScene[];
  slug: string;
}) {
  const navigate = useNavigate();
  const stageRef = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  const [pos, setPos] = useState(scenes.length - 1); // 최신을 중앙으로
  const drag = useRef<{ startX: number; startPos: number; moved: boolean } | null>(null);
  const rafId = useRef<number | null>(null);

  useEffect(() => {
    const el = stageRef.current;
    if (!el) return;
    const update = () => setWidth(el.clientWidth);
    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => {
      ro.disconnect();
      if (rafId.current) cancelAnimationFrame(rafId.current);
    };
  }, []);

  const n = scenes.length;
  // 캐니스터 지름 D. 살짝 작게.
  const D = clamp(width * 0.42, 130, 190);
  const spacing = D * 1.22; // 인접 캐니스터 중심 간 가로 간격(넉넉하게)
  const arcRadius = D * 1.64; // 호 곡률
  const ANGLE = 0.55;
  // 캐니스터(포커스) 세로 위치 — 스테이지 높이 대비 비율. 클수록 아래.
  const FOCUS_FRAC = 0.6;

  const animateTo = (target: number) => {
    if (rafId.current) cancelAnimationFrame(rafId.current);
    const start = pos;
    const t0 = performance.now();
    const dur = 320;
    const tick = (t: number) => {
      const k = Math.min(1, (t - t0) / dur);
      const e = 1 - Math.pow(1 - k, 3); // easeOutCubic
      setPos(start + (target - start) * e);
      if (k < 1) rafId.current = requestAnimationFrame(tick);
    };
    rafId.current = requestAnimationFrame(tick);
  };

  const onDown = (e: React.PointerEvent) => {
    if (rafId.current) cancelAnimationFrame(rafId.current);
    drag.current = { startX: e.clientX, startPos: pos, moved: false };
    // setPointerCapture는 일부러 안 쓴다 — 캡처하면 click이 캐니스터가 아니라
    // 이 wrapper로 retarget돼 캐니스터 onClick(상세 이동)이 안 먹는다. wrapper가
    // 전체 화면이라 캡처 없이도 드래그 move/up이 정상 버블된다.
  };
  const onMove = (e: React.PointerEvent) => {
    const d = drag.current;
    if (!d) return;
    const dx = e.clientX - d.startX;
    if (Math.abs(dx) > 3) d.moved = true;
    setPos(clamp(d.startPos - dx / spacing, 0, n - 1));
  };
  const onUp = () => {
    if (!drag.current) return;
    animateTo(clamp(Math.round(pos), 0, n - 1));
    // moved 플래그는 click 핸들러가 읽은 뒤 다음 down에서 리셋.
    setTimeout(() => (drag.current = null), 0);
  };

  const focused = clamp(Math.round(pos), 0, n - 1);

  return (
    <div
      // touch-none: 카카오 등 인앱 WebView가 가로 스와이프를 스크롤로 오인해
      // pointercancel을 쏘면 드래그가 끊겨 원래 인덱스로 튕긴다. 홈은 한 화면이라
      // 세로 스크롤이 필요 없으므로 브라우저 제스처를 전부 막아 드래그를 보장.
      className="flex flex-1 flex-col touch-none"
      onPointerDown={onDown}
      onPointerMove={onMove}
      onPointerUp={onUp}
      onPointerCancel={onUp}
    >
      <div className="pt-8">
        <CoupleTelescope couple={couple} />
      </div>

      {/* 스테이지: 아바타와 (하단 고정)메타 사이 공간을 채움. 캐니스터는 이 안
          에서 FOCUS_FRAC 위치에 떠 있다. 하단은 mask로 캐니스터·그림자가 실제로
          배경으로 fade out (오버레이 하드컷 대신 콘텐츠 자체가 사라짐). */}
      <div
        ref={stageRef}
        className="relative w-full flex-1 overflow-hidden"
        style={{
          // 포커스 바로 아래(opaque)부터 스테이지 바닥(100%, transparent)까지
          // fade. 끝을 100%로 둬 overflow 클립 지점엔 이미 완전 투명 → 하드컷 X.
          WebkitMaskImage: `linear-gradient(to bottom, #000 calc(${FOCUS_FRAC * 100}% + ${D * 0.55}px), transparent 100%)`,
          maskImage: `linear-gradient(to bottom, #000 calc(${FOCUS_FRAC * 100}% + ${D * 0.55}px), transparent 100%)`,
        }}
      >
        {scenes.map((scene, i) => {
          const delta = i - pos;
          const absD = Math.min(Math.abs(delta), 3);
          const ty = arcRadius * (1 - Math.cos(absD * ANGLE)); // 호: 멀수록 아래
          const tx = delta * spacing;
          const scale = Math.max(0.5, 1 - absD * 0.18);
          const opacity = clamp(1 - absD * 0.45, 0, 1);
          const rotXdeg = (clamp(-delta, -2, 2) * 0.18 * 180) / Math.PI;
          return (
            <div
              key={scene.id}
              onClick={() => {
                if (drag.current?.moved) return;
                // 포커스된 캐니스터를 다시 누르면 상세로 이동, 아니면 포커스 이동.
                if (i === focused) navigate(`/${slug}/${scene.number}`);
                else animateTo(i);
              }}
              className="absolute left-1/2 cursor-pointer"
              style={{
                top: `${FOCUS_FRAC * 100}%`,
                width: D,
                height: D,
                opacity,
                zIndex: Math.round(100 - absD * 10),
                transform: `translate(-50%, -50%) translateX(${tx}px) translateY(${ty}px) perspective(833px) rotateX(${rotXdeg}deg) scale(${scale})`,
              }}
            >
              <Canister scene={scene} />
            </div>
          );
        })}

      </div>

      <FocusedInfo scene={scenes[focused]} />
    </div>
  );
}

/// 필름 캐니스터(원형 커버). 크기/스케일/투명도는 다이얼 wrapper가 제어.
function Canister({ scene }: { scene: ShareScene }) {
  return (
    <div className="h-full w-full overflow-hidden rounded-full bg-surface ring-1 ring-foreground/10 shadow-[0_24px_40px_-20px_rgba(0,0,0,0.55)]">
      {scene.coverUrl ? (
        <img src={scene.coverUrl} alt={scene.title} draggable={false} className="h-full w-full object-cover" />
      ) : (
        <div className="flex h-full w-full items-center justify-center">
          <span className="font-display text-5xl text-muted">{firstChar(scene.title)}</span>
        </div>
      )}
    </div>
  );
}

/// 포커스된 scene 메타 — 앱 홈 FocusedSceneInfo와 동일 구성(공유 moment 기준).
/// #번호 · 제목 · 타입별 아이콘+개수 · 날짜 범위.
function FocusedInfo({ scene }: { scene: ShareScene | undefined }) {
  if (!scene) return null;
  const types: MediaType[] = ["photo", "film", "music", "place"];
  const items = types.filter((t) => scene.media[t] > 0);
  return (
    <div className="px-8 pb-24 pt-2 text-center">
      <p className="font-display text-xs tracking-[0.2em] text-muted">
        #{scene.number}
      </p>
      <h2 className="mt-2 font-display text-xl leading-tight sm:text-2xl">
        {scene.title}
      </h2>

      {items.length > 0 && (
        <div className="mt-4 flex items-center justify-center gap-2 text-foreground/55">
          {items.map((t, i) => (
            <Fragment key={t}>
              {i > 0 && <span className="text-foreground/30">·</span>}
              <span className="inline-flex items-center gap-1">
                <MediaIcon type={t} />
                <span className="text-xs">{scene.media[t]}</span>
              </span>
            </Fragment>
          ))}
        </div>
      )}

      {scene.dateRange && (
        <p className="mt-3 text-[10px] uppercase tracking-[0.2em] text-foreground/40">
          {scene.dateRange}
        </p>
      )}
    </div>
  );
}

function firstChar(s: string): string {
  return [...s.trim()][0]?.toUpperCase() ?? "";
}
