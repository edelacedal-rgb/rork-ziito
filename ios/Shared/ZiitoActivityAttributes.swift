import ActivityKit
import Foundation

/// Attributes for the Fog Mode (focus session) Live Activity.
/// Shared between the main app and the widget extension so they refer to the same type.
nonisolated public struct ZiitoFocusAttributes: ActivityAttributes {
    public typealias ZiitoFocusStatus = ContentState

    nonisolated public struct ContentState: Codable, Hashable, Sendable {
        /// When the current phase will reach 00:00 (live-tick reference).
        public var endDate: Date
        public var isPaused: Bool
        /// Remaining seconds when paused (so the UI freezes correctly).
        public var pausedRemaining: TimeInterval
        /// "focus" | "shortBreak" | "longBreak".
        public var phaseRaw: String
        public var subjectName: String
        public var subjectColorHex: String

        public init(
            endDate: Date,
            isPaused: Bool,
            pausedRemaining: TimeInterval,
            phaseRaw: String,
            subjectName: String,
            subjectColorHex: String
        ) {
            self.endDate = endDate
            self.isPaused = isPaused
            self.pausedRemaining = pausedRemaining
            self.phaseRaw = phaseRaw
            self.subjectName = subjectName
            self.subjectColorHex = subjectColorHex
        }
    }

    public var startedAt: Date

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }
}
