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
    <div className="fixed inset-0 z-50 flex flex-col overflow-hidden text-white">
      {/* Rock + mist background */}
      <div className="absolute inset-0 bg-gradient-to-b from-[#2a2a2e] to-[#0e0e12]" />
      <div
        className="absolute inset-0 opacity-70 mix-blend-plus-lighter"
        style={{
          backgroundImage:
            "radial-gradient(circle at 30% 35%, rgba(255,255,255,0.16), transparent 55%), radial-gradient(circle at 75% 65%, rgba(255,255,255,0.12), transparent 55%)",
        }}
      />
      <div
        className="absolute inset-0 opacity-30"
        style={{
          backgroundImage:
            "repeating-linear-gradient(115deg, rgba(255,255,255,0.04) 0 14px, rgba(0,0,0,0.18) 14px 30px)",
        }}
      />

      <div className="relative flex flex-1 flex-col px-6 pb-10 pt-[max(env(safe-area-inset-top),16px)]">
        {/* Top bar */}
        <div className="flex items-center justify-between">
          <button
            onClick={minimizeFocus}
            className="flex h-11 w-11 items-center justify-center rounded-full bg-white/10 backdrop-blur transition active:scale-90"
          >
            <ChevronDown className="h-5 w-5" />
          </button>
          <span className="text-xs font-black tracking-[0.3em] text-white/70">FOG MODE</span>
          <button
            onClick={() => setConfirmStop(true)}
            className="flex h-11 w-11 items-center justify-center rounded-full bg-white/10 backdrop-blur transition active:scale-90"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Center */}
        <div className="flex flex-1 flex-col items-center justify-center gap-5">
          <span className="text-xs font-black tracking-[0.25em] text-white/70">
            {PHASE_LABEL[pomodoro.phase].toUpperCase()}
          </span>
          <span className="font-rounded text-[5.5rem] font-black leading-none tabular-nums drop-shadow-lg sm:text-[7rem]">
            {formattedRemaining}
          </span>
          <div className="flex gap-2">
            {cycleDots.map((_, i) => (
              <span
                key={i}
                className={cn(
                  "h-2.5 w-2.5 rounded-full",
                  i < pomodoro.completedFocusCycles % settings.cyclesUntilLongBreak
                    ? "bg-white"
                    : "bg-white/20",
                )}
              />
            ))}
          </div>
        </div>

        {/* Active sub-topic HUD card — links the timer to the current content node */}
        {pomodoro.phase === "focus" && currentSubtopic && (
          <div className="mb-5 flex items-center gap-3 rounded-2xl bg-white px-4 py-3 text-black shadow-xl">
            <span
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-white"
              style={{ backgroundColor: colorVar(DENSITY_META[currentSubtopic.density].colorHex) }}
            >
              <span className="text-sm font-black">{DENSITY_META[currentSubtopic.density].short[0]}</span>
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-[10px] font-black uppercase tracking-wider text-black/50">Enfoque activo</p>
              <p className="truncate text-sm font-bold leading-tight">{currentSubtopic.title}</p>
            </div>
            <span
              className="shrink-0 rounded-full px-2.5 py-1 text-[10px] font-black"
              style={{
                backgroundColor: `${colorVar(DENSITY_META[currentSubtopic.density].colorHex)}22`,
                color: colorVar(DENSITY_META[currentSubtopic.density].colorHex),
              }}
            >
              Carga: {DENSITY_META[currentSubtopic.density].short}
            </span>
          </div>
        )}

        {/* Controls */}
        <div className="relative flex items-center justify-center gap-5">
          {flash && (
            <span className="absolute -top-14 flex items-center gap-1.5 rounded-full bg-white px-3.5 py-2 text-xs font-black text-black shadow-lg">
              <Flag className="h-3.5 w-3.5 fill-black" /> ¡Bandera plantada!
            </span>
          )}
          <CtrlButton onClick={skipPhase}>
            <SkipForward className="h-5 w-5 fill-white" />
          </CtrlButton>
          <button
            onClick={pomodoro.isPaused ? resumeFocus : pauseFocus}
            className="flex h-[72px] w-[72px] items-center justify-center rounded-full bg-white text-black shadow-xl transition active:scale-90"
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
            className="mt-6 flex items-center justify-center gap-2 text-xs font-medium text-white/70 transition active:scale-95"
          >
            <SlidersHorizontal className="h-3.5 w-3.5" /> Ajustar Pomodoro
          </button>
        )}
      </div>

      <PomodoroSettingsDialog open={showSettings} onOpenChange={setShowSettings} />

      {confirmStop && (
        <div className="absolute inset-0 z-10 flex items-center justify-center bg-black/60 px-8">
          <div className="w-full max-w-sm rounded-3xl bg-card p-6 text-foreground shadow-2xl">
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
                className="rounded-full bg-destructive px-4 py-3 font-semibold text-destructive-foreground transition active:scale-95"
              >
                Sí, descender
              </button>
              <button
                onClick={() => setConfirmStop(false)}
                className="rounded-full bg-secondary px-4 py-3 font-semibold text-secondary-foreground transition active:scale-95"
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
      className="flex h-[54px] w-[54px] items-center justify-center rounded-full border border-white/20 bg-white/10 transition active:scale-90"
    >
      {children}
    </button>
  );
}
