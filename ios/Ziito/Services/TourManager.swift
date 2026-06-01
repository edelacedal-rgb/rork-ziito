import Foundation
import SwiftUI

/// Drives the guided onboarding that walks the user through creating subjects,
/// building their schedule, registering exams, and generating the smart plan.
@Observable
@MainActor
final class TourManager {
    static let shared = TourManager()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let active = "ziito.tour.active"
        static let step = "ziito.tour.step"
        static let completed = "ziito.tour.completed"
        static let autoPrompted = "ziito.tour.autoPrompted"
    }

    /// Total number of guided steps (welcome + 3 setup steps + generate).
    static let stepCount = 5

    var isActive: Bool { didSet { defaults.set(isActive, forKey: Key.active) } }
    var step: Int { didSet { defaults.set(step, forKey: Key.step) } }
    var hasCompleted: Bool { didSet { defaults.set(hasCompleted, forKey: Key.completed) } }
    var autoPrompted: Bool { didSet { defaults.set(autoPrompted, forKey: Key.autoPrompted) } }

    private init() {
        isActive = defaults.bool(forKey: Key.active)
        step = defaults.integer(forKey: Key.step)
        hasCompleted = defaults.bool(forKey: Key.completed)
        autoPrompted = defaults.bool(forKey: Key.autoPrompted)
    }

    func start() {
        step = 0
        hasCompleted = false
        autoPrompted = true
        isActive = true
    }

    func close() {
        isActive = false
    }

    func goToStep(_ index: Int) {
        step = max(0, min(index, Self.stepCount - 1))
    }

    func next() {
        goToStep(step + 1)
    }

    func finish() {
        isActive = false
        hasCompleted = true
    }

    /// True once the guided onboarding has been seen to completion.
    var isComplete: Bool { hasCompleted }

    /// Auto-starts the tour the very first time a user opens an empty app.
    func autoStartIfNeeded(isEmpty: Bool) {
        guard !autoPrompted else { return }
        autoPrompted = true
        if isEmpty && !hasCompleted {
            step = 0
            isActive = true
        }
    }
}
