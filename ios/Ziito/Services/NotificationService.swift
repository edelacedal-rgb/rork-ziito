import Foundation
import UserNotifications

@Observable
@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var isAuthorized = false

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            isAuthorized = settings.authorizationStatus == .authorized
            return isAuthorized
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func scheduleExamReminder(for exam: Exam, subjectName: String, daysBefore: [Int] = [7, 3, 1]) async -> [String] {
        guard await requestAuthorization() else { return [] }

        var identifiers: [String] = []
        let calendar = Calendar.current

        for days in daysBefore {
            guard let reminderDate = calendar.date(byAdding: .day, value: -days, to: exam.date),
                  reminderDate > Date() else { continue }

            let identifier = "exam-\(exam.id.uuidString)-reminder-\(days)"
            let content = UNMutableNotificationContent()
            content.title = "\(subjectName): \(exam.title)"
            content.body = days == 0
                ? "¡Tu evaluación es hoy! ¡Mucho éxito!"
                : "Faltan \(days) días para tu evaluación. ¡A estudiar!"
            content.sound = .default

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            dateComponents.hour = 9
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                identifiers.append(identifier)
            } catch {
                print("Error scheduling exam reminder: \(error)")
            }
        }

        return identifiers
    }

    func scheduleTaskReminder(for task: StudyTask, subjectName: String?) async -> [String] {
        guard await requestAuthorization() else { return [] }

        var identifiers: [String] = []
        let calendar = Calendar.current

        if let reminderDate = calendar.date(byAdding: .day, value: -1, to: task.dueDate),
           reminderDate > Date() {
            let identifier = "task-\(task.id.uuidString)-reminder-1"
            let content = UNMutableNotificationContent()
            let prefix = subjectName != nil ? "[\(subjectName!)] " : ""
            content.title = "\(prefix)\(task.title)"
            content.body = "Tu tarea vence mañana."
            content.sound = .default

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: reminderDate)
            dateComponents.hour = 9
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                identifiers.append(identifier)
            } catch {
                print("Error scheduling task reminder: \(error)")
            }
        }

        if calendar.startOfDay(for: task.dueDate) >= calendar.startOfDay(for: Date()) {
            let identifier = "task-\(task.id.uuidString)-reminder-today"
            let content = UNMutableNotificationContent()
            let prefix = subjectName != nil ? "[\(subjectName!)] " : ""
            content.title = "\(prefix)\(task.title)"
            content.body = "Tu tarea vence hoy."
            content.sound = .default

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: task.dueDate)
            dateComponents.hour = 8
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
                identifiers.append(identifier)
            } catch {
                print("Error scheduling task today reminder: \(error)")
            }
        }

        return identifiers
    }

    func removeNotifications(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAllNotifications(forExam exam: Exam) {
        let prefix = "exam-\(exam.id.uuidString)"
        let notificationCenter = center
        notificationCenter.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }

    func removeAllNotifications(forTask task: StudyTask) {
        let prefix = "task-\(task.id.uuidString)"
        let notificationCenter = center
        notificationCenter.getPendingNotificationRequests { requests in
            let toRemove = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
