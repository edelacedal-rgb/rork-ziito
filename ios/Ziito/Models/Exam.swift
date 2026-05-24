import Foundation
import SwiftData

enum PriorityLevel: Int, Codable, CaseIterable {
    case low = 1
    case mediumLow = 2
    case medium = 3
    case high = 4
    case critical = 5

    var label: String {
        switch self {
        case .low: return "Bajo"
        case .mediumLow: return "Medio-Bajo"
        case .medium: return "Medio"
        case .high: return "Alto"
        case .critical: return "Crítico"
        }
    }

    var shortLabel: String {
        switch self {
        case .low: return "Bajo"
        case .mediumLow: return "M-Bajo"
        case .medium: return "Medio"
        case .high: return "Alto"
        case .critical: return "Crítico"
        }
    }

    var colorName: String {
        switch self {
        case .low: return "34C759"
        case .mediumLow: return "5AC8FA"
        case .medium: return "FFCC00"
        case .high: return "FF9500"
        case .critical: return "FF3B30"
        }
    }
}

@Model
final class Exam {
    var id: UUID
    var title: String
    var date: Date
    var priorityRaw: Int
    var subjectID: UUID
    var createdAt: Date
    var isCompleted: Bool
    var calendarEventID: String?
    var isSyncedToCalendar: Bool
    var notificationIDs: [String]

    init(title: String, date: Date, priority: PriorityLevel, subjectID: UUID) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.priorityRaw = priority.rawValue
        self.subjectID = subjectID
        self.createdAt = Date()
        self.isCompleted = false
        self.calendarEventID = nil
        self.isSyncedToCalendar = false
        self.notificationIDs = []
    }

    var priority: PriorityLevel {
        PriorityLevel(rawValue: priorityRaw) ?? .medium
    }

    var daysUntil: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExam = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfExam).day ?? 0
    }
}
