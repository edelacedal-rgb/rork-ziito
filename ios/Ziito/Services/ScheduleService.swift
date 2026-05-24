import Foundation
import SwiftData

struct FreeSlot: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

@Observable
@MainActor
final class ScheduleService {
    static let shared = ScheduleService()

    private init() {}

    /// Returns the class currently happening for the given date, if any.
    func currentClass(at date: Date, classes: [ClassSession]) -> ClassSession? {
        let weekday = Calendar.current.component(.weekday, from: date)
        let minute = ClassSession.minutes(from: date)
        return classes.first { c in
            c.weekdayRaw == weekday && minute >= c.startMinuteOfDay && minute < c.endMinuteOfDay
        }
    }

    /// Returns ordered classes scheduled for the given date.
    func classesFor(date: Date, classes: [ClassSession]) -> [ClassSession] {
        let weekday = Calendar.current.component(.weekday, from: date)
        return classes
            .filter { $0.weekdayRaw == weekday }
            .sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
    }

    /// Returns gaps in the day (between dayStartMinute and dayEndMinute) of at least `minMinutes`.
    func freeSlotsFor(
        date: Date,
        classes: [ClassSession],
        dayStartMinute: Int = 8 * 60,
        dayEndMinute: Int = 22 * 60,
        minMinutes: Int = 30
    ) -> [FreeSlot] {
        let cal = Calendar.current
        let dayClasses = classesFor(date: date, classes: classes)
        var slots: [FreeSlot] = []
        var cursor = dayStartMinute

        for c in dayClasses {
            if c.startMinuteOfDay > cursor {
                let gap = c.startMinuteOfDay - cursor
                if gap >= minMinutes {
                    if let s = cal.date(bySettingHour: cursor / 60, minute: cursor % 60, second: 0, of: date),
                       let e = cal.date(bySettingHour: c.startMinuteOfDay / 60, minute: c.startMinuteOfDay % 60, second: 0, of: date) {
                        slots.append(FreeSlot(start: s, end: e))
                    }
                }
            }
            cursor = max(cursor, c.endMinuteOfDay)
        }

        if dayEndMinute > cursor {
            let gap = dayEndMinute - cursor
            if gap >= minMinutes {
                if let s = cal.date(bySettingHour: cursor / 60, minute: cursor % 60, second: 0, of: date),
                   let e = cal.date(bySettingHour: dayEndMinute / 60, minute: dayEndMinute % 60, second: 0, of: date) {
                    slots.append(FreeSlot(start: s, end: e))
                }
            }
        }

        return slots
    }

    /// Returns the free slot containing `now` (if any).
    func currentFreeSlot(now: Date, classes: [ClassSession]) -> FreeSlot? {
        let slots = freeSlotsFor(date: now, classes: classes)
        return slots.first { $0.start <= now && now < $0.end }
    }
}
