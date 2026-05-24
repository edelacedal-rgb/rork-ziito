import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class PlannerViewModel {
    var selectedDate: Date = Date()
    var studySessions: [StudySession] = []
    var tasks: [StudyTask] = []
    var isGeneratingPlan = false

    private let plannerService = ZiitonerService.shared
    private let calendar = Calendar.current

    func generatePlan(modelContext: ModelContext) {
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }

        do {
            let descriptor = FetchDescriptor<Exam>()
            let exams = try modelContext.fetch(descriptor)
            let subjectDescriptor = FetchDescriptor<Subject>()
            let subjects = try modelContext.fetch(subjectDescriptor)

            let existingDescriptor = FetchDescriptor<StudySession>()
            let existing = try modelContext.fetch(existingDescriptor)
            for session in existing {
                modelContext.delete(session)
            }

            let startDate = calendar.startOfDay(for: Date())
            let endDate = calendar.date(byAdding: .month, value: 3, to: startDate)!

            let newSessions = plannerService.generateZiito(
                exams: exams,
                subjects: subjects,
                from: startDate,
                to: endDate
            )

            for session in newSessions {
                modelContext.insert(session)
            }

            try modelContext.save()
            loadSessions(modelContext: modelContext)
            loadTasks(modelContext: modelContext)
        } catch {
            print("Error generating plan: \(error)")
        }
    }

    func loadSessions(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<StudySession>(
                sortBy: [SortDescriptor(\.date), SortDescriptor(\.orderIndex)]
            )
            studySessions = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading sessions: \(error)")
        }
    }

    func loadTasks(modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<StudyTask>(
                sortBy: [SortDescriptor(\.dueDate), SortDescriptor(\.priorityRaw, order: .reverse)]
            )
            tasks = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading tasks: \(error)")
        }
    }

    func sessionsFor(date: Date) -> [StudySession] {
        studySessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func tasksFor(date: Date) -> [StudyTask] {
        tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: date) }
    }

    func upcomingTasks() -> [StudyTask] {
        tasks.filter { !$0.isCompleted && $0.daysUntil >= 0 }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func toggleSessionCompletion(_ session: StudySession, modelContext: ModelContext) {
        session.isCompleted.toggle()
        do {
            try modelContext.save()
        } catch {
            print("Error saving session: \(error)")
        }
    }

    func toggleTaskCompletion(_ task: StudyTask, modelContext: ModelContext) {
        task.isCompleted.toggle()
        do {
            try modelContext.save()
        } catch {
            print("Error saving task: \(error)")
        }
    }

    func deleteSession(_ session: StudySession, modelContext: ModelContext) {
        modelContext.delete(session)
        do {
            try modelContext.save()
            loadSessions(modelContext: modelContext)
        } catch {
            print("Error deleting session: \(error)")
        }
    }

    func deleteTask(_ task: StudyTask, modelContext: ModelContext) {
        Task {
            await CalendarSyncService.shared.unsyncTask(task)
            NotificationService.shared.removeAllNotifications(forTask: task)
        }
        modelContext.delete(task)
        do {
            try modelContext.save()
            loadTasks(modelContext: modelContext)
        } catch {
            print("Error deleting task: \(error)")
        }
    }

    func syncExamToCalendar(_ exam: Exam, subject: Subject, modelContext: ModelContext) async {
        if let eventID = await CalendarSyncService.shared.syncExam(exam, subjectName: subject.name, subjectColorHex: subject.colorHex) {
            exam.calendarEventID = eventID
            exam.isSyncedToCalendar = true
            do {
                try modelContext.save()
            } catch {
                print("Error saving exam sync state: \(error)")
            }
        }
    }

    func syncTaskToCalendar(_ task: StudyTask, subject: Subject?, modelContext: ModelContext) async {
        if let eventID = await CalendarSyncService.shared.syncTask(task, subjectName: subject?.name, subjectColorHex: subject?.colorHex) {
            task.calendarEventID = eventID
            task.isSyncedToCalendar = true
            do {
                try modelContext.save()
            } catch {
                print("Error saving task sync state: \(error)")
            }
        }
    }

    func scheduleExamNotifications(_ exam: Exam, subject: Subject) async {
        let ids = await NotificationService.shared.scheduleExamReminder(for: exam, subjectName: subject.name)
        exam.notificationIDs = ids
    }

    func scheduleTaskNotifications(_ task: StudyTask, subject: Subject?) async {
        let ids = await NotificationService.shared.scheduleTaskReminder(for: task, subjectName: subject?.name)
        task.notificationIDs = ids
    }
}
