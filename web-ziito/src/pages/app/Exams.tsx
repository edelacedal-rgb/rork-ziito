import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Check, ClipboardList, RotateCcw, Trash2 } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PriorityBadge } from "@/components/app/PriorityBadge";
import { Header, Empty } from "@/pages/app/Subjects";
import { useZiito } from "@/store/ZiitoStore";
import {
  PRIORITY_LEVELS,
  PRIORITY_META,
  type Exam,
  type PriorityLevel,
} from "@/lib/ziito-types";
import { daysUntil, formatShortDate } from "@/lib/ziito-date";
import { colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

export default function Exams() {
  const { exams, subjects, addExam, deleteExam, toggleExam } = useZiito();
  const navigate = useNavigate();
  const [adding, setAdding] = useState(false);

  const upcoming = exams.filter((e) => daysUntil(e.date) >= 0 && !e.isCompleted).sort((a, b) => a.date - b.date);
  const past = exams.filter((e) => daysUntil(e.date) < 0 || e.isCompleted).sort((a, b) => b.date - a.date);

  return (
    <div className="space-y-5 pb-2">
      <Header title="Evaluaciones" onAdd={() => setAdding(true)} onBack={() => navigate("/mas")} />

      {exams.length === 0 ? (
        <Empty
          icon={ClipboardList}
          title="Sin evaluaciones"
          desc="Registra tus pruebas para generar un plan de estudio inteligente"
        />
      ) : (
        <>
          {upcoming.length > 0 && (
            <Group title="Próximas">
              {upcoming.map((e) => (
                <ExamRow key={e.id} exam={e} subjects={subjects} onToggle={toggleExam} onDelete={deleteExam} />
              ))}
            </Group>
          )}
          {past.length > 0 && (
            <Group title="Pasadas">
              {past.map((e) => (
                <div key={e.id} className="opacity-60">
                  <ExamRow exam={e} subjects={subjects} onToggle={toggleExam} onDelete={deleteExam} />
                </div>
              ))}
            </Group>
          )}
        </>
      )}

      {adding && <ExamDialog onClose={() => setAdding(false)} onSave={addExam} subjects={subjects} />}
    </div>
  );
}

function Group({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="mb-2 px-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</h2>
      <div className="space-y-2">{children}</div>
    </section>
  );
}

function ExamRow({
  exam,
  subjects,
  onToggle,
  onDelete,
}: {
  exam: Exam;
  subjects: { id: string; name: string; colorHex: string }[];
  onToggle: (id: string) => void;
  onDelete: (id: string) => void;
}) {
  const subject = subjects.find((s) => s.id === exam.subjectID);
  const d = daysUntil(exam.date);
  return (
    <div className="flex items-center gap-3 rounded-2xl border bg-card p-4">
      <button onClick={() => onToggle(exam.id)} className="transition active:scale-90">
        <span
          className={cn(
            "flex h-6 w-6 items-center justify-center rounded-full border-2",
            exam.isCompleted ? "border-primary bg-primary text-primary-foreground" : "border-muted-foreground/40",
          )}
        >
          {exam.isCompleted && <Check className="h-3.5 w-3.5" />}
        </span>
      </button>
      <div className="flex-1">
        <p className="text-sm font-semibold">{exam.title}</p>
        <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
          {subject && <span className="h-2 w-2 rounded-full" style={{ backgroundColor: colorVar(subject.colorHex) }} />}
          {subject?.name} · {formatShortDate(new Date(exam.date))}
        </p>
      </div>
      <div className="flex flex-col items-end gap-1">
        <PriorityBadge priority={exam.priority} />
        {d >= 0 && (
          <span className={cn("text-[11px]", d <= 3 ? "font-semibold text-destructive" : "text-muted-foreground")}>
            {d === 0 ? "Hoy" : `en ${d} d`}
          </span>
        )}
      </div>
      <button onClick={() => onDelete(exam.id)} className="text-muted-foreground/50 transition active:scale-90 hover:text-destructive">
        <Trash2 className="h-4 w-4" />
      </button>
    </div>
  );
}

function ExamDialog({
  onClose,
  onSave,
  subjects,
}: {
  onClose: () => void;
  onSave: (input: { title: string; date: number; priority: PriorityLevel; subjectID: string }) => void;
  subjects: { id: string; name: string; colorHex: string }[];
}) {
  const [title, setTitle] = useState("");
  const defaultDate = new Date();
  defaultDate.setDate(defaultDate.getDate() + 7);
  const [date, setDate] = useState(defaultDate.toISOString().slice(0, 10));
  const [subjectID, setSubjectID] = useState<string | null>(null);
  const [priority, setPriority] = useState<PriorityLevel>(3);

  const canSave = title.trim().length > 0 && subjectID != null;

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="rounded-3xl">
        <DialogHeader>
          <DialogTitle>Nueva Evaluación</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <Input placeholder="Título de la evaluación" value={title} onChange={(e) => setTitle(e.target.value)} />
          <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          <SubjectPicker subjects={subjects} value={subjectID} onChange={setSubjectID} />
          <PriorityPicker value={priority} onChange={setPriority} />
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={onClose}>
            Cancelar
          </Button>
          <Button
            disabled={!canSave}
            onClick={() => {
              onSave({
                title: title.trim(),
                date: new Date(`${date}T12:00:00`).getTime(),
                priority,
                subjectID: subjectID!,
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

export function SubjectPicker({
  subjects,
  value,
  onChange,
  allowNone,
}: {
  subjects: { id: string; name: string; colorHex: string }[];
  value: string | null;
  onChange: (id: string | null) => void;
  allowNone?: boolean;
}) {
  if (subjects.length === 0) {
    return <p className="text-sm text-muted-foreground">Primero crea una materia en Materias.</p>;
  }
  return (
    <div>
      <label className="mb-1.5 block text-xs font-medium text-muted-foreground">Materia</label>
      <div className="flex flex-wrap gap-2">
        {allowNone && (
          <button
            onClick={() => onChange(null)}
            className={cn(
              "rounded-full border px-3 py-1.5 text-xs font-medium transition",
              value == null ? "border-primary bg-primary/10 text-primary" : "bg-card",
            )}
          >
            Ninguna
          </button>
        )}
        {subjects.map((s) => (
          <button
            key={s.id}
            onClick={() => onChange(s.id)}
            className={cn(
              "flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium transition",
              value === s.id ? "border-primary bg-primary/10 text-primary" : "bg-card",
            )}
          >
            <span className="h-2 w-2 rounded-full" style={{ backgroundColor: colorVar(s.colorHex) }} />
            {s.name}
          </button>
        ))}
      </div>
    </div>
  );
}

export function PriorityPicker({
  value,
  onChange,
}: {
  value: PriorityLevel;
  onChange: (p: PriorityLevel) => void;
}) {
  return (
    <div>
      <label className="mb-1.5 block text-xs font-medium text-muted-foreground">
        Prioridad: {PRIORITY_META[value].label}
      </label>
      <div className="grid grid-cols-5 gap-1.5">
        {PRIORITY_LEVELS.map((p) => (
          <button
            key={p}
            onClick={() => onChange(p)}
            className={cn(
              "rounded-lg py-2 text-[11px] font-bold transition",
              value === p ? "text-white" : "bg-secondary text-muted-foreground",
            )}
            style={value === p ? { backgroundColor: colorVar(PRIORITY_META[p].colorHex) } : undefined}
          >
            {PRIORITY_META[p].shortLabel}
          </button>
        ))}
      </div>
    </div>
  );
}

// re-export for consistency
export { RotateCcw };
