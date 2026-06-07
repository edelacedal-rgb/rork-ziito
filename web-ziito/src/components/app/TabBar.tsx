import { CalendarDays, Mountain, MoreHorizontal, Sun } from "lucide-react";

import { NavLink } from "@/components/NavLink";
import { cn } from "@/lib/utils";

const tabs = [
  { to: "/", label: "Hoy", icon: Sun, end: true },
  { to: "/horario", label: "Horario", icon: CalendarDays, end: false },
  { to: "/montana", label: "Montaña", icon: Mountain, end: false },
  { to: "/mas", label: "Más", icon: MoreHorizontal, end: false },
];

export function TabBar() {
  return (
    <nav className="sticky bottom-0 z-30 border-t border-border bg-card">
      <div className="mx-auto flex max-w-lg items-stretch justify-around px-2 pb-[env(safe-area-inset-bottom)] pt-1.5">
        {tabs.map((t) => (
          <NavLink
            key={t.to}
            to={t.to}
            end={t.end}
            className="flex flex-1 flex-col items-center gap-1 rounded-lg px-2 py-1.5 text-muted-foreground transition active:scale-95"
            activeClassName="text-primary"
          >
            {({ isActive }: { isActive: boolean }) => (
              <>
                <t.icon
                  className={cn("h-5 w-5 transition", isActive && "stroke-primary")}
                  strokeWidth={isActive ? 2.5 : 1.8}
                />
                <span className={cn("text-[10px] font-semibold tracking-tight", isActive && "text-primary")}>
                  {t.label}
                </span>
              </>
            )}
          </NavLink>
        ))}
      </div>
    </nav>
  );
}
