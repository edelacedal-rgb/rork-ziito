import { useState } from "react";
import { Bolt, Flame, Heart, Snowflake } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Progress } from "@/components/ui/progress";
import { useZiito } from "@/store/ZiitoStore";
import {
  FREEZE_COST,
  HEART_REFILL_INTERVAL,
  MAX_HEARTS,
} from "@/lib/ziito-types";
import { startOfDay, isSameDay } from "@/lib/ziito-date";
import { cn } from "@/lib/utils";

function mmss(ms: number): string {
  const s = Math.floor(ms / 1000);
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

export function GamificationBar() {
  const { game } = useZiito();
  const [open, setOpen] = useState(false);
  const streakActive = game.lastStudyDay != null && isSameDay(game.lastStudyDay, Date.now());

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="flex w-full items-center justify-around gap-2 rounded-full border border-border bg-card/80 px-4 py-2.5 shadow-sm backdrop-blur transition active:scale-[0.98]"
      >
        <Stat icon={Flame} value={game.streak} tint={streakActive ? "text-accent" : "text-muted-foreground"} glow={streakActive} />
        <Stat icon={Heart} value={game.hearts} tint="text-rose-500" />
        <Stat icon={Bolt} value={game.xp} tint="text-yellow-500" />
      </button>
      <RewardsDialog open={open} onOpenChange={setOpen} streakActive={streakActive} />
    </>
  );
}

function Stat({
  icon: Icon,
  value,
  tint,
  glow,
}: {
  icon: typeof Flame;
  value: number;
  tint: string;
  glow?: boolean;
}) {
  return (
    <span className="flex flex-1 items-center justify-center gap-1.5">
      <Icon className={cn("h-4 w-4 fill-current", tint, glow && "animate-pulse drop-shadow-[0_0_6px_currentColor]")} />
      <span className="text-sm font-extrabold tabular-nums text-foreground">{value}</span>
    </span>
  );
}

function RewardsDialog({
  open,
  onOpenChange,
  streakActive,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  streakActive: boolean;
}) {
  const { game, buyFreeze } = useZiito();
  const level = Math.max(1, Math.floor(game.xp / 500) + 1);
  const xpInLevel = game.xp % 500;
  const levelProgress = (xpInLevel / 500) * 100;
  const canBuyFreeze = game.xp >= FREEZE_COST;

  const nextHeartIn =
    game.hearts < MAX_HEARTS
      ? HEART_REFILL_INTERVAL - ((Date.now() - game.lastHeartLoss) % HEART_REFILL_INTERVAL)
      : null;

  const studyDays = new Set(game.studyDays);
  const today = startOfDay(new Date());
  const weeks = 17;
  const cells = Array.from({ length: weeks * 7 }, (_, i) => {
    const offset = weeks * 7 - 1 - i;
    const d = new Date(today);
    d.setDate(d.getDate() - offset);
    return studyDays.has(startOfDay(d).getTime());
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[85vh] overflow-y-auto rounded-3xl">
        <DialogHeader>
          <DialogTitle>Tu progreso</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          {/* Level */}
          <div className="rounded-2xl border bg-secondary/40 p-4">
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-full bg-accent/20 text-lg font-extrabold text-accent-foreground">
                {level}
              </div>
              <div>
                <p className="font-semibold">Nivel {level}</p>
                <p className="text-xs text-muted-foreground">{game.xp} XP totales</p>
              </div>
            </div>
            <Progress value={levelProgress} className="mt-3 h-2" />
            <p className="mt-1.5 text-xs text-muted-foreground">
              {xpInLevel}/500 XP para el nivel {level + 1}
            </p>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {/* Hearts */}
            <div className="rounded-2xl border bg-secondary/40 p-4 text-center">
              <div className="flex justify-center gap-1">
                {Array.from({ length: MAX_HEARTS }, (_, i) => (
                  <Heart
                    key={i}
                    className={cn(
                      "h-4 w-4",
                      i < game.hearts ? "fill-rose-500 text-rose-500" : "text-muted-foreground/40",
                    )}
                  />
                ))}
              </div>
              <p className="mt-2 text-xs font-semibold">Vidas</p>
              <p className="text-[11px] tabular-nums text-muted-foreground">
                {nextHeartIn != null ? `Próxima en ${mmss(nextHeartIn)}` : "¡Completas!"}
              </p>
            </div>

            {/* Streak */}
            <div className="rounded-2xl border bg-secondary/40 p-4 text-center">
              <Flame className={cn("mx-auto h-6 w-6", streakActive ? "fill-accent text-accent" : "text-muted-foreground")} />
              <p className="mt-1 text-lg font-bold tabular-nums">{game.streak} días</p>
              <p className="text-[11px] text-muted-foreground">Racha · récord {game.longestStreak}</p>
            </div>
          </div>

          {/* Shop */}
          <div className="rounded-2xl border bg-secondary/40 p-4">
            <p className="mb-3 flex items-center gap-2 font-semibold">
              <Snowflake className="h-4 w-4 text-cyan-500" /> Tienda offline
            </p>
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-full bg-cyan-500/15">
                <Snowflake className="h-5 w-5 text-cyan-500" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-semibold">Congelador de racha</p>
                <p className="text-xs text-muted-foreground">
                  Tienes {game.freezes} · protege un día perdido
                </p>
              </div>
              <button
                onClick={buyFreeze}
                disabled={!canBuyFreeze}
                className={cn(
                  "rounded-full px-3 py-2 text-xs font-bold text-white transition",
                  canBuyFreeze ? "bg-accent active:scale-95" : "bg-muted-foreground/40",
                )}
              >
                {FREEZE_COST} XP
              </button>
            </div>
          </div>

          {/* Heatmap */}
          <div className="rounded-2xl border bg-secondary/40 p-4">
            <p className="mb-3 font-semibold">Constancia</p>
            <div className="grid grid-cols-[repeat(17,minmax(0,1fr))] gap-1">
              {cells.map((active, i) => (
                <div
                  key={i}
                  className={cn(
                    "aspect-square rounded-[2px]",
                    active ? "bg-primary" : "bg-muted-foreground/15",
                  )}
                />
              ))}
            </div>
            <p className="mt-2 text-[11px] text-muted-foreground">
              Cada cuadro verde es un día que estudiaste.
            </p>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
