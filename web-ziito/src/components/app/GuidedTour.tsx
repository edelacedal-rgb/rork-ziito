import { useMemo } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  ArrowRight,
  BookMarked,
  CalendarDays,
  Check,
  ClipboardList,
  Mountain,
  Sparkles,
  X,
} from "lucide-react";

import { useZiito } from "@/store/ZiitoStore";
import { cn } from "@/lib/utils";

interface TourStep {
  icon: typeof BookMarked;
  title: string;
  body: string;
  /** Route the user should be on to complete this step. */
  route?: string;
  routeLabel?: string;
  /** Number of items already created for this step. */
  count: number;
  /** Whether the requirement is satisfied. */
  done: boolean;
  /** Hint shown once they are on the right screen. */
  actionHint: string;
}

export function GuidedTour() {
  const {
    subjects,
    classes,
    exams,
    tour,
    closeTour,
    setTourStep,
    finishTour,
    generatePlan,
  } = useZiito();
  const navigate = useNavigate();
  const location = useLocation();

  const steps = useMemo<TourStep[]>(
    () => [
      {
        icon: Sparkles,
        title: "Crea tu plan inteligente",
        body: "En 4 pasos tendrás un calendario de estudio armado solo. Empecemos por tus materias.",
        count: 0,
        done: true,
        actionHint: "",
      },
      {
        icon: BookMarked,
        title: "1 · Agrega tus materias",
        body: "Registra cada asignatura y dale un color. Serán la base de todo tu plan.",
        route: "/mas/materias",
        routeLabel: "Ir a Materias",
        count: subjects.length,
        done: subjects.length > 0,
        actionHint: "Toca el botón + arriba para crear una materia.",
      },
      {
        icon: CalendarDays,
        title: "2 · Arma tu horario",
        body: "Coloca tus clases en la semana usando las materias que creaste. Así Ziito sabe cuándo tienes tiempo libre.",
        route: "/horario",
        routeLabel: "Ir a Horario",
        count: classes.length,
        done: classes.length > 0,
        actionHint: "Toca + y elige la materia, el día y la hora de la clase.",
      },
      {
        icon: ClipboardList,
        title: "3 · Registra tus evaluaciones",
        body: "Añade tus pruebas con fecha y prioridad por materia. Esto alimenta el plan inteligente.",
        route: "/mas/evaluaciones",
        routeLabel: "Ir a Evaluaciones",
        count: exams.length,
        done: exams.length > 0,
        actionHint: "Toca + y completa título, fecha, materia y prioridad.",
      },
      {
        icon: Mountain,
        title: "4 · Genera tu plan",
        body: "Listo. Ziito repartirá sesiones de estudio hasta cada evaluación según su prioridad y fecha.",
        count: 0,
        done: true,
        actionHint: "",
      },
    ],
    [subjects.length, classes.length, exams.length],
  );

  if (!tour.active) return null;

  const stepIndex = Math.min(tour.step, steps.length - 1);
  const step = steps[stepIndex];
  const isFirst = stepIndex === 0;
  const isLast = stepIndex === steps.length - 1;
  const onRoute = step.route ? location.pathname === step.route : true;

  const goNext = () => {
    if (isLast) {
      generatePlan();
      finishTour();
      navigate("/");
      return;
    }
    setTourStep(stepIndex + 1);
  };

  const Icon = step.icon;

  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-[calc(env(safe-area-inset-bottom)+72px)] z-40 flex justify-center px-4">
      <div className="pointer-events-auto w-full max-w-lg overflow-hidden rounded-3xl border border-primary/20 bg-card/95 shadow-2xl shadow-primary/20 backdrop-blur-xl animate-in slide-in-from-bottom-4 fade-in duration-300">
        {/* progress */}
        <div className="flex items-center gap-1.5 px-5 pt-4">
          {steps.map((s, i) => (
            <span
              key={i}
              className={cn(
                "h-1.5 flex-1 rounded-full transition-all",
                i < stepIndex
                  ? "bg-primary"
                  : i === stepIndex
                    ? "bg-accent"
                    : "bg-secondary",
              )}
            />
          ))}
          <button
            onClick={closeTour}
            aria-label="Cerrar guía"
            className="ml-2 flex h-6 w-6 items-center justify-center rounded-full text-muted-foreground transition active:scale-90 hover:bg-secondary"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="flex gap-3 px-5 pb-4 pt-3">
          <span className="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-primary/10 text-primary">
            <Icon className="h-5 w-5" />
          </span>
          <div className="min-w-0 flex-1">
            <p className="font-bold leading-tight">{step.title}</p>
            <p className="mt-1 text-sm leading-snug text-muted-foreground">{step.body}</p>

            {/* status / hint */}
            {!isFirst && !isLast && (
              <div className="mt-2.5 flex items-center gap-2 text-xs font-medium">
                {step.done ? (
                  <span className="inline-flex items-center gap-1 rounded-full bg-primary/10 px-2.5 py-1 text-primary">
                    <Check className="h-3.5 w-3.5" />
                    {step.count} agregada{step.count === 1 ? "" : "s"}
                  </span>
                ) : onRoute ? (
                  <span className="text-muted-foreground">{step.actionHint}</span>
                ) : (
                  <span className="text-muted-foreground">Aún no has agregado ninguna.</span>
                )}
              </div>
            )}

            {/* actions */}
            <div className="mt-3.5 flex items-center gap-2">
              {isFirst ? (
                <button
                  onClick={goNext}
                  className="flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground transition active:scale-95"
                >
                  Empezar <ArrowRight className="h-4 w-4" />
                </button>
              ) : isLast ? (
                <button
                  onClick={goNext}
                  className="flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground transition active:scale-95"
                >
                  <Sparkles className="h-4 w-4" /> Crear plan inteligente
                </button>
              ) : step.done ? (
                <button
                  onClick={goNext}
                  className="flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground transition active:scale-95"
                >
                  Continuar <ArrowRight className="h-4 w-4" />
                </button>
              ) : (
                <>
                  <button
                    onClick={() => step.route && navigate(step.route)}
                    disabled={onRoute}
                    className={cn(
                      "flex items-center gap-1.5 rounded-xl px-4 py-2.5 text-sm font-semibold transition active:scale-95",
                      onRoute
                        ? "bg-secondary text-muted-foreground"
                        : "bg-primary text-primary-foreground",
                    )}
                  >
                    {onRoute ? "Estás aquí" : step.routeLabel}
                  </button>
                  <button
                    onClick={goNext}
                    className="rounded-xl px-3 py-2.5 text-sm font-medium text-muted-foreground transition active:scale-95"
                  >
                    Omitir
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
