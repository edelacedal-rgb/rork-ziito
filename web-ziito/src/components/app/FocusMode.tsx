import { useEffect, useState } from "react";
import { ChevronDown, Flag, Pause, Play, SkipForward, SlidersHorizontal, X } from "lucide-react";

import { useZiito } from "@/store/ZiitoStore";
import { DENSITY_META, PHASE_LABEL } from "@/lib/ziito-types";
import { PomodoroSettingsDialog } from "@/components/app/PomodoroSettingsDialog";
import { colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

export function FocusMode() {
  const {
    focusVisible,
    pomodoro,
    settings,
    formattedRemaining,
    pauseFocus,
    resumeFocus,
    skipPhase,
    stopFocus,
    minimizeFocus,
    lastReward,
    currentSubtopic,
  } = useZiito();

  const [showSettings, setShowSettings] = useState(false);
  const [confirmStop, setConfirmStop] = useState(false);
  const [flash, setFlash] = useState(false);

  useEffect(() => {
    if (!lastReward) return;
    setFlash(true);
    const t = setTimeout(() => setFlash(false), 1600);
    return () => clearTimeout(t);
  }, [lastReward]);

  if (!focusVisible) return null;

  const cycleDots = Array.from({ length: settings.cyclesUntilLongBreak });

  return (
    <div className="fixed inset-0 z-50 flex flex-col overflow-hidden bg-[#111214] text-white">
      <div className="relative flex flex-1 flex-col px-6 pb-10 pt-[max(env(safe-area-inset-top),16px)]">
        {/* Top bar */}
        <div className="flex items-center justify-between">
          <button
            onClick={minimizeFocus}
            className="flex h-10 w-10 items-center justify-center rounded-lg bg-white/10 transition active:scale-90"
          >
            <ChevronDown className="h-5 w-5" />
          </button>
          <span className="text-[11px] font-semibold tracking-[0.25em] text-white/50">FOG MODE</span>
          <button
            onClick={() => setConfirmStop(true)}
            className="flex h-10 w-10 items-center justify-center rounded-lg bg-white/10 transition active:scale-90"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Center */}
        <div className="flex flex-1 flex-col items-center justify-center gap-5">
          <span className="text-[11px] font-semibold tracking-[0.25em] text-white/50">
            {PHASE_LABEL[pomodoro.phase].toUpperCase()}
          </span>
          <span className="font-rounded text-[5.5rem] font-black leading-none tabular-nums sm:text-[7rem]">
            {formattedRemaining}
          </span>
          <div className="flex gap-2">
            {cycleDots.map((_, i) => (
              <span
                key={i}
                className={cn(
                  "h-2 w-2 rounded-full",
                  i < pomodoro.completedFocusCycles % settings.cyclesUntilLongBreak
                    ? "bg-white"
                    : "bg-white/20",
                )}
              />
            ))}
          </div>
        </div>

        {/* Active sub-topic HUD */}
        {pomodoro.phase === "focus" && currentSubtopic && (
          <div className="mb-5 flex items-center gap-3 rounded-xl bg-white px-4 py-3 text-black">
            <span
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-white"
              style={{ backgroundColor: colorVar(DENSITY_META[currentSubtopic.density].colorHex) }}
            >
              <span className="text-sm font-bold">{DENSITY_META[currentSubtopic.density].short[0]}</span>
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-[10px] font-semibold uppercase tracking-wider text-black/40">Enfoque activo</p>
              <p className="truncate text-sm font-semibold leading-tight">{currentSubtopic.title}</p>
            </div>
            <span
              className="shrink-0 rounded-lg px-2.5 py-1 text-[10px] font-semibold"
              style={{
                backgroundColor: `${colorVar(DENSITY_META[currentSubtopic.density].colorHex)}22`,
                color: colorVar(DENSITY_META[currentSubtopic.density].colorHex),
              }}
            >
              {DENSITY_META[currentSubtopic.density].short}
            </span>
          </div>
        )}

        {/* Controls */}
        <div className="relative flex items-center justify-center gap-5">
          {flash && (
            <span className="absolute -top-14 flex items-center gap-1.5 rounded-xl bg-white px-3.5 py-2 text-xs font-semibold text-black">
              <Flag className="h-3.5 w-3.5 fill-black" /> ¡Bandera plantada!
            </span>
          )}
          <CtrlButton onClick={skipPhase}>
            <SkipForward className="h-5 w-5 fill-white" />
          </CtrlButton>
          <button
            onClick={pomodoro.isPaused ? resumeFocus : pauseFocus}
            className="flex h-[68px] w-[68px] items-center justify-center rounded-2xl bg-white text-black transition active:scale-90"
          >
            {pomodoro.isPaused ? (
              <Play className="h-7 w-7 fill-black" />
            ) : (
              <Pause className="h-7 w-7 fill-black" />
            )}
          </button>
          <CtrlButton onClick={minimizeFocus}>
            <ChevronDown className="h-5 w-5" />
          </CtrlButton>
        </div>

        {pomodoro.mode === "pomodoro" && (
          <button
            onClick={() => setShowSettings(true)}
            className="mt-6 flex items-center justify-center gap-2 text-xs font-medium text-white/50 transition active:scale-95"
          >
            <SlidersHorizontal className="h-3.5 w-3.5" /> Ajustar Pomodoro
          </button>
        )}
      </div>

      <PomodoroSettingsDialog open={showSettings} onOpenChange={setShowSettings} />

      {confirmStop && (
        <div className="absolute inset-0 z-10 flex items-center justify-center bg-black/70 px-8">
          <div className="w-full max-w-sm rounded-2xl bg-card p-6 text-foreground">
            <h3 className="text-lg font-bold">¿Abandonar la pared?</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Si bajas ahora, no plantarás bandera en este tramo.
            </p>
            <div className="mt-6 flex flex-col gap-2">
              <button
                onClick={() => {
                  setConfirmStop(false);
                  stopFocus();
                }}
                className="rounded-xl bg-destructive px-4 py-3 font-semibold text-destructive-foreground transition active:scale-95"
              >
                Sí, descender
              </button>
              <button
                onClick={() => setConfirmStop(false)}
                className="rounded-xl bg-secondary px-4 py-3 font-semibold text-secondary-foreground transition active:scale-95"
              >
                Seguir escalando
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function CtrlButton({ onClick, children }: { onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      onClick={onClick}
      className="flex h-[52px] w-[52px] items-center justify-center rounded-xl border border-white/15 bg-white/10 transition active:scale-90"
    >
      {children}
    </button>
  );
}
