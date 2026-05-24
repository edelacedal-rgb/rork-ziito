import Foundation
import ActivityKit

/// Owns the lifecycle of the Fog Mode Live Activity (Lock Screen + Dynamic Island).
/// Mirrors PomodoroService state in real time. No-ops if Live Activities are disabled.
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()

    private var current: Activity<ZiitoFocusAttributes>?

    private init() {
        // Reattach to any in-flight activity (e.g. after a process restart).
        if let existing = Activity<ZiitoFocusAttributes>.activities.first {
            current = existing
        }
    }

    var isEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(state: ZiitoFocusAttributes.ContentState) {
        guard isEnabled else { return }
        if current != nil {
            update(state: state)
            return
        }
        do {
            let attrs = ZiitoFocusAttributes(startedAt: Date())
            let activity = try Activity<ZiitoFocusAttributes>.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            current = activity
        } catch {
            #if DEBUG
            print("LiveActivity start failed: \(error)")
            #endif
        }
    }

    func update(state: ZiitoFocusAttributes.ContentState) {
        guard let activity = current else { return }
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity = current else { return }
        let finalState = activity.content.state
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        current = nil
    }
}
