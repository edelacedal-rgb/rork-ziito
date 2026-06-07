import { useMemo, useState } from "react";
import { Flag, Play, Trophy } from "lucide-react";

import { useZiito } from "@/store/ZiitoStore";
import { colorAlpha, colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

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
    <div className="space-y-4 pb-2">
      <div className="flex items-center justify-between pt-1">
        <h1 className="text-2xl font-bold tracking-tight">Montaña</h1>
        <button
          onClick={() => openFocus()}
          className="flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground transition active:scale-95"
        >
          <Play className="h-3.5 w-3.5 fill-primary-foreground" /> Escalar
        </button>
      </div>

      {subjects.length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <MountainScene progress={0} color="16A34A" summited={false} />
          <p className="font-semibold">Aún no hay materias</p>
          <p className="mx-auto max-w-xs text-sm text-muted-foreground">
            Crea materias en "Más" y empieza a acumular minutos de enfoque para escalar cada cara.
          </p>
        </div>
      ) : (
        <>
          {/* Diorama */}
          <div className="overflow-hidden rounded-xl border bg-card p-6">
            <MountainScene
              progress={current?.progress ?? 0}
              color={current?.subject.colorHex ?? "16A34A"}
              summited={(current?.progress ?? 0) >= 1}
              flags={current?.flags ?? 0}
            />
            <div className="mt-4 text-center">
              <p className="font-semibold">{current?.subject.name}</p>
              <p className="text-sm text-muted-foreground">
                {current?.minutes} min · {Math.round((current?.progress ?? 0) * 100)}% a la cima
              </p>
            </div>
            <div className="mx-auto mt-3 h-1.5 max-w-xs overflow-hidden rounded-full bg-secondary">
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
                  "flex shrink-0 items-center gap-2 rounded-lg border px-3 py-2 text-sm font-medium transition active:scale-95",
                  i === active ? "border-primary bg-primary/10 text-primary" : "bg-card",
                )}
              >
                <span className="h-2 w-2 rounded-full" style={{ backgroundColor: colorVar(f.subject.colorHex) }} />
                {f.subject.name}
                {f.progress >= 1 && <Trophy className="h-3.5 w-3.5 text-accent" />}
              </button>
            ))}
          </div>

          {/* Flag log */}
          <div className="rounded-xl border bg-card divide-y divide-border">
            <div className="flex items-center gap-2 px-4 py-3">
              <Flag className="h-4 w-4 text-primary" />
              <p className="font-semibold text-sm">Banderas plantadas</p>
            </div>
            {faces.map((f) => (
              <div key={f.subject.id} className="flex items-center justify-between px-4 py-3">
                <span className="flex items-center gap-2 text-sm">
                  <span className="h-2 w-2 rounded-full" style={{ backgroundColor: colorVar(f.subject.colorHex) }} />
                  {f.subject.name}
                </span>
                <span
                  className="rounded-md px-2 py-0.5 text-xs font-semibold"
                  style={{
                    color: colorVar(f.subject.colorHex),
                    backgroundColor: colorAlpha(f.subject.colorHex, 0.1),
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
  const snowY = 70 - progress * 45;
  return (
    <svg viewBox="0 0 200 150" className="mx-auto h-44 w-full">
      <defs>
        <linearGradient id="rock" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#9ca3af" />
          <stop offset="100%" stopColor="#6b7280" />
        </linearGradient>
        <clipPath id="peak">
          <polygon points="100,15 165,120 35,120" />
        </clipPath>
      </defs>

      <g clipPath="url(#peak)">
        <rect x="20" y="10" width="160" height="120" fill="url(#rock)" />
        <rect x="20" y="10" width="160" height={Math.max(0, snowY)} fill="#f8fafc" />
        <rect x="20" y={Math.max(0, snowY)} width="160" height="5" fill="#e2e8f0" opacity="0.6" />
      </g>
      <polygon points="100,15 165,120 35,120" fill="none" stroke={colorAlpha(color, 0.25)} strokeWidth="1.5" />

      {flags > 0 && (
        <g>
          <line x1="100" y1="15" x2="100" y2="3" stroke="#374151" strokeWidth="1.5" />
          <polygon points="100,4 112,7.5 100,11" fill={colorVar(color)} opacity="0.9" />
        </g>
      )}

      <ellipse cx="100" cy="125" rx="90" ry="12" fill="#86c34a" opacity="0.8" />

      <g fill="#2f7d32" opacity="0.8">
        <polygon points="43,122 50,107 57,122" />
        <polygon points="150,122 157,108 164,122" />
      </g>

      {summited && (
        <circle cx="100" cy="8" r="2.5" fill="#FBBF24" />
      )}
    </svg>
  );
}
