import AppIntents
import Foundation

/// Notification names posted by the Live Activity intents.
/// The main app observes these to mutate `PomodoroService`.
public extension Notification.Name {
    static let ziitoFocusTogglePause = Notification.Name("ziito.focus.togglePause")
    static let ziitoFocusStop = Notification.Name("ziito.focus.stop")
}

/// Tap "Pausar / Reanudar" from the Dynamic Island or Lock Screen.
public struct ZiitoTogglePauseIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Pausar o reanudar"
    public static var description = IntentDescription("Pausa o reanuda la sesión de enfoque actual.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ziitoFocusTogglePause, object: nil)
        return .result()
    }
}

/// Tap "Detener" from the Dynamic Island or Lock Screen.
public struct ZiitoStopFocusIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Detener sesión"
    public static var description = IntentDescription("Termina la sesión de enfoque y guarda el progreso.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ziitoFocusStop, object: nil)
        return .result()
    }
}
