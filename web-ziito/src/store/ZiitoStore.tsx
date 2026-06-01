import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

import {
  DEFAULT_POMODORO,
  FREEZE_COST,
  HEART_REFILL_INTERVAL,
  MAX_HEARTS,
  XP_DAILY_BONUS,
  XP_PER_FOCUS_CYCLE,
  type ClassSession,
  type Exam,
  type FocusLog,
  type FocusMode,
  type GamificationState,
  type PomodoroPhase,
  type PomodoroSettings,
  type PriorityLevel,
  type StudySession,
  type StudyTask,
  type Subject,
  type Weekday,
} from "@/lib/ziito-types";
import { addMonths, isSameDay, startOfDay } from "@/lib/ziito-date";
import { generateZiito } from "@/lib/ziitoner";

const uid = (): string => Math.random().toString(36).slice(2) + Date.now().toString(36);

const KEYS = {
  subjects: "ziito.web.subjects",
  exams: "ziito.web.exams",
  tasks: "ziito.web.tasks",
  classes: "ziito.web.classes",
  logs: "ziito.web.logs",
  sessions: "ziito.web.sessions",
  game: "ziito.web.game",
  settings: "ziito.web.pomodoro.settings",
};

function load<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function save<T>(key: string, value: T): void {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // ignore quota errors
  }
}

const DEFAULT_GAME: GamificationState = {
  hearts: MAX_HEARTS,
  lastHeartLoss: Date.now(),
  xp: 0,
  streak: 0,
  longestStreak: 0,
  freezes: 0,
  lastStudyDay: null,
  studyDays: [],
};

export interface PomodoroRuntime {
  isRunning: boolean;
  isPaused: boolean;
  mode: FocusMode;
  phase: PomodoroPhase;
  phaseStart: number;
  phaseDurationMinutes: number;
  sessionStart: number;
  completedFocusCycles: number;
  subjectID: string | null;
  pausedRemaining: number; // seconds
}

interface ZiitoContextValue {
  // data
  subjects: Subject[];
  exams: Exam[];
  tasks: StudyTask[];
  classes: ClassSession[];
  logs: FocusLog[];
  sessions: StudySession[];
  game: GamificationState;
  settings: PomodoroSettings;

  // subjects
  addSubject: (name: string, colorHex: string) => void;
  deleteSubject: (id: string) => void;

  // exams
  addExam: (input: { title: string; date: number; priority: PriorityLevel; subjectID: string }) => void;
  deleteExam: (id: string) => void;
  toggleExam: (id: string) => void;

  // tasks
  addTask: (input: {
    title: string;
    notes: string;
    dueDate: number;
    priority: PriorityLevel;
    subjectID: string | null;
  }) => void;
  deleteTask: (id: string) => void;
  toggleTask: (id: string) => void;

  // classes
  upsertClass: (input: Omit<ClassSession, "id" | "createdAt"> & { id?: string }) => void;
  deleteClass: (id: string) => void;

  // planner
  generatePlan: () => void;
  toggleSession: (id: string) => void;

  // gamification
  buyFreeze: () => void;
  regenerateHearts: () => void;
  subjectFocusMinutes: (subjectID: string) => number;

  // pomodoro
  pomodoro: PomodoroRuntime;
  now: number;
  remaining: number; // seconds
  progress: number;
  formattedRemaining: string;
  startFocus: (mode?: FocusMode, subjectID?: string | null) => void;
  pauseFocus: () => void;
  resumeFocus: () => void;
  skipPhase: () => void;
  stopFocus: () => void;
  updateSettings: (s: PomodoroSettings) => void;

  // focus mode UI
  focusVisible: boolean;
  openFocus: () => void;
  minimizeFocus: () => void;
  lastReward: number; // timestamp of last flag planted, for UI flash
}

const ZiitoContext = createContext<ZiitoContextValue | null>(null);

export function ZiitoProvider({ children }: { children: ReactNode }) {
  const [subjects, setSubjects] = useState<Subject[]>(() => load(KEYS.subjects, []));
  const [exams, setExams] = useState<Exam[]>(() => load(KEYS.exams, []));
  const [tasks, setTasks] = useState<StudyTask[]>(() => load(KEYS.tasks, []));
  const [classes, setClasses] = useState<ClassSession[]>(() => load(KEYS.classes, []));
  const [logs, setLogs] = useState<FocusLog[]>(() => load(KEYS.logs, []));
  const [sessions, setSessions] = useState<StudySession[]>(() => load(KEYS.sessions, []));
  const [game, setGame] = useState<GamificationState>(() => load(KEYS.game, DEFAULT_GAME));
  const [settings, setSettings] = useState<PomodoroSettings>(() => load(KEYS.settings, DEFAULT_POMODORO));

  const [pomodoro, setPomodoro] = useState<PomodoroRuntime>({
    isRunning: false,
    isPaused: false,
    mode: "pomodoro",
    phase: "focus",
    phaseStart: Date.now(),
    phaseDurationMinutes: settings.focusMinutes,
    sessionStart: Date.now(),
    completedFocusCycles: 0,
    subjectID: null,
    pausedRemaining: 0,
  });
  const [now, setNow] = useState<number>(Date.now());
  const [focusVisible, setFocusVisible] = useState<boolean>(false);
  const [lastReward, setLastReward] = useState<number>(0);

  // persistence
  useEffect(() => save(KEYS.subjects, subjects), [subjects]);
  useEffect(() => save(KEYS.exams, exams), [exams]);
  useEffect(() => save(KEYS.tasks, tasks), [tasks]);
  useEffect(() => save(KEYS.classes, classes), [classes]);
  useEffect(() => save(KEYS.logs, logs), [logs]);
  useEffect(() => save(KEYS.sessions, sessions), [sessions]);
  useEffect(() => save(KEYS.game, game), [game]);
  useEffect(() => save(KEYS.settings, settings), [settings]);

  // ----- Gamification -----

  const regenerateHearts = useCallback(() => {
    setGame((g) => {
      if (g.hearts >= MAX_HEARTS) return g;
      const elapsed = Date.now() - g.lastHeartLoss;
      if (elapsed <= 0) return g;
      const gained = Math.floor(elapsed / HEART_REFILL_INTERVAL);
      if (gained <= 0) return g;
      const hearts = Math.min(MAX_HEARTS, g.hearts + gained);
      let lastHeartLoss = g.lastHeartLoss + gained * HEART_REFILL_INTERVAL;
      if (hearts >= MAX_HEARTS) lastHeartLoss = Date.now();
      return { ...g, hearts, lastHeartLoss };
    });
  }, []);

  const registerStudyCompletion = useCallback((cycles: number = 1) => {
    setGame((g) => {
      let { hearts, lastHeartLoss, xp, streak, longestStreak, freezes, lastStudyDay } = g;
      const studyDays = new Set(g.studyDays);

      xp += Math.max(1, cycles) * XP_PER_FOCUS_CYCLE;
      if (hearts < MAX_HEARTS) {
        hearts += 1;
        if (hearts >= MAX_HEARTS) lastHeartLoss = Date.now();
      }

      const today = startOfDay(new Date()).getTime();
      studyDays.add(today);

      if (lastStudyDay != null) {
        const lastDay = startOfDay(new Date(lastStudyDay)).getTime();
        if (lastDay === today) {
          // already counted today
          return { ...g, hearts, lastHeartLoss, xp, studyDays: Array.from(studyDays) };
        }
        const dayGap = Math.round((today - lastDay) / 86_400_000);
        if (dayGap === 1) {
          streak += 1;
        } else if (dayGap > 1) {
          const missed = dayGap - 1;
          if (freezes >= missed) {
            freezes -= missed;
            streak += 1;
          } else {
            freezes = 0;
            streak = 1;
          }
        }
        xp += XP_DAILY_BONUS;
      } else {
        streak = 1;
        xp += XP_DAILY_BONUS;
      }
      lastStudyDay = today;
      longestStreak = Math.max(longestStreak, streak);

      return {
        hearts,
        lastHeartLoss,
        xp,
        streak,
        longestStreak,
        freezes,
        lastStudyDay,
        studyDays: Array.from(studyDays),
      };
    });
  }, []);

  const buyFreeze = useCallback(() => {
    setGame((g) => {
      if (g.xp < FREEZE_COST) return g;
      return { ...g, xp: g.xp - FREEZE_COST, freezes: g.freezes + 1 };
    });
  }, []);

  const subjectFocusMinutes = useCallback(
    (subjectID: string) =>
      logs.filter((l) => l.subjectID === subjectID).reduce((s, l) => s + l.focusMinutes, 0),
    [logs],
  );

  // ----- CRUD -----

  const addSubject = useCallback((name: string, colorHex: string) => {
    setSubjects((s) => [...s, { id: uid(), name, colorHex, createdAt: Date.now() }]);
  }, []);

  const deleteSubject = useCallback((id: string) => {
    setSubjects((s) => s.filter((x) => x.id !== id));
  }, []);

  const addExam = useCallback(
    (input: { title: string; date: number; priority: PriorityLevel; subjectID: string }) => {
      setExams((e) => [
        ...e,
        { id: uid(), ...input, createdAt: Date.now(), isCompleted: false },
      ]);
    },
    [],
  );

  const deleteExam = useCallback((id: string) => {
    setExams((e) => e.filter((x) => x.id !== id));
  }, []);

  const toggleExam = useCallback((id: string) => {
    setExams((e) => e.map((x) => (x.id === id ? { ...x, isCompleted: !x.isCompleted } : x)));
  }, []);

  const addTask = useCallback(
    (input: {
      title: string;
      notes: string;
      dueDate: number;
      priority: PriorityLevel;
      subjectID: string | null;
    }) => {
      setTasks((t) => [
        ...t,
        { id: uid(), ...input, createdAt: Date.now(), isCompleted: false },
      ]);
    },
    [],
  );

  const deleteTask = useCallback((id: string) => {
    setTasks((t) => t.filter((x) => x.id !== id));
  }, []);

  const toggleTask = useCallback((id: string) => {
    setTasks((t) => t.map((x) => (x.id === id ? { ...x, isCompleted: !x.isCompleted } : x)));
  }, []);

  const upsertClass = useCallback(
    (input: Omit<ClassSession, "id" | "createdAt"> & { id?: string }) => {
      setClasses((c) => {
        if (input.id) {
          return c.map((x) => (x.id === input.id ? { ...x, ...input, id: x.id } : x));
        }
        return [...c, { ...input, id: uid(), createdAt: Date.now() }];
      });
    },
    [],
  );

  const deleteClass = useCallback((id: string) => {
    setClasses((c) => c.filter((x) => x.id !== id));
  }, []);

  // ----- Planner -----

  const generatePlan = useCallback(() => {
    const start = startOfDay(new Date());
    const end = addMonths(start, 3);
    const newSessions = generateZiito(exams, start, end);
    setSessions(newSessions);
  }, [exams]);

  const toggleSession = useCallback((id: string) => {
    setSessions((s) => s.map((x) => (x.id === id ? { ...x, isCompleted: !x.isCompleted } : x)));
  }, []);

  // ----- Pomodoro engine -----

  const phaseEnd = useMemo(
    () => pomodoro.phaseStart + pomodoro.phaseDurationMinutes * 60_000,
    [pomodoro.phaseStart, pomodoro.phaseDurationMinutes],
  );

  const remaining = useMemo(() => {
    if (pomodoro.isPaused) return pomodoro.pausedRemaining;
    return Math.max(0, Math.round((phaseEnd - now) / 1000));
  }, [pomodoro.isPaused, pomodoro.pausedRemaining, phaseEnd, now]);

  const progress = useMemo(() => {
    const total = pomodoro.phaseDurationMinutes * 60;
    if (total <= 0) return 0;
    return Math.min(1, Math.max(0, 1 - remaining / total));
  }, [pomodoro.phaseDurationMinutes, remaining]);

  const formattedRemaining = useMemo(() => {
    const r = remaining;
    return `${String(Math.floor(r / 60)).padStart(2, "0")}:${String(r % 60).padStart(2, "0")}`;
  }, [remaining]);

  const startFocus = useCallback(
    (mode: FocusMode = "pomodoro", subjectID: string | null = null) => {
      const ts = Date.now();
      setPomodoro({
        isRunning: true,
        isPaused: false,
        mode,
        phase: "focus",
        phaseStart: ts,
        phaseDurationMinutes: mode === "pomodoro" ? settings.focusMinutes : 60,
        sessionStart: ts,
        completedFocusCycles: 0,
        subjectID,
        pausedRemaining: 0,
      });
      setNow(ts);
    },
    [settings.focusMinutes],
  );

  const pauseFocus = useCallback(() => {
    setPomodoro((p) => {
      if (!p.isRunning || p.isPaused) return p;
      const end = p.phaseStart + p.phaseDurationMinutes * 60_000;
      const rem = Math.max(0, Math.round((end - Date.now()) / 1000));
      return { ...p, isPaused: true, pausedRemaining: rem };
    });
  }, []);

  const resumeFocus = useCallback(() => {
    setPomodoro((p) => {
      if (!p.isRunning || !p.isPaused) return p;
      const phaseStart = Date.now() - (p.phaseDurationMinutes * 60_000 - p.pausedRemaining * 1000);
      return { ...p, isPaused: false, phaseStart };
    });
  }, []);

  const advanceRef = useRef<(force: boolean) => void>(() => {});
  advanceRef.current = (force: boolean) => {
    setPomodoro((p) => {
      const endingFocusOrganically = p.phase === "focus" && !force;
      let phase: PomodoroPhase;
      let phaseDurationMinutes: number;
      let completedFocusCycles = p.completedFocusCycles;
      if (p.phase === "focus") {
        completedFocusCycles += 1;
        const isLong = completedFocusCycles % settings.cyclesUntilLongBreak === 0;
        phase = isLong ? "longBreak" : "shortBreak";
        phaseDurationMinutes = isLong ? settings.longBreakMinutes : settings.shortBreakMinutes;
      } else {
        phase = "focus";
        phaseDurationMinutes = settings.focusMinutes;
      }
      if (endingFocusOrganically) {
        registerStudyCompletion(1);
        if (p.subjectID) {
          setLogs((l) => [
            {
              id: uid(),
              startedAt: p.phaseStart,
              endedAt: Date.now(),
              focusMinutes: p.phaseDurationMinutes,
              breakMinutes: 0,
              completedCycles: 1,
              subjectID: p.subjectID,
              mode: p.mode,
            },
            ...l,
          ]);
        }
        setLastReward(Date.now());
      }
      return {
        ...p,
        phase,
        phaseDurationMinutes,
        completedFocusCycles,
        phaseStart: Date.now(),
        isPaused: false,
      };
    });
  };

  const skipPhase = useCallback(() => advanceRef.current(true), []);

  const stopFocus = useCallback(() => {
    setPomodoro((p) => {
      const endedAt = Date.now();
      const totalMinutes = Math.max(0, Math.floor((endedAt - p.sessionStart) / 60_000));
      if (totalMinutes >= 1) {
        const focusMinutes =
          p.mode === "freeFocus"
            ? totalMinutes
            : Math.min(
                totalMinutes,
                p.completedFocusCycles * settings.focusMinutes +
                  (p.phase === "focus" ? Math.floor((endedAt - p.phaseStart) / 60_000) : 0),
              );
        setLogs((l) => [
          {
            id: uid(),
            startedAt: p.sessionStart,
            endedAt,
            focusMinutes,
            breakMinutes: Math.max(0, totalMinutes - focusMinutes),
            completedCycles: p.completedFocusCycles,
            subjectID: p.subjectID,
            mode: p.mode,
          },
          ...l,
        ]);
      }
      return { ...p, isRunning: false, isPaused: false };
    });
    setFocusVisible(false);
  }, [settings.focusMinutes]);

  const updateSettings = useCallback((s: PomodoroSettings) => {
    setSettings(s);
    setPomodoro((p) =>
      p.isRunning && p.phase === "focus" ? { ...p, phaseDurationMinutes: s.focusMinutes } : p,
    );
  }, []);

  // timer tick
  useEffect(() => {
    if (!pomodoro.isRunning) return;
    const t = setInterval(() => {
      const n = Date.now();
      setNow(n);
      setPomodoro((p) => {
        if (!p.isPaused && p.mode === "pomodoro") {
          const end = p.phaseStart + p.phaseDurationMinutes * 60_000;
          if (end - n <= 0) {
            // defer to advance to keep settings consistent
            queueMicrotask(() => advanceRef.current(false));
          }
        }
        return p;
      });
    }, 500);
    return () => clearInterval(t);
  }, [pomodoro.isRunning]);

  // heart regen poller
  useEffect(() => {
    regenerateHearts();
    const t = setInterval(regenerateHearts, 30_000);
    return () => clearInterval(t);
  }, [regenerateHearts]);

  const openFocus = useCallback(() => {
    setPomodoro((p) => (p.isRunning ? p : p));
    if (!pomodoro.isRunning) startFocus("pomodoro");
    setFocusVisible(true);
  }, [pomodoro.isRunning, startFocus]);

  const minimizeFocus = useCallback(() => setFocusVisible(false), []);

  const value: ZiitoContextValue = {
    subjects,
    exams,
    tasks,
    classes,
    logs,
    sessions,
    game,
    settings,
    addSubject,
    deleteSubject,
    addExam,
    deleteExam,
    toggleExam,
    addTask,
    deleteTask,
    toggleTask,
    upsertClass,
    deleteClass,
    generatePlan,
    toggleSession,
    buyFreeze,
    regenerateHearts,
    subjectFocusMinutes,
    pomodoro,
    now,
    remaining,
    progress,
    formattedRemaining,
    startFocus,
    pauseFocus,
    resumeFocus,
    skipPhase,
    stopFocus,
    updateSettings,
    focusVisible,
    openFocus,
    minimizeFocus,
    lastReward,
  };

  return <ZiitoContext.Provider value={value}>{children}</ZiitoContext.Provider>;
}

export function useZiito(): ZiitoContextValue {
  const ctx = useContext(ZiitoContext);
  if (!ctx) throw new Error("useZiito must be used within ZiitoProvider");
  return ctx;
}

// Convenience selectors

export function useSessionsForDate(date: Date): StudySession[] {
  const { sessions } = useZiito();
  return useMemo(
    () => sessions.filter((s) => isSameDay(s.date, date)),
    [sessions, date],
  );
}

export function classesForWeekday(classes: ClassSession[], weekday: Weekday): ClassSession[] {
  return classes
    .filter((c) => c.weekday === weekday)
    .sort((a, b) => a.startMinuteOfDay - b.startMinuteOfDay);
}
