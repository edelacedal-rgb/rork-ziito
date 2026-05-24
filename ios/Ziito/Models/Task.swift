import Foundation
import SwiftData

@Model
final class StudyTask {
    var id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var isCompleted: Bool
    var priorityRaw: Int
    var subjectID: UUID?
    var createdAt: Date
    var calendarEventID: String?
    var notificationIDs: [String]
    var isSyncedToCalendar: Bool

    init(title: String, notes: String = "", dueDate: Date, priority: PriorityLevel = .medium, subjectID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
        self.subjectID = subjectID
        self.createdAt = Date()
        self.isCompleted = false
        self.calendarEventID = nil
        self.notificationIDs = []
        self.isSyncedToCalendar = false
    }

    var priority: PriorityLevel {
        PriorityLevel(rawValue: priorityRaw) ?? .medium
    }

    var daysUntil: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
    }

    var isOverdue: Bool {
        daysUntil < 0 && !isCompleted
    }
}
