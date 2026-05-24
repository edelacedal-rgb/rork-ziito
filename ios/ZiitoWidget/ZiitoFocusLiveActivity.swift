import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Color hex helper (widget-local so it doesn't depend on the main app module)

private extension Color {
    init?(focusHex: String) {
        let hex = focusHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

private func phaseLabel(_ raw: String) -> String {
    switch raw {
    case "focus": return "Enfoque"
    case "shortBreak": return "Descanso"
    case "longBreak": return "Descanso largo"
    default: return raw.capitalized
    }
}

private func pausedTimeString(_ t: TimeInterval) -> String {
    let total = max(0, Int(t.rounded()))
    return String(format: "%02d:%02d", total / 60, total % 60)
}

// MARK: - Live Activity

struct ZiitoFocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ZiitoFocusAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let subjectColor = Color(focusHex: context.state.subjectColorHex) ?? .white

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "mountain.2.fill")
                                .foregroundStyle(subjectColor)
                            Text(context.state.subjectName.isEmpty ? "Ziito" : context.state.subjectName)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Text(phaseLabel(context.state.phaseRaw).uppercased())
                            .font(.caption2.weight(.heavy))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timerText(state: context.state, big: true)
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Button(intent: ZiitoTogglePauseIntent()) {
                            Label(
                                context.state.isPaused ? "Reanudar" : "Pausar",
                                systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .tint(.white)

                        Button(intent: ZiitoStopFocusIntent()) {
                            Label("Detener", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.white.opacity(0.65))
                    }
                }
            } compactLeading: {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(subjectColor)
            } compactTrailing: {
                timerText(state: context.state, big: false)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "mountain.2.fill")
                    .foregroundStyle(subjectColor)
            }
            .keylineTint(subjectColor)
        }
    }

    @ViewBuilder
    private func timerText(state: ZiitoFocusAttributes.ContentState, big: Bool) -> some View {
        if state.isPaused {
            Text(pausedTimeString(state.pausedRemaining))
                .font(big ? .title3.monospacedDigit().weight(.heavy) : .caption.monospacedDigit().weight(.bold))
        } else {
            Text(timerInterval: Date.now...state.endDate, countsDown: true)
                .font(big ? .title3.monospacedDigit().weight(.heavy) : .caption.monospacedDigit().weight(.bold))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Lock Screen / banner view

private struct LockScreenView: View {
    let state: ZiitoFocusAttributes.ContentState

    var body: some View {
        let subjectColor = Color(focusHex: state.subjectColorHex) ?? .white

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(subjectColor.opacity(0.25))
                        .frame(width: 32, height: 32)
                    Image(systemName: "mountain.2.fill")
                        .foregroundStyle(subjectColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.subjectName.isEmpty ? "Ziito" : state.subjectName)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(phaseLabel(state.phaseRaw).uppercased())
                        .font(.caption2.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                if state.isPaused {
                    Label("Pausado", systemImage: "pause.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12), in: .capsule)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Group {
                    if state.isPaused {
                        Text(pausedTimeString(state.pausedRemaining))
                    } else {
                        Text(timerInterval: Date.now...state.endDate, countsDown: true)
                    }
                }
                .font(.system(size: 38, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                Spacer()
            }

            if !state.isPaused {
                ProgressView(
                    timerInterval: Date.now...state.endDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.linear)
                .tint(subjectColor)
            } else {
                ProgressView(value: 0)
                    .progressViewStyle(.linear)
                    .tint(.white.opacity(0.4))
            }

            HStack(spacing: 10) {
                Button(intent: ZiitoTogglePauseIntent()) {
                    Label(
                        state.isPaused ? "Reanudar" : "Pausar",
                        systemImage: state.isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .tint(.white)
                .buttonStyle(.bordered)

                Button(intent: ZiitoStopFocusIntent()) {
                    Label("Detener", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.white.opacity(0.7))
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
    }
}
