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
  greeting,
  isSameDay,
  minutesOfDay,
  weekdayOf,
} from "@/lib/ziito-date";
import { colorAlpha, colorVar } from "@/lib/ziito-color";
import { buildSubtopicQueue } from "@/lib/subtopic-scheduler";
import { DENSITY_META, type ClassSession, type Exam, type StudySession, type SubTopic, type Weekday } from "@/lib/ziito-types";
import { cn } from "@/lib/utils";

export default function Today() {
  const {
    subjects,
    exams,
    tasks,
    classes,
    sessions,
    pomodoro,
    settings,
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

  const nextClass = todayClasses.find((c) => c.startMinuteOfDay > nowMin);
  const freeMinutes = nextClass ? nextClass.startMinuteOfDay - nowMin : 22 * 60 - nowMin;
  const isStudyMoment = !currentClass && freeMinutes >= 25 && nowMin >= 8 * 60 && nowMin < 22 * 60;

  // For subtopic breakdown: all sessions per exam, sorted by date
  const sessionsByExam = useMemo(() => {
    const map = new Map<string, StudySession[]>();
    for (const s of sessions) {
      const arr = map.get(s.examID) ?? [];
      arr.push(s);
      map.set(s.examID, arr);
    }
    // Sort each group by date + orderIndex
    for (const [key, arr] of map) {
      map.set(key, arr.sort((a, b) => a.date - b.date || a.orderIndex - b.orderIndex));
    }
    return map;
  }, [sessions]);

  return (
    <div className="space-y-4 pb-2">
      <div className="flex items-center justify-between pt-1">
        <h1 className="text-2xl font-bold tracking-tight">Hoy</h1>
        <button
          onClick={generatePlan}
          className="flex items-center gap-1.5 rounded-lg bg-secondary px-3 py-1.5 text-xs font-semibold text-primary transition active:scale-95"
        >
          <Sparkles className="h-3.5 w-3.5" /> Plan
        </button>
      </div>

      <GamificationBar />

      {/* Header card */}
      <div className="rounded-xl border border-border bg-card p-4">
        <h2 className="font-semibold">{greeting()}</h2>
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
            <div className="h-1 flex-1 overflow-hidden rounded-full bg-secondary">
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
          className="flex w-full items-center gap-3 rounded-xl bg-primary p-4 text-left text-primary-foreground transition active:scale-[0.99]"
        >
          <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-white/20">
            <Leaf className="h-5 w-5" />
          </span>
          <span className="flex-1">
            <span className="block font-semibold">Es momento de estudiar</span>
            <span className="block text-xs opacity-80">
              Tienes {freeMinutes} min libres. Inicia un Pomodoro.
            </span>
          </span>
          <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-white text-primary">
            <Play className="h-4 w-4 fill-primary" />
          </span>
        </button>
      ) : (
        <button
          onClick={openFocus}
          className="flex w-full items-center gap-3 rounded-xl border bg-card p-4 text-left transition active:scale-[0.99]"
        >
          <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
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
          <ChevronRight className="h-5 w-5 text-muted-foreground/40" />
        </button>
      )}

      {/* Today timeline */}
      {todayClasses.length > 0 && (
        <section>
          <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Tu día</h3>
          <div className="divide-y divide-border rounded-xl border bg-card">
            {todayClasses.map((c) => {
              const subject = subjectOf(c.subjectID);
              const color = subject?.colorHex ?? "16A34A";
              const isPast = nowMin >= c.endMinuteOfDay;
              const isCurrent = nowMin >= c.startMinuteOfDay && nowMin < c.endMinuteOfDay;
              return (
                <div key={c.id} className="flex items-center gap-3 px-4 py-3">
                  <span
                    className="h-2 w-2 shrink-0 rounded-full"
                    style={{ backgroundColor: isCurrent ? colorVar(color) : colorAlpha(color, isPast ? 0.3 : 0.6) }}
                  />
                  <div className="flex-1">
                    <p className={cn("text-sm font-medium", isPast && "text-muted-foreground line-through")}>
                      {subject?.name ?? (c.customName || "Clase")}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {formatMinutes(c.startMinuteOfDay)} – {formatMinutes(c.endMinuteOfDay)}
                    </p>
                  </div>
                  {isCurrent && (
                    <span
                      className="rounded-md px-2 py-0.5 text-[10px] font-semibold"
                      style={{ backgroundColor: colorAlpha(color, 0.12), color: colorVar(color) }}
                    >
                      Ahora
                    </span>
                  )}
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
              <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Tareas de hoy</h3>
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
              <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Qué estudiar hoy</h3>
              <div className="space-y-3">
                {todaySessions.map((s) => {
                  const exam = exams.find((e) => e.id === s.examID);
                  const subject = subjectOf(s.subjectID);
                  if (!exam || !subject) return null;
                  const allExamSessions = sessionsByExam.get(s.examID) ?? [];
                  return (
                    <StudySessionCard
                      key={s.id}
                      session={s}
                      exam={exam}
                      subjectName={subject.name}
                      subjectColor={subject.colorHex}
                      allExamSessions={allExamSessions}
                      focusMinutes={settings.focusMinutes}
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
        <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Próximas tareas</h3>
        {upcomingTasks.length === 0 ? (
          <p className="py-4 text-center text-sm text-muted-foreground">No hay tareas pendientes</p>
        ) : (
          <div className="space-y-1.5">
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
        <h3 className="mb-2 text-sm font-semibold text-muted-foreground">Próximas evaluaciones</h3>
        {upcomingExams.length === 0 ? (
          <p className="py-4 text-center text-sm text-muted-foreground">No hay evaluaciones registradas</p>
        ) : (
          <div className="space-y-1.5">
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
          className="mt-3 w-full rounded-lg border border-dashed py-2.5 text-sm font-medium text-muted-foreground transition active:scale-[0.99]"
        >
          Gestionar evaluaciones
        </button>
      </section>
    </div>
  );
}

// ─── Study Session Card with subtopic breakdown ────────────────────────────

function StudySessionCard({
  session,
  exam,
  subjectName,
  subjectColor,
  allExamSessions,
  focusMinutes,
  onToggle,
}: {
  session: StudySession;
  exam: Exam;
  subjectName: string;
  subjectColor: string;
  allExamSessions: StudySession[];
  focusMinutes: number;
  onToggle: () => void;
}) {
  const hasSubtopics = (exam.subTopics ?? []).length > 0;

  // Compute which subtopics belong to this session
  const subtopicAssignment = useMemo(() => {
    if (!hasSubtopics) return { sessionTopics: new Set<string>(), allTopics: exam.subTopics ?? [] };

    const queue = buildSubtopicQueue(exam.subTopics);
    const blocksPerSession = Math.max(1, Math.ceil(session.durationMinutes / focusMinutes));
    const sessionIndex = allExamSessions.findIndex((s) => s.id === session.id);
    const start = Math.max(0, sessionIndex) * blocksPerSession;
    const end = start + blocksPerSession;

    // Build a frequency map of subtopic IDs in this session's slice
    const sessionTopics = new Set<string>(
      queue.slice(start, end).map((st) => st.id),
    );

    return { sessionTopics, allTopics: exam.subTopics ?? [] };
  }, [exam, session, allExamSessions, focusMinutes, hasSubtopics]);

  return (
    <div className="rounded-xl border bg-card overflow-hidden">
      {/* Main row */}
      <div className="flex items-center gap-3 p-3.5">
        <button onClick={onToggle} className="transition active:scale-90">
          <span
            className={cn(
              "flex h-5 w-5 items-center justify-center rounded-md border-2",
              session.isCompleted ? "border-primary bg-primary text-primary-foreground" : "bg-transparent",
            )}
            style={!session.isCompleted ? { borderColor: colorVar(subjectColor) } : undefined}
          >
            {session.isCompleted && <span className="text-[10px]">✓</span>}
          </span>
        </button>
        <div className="flex-1">
          <p className={cn("text-sm font-medium", session.isCompleted && "text-muted-foreground line-through")}>
            {exam.title}
          </p>
          <span className="mt-0.5 flex items-center gap-1.5 text-xs text-muted-foreground">
            <span className="h-2 w-2 rounded-full" style={{ backgroundColor: colorVar(subjectColor) }} />
            {subjectName} · {session.durationMinutes} min
          </span>
        </div>
        <PriorityBadge priority={exam.priority} />
      </div>

      {/* Subtopic breakdown */}
      {hasSubtopics && (
        <div className="border-t border-border bg-muted/30 px-3.5 py-3">
          <p className="mb-2 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
            Contenidos de la evaluación
          </p>
          <div className="flex flex-col gap-1.5">
            {subtopicAssignment.allTopics.map((st) => {
              const isActive = subtopicAssignment.sessionTopics.has(st.id);
              const density = DENSITY_META[st.density];
              return (
                <div
                  key={st.id}
                  className={cn(
                    "flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm transition",
                    isActive
                      ? "bg-card border border-border"
                      : "opacity-40",
                  )}
                >
                  <span
                    className="h-1.5 w-1.5 shrink-0 rounded-full"
                    style={{ backgroundColor: colorVar(density.colorHex) }}
                  />
                  <span className={cn("flex-1 text-xs", isActive ? "font-medium text-foreground" : "text-muted-foreground")}>
                    {st.title}
                  </span>
                  {isActive && (
                    <span
                      className="shrink-0 rounded-md px-1.5 py-0.5 text-[10px] font-semibold"
                      style={{
                        backgroundColor: colorAlpha(density.colorHex, 0.12),
                        color: colorVar(density.colorHex),
                      }}
                    >
                      {density.short}
                    </span>
                  )}
                </div>
              );
            })}
          </div>
          {subtopicAssignment.sessionTopics.size > 0 && (
            <p className="mt-2 text-[10px] text-muted-foreground">
              Esta sesión cubre {subtopicAssignment.sessionTopics.size} de {subtopicAssignment.allTopics.length} contenidos.
            </p>
          )}
        </div>
      )}
    </div>
  );
}

// ─── Sub-components ────────────────────────────────────────────────────────

function InClassBanner({ c, subjectName, color }: { c: ClassSession; subjectName?: string; color: string }) {
  return (
    <div
      className="flex items-center gap-3 rounded-xl p-4"
      style={{ backgroundColor: colorAlpha(color, 0.08) }}
    >
      <span
        className="flex h-10 w-10 items-center justify-center rounded-lg text-white"
        style={{ backgroundColor: colorVar(color) }}
      >
        <GraduationCap className="h-5 w-5" />
      </span>
      <div>
        <p className="text-xs font-medium text-muted-foreground">En clase ahora</p>
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
    <div className="flex items-center gap-3 rounded-xl border bg-card p-3.5">
      <button onClick={onToggle} className="transition active:scale-90">
        <span
          className={cn(
            "flex h-5 w-5 items-center justify-center rounded-md border-2",
            done ? "border-primary bg-primary text-primary-foreground" : "bg-transparent",
          )}
          style={!done && color ? { borderColor: colorVar(color) } : undefined}
        >
          {done && <span className="text-[10px]">✓</span>}
        </span>
      </button>
      <div className="flex-1">
        <p className={cn("text-sm font-medium", done && "text-muted-foreground line-through")}>{title}</p>
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
    <div className="flex items-center gap-3 rounded-lg border bg-card p-3">
      <span className="h-2 w-2 shrink-0 rounded-full" style={{ backgroundColor: colorVar(color) }} />
      <div className="flex-1">
        <p className="text-sm font-medium">{title}</p>
        {subtitle && <p className="text-xs text-muted-foreground">{subtitle}</p>}
      </div>
      {days === 0 ? (
        <span className="rounded-md bg-destructive/10 px-2 py-0.5 text-[10px] font-semibold text-destructive">Hoy</span>
      ) : (
        <span className="text-xs text-muted-foreground">en {days}d</span>
      )}
    </div>
  );
}

function EmptyPlan({ onGenerate }: { onGenerate: () => void }) {
  return (
    <div className="flex flex-col items-center gap-4 py-10 text-center">
      <CalendarPlus className="h-12 w-12 text-primary/50" />
      <div>
        <p className="font-semibold">Genera tu plan de estudio</p>
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
      <Sun className="h-10 w-10 text-accent/70" />
      <p className="font-semibold">Día libre de estudio</p>
      <p className="mx-auto max-w-xs text-sm text-muted-foreground">
        No tienes sesiones ni tareas para hoy. ¡Descansa o adelanta otra materia!
      </p>
    </div>
  );
}
