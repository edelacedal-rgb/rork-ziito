import { useMemo, useState } from "react";
import { Flag, Play, Trophy } from "lucide-react";

import { useZiito } from "@/store/ZiitoStore";
import { colorAlpha, colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

// Minutes of focus needed to fully "summit" a subject.
const GOAL_MINUTES = 300;

export default function Mountain() {
  const { subjects, openFocus, subjectFocusMinutes } = useZiito();
  const [active, setActive] = useState(0);

  const faces = useMemo(
    () =>
      subjects.map((s) => {
        const minutes = subjectFocusMinutes(s.id);
        const progress = Math.min(1, minutes / GOAL_MINUTES);
        const flags = Math.floor(minutes / 25);
        return { subject: s, minutes, progress, flags };
      }),
    [subjects, subjectFocusMinutes],
  );

  const current = faces[active];

  return (
    <div className="space-y-5 pb-2">
      <div className="flex items-center justify-between pt-1">
        <h1 className="text-2xl font-extrabold tracking-tight">Montaña</h1>
        <button
          onClick={() => openFocus()}
          className="flex items-center gap-1.5 rounded-full bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground transition active:scale-95"
        >
          <Play className="h-3.5 w-3.5 fill-primary-foreground" /> Escalar
        </button>
      </div>

      {subjects.length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <MountainScene progress={0} color="16A34A" summited={false} />
          <p className="text-lg font-semibold">Aún no hay materias</p>
          <p className="mx-auto max-w-xs text-sm text-muted-foreground">
            Crea materias en "Más" y empieza a acumular minutos de enfoque para escalar cada cara.
          </p>
        </div>
      ) : (
        <>
          {/* Diorama */}
          <div className="overflow-hidden rounded-3xl border bg-gradient-to-b from-sky-200/70 to-background p-6">
            <MountainScene
              progress={current?.progress ?? 0}
              color={current?.subject.colorHex ?? "16A34A"}
              summited={(current?.progress ?? 0) >= 1}
              flags={current?.flags ?? 0}
            />
            <div className="mt-4 text-center">
              <p className="text-lg font-bold">{current?.subject.name}</p>
              <p className="text-sm text-muted-foreground">
                {current?.minutes} min de enfoque · {Math.round((current?.progress ?? 0) * 100)}% a la cima
              </p>
            </div>
            <div className="mx-auto mt-3 h-2 max-w-xs overflow-hidden rounded-full bg-card">
              <div
                className="h-full rounded-full transition-all duration-500"
                style={{
                  width: `${(current?.progress ?? 0) * 100}%`,
                  backgroundColor: colorVar(current?.subject.colorHex ?? "16A34A"),
                }}
              />
            </div>
          </div>

          {/* Face selector */}
          <div className="flex gap-2 overflow-x-auto pb-1">
            {faces.map((f, i) => (
              <button
                key={f.subject.id}
                onClick={() => setActive(i)}
                className={cn(
                  "flex shrink-0 items-center gap-2 rounded-full border px-3.5 py-2 text-sm font-medium transition active:scale-95",
                  i === active ? "border-primary bg-primary/10" : "bg-card",
                )}
              >
                <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: colorVar(f.subject.colorHex) }} />
                {f.subject.name}
                {f.progress >= 1 && <Trophy className="h-3.5 w-3.5 text-accent" />}
              </button>
            ))}
          </div>

          {/* Flag log */}
          <div className="rounded-2xl border bg-card p-4">
            <p className="mb-3 flex items-center gap-2 font-semibold">
              <Flag className="h-4 w-4 text-primary" /> Banderas plantadas
            </p>
            {faces.map((f) => (
              <div key={f.subject.id} className="flex items-center justify-between py-1.5">
                <span className="flex items-center gap-2 text-sm">
                  <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: colorVar(f.subject.colorHex) }} />
                  {f.subject.name}
                </span>
                <span
                  className="rounded-full px-2 py-0.5 text-xs font-bold"
                  style={{
                    color: colorVar(f.subject.colorHex),
                    backgroundColor: colorAlpha(f.subject.colorHex, 0.12),
                  }}
                >
                  {f.flags} {f.flags === 1 ? "bandera" : "banderas"}
                </span>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

/** SVG mountain that fills with snow as progress increases and plants a flag at the summit. */
function MountainScene({
  progress,
  color,
  summited,
  flags = 0,
}: {
  progress: number;
  color: string;
  summited: boolean;
  flags?: number;
}) {
  // snow line moves up (smaller y) as progress grows
  const snowY = 70 - progress * 45;
  return (
    <svg viewBox="0 0 200 150" className="mx-auto h-48 w-full">
      <defs>
        <linearGradient id="rock" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#8a8f98" />
          <stop offset="100%" stopColor="#5b6068" />
        </linearGradient>
        <clipPath id="peak">
          <polygon points="100,15 165,120 35,120" />
        </clipPath>
      </defs>

      {/* sky glow */}
      <circle cx="150" cy="35" r="14" fill={colorAlpha(color, 0.5)} />

      {/* mountain body */}
      <g clipPath="url(#peak)">
        <rect x="20" y="10" width="160" height="120" fill="url(#rock)" />
        {/* snow cap */}
        <rect x="20" y="10" width="160" height={Math.max(0, snowY)} fill="#f4f7fb" />
        {/* snow line softening */}
        <rect x="20" y={Math.max(0, snowY)} width="160" height="6" fill="#e2e8f0" opacity="0.7" />
        {/* subtle ridge */}
        <polyline points="100,15 120,120" stroke="#00000018" strokeWidth="4" fill="none" />
      </g>
      <polygon points="100,15 165,120 35,120" fill="none" stroke={colorAlpha(color, 0.3)} strokeWidth="1.5" />

      {/* summit flag */}
      {flags > 0 && (
        <g>
          <line x1="100" y1="15" x2="100" y2="2" stroke="#1f2937" strokeWidth="1.5" />
          <polygon points="100,3 113,7 100,11" fill="#fff" stroke="#16A34A" strokeWidth="1" />
          <text x="103" y="9.5" fontSize="6" fontWeight="bold" fill="#16A34A">Z</text>
        </g>
      )}

      {/* grass base */}
      <ellipse cx="100" cy="125" rx="92" ry="14" fill="#86c34a" />
      <ellipse cx="100" cy="123" rx="70" ry="9" fill="#6fae3a" opacity="0.6" />

      {/* pines */}
      <g fill="#2f7d32">
        <polygon points="42,122 50,104 58,122" />
        <polygon points="150,122 158,106 166,122" />
      </g>

      {summited && (
        <g>
          <circle cx="100" cy="8" r="3" fill="#FBBF24" />
        </g>
      )}
    </svg>
  );
}
