import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Bar,
  BarChart,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
} from "recharts";
import { CheckCircle2, Clock, Flame, Infinity as InfinityIcon, Timer } from "lucide-react";

import { Header } from "@/pages/app/Subjects";
import { useZiito } from "@/store/ZiitoStore";
import { isSameDay, startOfDay } from "@/lib/ziito-date";
import { colorVar } from "@/lib/ziito-color";
import { cn } from "@/lib/utils";

const DOW = ["D", "L", "M", "X", "J", "V", "S"];

export default function Stats() {
  const { logs, subjects } = useZiito();
  const navigate = useNavigate();
  const [range, setRange] = useState(7);

  const buckets = useMemo(() => {
    const today = startOfDay(new Date());
    const out: { label: string; minutes: number }[] = [];
    for (let offset = range - 1; offset >= 0; offset--) {
      const day = new Date(today);
      day.setDate(day.getDate() - offset);
      const minutes = logs
        .filter((l) => isSameDay(l.startedAt, day))
        .reduce((s, l) => s + l.focusMinutes, 0);
      out.push({ label: DOW[day.getDay()], minutes });
    }
    return out;
  }, [logs, range]);

  const total = buckets.reduce((s, b) => s + b.minutes, 0);

  const streak = useMemo(() => {
    let count = 0;
    const day = startOfDay(new Date());
    while (logs.some((l) => isSameDay(l.startedAt, day))) {
      count += 1;
      day.setDate(day.getDate() - 1);
    }
    return count;
  }, [logs]);

  const bySubject = useMemo(
    () =>
      subjects
        .map((s) => ({
          subject: s,
          minutes: logs.filter((l) => l.subjectID === s.id).reduce((acc, l) => acc + l.focusMinutes, 0),
        }))
        .filter((x) => x.minutes > 0)
        .sort((a, b) => b.minutes - a.minutes),
    [subjects, logs],
  );

  return (
    <div className="space-y-5 pb-2">
      <Header title="Estadísticas" onBack={() => navigate("/mas")} />

      <div className="grid grid-cols-3 gap-3">
        <SummaryCard icon={Clock} tint="text-primary" value={`${Math.floor(total / 60)}h ${total % 60}m`} label={`Total ${range}d`} />
        <SummaryCard icon={Flame} tint="text-accent" value={`${streak} d`} label="Racha" />
        <SummaryCard icon={CheckCircle2} tint="text-emerald-600" value={`${logs.length}`} label="Sesiones" />
      </div>

      <div className="grid grid-cols-3 gap-1.5 rounded-xl bg-secondary p-1">
        {[7, 14, 30].map((r) => (
          <button
            key={r}
            onClick={() => setRange(r)}
            className={cn(
              "rounded-lg py-1.5 text-xs font-semibold transition",
              range === r ? "bg-card shadow-sm" : "text-muted-foreground",
            )}
          >
            {r} días
          </button>
        ))}
      </div>

      <div className="rounded-2xl border bg-card p-4">
        <p className="mb-3 font-semibold">Minutos enfocados por día</p>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={buckets}>
            <XAxis dataKey="label" tickLine={false} axisLine={false} fontSize={11} />
            <Tooltip
              cursor={{ fill: "hsl(var(--secondary))" }}
              contentStyle={{ borderRadius: 12, border: "1px solid hsl(var(--border))", fontSize: 12 }}
              formatter={(v: number) => [`${v} min`, "Enfoque"]}
            />
            <Bar dataKey="minutes" radius={[6, 6, 0, 0]}>
              {buckets.map((_, i) => (
                <Cell key={i} fill="hsl(var(--primary))" />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="rounded-2xl border bg-card p-4">
        <p className="mb-3 font-semibold">Por materia</p>
        {bySubject.length === 0 ? (
          <p className="text-sm text-muted-foreground">Aún sin sesiones registradas por materia.</p>
        ) : (
          <div className="space-y-2.5">
            {bySubject.map(({ subject, minutes }) => (
              <div key={subject.id} className="flex items-center gap-2">
                <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: colorVar(subject.colorHex) }} />
                <span className="text-sm">{subject.name}</span>
                <span className="ml-auto text-sm font-semibold text-muted-foreground">{minutes} min</span>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="rounded-2xl border bg-card p-4">
        <p className="mb-3 font-semibold">Sesiones recientes</p>
        {logs.length === 0 ? (
          <p className="text-sm text-muted-foreground">Aún no has completado sesiones.</p>
        ) : (
          <div className="space-y-1">
            {logs.slice(0, 8).map((log) => (
              <div key={log.id} className="flex items-center gap-3 py-1.5">
                {log.mode === "pomodoro" ? (
                  <Timer className="h-4 w-4 text-primary" />
                ) : (
                  <InfinityIcon className="h-4 w-4 text-primary" />
                )}
                <div className="flex-1">
                  <p className="text-sm font-medium">
                    {new Date(log.startedAt).toLocaleDateString("es-ES", { day: "numeric", month: "short" })} ·{" "}
                    {new Date(log.startedAt).toLocaleTimeString("es-ES", { hour: "2-digit", minute: "2-digit" })}
                  </p>
                  {log.completedCycles > 0 && (
                    <p className="text-xs text-muted-foreground">{log.completedCycles} ciclos completados</p>
                  )}
                </div>
                <span className="text-sm font-semibold">{log.focusMinutes} min</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function SummaryCard({
  icon: Icon,
  tint,
  value,
  label,
}: {
  icon: typeof Clock;
  tint: string;
  value: string;
  label: string;
}) {
  return (
    <div className="rounded-2xl border bg-card p-3.5">
      <Icon className={cn("h-5 w-5", tint)} />
      <p className="mt-2 text-base font-bold leading-tight">{value}</p>
      <p className="text-xs text-muted-foreground">{label}</p>
    </div>
  );
}
