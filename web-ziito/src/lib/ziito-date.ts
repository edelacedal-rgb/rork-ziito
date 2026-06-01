// Date helpers shared across the Ziito web app.

export function startOfDay(d: Date): Date {
  const c = new Date(d);
  c.setHours(0, 0, 0, 0);
  return c;
}

export function isSameDay(a: number | Date, b: number | Date): boolean {
  return startOfDay(new Date(a)).getTime() === startOfDay(new Date(b)).getTime();
}

/** Whole days from today (start of day) until the given date. */
export function daysUntil(date: number | Date): number {
  const today = startOfDay(new Date());
  const target = startOfDay(new Date(date));
  return Math.round((target.getTime() - today.getTime()) / 86_400_000);
}

export function addDays(d: Date, days: number): Date {
  const c = new Date(d);
  c.setDate(c.getDate() + days);
  return c;
}

export function addMonths(d: Date, months: number): Date {
  const c = new Date(d);
  c.setMonth(c.getMonth() + months);
  return c;
}

/** Calendar.current weekday: 1 = Sunday ... 7 = Saturday. */
export function weekdayOf(d: Date): number {
  return d.getDay() + 1;
}

export function minutesOfDay(d: Date): number {
  return d.getHours() * 60 + d.getMinutes();
}

export function formatMinutes(minutes: number): string {
  const h = Math.floor(minutes / 60) % 24;
  const m = minutes % 60;
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}

const MONTHS = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];
const WEEKDAYS_FULL = [
  "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado",
];

function cap(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export function formatLongDate(d: Date): string {
  return cap(`${WEEKDAYS_FULL[d.getDay()]}, ${d.getDate()} de ${MONTHS[d.getMonth()]}`);
}

export function formatShortDate(d: Date): string {
  const m = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
  return `${d.getDate()} ${m[d.getMonth()]}`;
}

export function formatTimeShort(d: Date): string {
  return d.toLocaleTimeString("es-ES", { hour: "2-digit", minute: "2-digit" });
}

export function greeting(): string {
  const h = new Date().getHours();
  if (h >= 5 && h < 12) return "Buenos días";
  if (h >= 12 && h < 18) return "Buenas tardes";
  return "Buenas noches";
}
