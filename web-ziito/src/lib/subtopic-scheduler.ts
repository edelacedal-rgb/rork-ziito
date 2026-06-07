// Smart Session Interleaving (Ciclado de Contenidos).
//
// Given an exam's declared sub-topics, build an ordered queue that decides which
// module a given 25-minute Micro-Ziito focus block should target. The queue is
// weighted by ContentDensity (high-density topics get more blocks) and
// interleaved so consecutive blocks rarely repeat the same module — unless a
// high-density topic still has back-to-back work pending.

import { densityPoints, slopeIndex, type Exam, type SubTopic } from "./ziito-types";
import { daysUntil } from "./ziito-date";

/**
 * Expand sub-topics into a block queue. Each topic receives one block per
 * density point (low=1, medium=2, high=3), then the blocks are interleaved.
 */
export function buildSubtopicQueue(subTopics: SubTopic[]): SubTopic[] {
  const topics = subTopics ?? [];
  if (topics.length === 0) return [];

  // Remaining blocks owed to each topic, keyed by index.
  const remaining = topics.map((t) => densityPoints(t.density));
  const queue: SubTopic[] = [];
  let lastIndex = -1;

  const totalBlocks = remaining.reduce((s, n) => s + n, 0);
  for (let placed = 0; placed < totalBlocks; placed++) {
    // Candidate = topic with the most remaining work, preferring NOT to repeat
    // the previous one. A high-density topic (>= 2 blocks still pending) is
    // allowed to go back-to-back when nothing else can interleave.
    let pick = -1;
    let bestScore = -Infinity;
    for (let i = 0; i < topics.length; i++) {
      if (remaining[i] <= 0) continue;
      const isRepeat = i === lastIndex;
      // Base score favors topics with more remaining blocks (keeps high-density
      // content progressing) but penalizes immediate repeats.
      let score = remaining[i] * 10;
      if (isRepeat) score -= 25;
      if (score > bestScore) {
        bestScore = score;
        pick = i;
      }
    }

    // If the only positive choice is a repeat, allow back-to-back ONLY when the
    // topic is high-density (still owes 2+ blocks). Otherwise force a different
    // topic if one with remaining work exists.
    if (pick === lastIndex) {
      const other = topics.findIndex((_, i) => i !== lastIndex && remaining[i] > 0);
      const owesBackToBack = remaining[pick] >= 2;
      if (other >= 0 && !owesBackToBack) pick = other;
    }

    if (pick < 0) break;
    queue.push(topics[pick]);
    remaining[pick] -= 1;
    lastIndex = pick;
  }

  return queue;
}

/**
 * Choose the exam whose content the focus engine should pace right now: the
 * upcoming exam with declared sub-topics and the steepest Slope Index.
 */
export function pickFocusExam(exams: Exam[]): Exam | null {
  const candidates = exams
    .filter((e) => !e.isCompleted && daysUntil(e.date) >= 0 && (e.subTopics?.length ?? 0) > 0)
    .map((e) => ({ exam: e, score: slopeIndex(e, daysUntil(e.date)) }))
    .sort((a, b) => b.score - a.score || a.exam.date - b.exam.date);
  return candidates[0]?.exam ?? null;
}
