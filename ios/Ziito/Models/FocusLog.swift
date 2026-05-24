import Foundation
import SwiftData

enum FocusMode: String, Codable, CaseIterable {
    case pomodoro
    case freeFocus

    var label: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .freeFocus: return "Enfoque libre"
        }
    }
}

@Model
final class FocusLog {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var focusMinutes: Int
    var breakMinutes: Int
    var completedCycles: Int
    var subjectID: UUID?
    var modeRaw: String

    init(
        startedAt: Date,
        endedAt: Date,
        focusMinutes: Int,
        breakMinutes: Int = 0,
        completedCycles: Int = 0,
        subjectID: UUID? = nil,
        mode: FocusMode = .pomodoro
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.completedCycles = completedCycles
        self.subjectID = subjectID
        self.modeRaw = mode.rawValue
    }

    var mode: FocusMode {
        FocusMode(rawValue: modeRaw) ?? .pomodoro
    }
}
