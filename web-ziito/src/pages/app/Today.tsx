import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import {
  CalendarPlus,
  ChevronRight,
  GraduationCap,
  Leaf,
  Play,
  Sparkles,
  Sun,
  Timer,
} from "lucide-react";

import { GamificationBar } from "@/components/app/GamificationBar";
import { PriorityBadge } from "@/components/app/PriorityBadge";
import { useZiito } from "@/store/ZiitoStore";
import { classesForWeekday } from "@/store/ZiitoStore";
import {
  daysUntil,
  formatLongDate,
  formatMinutes,
  formatTimeShort,
  greeting,
  isSameDay,
  minutesOfDay,
  weekdayOf,
} from "@/lib/ziito-date";
import { colorAlpha, colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";
import type { ClassSession, Weekday } from "@/lib/ziito-types";

export default function Today() {
  const {
    subjects,
    exams,
    tasks,
    classes,
    sessions,
    pomodoro,
    openFocus,
    generatePlan,
    toggleTask,
    toggleSession,
  } = useZiito();
  const navigate = useNavigate();

  const now = new Date();
  const todayWeekday = weekdayOf(now) as Weekday;
  const todayClasses = useMemo(
    () => classesForWeekday(classes, todayWeekday),
    [classes, todayWeekday],
  );
  const nowMin = minutesOfDay(now);

  const currentClass = todayClasses.find((c) => nowMin >= c.startMinuteOfDay && nowMin < c.endMinuteOfDay);
  const subjectOf = (id: string | null) => subjects.find((s) => s.id === id);

  const todaySessions = useMemo(
    () => sessions.filter((s) => isSameDay(s.date, now)),
    [sessions],
  );
  const todayTasks = useMemo(
    () => tasks.filter((t) => isSameDay(t.dueDate, now) && !t.isCompleted),
    [tasks],
  );
  const hasPlan = sessions.length > 0;

  const upcomingTasks = useMemo(
    () =>
      tasks
        .filter((t) => !t.isCompleted && daysUntil(t.dueDate) >= 0 && !isSameDay(t.dueDate, now))
        .sort((a, b) => a.dueDate - b.dueDate)
        .slice(0, 3),
    [tasks],
  );
  const upcomingExams = useMemo(
    () =>
      exams
        .filter((e) => daysUntil(e.date) >= 0 && !e.isCompleted)
        .sort((a, b) => a.date - b.date)
        .slice(0, 5),
    [exams],
  );

  const totalItems = todaySessions.length + todayTasks.length;
  const completedItems = todaySessions.filter((s) => s.isCompleted).length;

  // free-slot detection (simplified): gap of >= 25 min from now to next class
  const nextClass = todayClasses.find((c) => c.startMinuteOfDay > nowMin);
  const freeMinutes = nextClass ? nextClass.startMinuteOfDay - nowMin : 22 * 60 - nowMin;
  const isStudyMoment = !currentClass && freeMinutes >= 25 && nowMin >= 8 * 60 && nowMin < 22 * 60;

  return (
    <div className="space-y-5 pb-2">
      <div className="flex items-center justify-between pt-1">
        <h1 className="text-2xl font-extrabold tracking-tight">Hoy</h1>
        <button
          onClick={generatePlan}
          className="flex items-center gap-1.5 rounded-full bg-secondary px-3 py-1.5 text-xs font-semibold text-primary transition active:scale-95"
        >
          <Sparkles className="h-3.5 w-3.5" /> Plan
        </button>
      </div>

      <GamificationBar />

      {/* Header card */}
      <div className="rounded-3xl border border-primary/15 bg-card/70 p-5 backdrop-blur">
        <h2 className="text-xl font-bold">{greeting()}</h2>
        <p className="text-sm text-muted-foreground">{formatLongDate(now)}</p>
        {totalItems > 0 && (
          <div className="mt-3 flex items-center gap-2">
            <span
              className={cn(
                "text-xs font-medium",
                completedItems === totalItems ? "text-primary" : "text-muted-foreground",
              )}
            >
              {completedItems}/{totalItems} completadas
            </span>
            <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-secondary">
              <div
                className={cn("h-full rounded-full transition-all", completedItems === totalItems ? "bg-primary" : "bg-accent")}
                style={{ width: `${totalItems ? (completedItems / totalItems) * 100 : 0}%` }}
              />
            </div>
          </div>
        )}
      </div>

      {/* Study moment banner */}
      {currentClass ? (
        <InClassBanner c={currentClass} subjectName={subjectOf(currentClass.subjectID)?.name} color={subjectOf(currentClass.subjectID)?.colorHex ?? "16A34A"} />
      ) : isStudyMoment ? (
        <button
          onClick={openFocus}
          className="flex w-full items-center gap-3 rounded-3xl bg-gradient-to-r from-primary to-emerald-600 p-4 text-left text-primary-foreground shadow-lg shadow-primary/30 transition active:scale-[0.99]"
        >
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-white/20">
            <Leaf className="h-5 w-5" />
          </span>
          <span className="flex-1">
            <span className="block font-bold">Es momento de estudiar</span>
            <span className="block text-xs opacity-90">
              Tienes {freeMinutes} min libres. Inicia un Pomodoro.
            </span>
          </span>
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-primary">
            <Play className="h-4 w-4 fill-primary" />
          </span>
        </button>
      ) : (
        <button
          onClick={openFocus}
          className="flex w-full items-center gap-3 rounded-2xl border bg-card p-4 text-left transition active:scale-[0.99]"
        >
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-primary">
            <Timer className="h-5 w-5" />
          </span>
          <span className="flex-1">
            <span className="block font-semibold">
              {pomodoro.isRunning ? "Sesión en curso" : "Inicia una sesión de enfoque"}
            </span>
            <span className="block text-xs text-muted-foreground">
              {pomodoro.isRunning
                ? "Toca para volver al modo enfocado."
                : "Pomodoro · Modo inmersivo · Sin distracciones"}
            </span>
          </span>
          <ChevronRight className="h-5 w-5 text-muted-foreground/50" />
        </button>
      )}

      {/* Today timeline */}
      {todayClasses.length > 0 && (
        <section>
          <h3 className="mb-2 font-semibold">Tu día</h3>
          <div className="rounded-2xl border bg-card p-3">
            {todayClasses.map((c, idx) => {
              const subject = subjectOf(c.subjectID);
              const color = subject?.colorHex ?? "16A34A";
              const isPast = nowMin >= c.endMinuteOfDay;
              const isCurrent = nowMin >= c.startMinuteOfDay && nowMin < c.endMinuteOfDay;
              return (
                <div key={c.id} className="flex gap-3">
                  <div className="flex w-4 flex-col items-center">
                    <span
                      className="mt-1.5 flex h-4 w-4 items-center justify-center rounded-full border-2"
                      style={{ borderColor: colorAlpha(color, 0.4) }}
                    >
                      {(isCurrent || isPast) && (
                        <span
                          className="h-2 w-2 rounded-full"
                          style={{ backgroundColor: isCurrent ? colorVar(color) : colorAlpha(color, 0.4) }}
                        />
                      )}
                    </span>
                    {idx < todayClasses.length - 1 && (
                      <span className="w-0.5 flex-1" style={{ backgroundColor: colorAlpha(color, 0.25) }} />
                    )}
                  </div>
                  <div className="flex flex-1 items-start justify-between py-1.5">
                    <div>
                      <p className="text-xs text-muted-foreground">
                        {formatMinutes(c.startMinuteOfDay)} – {formatMinutes(c.endMinuteOfDay)}
                      </p>
                      <p className={cn("text-sm font-semibold", isPast && "text-muted-foreground line-through")}>
                        {subject?.name ?? (c.customName || "Clase")}
                      </p>
                    </div>
                    {isCurrent && (
                      <span
                        className="rounded-full px-2 py-0.5 text-[10px] font-bold"
                        style={{ backgroundColor: colorAlpha(color, 0.15), color: colorVar(color) }}
                      >
                        Ahora
                      </span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      )}

      {/* Plan / sessions / tasks */}
      {!hasPlan ? (
        <EmptyPlan onGenerate={generatePlan} />
      ) : todaySessions.length === 0 && todayTasks.length === 0 ? (
        <FreeDay />
      ) : (
        <>
          {todayTasks.length > 0 && (
            <section>
              <h3 className="mb-2 font-semibold">Tareas de hoy</h3>
              <div className="space-y-2">
                {todayTasks.map((t) => (
                  <CheckRow
                    key={t.id}
                    title={t.title}
                    done={t.isCompleted}
                    color={subjectOf(t.subjectID)?.colorHex}
                    subtitle={subjectOf(t.subjectID)?.name}
                    priority={t.priority}
                    onToggle={() => toggleTask(t.id)}
                  />
                ))}
              </div>
            </section>
          )}
          {todaySessions.length > 0 && (
            <section>
              <h3 className="mb-2 font-semibold">Qué estudiar hoy</h3>
              <div className="space-y-2">
                {todaySessions.map((s) => {
                  const exam = exams.find((e) => e.id === s.examID);
                  const subject = subjectOf(s.subjectID);
                  if (!exam || !subject) return null;
                  return (
                    <CheckRow
                      key={s.id}
                      title={exam.title}
                      done={s.isCompleted}
                      color={subject.colorHex}
                      subtitle={`${subject.name} · ${s.durationMinutes} min`}
                      priority={exam.priority}
                      onToggle={() => toggleSession(s.id)}
                    />
                  );
                })}
              </div>
            </section>
          )}
        </>
      )}

      {/* Upcoming */}
      <section>
        <h3 className="mb-2 font-semibold">Próximas tareas</h3>
        {upcomingTasks.length === 0 ? (
          <p className="py-4 text-center text-sm text-muted-foreground">No hay tareas pendientes</p>
        ) : (
          <div className="space-y-2">
            {upcomingTasks.map((t) => (
              <MiniRow
                key={t.id}
                title={t.title}
                subtitle={subjectOf(t.subjectID)?.name}
                color={subjectOf(t.subjectID)?.colorHex ?? "16A34A"}
                days={daysUntil(t.dueDate)}
              />
            ))}
          </div>
        )}
      </section>

      <section>
        <h3 className="mb-2 font-semibold">Próximas evaluaciones</h3>
        {upcomingExams.length === 0 ? (
          <p className="py-4 text-center text-sm text-muted-foreground">No hay evaluaciones registradas</p>
        ) : (
          <div className="space-y-2">
            {upcomingExams.map((e) => {
              const subject = subjectOf(e.subjectID);
              if (!subject) return null;
              return (
                <MiniRow
                  key={e.id}
                  title={e.title}
                  subtitle={subject.name}
                  color={subject.colorHex}
                  days={daysUntil(e.date)}
                />
              );
            })}
          </div>
        )}
        <button
          onClick={() => navigate("/mas/evaluaciones")}
          className="mt-3 w-full rounded-xl border border-dashed py-2.5 text-sm font-medium text-muted-foreground transition active:scale-[0.99]"
        >
          Gestionar evaluaciones
        </button>
      </section>
    </div>
  );
}

function InClassBanner({ c, subjectName, color }: { c: ClassSession; subjectName?: string; color: string }) {
  return (
    <div
      className="flex items-center gap-3 rounded-2xl p-4"
      style={{ backgroundColor: colorAlpha(color, 0.1) }}
    >
      <span
        className="flex h-11 w-11 items-center justify-center rounded-full text-white"
        style={{ backgroundColor: colorVar(color) }}
      >
        <GraduationCap className="h-5 w-5" />
      </span>
      <div>
        <p className="text-xs font-semibold text-muted-foreground">En clase ahora</p>
        <p className="font-semibold">{subjectName ?? (c.customName || "Clase")}</p>
        <p className="text-xs text-muted-foreground">Hasta las {formatMinutes(c.endMinuteOfDay)}</p>
      </div>
    </div>
  );
}

function CheckRow({
  title,
  subtitle,
  done,
  color,
  priority,
  onToggle,
}: {
  title: string;
  subtitle?: string;
  done: boolean;
  color?: string;
  priority: 1 | 2 | 3 | 4 | 5;
  onToggle: () => void;
}) {
  return (
    <div className="flex items-center gap-3 rounded-2xl border bg-card p-4">
      <button onClick={onToggle} className="transition active:scale-90">
        <span
          className={cn(
            "flex h-6 w-6 items-center justify-center rounded-full border-2",
            done ? "border-primary bg-primary text-primary-foreground" : "bg-transparent",
          )}
          style={!done && color ? { borderColor: colorVar(color) } : undefined}
        >
          {done && <span className="text-xs">✓</span>}
        </span>
      </button>
      <div className="flex-1">
        <p className={cn("text-sm font-semibold", done && "text-muted-foreground line-through")}>{title}</p>
        {subtitle && (
          <span className="mt-0.5 flex items-center gap-1.5 text-xs text-muted-foreground">
            {color && <span className="h-2 w-2 rounded-full" style={{ backgroundColor: colorVar(color) }} />}
            {subtitle}
          </span>
        )}
      </div>
      <PriorityBadge priority={priority} />
    </div>
  );
}

function MiniRow({ title, subtitle, color, days }: { title: string; subtitle?: string; color: string; days: number }) {
  return (
    <div className="flex items-center gap-3 rounded-xl border bg-card p-3.5">
      <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: colorVar(color) }} />
      <div className="flex-1">
        <p className="text-sm font-medium">{title}</p>
        {subtitle && <p className="text-xs text-muted-foreground">{subtitle}</p>}
      </div>
      {days === 0 ? (
        <span className="rounded-full bg-destructive/10 px-2 py-0.5 text-[10px] font-bold text-destructive">Hoy</span>
      ) : (
        <span className="text-xs text-muted-foreground">en {days} d</span>
      )}
    </div>
  );
}

function EmptyPlan({ onGenerate }: { onGenerate: () => void }) {
  return (
    <div className="flex flex-col items-center gap-4 py-10 text-center">
      <CalendarPlus className="h-14 w-14 text-primary/60" />
      <div>
        <p className="text-lg font-semibold">Genera tu plan de estudio</p>
        <p className="mx-auto mt-1 max-w-xs text-sm text-muted-foreground">
          La app creará un calendario inteligente basado en tus evaluaciones y prioridades.
        </p>
      </div>
      <button
        onClick={onGenerate}
        className="flex items-center gap-2 rounded-xl bg-primary px-6 py-3 font-semibold text-primary-foreground transition active:scale-95"
      >
        <Sparkles className="h-4 w-4" /> Crear plan inteligente
      </button>
    </div>
  );
}

function FreeDay() {
  return (
    <div className="flex flex-col items-center gap-3 py-10 text-center">
      <Sun className="h-12 w-12 text-accent/70" />
      <p className="text-lg font-semibold">Día libre de estudio</p>
      <p className="mx-auto max-w-xs text-sm text-muted-foreground">
        No tienes sesiones ni tareas para hoy. ¡Descansa o adelanta otra materia!
      </p>
    </div>
  );
}
