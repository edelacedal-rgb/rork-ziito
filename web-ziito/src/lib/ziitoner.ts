// Smart study-plan generator, ported from iOS ZiitonerService.
import { slopeIndex, totalDensityPoints, type Exam, type StudySession } from "./ziito-types";
import { daysUntil, startOfDay } from "./ziito-date";

const MAX_SESSIONS_PER_DAY = 5;
const MAX_SAME_SUBJECT_PER_DAY = 1;
const BASE_SESSION_DURATION = 45;

function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

function generateDays(from: Date, to: Date): Date[] {
  const days: Date[] = [];
  let current = startOfDay(from);
  const end = startOfDay(to);
  while (current.getTime() <= end.getTime()) {
    days.push(new Date(current));
    current = new Date(current);
    current.setDate(current.getDate() + 1);
  }
  return days;
}

function urgencyScore(exam: Exam): number {
  const d = Math.max(daysUntil(exam.date), 1);
  return exam.priority / Math.sqrt(d);
}

function totalSessions(exam: Exam, urgency: number): number {
  const d = Math.max(daysUntil(exam.date), 1);
  const base = 2;
  const priorityBonus = exam.priority;
  const urgencyBonus = Math.min(Math.floor(urgency * 2), 6);
  const timeBonus = Math.max(8 - d, 0);
  // Slope Index: denser content over fewer days demands more focus nodes before
  // the peak. Each sub-topic also guarantees at least one dedicated block.
  const slope = slopeIndex(exam, d);
  const densityBonus = Math.min(Math.ceil(slope * 3), 8);
  const topicFloor = Math.min(totalDensityPoints(exam), 12);
  const computed = base + priorityBonus + urgencyBonus + timeBonus + densityBonus;
  return Math.min(Math.max(computed, topicFloor), 24);
}

function distribute(total: number, days: number, urgency: number): number[] {
  const distribution = new Array<number>(days).fill(0);
  let remaining = total;
  let totalWeight = 0;
  for (let i = 0; i < days; i++) {
    const closeness = (i + 1) / Math.max(days, 1);
    totalWeight += 1 + closeness * 2 + urgency * 0.5;
  }
  for (let i = 0; i < days; i++) {
    const closeness = (i + 1) / Math.max(days, 1);
    const weight = 1 + closeness * 2 + urgency * 0.5;
    const proportion = weight / Math.max(totalWeight, 1);
    const forDay = Math.round(total * proportion);
    distribution[i] = forDay;
    remaining -= forDay;
  }
  while (remaining > 0) {
    for (let i = days - 1; i >= 0 && remaining > 0; i--) {
      distribution[i] += 1;
      remaining -= 1;
    }
  }
  while (remaining < 0) {
    for (let i = 0; i < days && remaining < 0; i++) {
      if (distribution[i] > 0) {
        distribution[i] -= 1;
        remaining += 1;
      }
    }
  }
  return distribution;
}

function adjustedDuration(exam: Exam): number {
  const d = daysUntil(exam.date);
  if (d <= 1) return 60;
  if (d <= 3) return 50;
  return BASE_SESSION_DURATION;
}

function sameDay(a: number, b: number): boolean {
  return startOfDay(new Date(a)).getTime() === startOfDay(new Date(b)).getTime();
}

function interleaveBySubject(sessions: StudySession[]): StudySession[] {
  const groups = new Map<number, StudySession[]>();
  for (const s of sessions) {
    const key = startOfDay(new Date(s.date)).getTime();
    const arr = groups.get(key) ?? [];
    arr.push(s);
    groups.set(key, arr);
  }
  const result: StudySession[] = [];
  for (const key of Array.from(groups.keys()).sort((a, b) => a - b)) {
    const pool = [...(groups.get(key) ?? [])];
    const ordered: StudySession[] = [];
    let lastSubject: string | null = null;
    while (pool.length > 0) {
      let pickIndex = 0;
      if (lastSubject) {
        const idx = pool.findIndex((s) => s.subjectID !== lastSubject);
        if (idx >= 0) pickIndex = idx;
      }
      const [picked] = pool.splice(pickIndex, 1);
      ordered.push(picked);
      lastSubject = picked.subjectID;
    }
    ordered.forEach((s, i) => (s.orderIndex = i));
    result.push(...ordered);
  }
  return result.sort((a, b) => {
    if (sameDay(a.date, b.date)) return a.orderIndex - b.orderIndex;
    return a.date - b.date;
  });
}

export function generateZiito(exams: Exam[], from: Date, to: Date): StudySession[] {
  const days = generateDays(from, to);
  if (days.length === 0 || exams.length === 0) return [];

  const futureExams = exams
    .filter((e) => daysUntil(e.date) >= 0 && !e.isCompleted)
    .sort((a, b) => a.date - b.date);
  if (futureExams.length === 0) return [];

  const sessions: StudySession[] = [];
  const dailySubjectCounts = new Map<number, Map<string, number>>();
  const dailyTotalCounts = new Map<number, number>();

  for (const day of days) {
    const k = startOfDay(day).getTime();
    dailySubjectCounts.set(k, new Map());
    dailyTotalCounts.set(k, 0);
  }

  for (const exam of futureExams) {
    const examDaysUntil = daysUntil(exam.date);
    if (examDaysUntil < 0) continue;
    const urgency = urgencyScore(exam);
    const needed = totalSessions(exam, urgency);

    const examDayKey = startOfDay(new Date(exam.date)).getTime();
    const relevantDays = days.filter((d) => startOfDay(d).getTime() < examDayKey);
    if (relevantDays.length === 0) continue;

    const perDay = distribute(needed, relevantDays.length, urgency);

    relevantDays.forEach((day, index) => {
      const dayKey = startOfDay(day).getTime();
      const countForDay = perDay[index];
      if (countForDay <= 0) return;

      const subjectCount = dailySubjectCounts.get(dayKey)!;
      const currentSubjectCount = subjectCount.get(exam.subjectID) ?? 0;
      const currentTotal = dailyTotalCounts.get(dayKey) ?? 0;

      const availableSlots = Math.min(
        countForDay,
        MAX_SESSIONS_PER_DAY - currentTotal,
        MAX_SAME_SUBJECT_PER_DAY - currentSubjectCount,
      );
      if (availableSlots <= 0) return;

      for (let i = 0; i < availableSlots; i++) {
        sessions.push({
          id: uid(),
          examID: exam.id,
          subjectID: exam.subjectID,
          date: day.getTime(),
          durationMinutes: adjustedDuration(exam),
          isCompleted: false,
          orderIndex: currentTotal + i,
        });
      }
      subjectCount.set(exam.subjectID, currentSubjectCount + availableSlots);
      dailyTotalCounts.set(dayKey, currentTotal + availableSlots);
    });
  }

  return interleaveBySubject(sessions);
}
