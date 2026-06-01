// Core domain models for the Ziito web app, ported from the iOS app.

export interface Subject {
  id: string;
  name: string;
  colorHex: string;
  createdAt: number;
}

export type PriorityLevel = 1 | 2 | 3 | 4 | 5;

export const PRIORITY_META: Record<
  PriorityLevel,
  { label: string; shortLabel: string; colorHex: string }
> = {
  1: { label: "Bajo", shortLabel: "Bajo", colorHex: "34C759" },
  2: { label: "Medio-Bajo", shortLabel: "M-Bajo", colorHex: "5AC8FA" },
  3: { label: "Medio", shortLabel: "Medio", colorHex: "FFCC00" },
  4: { label: "Alto", shortLabel: "Alto", colorHex: "FF9500" },
  5: { label: "Crítico", shortLabel: "Crítico", colorHex: "FF3B30" },
};

export const PRIORITY_LEVELS: PriorityLevel[] = [1, 2, 3, 4, 5];

export interface Exam {
  id: string;
  title: string;
  date: number;
  priority: PriorityLevel;
  subjectID: string;
  createdAt: number;
  isCompleted: boolean;
}

export interface StudyTask {
  id: string;
  title: string;
  notes: string;
  dueDate: number;
  isCompleted: boolean;
  priority: PriorityLevel;
  subjectID: string | null;
  createdAt: number;
}

export type Weekday = 1 | 2 | 3 | 4 | 5 | 6 | 7; // 1 = Sunday ... 7 = Saturday (Calendar.current style)

export const WEEKDAY_META: Record<Weekday, { short: string; full: string }> = {
  1: { short: "Dom", full: "Domingo" },
  2: { short: "Lun", full: "Lunes" },
  3: { short: "Mar", full: "Martes" },
  4: { short: "Mié", full: "Miércoles" },
  5: { short: "Jue", full: "Jueves" },
  6: { short: "Vie", full: "Viernes" },
  7: { short: "Sáb", full: "Sábado" },
};

export const WEEK_ORDERED: Weekday[] = [2, 3, 4, 5, 6, 7, 1];

export interface ClassSession {
  id: string;
  subjectID: string | null;
  customName: string;
  weekday: Weekday;
  startMinuteOfDay: number;
  endMinuteOfDay: number;
  location: string;
  createdAt: number;
}

export interface StudySession {
  id: string;
  examID: string;
  subjectID: string;
  date: number;
  durationMinutes: number;
  isCompleted: boolean;
  orderIndex: number;
}

export type FocusMode = "pomodoro" | "freeFocus";

export interface FocusLog {
  id: string;
  startedAt: number;
  endedAt: number;
  focusMinutes: number;
  breakMinutes: number;
  completedCycles: number;
  subjectID: string | null;
  mode: FocusMode;
}

export interface PomodoroSettings {
  focusMinutes: number;
  shortBreakMinutes: number;
  longBreakMinutes: number;
  cyclesUntilLongBreak: number;
}

export const DEFAULT_POMODORO: PomodoroSettings = {
  focusMinutes: 25,
  shortBreakMinutes: 5,
  longBreakMinutes: 15,
  cyclesUntilLongBreak: 4,
};

export type PomodoroPhase = "focus" | "shortBreak" | "longBreak";

export const PHASE_LABEL: Record<PomodoroPhase, string> = {
  focus: "Enfoque",
  shortBreak: "Descanso",
  longBreak: "Descanso largo",
};

export interface GamificationState {
  hearts: number;
  lastHeartLoss: number;
  xp: number;
  streak: number;
  longestStreak: number;
  freezes: number;
  lastStudyDay: number | null;
  studyDays: number[]; // start-of-day timestamps
}

export const MAX_HEARTS = 5;
export const HEART_REFILL_INTERVAL = 30 * 60 * 1000; // ms
export const XP_PER_FOCUS_CYCLE = 20;
export const XP_DAILY_BONUS = 30;
export const FREEZE_COST = 200;
