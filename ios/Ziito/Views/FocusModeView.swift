import SwiftUI
import SwiftData
import AVFoundation

/// FOG MODE — Deep Focus engine.
/// Replaces the deprecated "Study Tree". Camera is locked on a stone rock face;
/// dense mist hides the rest of the mountain. White-noise alpine wind.
/// If the app loses focus, the audio transitions to a blizzard and a frost
/// shader is applied on top.
struct FocusModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var subjects: [Subject]

    var pomodoro = PomodoroService.shared
    /// Closes the cover WITHOUT stopping the timer (multitasking).
    var onMinimize: () -> Void = {}

    @State private var showingSettings = false
    @State private var showingStop = false
    @State private var grainOffset: CGFloat = 0
    @State private var blizzard: Bool = false
    @State private var frostOpacity: Double = 0
    @State private var pulse: CGFloat = 0
    @State private var flashReward: Bool = false

    var body: some View {
        ZStack {
            rockBackground
                .ignoresSafeArea()

            // Dense mist
            mistVeil
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Frost overlay (when app loses focus)
            frostOverlay
                .opacity(frostOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 22) {
                topBar
                    .padding(.top, 8)

                Spacer(minLength: 0)

                phaseLabel
                timerDisplay
                    .scaleEffect(1 + pulse * 0.012)
                cyclesIndicator

                Spacer(minLength: 0)

                controls

                if pomodoro.mode == .pomodoro {
                    Button { showingSettings = true } label: {
                        Label("Ajustar Pomodoro", systemImage: "slider.horizontal.3")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            if blizzard {
                blizzardBanner
                    .padding(.top, 48)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .onAppear {
            if !pomodoro.isRunning {
                pomodoro.start(mode: .pomodoro)
            }
            FlagFXService.shared.startWind(intensity: 0.35)
            startAnimations()
            // Wire the automatic reward: only fires when the focus timer reaches 00:00.
            pomodoro.onFocusCompleted = { _ in
                FlagFXService.shared.playFlagPlant(mastery: false)
                // Duolingo-style reward: XP, streak advance and a refilled heart.
                GamificationService.shared.registerStudyCompletion(cycles: 1)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { flashReward = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.easeOut(duration: 0.4)) { flashReward = false }
                }
            }
        }
        .onDisappear {
            FlagFXService.shared.stopWind()
            pomodoro.onFocusCompleted = nil
        }
        .onChange(of: scenePhase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
        .sheet(isPresented: $showingSettings) {
            PomodoroSettingsView()
        }
        .confirmationDialog("¿Abandonar la pared?", isPresented: $showingStop, titleVisibility: .visible) {
            Button("Sí, descender", role: .destructive) {
                pomodoro.stop(modelContext: modelContext)
                FlagFXService.shared.stopWind()
                dismiss()
            }
            Button("Seguir escalando", role: .cancel) {}
        } message: {
            Text("Si bajas ahora, no plantarás bandera en este tramo.")
        }
    }

    // MARK: - Background

    private var rockBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.16, blue: 0.18),
                    Color(red: 0.08, green: 0.08, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Procedural rock texture using stacked offset ellipses
            Canvas { ctx, size in
                let cols = 14
                let rows = 24
                let cellW = size.width / CGFloat(cols)
                let cellH = size.height / CGFloat(rows)
                for r in 0..<rows {
                    for c in 0..<cols {
                        let jitterX = CGFloat.random(in: -6...6)
                        let jitterY = CGFloat.random(in: -3...3)
                        let rect = CGRect(
                            x: CGFloat(c) * cellW + jitterX,
                            y: CGFloat(r) * cellH + jitterY,
                            width: cellW * CGFloat.random(in: 0.85...1.1),
                            height: cellH * CGFloat.random(in: 0.8...1.05)
                        )
                        let g = Double.random(in: 0.18...0.32)
                        let path = Path(roundedRect: rect, cornerRadius: 2)
                        ctx.fill(path, with: .color(Color(white: g)))
                        ctx.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 0.8)
                    }
                }
            }
            .blur(radius: 0.5)
            .opacity(0.85)
        }
    }

    private var mistVeil: some View {
        ZStack {
            // Soft moving mist using radial gradients
            RadialGradient(
                colors: [Color.white.opacity(0.16), .clear],
                center: UnitPoint(x: 0.3, y: 0.4),
                startRadius: 30,
                endRadius: 320
            )
            RadialGradient(
                colors: [Color.white.opacity(0.13), .clear],
                center: UnitPoint(x: 0.75, y: 0.65),
                startRadius: 40,
                endRadius: 380
            )
            LinearGradient(
                colors: [
                    Color(white: 0.85, opacity: 0.18),
                    .clear,
                    Color(white: 0.7, opacity: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .blendMode(.plusLighter)
    }

    private var frostOverlay: some View {
        ZStack {
            // Bluish overlay
            Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.2)
            // Edge frost vignette
            RadialGradient(
                colors: [.clear, Color.white.opacity(0.4)],
                center: .center,
                startRadius: 120,
                endRadius: 480
            )
            // Snowflake glints
            Canvas { ctx, size in
                for _ in 0..<60 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let r = CGFloat.random(in: 0.6...1.6)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.6)))
                }
            }
        }
        .blendMode(.plusLighter)
    }

    // MARK: - HUD

    private var topBar: some View {
        HStack {
            // Minimize: closes the cover but KEEPS the timer running in background.
            Button {
                onMinimize()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("FOG MODE")
                .font(.caption.weight(.heavy))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            // Stop: destroys the session.
            Button {
                showingStop = true
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .buttonStyle(.plain)
        }
    }

    private var phaseLabel: some View {
        Text(pomodoro.phase.label.uppercased())
            .font(.caption.weight(.heavy))
            .tracking(3)
            .foregroundStyle(.white.opacity(0.7))
    }

    private var timerDisplay: some View {
        Text(pomodoro.formattedRemaining)
            .font(.system(size: 84, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }

    private var cyclesIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pomodoro.settings.cyclesUntilLongBreak, id: \.self) { i in
                Circle()
                    .fill(i < pomodoro.completedFocusCycles % pomodoro.settings.cyclesUntilLongBreak
                          ? Color.white
                          : Color.white.opacity(0.18))
                    .frame(width: 9, height: 9)
            }
        }
    }

    // No manual flag button: the reward is triggered automatically when the timer hits 00:00.
    private var controls: some View {
        HStack(spacing: 18) {
            controlButton(icon: "forward.fill") {
                pomodoro.skipPhase()
            }
            controlButton(icon: pomodoro.isPaused ? "play.fill" : "pause.fill", large: true) {
                if pomodoro.isPaused { pomodoro.resume() } else { pomodoro.pause() }
            }
            controlButton(icon: "chevron.down") {
                onMinimize()
            }
        }
        .overlay(alignment: .top) {
            if flashReward {
                Label("¡Bandera plantada!", systemImage: "flag.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white, in: .capsule)
                    .offset(y: -54)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func controlButton(icon: String, large: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.tap(.medium)
            action()
        }) {
            Image(systemName: icon)
                .font(large ? .title2.weight(.bold) : .title3.weight(.semibold))
                .foregroundStyle(large ? .black : .white)
                .frame(width: large ? 72 : 54, height: large ? 72 : 54)
                .background {
                    Circle().fill(large ? Color.white : Color.white.opacity(0.12))
                }
                .overlay(Circle().stroke(.white.opacity(large ? 0 : 0.18)))
        }
        .buttonStyle(.plain)
    }

    private var blizzardBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wind.snow")
                .foregroundStyle(.white)
            Text("Blizzard activado — vuelve a la app")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay(Capsule().stroke(.white.opacity(0.2)))
    }

    // MARK: - Animations / Phase

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            pulse = 1
        }
    }

    private func handlePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if blizzard {
                withAnimation(.easeOut(duration: 0.6)) {
                    blizzard = false
                    frostOpacity = 0
                }
                FlagFXService.shared.startWind(intensity: 0.35)
            }
        case .inactive, .background:
            if pomodoro.isRunning && !pomodoro.isPaused {
                FlagFXService.shared.transitionToBlizzard()
                withAnimation(.easeIn(duration: 0.6)) {
                    blizzard = true
                    frostOpacity = 1
                }
            }
        @unknown default:
            break
        }
    }
}

// MARK: - Pomodoro Settings (kept for compatibility)

struct PomodoroSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PomodoroSettings = PomodoroService.shared.settings

    var body: some View {
        NavigationStack {
            Form {
                Section("Duraciones") {
                    Stepper("Enfoque: \(draft.focusMinutes) min", value: $draft.focusMinutes, in: 5...90, step: 5)
                    Stepper("Descanso corto: \(draft.shortBreakMinutes) min", value: $draft.shortBreakMinutes, in: 1...30)
                    Stepper("Descanso largo: \(draft.longBreakMinutes) min", value: $draft.longBreakMinutes, in: 5...60, step: 5)
                }
                Section("Ciclos") {
                    Stepper("Ciclos hasta descanso largo: \(draft.cyclesUntilLongBreak)", value: $draft.cyclesUntilLongBreak, in: 2...8)
                }
            }
            .navigationTitle("Pomodoro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        PomodoroService.shared.updateSettings(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
