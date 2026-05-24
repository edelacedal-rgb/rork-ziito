import Foundation

struct ScannedClass: Identifiable {
    let id = UUID()
    var name: String
    var weekday: Weekday
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int
    var location: String = ""
    var subjectID: UUID?
    var isSelected: Bool = true

    var startTimeString: String { ClassSession.formatMinutes(startMinuteOfDay) }
    var endTimeString: String { ClassSession.formatMinutes(endMinuteOfDay) }
}
