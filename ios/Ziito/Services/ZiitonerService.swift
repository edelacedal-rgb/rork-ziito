import Foundation
import SwiftUI

@Observable
final class ZiitonerService {
    static let shared = ZiitonerService()

    private let calendar = Calendar.current
    private let maxSessionsPerDay = 5
    /// Strict: never repeat the same subject inside the same day's plan.
    /// Itineraries must hand the user a clean, varied route of UNIQUE subjects.
    private let maxSameSubjectPerDay = 1
    private let baseSessionDuration = 45

    private init() {}

    func generateZiito(exams: [Exam], subjects: [Subject], from startDate: Date, to endDate: Date) -> [StudySession] {
        let days = generateDays(from: startDate, to: endDate)
        guard !days.isEmpty, !exams.isEmpty else { return [] }

        let futureExams = exams.filter { $0.daysUntil >= 0 && !$0.isCompleted }
        guard !futureExams.isEmpty else { return [] }

        var sessions: [StudySession] = []
        var dailySubjectCounts: [Date: [UUID: Int]] = [:]
        var dailyTotalCounts: [Date: Int] = [:]

        for day in days {
            let dayStart = calendar.startOfDay(for: day)
            dailySubjectCounts[dayStart] = [:]
            dailyTotalCounts[dayStart] = 0
        }

        for exam in futureExams.sorted(by: { $0.date < $1.date }) {
            let examDaysUntil = exam.daysUntil
            guard examDaysUntil >= 0 else { continue }

            let urgencyScore = calculateUrgencyScore(exam: exam)
            let totalSessionsNeeded = calculateTotalSessions(exam: exam, urgencyScore: urgencyScore)

            let relevantDays = days.filter {
                let d = calendar.startOfDay(for: $0)
                let examDay = calendar.startOfDay(for: exam.date)
                return d < examDay
            }

            guard !relevantDays.isEmpty else { continue }

            let sessionsPerDay = distributeSessions(
                totalSessions: totalSessionsNeeded,
                over: relevantDays.count,
                urgencyScore: urgencyScore,
                daysUntil: examDaysUntil
            )

            for (index, day) in relevantDays.enumerated() {
                let dayStart = calendar.startOfDay(for: day)
                let countForDay = sessionsPerDay[index]
                guard countForDay > 0 else { continue }

                var subjectCount = dailySubjectCounts[dayStart] ?? [:]
                let currentSubjectCount = subjectCount[exam.subjectID] ?? 0
                let currentTotal = dailyTotalCounts[dayStart] ?? 0

                let availableSlots = min(
                    countForDay,
                    maxSessionsPerDay - currentTotal,
                    maxSameSubjectPerDay - currentSubjectCount
                )

                guard availableSlots > 0 else { continue }

                for i in 0..<availableSlots {
                    let session = StudySession(
                        examID: exam.id,
                        subjectID: exam.subjectID,
                        date: day,
                        durationMinutes: adjustedDuration(for: exam, daysUntil: examDaysUntil),
                        orderIndex: currentTotal + i
                    )
                    sessions.append(session)
                }

                subjectCount[exam.subjectID] = currentSubjectCount + availableSlots
                dailySubjectCounts[dayStart] = subjectCount
                dailyTotalCounts[dayStart] = currentTotal + availableSlots
            }
        }

        // Final pass: de-duplicate AND interleave so two consecutive blocks within
        // the same day never share the same subject.
        let sorted = sessions.sorted { s1, s2 in
            if calendar.isDate(s1.date, inSameDayAs: s2.date) {
                return s1.orderIndex < s2.orderIndex
            }
            return s1.date < s2.date
        }
        return interleaveBySubject(sorted)
    }

    /// Within each day, reorder sessions so that no two consecutive blocks share
    /// the same `subjectID`. If two adjacent items collide, the next non-colliding
    /// session is brought forward; ties fall back to a stable greedy choice.
    private func interleaveBySubject(_ sessions: [StudySession]) -> [StudySession] {
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        var result: [StudySession] = []
        for day in grouped.keys.sorted() {
            var pool = grouped[day] ?? []
            var ordered: [StudySession] = []
            var lastSubject: UUID? = nil
            while !pool.isEmpty {
                let pickIndex: Int = {
                    if let last = lastSubject,
                       let idx = pool.firstIndex(where: { $0.subjectID != last }) {
                        return idx
                    }
                    return 0
                }()
                let picked = pool.remove(at: pickIndex)
                ordered.append(picked)
                lastSubject = picked.subjectID
            }
            for (i, s) in ordered.enumerated() {
                s.orderIndex = i
            }
            result.append(contentsOf: ordered)
        }
        return result.sorted { s1, s2 in
            if calendar.isDate(s1.date, inSameDayAs: s2.date) {
                return s1.orderIndex < s2.orderIndex
            }
            return s1.date < s2.date
        }
    }

    private func generateDays(from: Date, to: Date) -> [Date] {
        var days: [Date] = []
        var current = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        while current <= end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }

    private func calculateUrgencyScore(exam: Exam) -> Double {
        let days = Double(max(exam.daysUntil, 1))
        let priorityWeight = Double(exam.priority.rawValue)
        return priorityWeight / sqrt(days)
    }

    private func calculateTotalSessions(exam: Exam, urgencyScore: Double) -> Int {
        let days = max(exam.daysUntil, 1)
        let baseSessions = 2
        let priorityBonus = exam.priority.rawValue
        let urgencyBonus = min(Int(urgencyScore * 2), 6)
        let timeBonus = max(8 - days, 0)
        return min(baseSessions + priorityBonus + urgencyBonus + timeBonus, 16)
    }

    private func distributeSessions(totalSessions: Int, over days: Int, urgencyScore: Double, daysUntil: Int) -> [Int] {
        var distribution = Array(repeating: 0, count: days)
        var remaining = totalSessions

        let proximityWeight = Double(daysUntil) / Double(max(days, 1))
        let totalWeight = (0..<days).reduce(0.0) { sum, i in
            let closeness = Double(i + 1) / Double(max(days, 1))
            return sum + (1.0 + closeness * 2.0 + urgencyScore * 0.5)
        }

        for i in 0..<days {
            let closeness = Double(i + 1) / Double(max(days, 1))
            let weight = 1.0 + closeness * 2.0 + urgencyScore * 0.5
            let proportion = weight / max(totalWeight, 1.0)
            let sessionsForDay = Int(round(Double(totalSessions) * proportion))
            distribution[i] = sessionsForDay
            remaining -= sessionsForDay
        }

        while remaining > 0 {
            for i in (0..<days).reversed() where remaining > 0 {
                distribution[i] += 1
                remaining -= 1
            }
        }
        while remaining < 0 {
            for i in 0..<days where remaining < 0 && distribution[i] > 0 {
                distribution[i] -= 1
                remaining += 1
            }
        }

        return distribution
    }

    private func adjustedDuration(for exam: Exam, daysUntil: Int) -> Int {
        if daysUntil <= 1 {
            return 60
        } else if daysUntil <= 3 {
            return 50
        } else {
            return baseSessionDuration
        }
    }
}
