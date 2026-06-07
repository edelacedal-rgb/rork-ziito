import Foundation
import SwiftData
import UserNotifications
import SwiftUI

enum PomodoroPhase: String, Codable {
    case focus
    case shortBreak
    case longBreak

    var label: String {
        switch self {
        case .focus: return "Enfoque"
        case .shortBreak: return "Descanso"
        case .longBreak: return "Descanso largo"
        }
    }
}

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes: Int = 25
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 15
    var cyclesUntilLongBreak: Int = 4

    static let key = "pomodoro.settings.v1"

    static func load() -> PomodoroSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(PomodoroSettings.self, from: data) else {
            return PomodoroSettings()
        }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

struct PersistedFocusState: Codable {
    var phase: PomodoroPhase
    var phaseStart: Date
    var phaseDurationMinutes: Int
    var sessionStart: Date
    var completedFocusCycles: Int
    var subjectID: UUID?
    var isPaused: Bool
    var pausedRemaining: TimeInterval
    var modeRaw: String
    var examID: UUID?
    var subtopicQueue: [SubTopic]?
    var subtopicIndex: Int?

    static let key = "pomodoro.state.v2"
}

@Observable
@MainActor
final class PomodoroService {
    static let shared = PomodoroService()

    var settings: PomodoroSettings
    var phase: PomodoroPhase = .focus
    var phaseStart: Date = Date()
    var phaseDurationMinutes: Int = 25
    var sessionStart: Date = Date()
    var completedFocusCycles: Int = 0
    var subjectID: UUID?
    var isRunning: Bool = false
    var isPaused: Bool = false
    var pausedRemaining: TimeInterval = 0
    var mode: FocusMode = .pomodoro
    var now: Date = Date()
    // Smart Session Interleaving
    var examID: UUID?
    var subtopicQueue: [SubTopic] = []
    var subtopicIndex: Int = 0

    /// The module the current focus block is targeting (nil when no sub-topics).
    var currentSubtopic: SubTopic? {
        guard !subtopicQueue.isEmpty else { return nil }
        return subtopicQueue[subtopicIndex % subtopicQueue.count]
    }
    /// Fired exactly when a focus phase organically reaches 00:00 (not on manual skip / stop).
    /// Used by Fog Mode + Path to plant a flag automatically and reward the user.
    var onFocusCompleted: ((_ subjectID: UUID?) -> Void)?

    private var timer: Timer?
    private let center = UNUserNotificationCenter.current()
    private let notificationID = "pomodoro.phase.end"

    private init() {
        self.settings = PomodoroSettings.load()
        restore()
        observeLiveActivityIntents()
    }

    private func observeLiveActivityIntents() {
        NotificationCenter.default.addObserver(
            forName: .ziitoFocusTogglePause,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isPaused { self.resume() } else { self.pause() }
            }
        }
        NotificationCenter.default.addObserver(
            forName: .ziitoFocusStop,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stop(modelContext: nil)
            }
        }
    }

    var phaseEnd: Date {
        phaseStart.addingTimeInterval(TimeInterval(phaseDurationMinutes * 60))
    }

    var remaining: TimeInterval {
        if isPaused { return pausedRemaining }
        return max(0, phaseEnd.timeIntervalSince(now))
    }

    var progress: Double {
        let total = TimeInterval(phaseDurationMinutes * 60)
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    var formattedRemaining: String {
        let r = Int(remaining.rounded())
        return String(format: "%02d:%02d", r / 60, r % 60)
    }

    // MARK: - Lifecycle

    func start(mode: FocusMode = .pomodoro, subjectID: UUID? = nil, subTopics: [SubTopic] = [], examID: UUID? = nil) {
        self.mode = mode
        self.subjectID = subjectID
        self.examID = examID
        self.subtopicQueue = SubtopicScheduler.buildQueue(subTopics)
        self.subtopicIndex = 0
        self.completedFocusCycles = 0
        self.sessionStart = Date()
        self.phase = .focus
        self.phaseDurationMinutes = mode == .pomodoro ? settings.focusMinutes : 60
        self.phaseStart = Date()
        self.isPaused = false
        self.isRunning = true
        startTimer()
        scheduleEndNotification()
        persist()
        startLiveActivity()
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        pausedRemaining = remaining
        isPaused = true
        cancelEndNotification()
        persist()
        updateLiveActivity()
    }

    func resume() {
        guard isRunning, isPaused else { return }
        phaseStart = Date().addingTimeInterval(-(TimeInterval(phaseDurationMinutes * 60) - pausedRemaining))
        isPaused = false
        scheduleEndNotification()
        persist()
        updateLiveActivity()
    }

    func skipPhase() {
        advance(force: true)
    }

    func stop(modelContext: ModelContext?) {
        let endedAt = Date()
        let totalMinutes = max(0, Int(endedAt.timeIntervalSince(sessionStart) / 60))
        if totalMinutes >= 1, let ctx = modelContext {
            let log = FocusLog(
                startedAt: sessionStart,
                endedAt: endedAt,
                focusMinutes: estimatedFocusMinutes(totalMinutes: totalMinutes),
                breakMinutes: max(0, totalMinutes - estimatedFocusMinutes(totalMinutes: totalMinutes)),
                completedCycles: completedFocusCycles,
                subjectID: subjectID,
                mode: mode
            )
            ctx.insert(log)
            try? ctx.save()
        }
        reset()
        LiveActivityService.shared.end()
    }

    private func estimatedFocusMinutes(totalMinutes: Int) -> Int {
        if mode == .freeFocus { return totalMinutes }
        return min(totalMinutes, completedFocusCycles * settings.focusMinutes + Int(elapsedInPhase() / 60))
    }

    private func elapsedInPhase() -> TimeInterval {
        if phase == .focus {
            if isPaused {
                return TimeInterval(phaseDurationMinutes * 60) - pausedRemaining
            }
            return min(TimeInterval(phaseDurationMinutes * 60), Date().timeIntervalSince(phaseStart))
        }
        return 0
    }

    private func reset() {
        isRunning = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        cancelEndNotification()
        UserDefaults.standard.removeObject(forKey: PersistedFocusState.key)
    }

    // MARK: - Tick

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        now = Date()
        if !isPaused && remaining <= 0 && mode == .pomodoro {
            advance(force: false)
        }
    }

    private func advance(force: Bool) {
        let endingFocusOrganically = (phase == .focus && !force)
        let completedSubjectID = subjectID
        switch phase {
        case .focus:
            completedFocusCycles += 1
            let isLong = completedFocusCycles % settings.cyclesUntilLongBreak == 0
            phase = isLong ? .longBreak : .shortBreak
            phaseDurationMinutes = isLong ? settings.longBreakMinutes : settings.shortBreakMinutes
        case .shortBreak, .longBreak:
            phase = .focus
            phaseDurationMinutes = settings.focusMinutes
            // Entering a fresh focus block: advance the interleaved sub-topic
            // queue so each Micro-Ziito targets a new module.
            if !subtopicQueue.isEmpty { subtopicIndex += 1 }
        }
        phaseStart = Date()
        isPaused = false
        scheduleEndNotification()
        persist()
        updateLiveActivity()
        Haptics.notify(.success)
        if endingFocusOrganically {
            onFocusCompleted?(completedSubjectID)
        }
    }

    // MARK: - Live Activity bridge

    /// Resolves the current subject's display name + color hex from any SwiftData store.
    /// We don't have a ModelContext here, so callers may override via `liveActivitySubjectProvider`.
    var liveActivitySubjectProvider: (() -> (name: String, colorHex: String)?)?

    private func currentLiveActivityState() -> ZiitoFocusAttributes.ContentState {
        let info = liveActivitySubjectProvider?() ?? (name: "Ziito", colorHex: "5856D6")
        return ZiitoFocusAttributes.ContentState(
            endDate: phaseEnd,
            isPaused: isPaused,
            pausedRemaining: pausedRemaining,
            phaseRaw: phase.rawValue,
            subjectName: info.name,
            subjectColorHex: info.colorHex
        )
    }

    private func startLiveActivity() {
        LiveActivityService.shared.start(state: currentLiveActivityState())
    }

    private func updateLiveActivity() {
        guard isRunning else { return }
        LiveActivityService.shared.update(state: currentLiveActivityState())
    }

    // MARK: - Notifications

    private func scheduleEndNotification() {
        guard mode == .pomodoro, !isPaused else { return }
        Task {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
        }
        let content = UNMutableNotificationContent()
        content.title = phase == .focus ? "¡Sesión completada!" : "Hora de volver"
        content.body = phase == .focus
            ? "Tómate un descanso de \(phase == .focus ? settings.shortBreakMinutes : settings.longBreakMinutes) min."
            : "Descanso terminado. ¡A enfocarse de nuevo!"
        content.sound = .default
        let interval = max(1, remaining)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let req = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.add(req)
    }

    private func cancelEndNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    // MARK: - Persistence

    private func persist() {
        guard isRunning else { return }
        let s = PersistedFocusState(
            phase: phase,
            phaseStart: phaseStart,
            phaseDurationMinutes: phaseDurationMinutes,
            sessionStart: sessionStart,
            completedFocusCycles: completedFocusCycles,
            subjectID: subjectID,
            isPaused: isPaused,
            pausedRemaining: pausedRemaining,
            modeRaw: mode.rawValue,
            examID: examID,
            subtopicQueue: subtopicQueue,
            subtopicIndex: subtopicIndex
        )
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: PersistedFocusState.key)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: PersistedFocusState.key),
              let s = try? JSONDecoder().decode(PersistedFocusState.self, from: data) else { return }
        phase = s.phase
        phaseStart = s.phaseStart
        phaseDurationMinutes = s.phaseDurationMinutes
        sessionStart = s.sessionStart
        completedFocusCycles = s.completedFocusCycles
        subjectID = s.subjectID
        isPaused = s.isPaused
        pausedRemaining = s.pausedRemaining
        mode = FocusMode(rawValue: s.modeRaw) ?? .pomodoro
        examID = s.examID
        subtopicQueue = s.subtopicQueue ?? []
        subtopicIndex = s.subtopicIndex ?? 0
        isRunning = true
        startTimer()
    }

    func updateSettings(_ new: PomodoroSettings) {
        settings = new
        new.save()
        if isRunning && phase == .focus {
            phaseDurationMinutes = new.focusMinutes
        }
    }
}

enum Haptics {
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(type)
    }

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }
}

import UIKit
