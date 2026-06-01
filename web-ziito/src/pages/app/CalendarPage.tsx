import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { Header } from "@/pages/app/Subjects";
import { useZiito } from "@/store/ZiitoStore";
import { isSameDay, startOfDay } from "@/lib/ziito-date";
import { colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

const MONTHS = [
  "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
  "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
];
const DOW = ["L", "M", "X", "J", "V", "S", "D"];

export default function CalendarPage() {
  const { exams, tasks, sessions, subjects } = useZiito();
  const navigate = useNavigate();
  const [cursor, setCursor] = useState(() => startOfDay(new Date()));
  const [selected, setSelected] = useState(() => startOfDay(new Date()));

  const subjectOf = (id: string | null) => subjects.find((s) => s.id === id);

  const days = useMemo(() => {
    const year = cursor.getFullYear();
    const month = cursor.getMonth();
    const first = new Date(year, month, 1);
    const startOffset = (first.getDay() + 6) % 7; // Monday-first
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const cells: (Date | null)[] = [];
    for (let i = 0; i < startOffset; i++) cells.push(null);
    for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, month, d));
    return cells;
  }, [cursor]);

  const dotsFor = (d: Date) => {
    const ids = new Set<string>();
    exams.forEach((e) => isSameDay(e.date, d) && e.subjectID && ids.add(e.subjectID));
    tasks.forEach((t) => isSameDay(t.dueDate, d) && t.subjectID && ids.add(t.subjectID));
    sessions.forEach((s) => isSameDay(s.date, d) && ids.add(s.subjectID));
    return Array.from(ids).slice(0, 4);
  };

  const dayExams = exams.filter((e) => isSameDay(e.date, selected));
  const dayTasks = tasks.filter((t) => isSameDay(t.dueDate, selected));
  const daySessions = sessions.filter((s) => isSameDay(s.date, selected));

  return (
    <div className="space-y-5 pb-2">
      <Header title="Calendario" onBack={() => navigate("/mas")} />

      <div className="rounded-2xl border bg-card p-4">
        <div className="mb-3 flex items-center justify-between">
          <button
            onClick={() => setCursor(new Date(cursor.getFullYear(), cursor.getMonth() - 1, 1))}
            className="flex h-8 w-8 items-center justify-center rounded-full transition active:scale-90"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
          <p className="font-bold">
            {MONTHS[cursor.getMonth()]} {cursor.getFullYear()}
          </p>
          <button
            onClick={() => setCursor(new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1))}
            className="flex h-8 w-8 items-center justify-center rounded-full transition active:scale-90"
          >
            <ChevronRight className="h-5 w-5" />
          </button>
        </div>

        <div className="mb-1 grid grid-cols-7 text-center text-[11px] font-semibold text-muted-foreground">
          {DOW.map((d, i) => (
            <span key={i}>{d}</span>
          ))}
        </div>
        <div className="grid grid-cols-7 gap-1">
          {days.map((d, i) => {
            if (!d) return <span key={i} />;
            const isToday = isSameDay(d, new Date());
            const isSel = isSameDay(d, selected);
            const dots = dotsFor(d);
            return (
              <button
                key={i}
                onClick={() => setSelected(startOfDay(d))}
                className={cn(
                  "flex aspect-square flex-col items-center justify-center rounded-lg text-sm transition active:scale-90",
                  isSel ? "bg-primary text-primary-foreground" : isToday ? "bg-secondary font-bold text-primary" : "",
                )}
              >
                <span>{d.getDate()}</span>
                {dots.length > 0 && (
                  <span className="mt-0.5 flex gap-0.5">
                    {dots.map((id) => (
                      <span
                        key={id}
                        className="h-1 w-1 rounded-full"
                        style={{ backgroundColor: isSel ? "#fff" : colorVar(subjectOf(id)?.colorHex ?? "16A34A") }}
                      />
                    ))}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Selected day detail */}
      <section>
        <h3 className="mb-2 font-semibold">
          {selected.toLocaleDateString("es-ES", { weekday: "long", day: "numeric", month: "long" })}
        </h3>
        {dayExams.length === 0 && dayTasks.length === 0 && daySessions.length === 0 ? (
          <p className="py-6 text-center text-sm text-muted-foreground">Nada programado este día</p>
        ) : (
          <div className="space-y-2">
            {dayExams.map((e) => (
              <DetailRow key={e.id} label={e.title} tag="Evaluación" color={subjectOf(e.subjectID)?.colorHex ?? "16A34A"} />
            ))}
            {dayTasks.map((t) => (
              <DetailRow key={t.id} label={t.title} tag="Tarea" color={subjectOf(t.subjectID)?.colorHex ?? "16A34A"} />
            ))}
            {daySessions.map((s) => {
              const exam = exams.find((e) => e.id === s.examID);
              return (
                <DetailRow
                  key={s.id}
                  label={exam?.title ?? "Sesión de estudio"}
                  tag={`${s.durationMinutes} min`}
                  color={subjectOf(s.subjectID)?.colorHex ?? "16A34A"}
                />
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}

function DetailRow({ label, tag, color }: { label: string; tag: string; color: string }) {
  return (
    <div className="flex items-center gap-3 rounded-xl border bg-card p-3.5">
      <span className="h-8 w-1 rounded-full" style={{ backgroundColor: colorVar(color) }} />
      <span className="flex-1 text-sm font-medium">{label}</span>
      <span className="text-xs text-muted-foreground">{tag}</span>
    </div>
  );
}
