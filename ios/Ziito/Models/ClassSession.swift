import Foundation
import SwiftData

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Dom"
        case .monday: return "Lun"
        case .tuesday: return "Mar"
        case .wednesday: return "Mié"
        case .thursday: return "Jue"
        case .friday: return "Vie"
        case .saturday: return "Sáb"
        }
    }

    var fullLabel: String {
        switch self {
        case .sunday: return "Domingo"
        case .monday: return "Lunes"
        case .tuesday: return "Martes"
        case .wednesday: return "Miércoles"
        case .thursday: return "Jueves"
        case .friday: return "Viernes"
        case .saturday: return "Sábado"
        }
    }

    static var weekOrdered: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}

@Model
final class ClassSession {
    var id: UUID
    var subjectID: UUID?
    var customName: String
    var weekdayRaw: Int
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int
    var location: String
    var createdAt: Date

    init(
        subjectID: UUID? = nil,
        customName: String = "",
        weekday: Weekday,
        startMinuteOfDay: Int,
        endMinuteOfDay: Int,
        location: String = ""
    ) {
        self.id = UUID()
        self.subjectID = subjectID
        self.customName = customName
        self.weekdayRaw = weekday.rawValue
        self.startMinuteOfDay = startMinuteOfDay
        self.endMinuteOfDay = endMinuteOfDay
        self.location = location
        self.createdAt = Date()
    }

    var weekday: Weekday {
        Weekday(rawValue: weekdayRaw) ?? .monday
    }

    var startTimeString: String {
        Self.formatMinutes(startMinuteOfDay)
    }

    var endTimeString: String {
        Self.formatMinutes(endMinuteOfDay)
    }

    var durationMinutes: Int {
        max(0, endMinuteOfDay - startMinuteOfDay)
    }

    static func formatMinutes(_ minutes: Int) -> String {
        let h = (minutes / 60) % 24
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    static func minutes(from date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
