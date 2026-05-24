import Foundation
import EventKit
import SwiftData

@Observable
@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()

    private let eventStore = EKEventStore()
    private var isAuthorized = false

    private init() {}

    func requestAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            isAuthorized = true
            return true
        case .notDetermined:
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                isAuthorized = granted
                return granted
            } catch {
                print("Calendar access error: \(error)")
                return false
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func syncExam(_ exam: Exam, subjectName: String, subjectColorHex: String) async -> String? {
        guard await requestAccess() else { return nil }

        if let eventID = exam.calendarEventID,
           let existingEvent = eventStore.event(withIdentifier: eventID) {
            updateEvent(existingEvent, title: exam.title, date: exam.date, notes: "Evaluación de \(subjectName)", colorHex: subjectColorHex)
            do {
                try eventStore.save(existingEvent, span: .thisEvent)
                return existingEvent.eventIdentifier
            } catch {
                print("Error updating exam event: \(error)")
                return nil
            }
        }

        let event = createEvent(title: exam.title, date: exam.date, notes: "Evaluación de \(subjectName)", colorHex: subjectColorHex)
        event.isAllDay = true
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Error saving exam event: \(error)")
            return nil
        }
    }

    func syncTask(_ task: StudyTask, subjectName: String?, subjectColorHex: String?) async -> String? {
        guard await requestAccess() else { return nil }

        if let eventID = task.calendarEventID,
           let existingEvent = eventStore.event(withIdentifier: eventID) {
            let notes = task.notes.isEmpty ? "Tarea de Ziito" : task.notes
            let title = subjectName != nil ? "[\(subjectName!)] \(task.title)" : task.title
            updateEvent(existingEvent, title: title, date: task.dueDate, notes: notes, colorHex: subjectColorHex)
            do {
                try eventStore.save(existingEvent, span: .thisEvent)
                return existingEvent.eventIdentifier
            } catch {
                print("Error updating task event: \(error)")
                return nil
            }
        }

        let notes = task.notes.isEmpty ? "Tarea de Ziito" : task.notes
        let title = subjectName != nil ? "[\(subjectName!)] \(task.title)" : task.title
        let event = createEvent(title: title, date: task.dueDate, notes: notes, colorHex: subjectColorHex)
        event.isAllDay = true
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Error saving task event: \(error)")
            return nil
        }
    }

    func removeEvent(eventID: String?) async {
        guard let eventID = eventID else { return }
        guard await requestAccess() else { return }

        if let event = eventStore.event(withIdentifier: eventID) {
            do {
                try eventStore.remove(event, span: .thisEvent)
            } catch {
                print("Error removing event: \(error)")
            }
        }
    }

    func unsyncExam(_ exam: Exam) async {
        await removeEvent(eventID: exam.calendarEventID)
        exam.calendarEventID = nil
        exam.isSyncedToCalendar = false
    }

    func unsyncTask(_ task: StudyTask) async {
        await removeEvent(eventID: task.calendarEventID)
        task.calendarEventID = nil
        task.isSyncedToCalendar = false
    }

    private func createEvent(title: String, date: Date, notes: String, colorHex: String?) -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        return event
    }

    private func updateEvent(_ event: EKEvent, title: String, date: Date, notes: String, colorHex: String?) {
        event.title = title
        event.startDate = date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
        event.notes = notes
    }
}
