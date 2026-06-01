import { ChevronUp, Coffee, Mountain } from "lucide-react";

import { useZiito } from "@/store/ZiitoStore";
import { PHASE_LABEL } from "@/lib/ziito-types";

export function ActiveFocusBar() {
  const { pomodoro, formattedRemaining, openFocus, focusVisible } = useZiito();
  if (!pomodoro.isRunning || focusVisible) return null;

  return (
    <div className="pointer-events-none px-4 pb-2">
      <button
        onClick={openFocus}
        className="pointer-events-auto mx-auto flex w-full max-w-lg items-center gap-3 rounded-full bg-primary px-4 py-3 text-primary-foreground shadow-lg shadow-primary/30 transition active:scale-[0.98]"
      >
        <span className="flex h-9 w-9 items-center justify-center rounded-full bg-white/20">
          {pomodoro.phase === "focus" ? (
            <Mountain className="h-4 w-4" />
          ) : (
            <Coffee className="h-4 w-4" />
          )}
        </span>
        <span className="flex flex-col items-start leading-tight">
          <span className="text-[11px] font-semibold opacity-80">{PHASE_LABEL[pomodoro.phase]}</span>
          <span className="text-base font-bold tabular-nums">{formattedRemaining}</span>
        </span>
        <ChevronUp className="ml-auto h-5 w-5 opacity-70" />
      </button>
    </div>
  );
}
