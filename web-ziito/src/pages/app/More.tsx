import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  BarChart3,
  BookMarked,
  Calendar,
  ChevronRight,
  ClipboardList,
  ListChecks,
  Sparkles,
  Timer,
} from "lucide-react";

import { PomodoroSettingsDialog } from "@/components/app/PomodoroSettingsDialog";
import { useZiito } from "@/store/ZiitoStore";

const planning = [
  { to: "/mas/tareas", label: "Tareas", icon: ListChecks },
  { to: "/mas/evaluaciones", label: "Evaluaciones", icon: ClipboardList },
  { to: "/mas/calendario", label: "Calendario", icon: Calendar },
  { to: "/mas/materias", label: "Materias", icon: BookMarked },
];

export default function More() {
  const navigate = useNavigate();
  const { startTour } = useZiito();
  const [showSettings, setShowSettings] = useState(false);

  return (
    <div className="space-y-5 pb-2">
      <h1 className="pt-1 text-2xl font-bold tracking-tight">Más</h1>

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

      <Section title="Primeros pasos">
        <Row
          icon={Sparkles}
          label="Guía del plan inteligente"
          onClick={() => {
            startTour();
            navigate("/");
          }}
        />
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
      <h2 className="mb-1.5 px-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</h2>
      <div className="divide-y divide-border overflow-hidden rounded-xl border bg-card">{children}</div>
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
    <button onClick={onClick} className="flex w-full items-center gap-3 px-4 py-3 text-left transition active:bg-secondary/50">
      <Icon className="h-5 w-5 text-muted-foreground" />
      <span className="flex-1 text-sm font-medium">{label}</span>
      <ChevronRight className="h-4 w-4 text-muted-foreground/40" />
    </button>
  );
}
