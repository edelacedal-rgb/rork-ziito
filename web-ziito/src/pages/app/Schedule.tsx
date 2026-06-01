import { useMemo, useState } from "react";
import { Plus, Trash2 } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useZiito, classesForWeekday } from "@/store/ZiitoStore";
import {
  WEEKDAY_META,
  WEEK_ORDERED,
  type ClassSession,
  type Weekday,
} from "@/lib/ziito-types";
import { formatMinutes, minutesOfDay, weekdayOf } from "@/lib/ziito-date";
import { colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

const START_HOUR = 6;
const END_HOUR = 23;
const HOUR_HEIGHT = 64;

export default function Schedule() {
  const { classes, subjects } = useZiito();
  const today = weekdayOf(new Date()) as Weekday;
  const [selectedDay, setSelectedDay] = useState<Weekday>(today);
  const [editing, setEditing] = useState<ClassSession | null>(null);
  const [adding, setAdding] = useState(false);

  const dayClasses = useMemo(
    () => classesForWeekday(classes, selectedDay),
    [classes, selectedDay],
  );

  const totalHeight = (END_HOUR - START_HOUR + 1) * HOUR_HEIGHT;
  const yOffset = (min: number) => Math.max(0, ((min - START_HOUR * 60) / 60) * HOUR_HEIGHT);
  const nowMin = minutesOfDay(new Date());

  return (
    <div className="flex h-[calc(100dvh-120px)] flex-col">
      <div className="flex items-center justify-between pb-3 pt-1">
        <h1 className="text-2xl font-extrabold tracking-tight">Horario</h1>
        <button
          onClick={() => setAdding(true)}
          className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-primary-foreground transition active:scale-90"
        >
          <Plus className="h-5 w-5" />
        </button>
      </div>

      {/* Weekday strip */}
      <div className="grid grid-cols-7 gap-1.5 pb-3">
        {WEEK_ORDERED.map((day) => {
          const isSelected = day === selectedDay;
          const isToday = day === today;
          const count = classes.filter((c) => c.weekday === day).length;
          return (
            <button
              key={day}
              onClick={() => setSelectedDay(day)}
              className={cn(
                "flex flex-col items-center gap-1 rounded-xl py-2 transition active:scale-95",
                isSelected ? "bg-primary text-primary-foreground" : "bg-secondary",
                !isSelected && isToday && "ring-1 ring-primary/50",
              )}
            >
              <span className={cn("text-[10px] font-black tracking-wide", !isSelected && isToday && "text-primary")}>
                {WEEKDAY_META[day].short.toUpperCase()}
              </span>
              <span className="text-sm font-bold tabular-nums">{count}</span>
            </button>
          );
        })}
      </div>

      {/* Timeline */}
      <div className="flex-1 overflow-y-auto rounded-2xl border bg-card">
        <div className="relative" style={{ height: totalHeight }}>
          {Array.from({ length: END_HOUR - START_HOUR + 1 }, (_, i) => START_HOUR + i).map((hour) => (
            <div
              key={hour}
              className="absolute left-0 right-0 flex items-start"
              style={{ top: yOffset(hour * 60) }}
            >
              <span className="w-12 -translate-y-2 pr-2 text-right text-[10px] tabular-nums text-muted-foreground">
                {String(hour).padStart(2, "0")}:00
              </span>
              <span className="mt-0 h-px flex-1 bg-border/60" />
            </div>
          ))}

          {/* Now line */}
          {selectedDay === today && nowMin >= START_HOUR * 60 && nowMin <= END_HOUR * 60 && (
            <div className="absolute left-9 right-2 flex items-center" style={{ top: yOffset(nowMin) }}>
              <span className="h-2.5 w-2.5 rounded-full bg-destructive" />
              <span className="h-0.5 flex-1 bg-destructive" />
            </div>
          )}

          {/* Blocks */}
          {dayClasses.map((c) => {
            const subject = subjects.find((s) => s.id === c.subjectID);
            const color = subject?.colorHex ?? "16A34A";
            const top = yOffset(c.startMinuteOfDay);
            const height = Math.max(28, yOffset(c.endMinuteOfDay) - top - 2);
            return (
              <button
                key={c.id}
                onClick={() => setEditing(c)}
                className="absolute left-14 right-3 overflow-hidden rounded-lg p-2 text-left text-white shadow-sm transition active:scale-[0.99]"
                style={{
                  top,
                  height,
                  background: `linear-gradient(135deg, ${colorVar(color)}, ${colorVar(color)}c8)`,
                }}
              >
                <p className="text-xs font-bold leading-tight">{subject?.name ?? (c.customName || "Clase")}</p>
                <p className="text-[10px] tabular-nums opacity-90">
                  {formatMinutes(c.startMinuteOfDay)} – {formatMinutes(c.endMinuteOfDay)}
                </p>
                {c.location && height > 56 && <p className="text-[10px] opacity-85">{c.location}</p>}
              </button>
            );
          })}
        </div>
      </div>

      {(adding || editing) && (
        <ClassDialog
          editing={editing}
          defaultDay={selectedDay}
          onClose={() => {
            setAdding(false);
            setEditing(null);
          }}
        />
      )}
    </div>
  );
}

function timeToMinutes(t: string): number {
  const [h, m] = t.split(":").map(Number);
  return (h || 0) * 60 + (m || 0);
}

function ClassDialog({
  editing,
  defaultDay,
  onClose,
}: {
  editing: ClassSession | null;
  defaultDay: Weekday;
  onClose: () => void;
}) {
  const { subjects, upsertClass, deleteClass } = useZiito();
  const [subjectID, setSubjectID] = useState<string | null>(editing?.subjectID ?? null);
  const [customName, setCustomName] = useState(editing?.customName ?? "");
  const [weekday, setWeekday] = useState<Weekday>(editing?.weekday ?? defaultDay);
  const [start, setStart] = useState(formatMinutes(editing?.startMinuteOfDay ?? 8 * 60));
  const [end, setEnd] = useState(formatMinutes(editing?.endMinuteOfDay ?? 9 * 60));
  const [location, setLocation] = useState(editing?.location ?? "");

  const startMin = timeToMinutes(start);
  const endMin = timeToMinutes(end);
  const canSave = endMin > startMin && (subjectID != null || customName.trim().length > 0);

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="rounded-3xl">
        <DialogHeader>
          <DialogTitle>{editing ? "Editar clase" : "Nueva clase"}</DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div>
            <label className="mb-1.5 block text-xs font-medium text-muted-foreground">Materia</label>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => setSubjectID(null)}
                className={cn(
                  "rounded-full border px-3 py-1.5 text-xs font-medium transition",
                  subjectID == null ? "border-primary bg-primary/10 text-primary" : "bg-card",
                )}
              >
                Personalizada
              </button>
              {subjects.map((s) => (
                <button
                  key={s.id}
                  onClick={() => setSubjectID(s.id)}
                  className={cn(
                    "flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium transition",
                    subjectID === s.id ? "border-primary bg-primary/10 text-primary" : "bg-card",
                  )}
                >
                  <span className="h-2 w-2 rounded-full" style={{ backgroundColor: colorVar(s.colorHex) }} />
                  {s.name}
                </button>
              ))}
            </div>
          </div>

          <Input
            placeholder="Nombre personalizado (opcional)"
            value={customName}
            onChange={(e) => setCustomName(e.target.value)}
          />

          <div>
            <label className="mb-1.5 block text-xs font-medium text-muted-foreground">Día</label>
            <div className="grid grid-cols-7 gap-1">
              {WEEK_ORDERED.map((d) => (
                <button
                  key={d}
                  onClick={() => setWeekday(d)}
                  className={cn(
                    "rounded-lg py-1.5 text-[10px] font-bold transition",
                    weekday === d ? "bg-primary text-primary-foreground" : "bg-secondary",
                  )}
                >
                  {WEEKDAY_META[d].short}
                </button>
              ))}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mb-1.5 block text-xs font-medium text-muted-foreground">Inicio</label>
              <Input type="time" value={start} onChange={(e) => setStart(e.target.value)} />
            </div>
            <div>
              <label className="mb-1.5 block text-xs font-medium text-muted-foreground">Fin</label>
              <Input type="time" value={end} onChange={(e) => setEnd(e.target.value)} />
            </div>
          </div>

          <Input placeholder="Aula, edificio, etc." value={location} onChange={(e) => setLocation(e.target.value)} />

          {editing && (
            <Button
              variant="ghost"
              className="w-full text-destructive hover:text-destructive"
              onClick={() => {
                deleteClass(editing.id);
                onClose();
              }}
            >
              <Trash2 className="mr-2 h-4 w-4" /> Eliminar clase
            </Button>
          )}
        </div>

        <DialogFooter>
          <Button variant="ghost" onClick={onClose}>
            Cancelar
          </Button>
          <Button
            disabled={!canSave}
            onClick={() => {
              upsertClass({
                id: editing?.id,
                subjectID,
                customName: customName.trim(),
                weekday,
                startMinuteOfDay: startMin,
                endMinuteOfDay: endMin,
                location: location.trim(),
              });
              onClose();
            }}
          >
            Guardar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
