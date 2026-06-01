import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  BarChart3,
  BookMarked,
  Calendar,
  ChevronRight,
  ClipboardList,
  ListChecks,
  Timer,
} from "lucide-react";

import { PomodoroSettingsDialog } from "@/components/app/PomodoroSettingsDialog";

const planning = [
  { to: "/mas/tareas", label: "Tareas", icon: ListChecks },
  { to: "/mas/evaluaciones", label: "Evaluaciones", icon: ClipboardList },
  { to: "/mas/calendario", label: "Calendario", icon: Calendar },
  { to: "/mas/materias", label: "Materias", icon: BookMarked },
];

export default function More() {
  const navigate = useNavigate();
  const [showSettings, setShowSettings] = useState(false);

  return (
    <div className="space-y-6 pb-2">
      <h1 className="pt-1 text-2xl font-extrabold tracking-tight">Más</h1>

      <Section title="Planificación">
        {planning.map((item) => (
          <Row key={item.to} icon={item.icon} label={item.label} onClick={() => navigate(item.to)} />
        ))}
      </Section>

      <Section title="Estudio">
        <Row icon={BarChart3} label="Estadísticas" onClick={() => navigate("/mas/estadisticas")} />
      </Section>

      <Section title="Enfoque">
        <Row icon={Timer} label="Configurar Pomodoro" onClick={() => setShowSettings(true)} />
      </Section>

      <p className="px-1 text-xs leading-relaxed text-muted-foreground">
        Ziito funciona offline. Usa la pestaña Montaña para visualizar tu ascenso, y el resto de
        secciones para planificar tu estudio. Con cada paso avanzas.
      </p>

      <PomodoroSettingsDialog open={showSettings} onOpenChange={setShowSettings} />
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="mb-2 px-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</h2>
      <div className="divide-y divide-border overflow-hidden rounded-2xl border bg-card">{children}</div>
    </section>
  );
}

function Row({
  icon: Icon,
  label,
  onClick,
}: {
  icon: typeof Timer;
  label: string;
  onClick: () => void;
}) {
  return (
    <button onClick={onClick} className="flex w-full items-center gap-3 px-4 py-3.5 text-left transition active:bg-secondary/50">
      <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
        <Icon className="h-5 w-5" />
      </span>
      <span className="flex-1 font-medium">{label}</span>
      <ChevronRight className="h-5 w-5 text-muted-foreground/50" />
    </button>
  );
}
