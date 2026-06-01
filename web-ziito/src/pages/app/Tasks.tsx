import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { AlertTriangle, Check, ListChecks, Trash2 } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { PriorityBadge } from "@/components/app/PriorityBadge";
import { Header, Empty } from "@/pages/app/Subjects";
import { PriorityPicker, SubjectPicker } from "@/pages/app/Exams";
import { useZiito } from "@/store/ZiitoStore";
import type { PriorityLevel, StudyTask } from "@/lib/ziito-types";
import { daysUntil, formatShortDate } from "@/lib/ziito-date";
import { colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

type Filter = "all" | "pending" | "completed" | "overdue";
const FILTERS: { id: Filter; label: string }[] = [
  { id: "all", label: "Todas" },
  { id: "pending", label: "Pendientes" },
  { id: "completed", label: "Completadas" },
  { id: "overdue", label: "Vencidas" },
];

function isOverdue(t: StudyTask): boolean {
  return daysUntil(t.dueDate) < 0 && !t.isCompleted;
}

export default function Tasks() {
  const { tasks, subjects, addTask, toggleTask, deleteTask } = useZiito();
  const navigate = useNavigate();
  const [adding, setAdding] = useState(false);
  const [filter, setFilter] = useState<Filter>("all");

  const sorted = [...tasks].sort((a, b) => a.dueDate - b.dueDate);
  const filtered = sorted.filter((t) => {
    if (filter === "pending") return !t.isCompleted && !isOverdue(t);
    if (filter === "completed") return t.isCompleted;
    if (filter === "overdue") return isOverdue(t);
    return true;
  });
  const overdueCount = tasks.filter(isOverdue).length;

  return (
    <div className="space-y-4 pb-2">
      <Header title="Tareas" onAdd={() => setAdding(true)} onBack={() => navigate("/mas")} />

      {tasks.length === 0 ? (
        <Empty icon={ListChecks} title="Sin tareas" desc="Agrega tareas para organizar tu estudio" />
      ) : (
        <>
          <div className="grid grid-cols-4 gap-1.5 rounded-xl bg-secondary p-1">
            {FILTERS.map((f) => (
              <button
                key={f.id}
                onClick={() => setFilter(f.id)}
                className={cn(
                  "rounded-lg py-1.5 text-xs font-semibold transition",
                  filter === f.id ? "bg-card shadow-sm" : "text-muted-foreground",
                )}
              >
                {f.label}
              </button>
            ))}
          </div>

          {overdueCount > 0 && filter !== "completed" && (
            <div className="flex items-center gap-2 rounded-xl bg-accent/10 px-3 py-2.5 text-sm font-medium text-accent-foreground">
              <AlertTriangle className="h-4 w-4 text-accent" />
              {overdueCount} tarea(s) vencida(s)
            </div>
          )}

          <div className="space-y-2">
            {filtered.map((t) => {
              const subject = subjects.find((s) => s.id === t.subjectID);
              const overdue = isOverdue(t);
              const d = daysUntil(t.dueDate);
              return (
                <div key={t.id} className="flex items-center gap-3 rounded-2xl border bg-card p-4">
                  <button onClick={() => toggleTask(t.id)} className="transition active:scale-90">
                    <span
                      className={cn(
                        "flex h-6 w-6 items-center justify-center rounded-full border-2",
                        t.isCompleted ? "border-primary bg-primary text-primary-foreground" : "border-muted-foreground/40",
                      )}
                      style={!t.isCompleted && subject ? { borderColor: colorVar(subject.colorHex) } : undefined}
                    >
                      {t.isCompleted && <Check className="h-3.5 w-3.5" />}
                    </span>
                  </button>
                  <div className="flex-1">
                    <p className={cn("text-sm font-semibold", t.isCompleted && "text-muted-foreground line-through")}>
                      {t.title}
                    </p>
                    <p className="flex items-center gap-1.5 text-xs">
                      {subject && (
                        <>
                          <span className="h-2 w-2 rounded-full" style={{ backgroundColor: colorVar(subject.colorHex) }} />
                          <span className="text-muted-foreground">{subject.name}</span>
                        </>
                      )}
                      <span className={cn(overdue ? "font-semibold text-accent" : d <= 1 ? "text-destructive" : "text-muted-foreground")}>
                        {formatShortDate(new Date(t.dueDate))}
                      </span>
                    </p>
                  </div>
                  <PriorityBadge priority={t.priority} />
                  <button onClick={() => deleteTask(t.id)} className="text-muted-foreground/50 transition active:scale-90 hover:text-destructive">
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              );
            })}
          </div>
        </>
      )}

      {adding && <TaskDialog onClose={() => setAdding(false)} onSave={addTask} subjects={subjects} />}
    </div>
  );
}

function TaskDialog({
  onClose,
  onSave,
  subjects,
}: {
  onClose: () => void;
  onSave: (input: {
    title: string;
    notes: string;
    dueDate: number;
    priority: PriorityLevel;
    subjectID: string | null;
  }) => void;
  subjects: { id: string; name: string; colorHex: string }[];
}) {
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  const defaultDate = new Date();
  defaultDate.setDate(defaultDate.getDate() + 3);
  const [date, setDate] = useState(defaultDate.toISOString().slice(0, 10));
  const [subjectID, setSubjectID] = useState<string | null>(null);
  const [priority, setPriority] = useState<PriorityLevel>(3);

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="max-h-[88vh] overflow-y-auto rounded-3xl">
        <DialogHeader>
          <DialogTitle>Nueva Tarea</DialogTitle>
        </DialogHeader>
        <div className="space-y-4">
          <Input placeholder="Título de la tarea" value={title} onChange={(e) => setTitle(e.target.value)} />
          <Textarea placeholder="Notas (opcional)" value={notes} onChange={(e) => setNotes(e.target.value)} rows={3} />
          <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          <SubjectPicker subjects={subjects} value={subjectID} onChange={setSubjectID} allowNone />
          <PriorityPicker value={priority} onChange={setPriority} />
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={onClose}>
            Cancelar
          </Button>
          <Button
            disabled={!title.trim()}
            onClick={() => {
              onSave({
                title: title.trim(),
                notes,
                dueDate: new Date(`${date}T12:00:00`).getTime(),
                priority,
                subjectID,
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
