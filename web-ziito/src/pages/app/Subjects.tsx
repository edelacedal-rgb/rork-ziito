import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { BookMarked, ChevronLeft, Plus, Trash2 } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useZiito } from "@/store/ZiitoStore";
import { PRESET_COLORS, colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

export default function Subjects() {
  const { subjects, addSubject, deleteSubject } = useZiito();
  const navigate = useNavigate();
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState("");
  const [hex, setHex] = useState("007AFF");

  return (
    <div className="space-y-5 pb-2">
      <Header title="Materias" onAdd={() => setAdding(true)} onBack={() => navigate("/mas")} />

      {subjects.length === 0 ? (
        <Empty
          icon={BookMarked}
          title="Sin materias"
          desc="Agrega tus materias para empezar a planificar"
        />
      ) : (
        <div className="divide-y divide-border overflow-hidden rounded-2xl border bg-card">
          {subjects.map((s) => (
            <div key={s.id} className="flex items-center gap-3 px-4 py-3.5">
              <span className="h-3.5 w-3.5 rounded-full" style={{ backgroundColor: colorVar(s.colorHex) }} />
              <span className="flex-1 font-medium">{s.name}</span>
              <button
                onClick={() => deleteSubject(s.id)}
                className="text-muted-foreground/60 transition active:scale-90 hover:text-destructive"
              >
                <Trash2 className="h-4 w-4" />
              </button>
            </div>
          ))}
        </div>
      )}

      <Dialog open={adding} onOpenChange={setAdding}>
        <DialogContent className="rounded-3xl">
          <DialogHeader>
            <DialogTitle>Nueva Materia</DialogTitle>
          </DialogHeader>
          <Input placeholder="Nombre de la materia" value={name} onChange={(e) => setName(e.target.value)} />
          <div className="grid grid-cols-4 gap-3 py-2">
            {PRESET_COLORS.map((c) => (
              <button
                key={c.hex}
                onClick={() => setHex(c.hex)}
                className="flex flex-col items-center gap-1"
              >
                <span
                  className={cn(
                    "h-11 w-11 rounded-full transition",
                    hex === c.hex && "ring-4 ring-foreground/80 ring-offset-2 ring-offset-background",
                  )}
                  style={{ backgroundColor: colorVar(c.hex) }}
                />
                <span className="text-[10px] text-muted-foreground">{c.name}</span>
              </button>
            ))}
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setAdding(false)}>
              Cancelar
            </Button>
            <Button
              disabled={!name.trim()}
              onClick={() => {
                addSubject(name.trim(), hex);
                setName("");
                setHex("007AFF");
                setAdding(false);
              }}
            >
              Guardar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export function Header({
  title,
  onAdd,
  onBack,
}: {
  title: string;
  onAdd?: () => void;
  onBack: () => void;
}) {
  return (
    <div className="flex items-center justify-between pt-1">
      <div className="flex items-center gap-1">
        <button onClick={onBack} className="-ml-2 flex h-9 w-9 items-center justify-center rounded-full transition active:scale-90">
          <ChevronLeft className="h-6 w-6" />
        </button>
        <h1 className="text-2xl font-extrabold tracking-tight">{title}</h1>
      </div>
      {onAdd && (
        <button
          onClick={onAdd}
          className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-primary-foreground transition active:scale-90"
        >
          <Plus className="h-5 w-5" />
        </button>
      )}
    </div>
  );
}

export function Empty({
  icon: Icon,
  title,
  desc,
}: {
  icon: typeof BookMarked;
  title: string;
  desc: string;
}) {
  return (
    <div className="flex flex-col items-center gap-3 py-16 text-center">
      <Icon className="h-12 w-12 text-primary/40" />
      <p className="font-semibold text-muted-foreground">{title}</p>
      <p className="mx-auto max-w-xs text-sm text-muted-foreground">{desc}</p>
    </div>
  );
}
