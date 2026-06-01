import { useEffect, useState } from "react";
import { Minus, Plus } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useZiito } from "@/store/ZiitoStore";
import type { PomodoroSettings } from "@/lib/ziito-types";

export function PomodoroSettingsDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const { settings, updateSettings } = useZiito();
  const [draft, setDraft] = useState<PomodoroSettings>(settings);

  useEffect(() => {
    if (open) setDraft(settings);
  }, [open, settings]);

  const rows: {
    label: string;
    key: keyof PomodoroSettings;
    min: number;
    max: number;
    step: number;
    unit: string;
  }[] = [
    { label: "Enfoque", key: "focusMinutes", min: 5, max: 90, step: 5, unit: "min" },
    { label: "Descanso corto", key: "shortBreakMinutes", min: 1, max: 30, step: 1, unit: "min" },
    { label: "Descanso largo", key: "longBreakMinutes", min: 5, max: 60, step: 5, unit: "min" },
    { label: "Ciclos hasta descanso largo", key: "cyclesUntilLongBreak", min: 2, max: 8, step: 1, unit: "" },
  ];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="rounded-3xl">
        <DialogHeader>
          <DialogTitle>Pomodoro</DialogTitle>
        </DialogHeader>
        <div className="space-y-2">
          {rows.map((r) => (
            <div key={r.key} className="flex items-center justify-between rounded-xl bg-secondary/50 px-4 py-3">
              <span className="text-sm font-medium">{r.label}</span>
              <div className="flex items-center gap-3">
                <button
                  onClick={() =>
                    setDraft((d) => ({ ...d, [r.key]: Math.max(r.min, d[r.key] - r.step) }))
                  }
                  className="flex h-8 w-8 items-center justify-center rounded-full bg-background transition active:scale-90"
                >
                  <Minus className="h-4 w-4" />
                </button>
                <span className="w-16 text-center text-sm font-bold tabular-nums">
                  {draft[r.key]} {r.unit}
                </span>
                <button
                  onClick={() =>
                    setDraft((d) => ({ ...d, [r.key]: Math.min(r.max, d[r.key] + r.step) }))
                  }
                  className="flex h-8 w-8 items-center justify-center rounded-full bg-background transition active:scale-90"
                >
                  <Plus className="h-4 w-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
        <DialogFooter>
          <Button
            variant="ghost"
            onClick={() => onOpenChange(false)}
          >
            Cancelar
          </Button>
          <Button
            onClick={() => {
              updateSettings(draft);
              onOpenChange(false);
            }}
          >
            Guardar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
