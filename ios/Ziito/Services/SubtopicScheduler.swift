import Foundation

/// Smart Session Interleaving (Ciclado de Contenidos).
///
/// Expands an exam's declared sub-topics into an ordered queue that decides which
/// module a given 25-minute Micro-Ziito focus block should target. Density-weighted
/// (high=3 blocks, medium=2, low=1) and interleaved so consecutive blocks rarely
/// repeat the same module — unless a high-density topic still owes back-to-back work.
enum SubtopicScheduler {
    static func buildQueue(_ subTopics: [SubTopic]) -> [SubTopic] {
        guard !subTopics.isEmpty else { return [] }

        var remaining = subTopics.map { $0.density.points }
        var queue: [SubTopic] = []
        var lastIndex = -1
        let totalBlocks = remaining.reduce(0, +)

        for _ in 0..<totalBlocks {
            var pick = -1
            var bestScore = -Double.infinity
            for i in 0..<subTopics.count where remaining[i] > 0 {
                var score = Double(remaining[i]) * 10.0
                if i == lastIndex { score -= 25.0 }
                if score > bestScore {
                    bestScore = score
                    pick = i
                }
            }

            // Allow back-to-back only for high-density topics still owing 2+ blocks.
            if pick == lastIndex {
                let other = (0..<subTopics.count).first { $0 != lastIndex && remaining[$0] > 0 }
                let owesBackToBack = remaining[pick] >= 2
                if let other, !owesBackToBack { pick = other }
            }

            guard pick >= 0 else { break }
            queue.append(subTopics[pick])
            remaining[pick] -= 1
            lastIndex = pick
        }

        return queue
    }

    /// Picks the upcoming exam whose content should be paced right now: the one
    /// with declared sub-topics and the steepest Slope Index.
    static func pickFocusExam(_ exams: [Exam]) -> Exam? {
        exams
            .filter { !$0.isCompleted && $0.daysUntil >= 0 && !$0.subTopics.isEmpty }
            .sorted {
                if $0.slopeIndex != $1.slopeIndex { return $0.slopeIndex > $1.slopeIndex }
                return $0.date < $1.date
            }
            .first
    }
}
