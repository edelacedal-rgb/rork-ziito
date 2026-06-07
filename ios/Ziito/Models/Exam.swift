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

/// Workload weight of an individual sub-topic / module within an exam.
enum ContentDensity: Int, Codable, CaseIterable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    /// Points contributed to the Slope Index.
    var points: Int { rawValue }

    var label: String {
        switch self {
        case .low: return "Carga baja"
        case .medium: return "Carga media"
        case .high: return "Carga alta"
        }
    }

    var shortLabel: String {
        switch self {
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }

    var colorName: String {
        switch self {
        case .low: return "34C759"
        case .medium: return "FF9500"
        case .high: return "FF3B30"
        }
    }
}

/// A specific module/topic a student must master for an evaluation.
struct SubTopic: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var densityRaw: Int

    init(title: String, density: ContentDensity) {
        self.id = UUID()
        self.title = title
        self.densityRaw = density.rawValue
    }

    var density: ContentDensity {
        ContentDensity(rawValue: densityRaw) ?? .medium
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
    /// Declared modules with their content density, used by the Slope Index +
    /// the focus engine's session interleaving. Defaults to empty for existing data.
    var subTopics: [SubTopic] = []

    init(title: String, date: Date, priority: PriorityLevel, subjectID: UUID, subTopics: [SubTopic] = []) {
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
        self.subTopics = subTopics
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

    /// Sum of density points across all declared sub-topics.
    var totalDensityPoints: Int {
        subTopics.reduce(0) { $0 + $1.density.points }
    }

    /// The "Slope Index": `TotalDensityPoints / DaysUntilExam`.
    /// Higher score => steeper climb => more focus nodes required before the peak.
    var slopeIndex: Double {
        let points = totalDensityPoints
        guard points > 0 else { return 0 }
        return Double(points) / Double(max(daysUntil, 1))
    }
}
