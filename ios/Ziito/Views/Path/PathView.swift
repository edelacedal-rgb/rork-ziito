import SwiftUI
import SwiftData
import Combine
import AudioToolbox

// MARK: - Celebration models

struct ZiitoCelebration: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let subjectColor: Color
    let isMonument: Bool
}

struct CelebrationToast: View {
    let celebration: ZiitoCelebration
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(celebration.subjectColor.opacity(0.25))
                        .frame(width: 44, height: 44)
                    Image(systemName: celebration.isMonument ? "building.columns.fill" : "flag.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(celebration.isMonument ? .white : celebration.subjectColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(celebration.title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text(celebration.message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(8)
                        .background(.white.opacity(0.08), in: .circle)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(celebration.subjectColor.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }
}

/// "THE PATH" — the hybrid 3D mountain interface that replaces the old tab hub.
/// Dual-axis: vertical drag = ascent (altitude), horizontal drag = subject rotation (L1).
struct PathView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Query private var allTasks: [StudyTask]
    @Query private var logs: [FocusLog]
    @Query private var exams: [Exam]

    // Camera state
    @State private var altitude: Double = 0
    @State private var rotation: Double = 0          // radians
    @State private var dragStartAltitude: Double = 0
    @State private var dragStartRotation: Double = 0
    @State private var inFogMode: Bool = false
    @State private var showSubjectSheet: Subject? = nil
    @State private var showZenitSheet: Bool = false
    @State private var showAltarSheet: Bool = false
    @State private var nowTick: Date = Date()
    @State private var lastPlantedTaskIds: Set<UUID> = []
    @State private var celebration: ZiitoCelebration? = nil
    @AppStorage("ziito.zenit.goal") private var zenitGoal: String = ""
    @Environment(\.scenePhase) private var scenePhase
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var onStartFocus: () -> Void

    init(onStartFocus: @escaping () -> Void = {}) {
        self.onStartFocus = onStartFocus
    }

    // MARK: - Derived

    /// Dynamic faces — strictly equal to the user's active subjects count
    /// (clamped only to keep a minimum visual prism when there are < 3 subjects).
    private var faceCount: Int {
        max(3, subjects.count)
    }

    private var currentSubjectIndex: Int {
        guard faceCount > 0 else { return 0 }
        let segs = Double(faceCount)
        var normalized = rotation / (2 * .pi)
        normalized -= floor(normalized)
        let idx = Int((normalized * segs + 0.5).rounded(.down)) % faceCount
        return idx
    }

    private var currentSubject: Subject? {
        guard !subjects.isEmpty else { return nil }
        return subjects[currentSubjectIndex % subjects.count]
    }

    private var subjectColors: [UIColor] {
        if subjects.isEmpty {
            return [
                UIColor(red: 0.36, green: 0.32, blue: 0.72, alpha: 1),
                UIColor(red: 0.22, green: 0.55, blue: 0.66, alpha: 1),
                UIColor(red: 0.74, green: 0.42, blue: 0.32, alpha: 1),
                UIColor(red: 0.48, green: 0.34, blue: 0.55, alpha: 1)
            ]
        }
        return subjects.map { UIColor(Color(hex: $0.colorHex) ?? .indigo) }
    }

    private var subjectNames: [String] {
        if subjects.isEmpty {
            return ["RUTA 1", "RUTA 2", "RUTA 3", "RUTA 4"]
        }
        return subjects.map { $0.name }
    }

    private var totalZiitos: Int {
        logs.reduce(0) { $0 + max(1, $1.completedCycles) }
    }

    private var flags: [MountainFlag] {
        // Group completed tasks + focus sessions by subject and lay them along the slope.
        var result: [MountainFlag] = []
        for (sIdx, subject) in subjects.prefix(faceCount).enumerated() {
            let completed = allTasks
                .filter { $0.isCompleted && $0.subjectID == subject.id }
                .sorted { $0.dueDate < $1.dueDate }
            // Each completed focus session also plants a flag on this face.
            let subjectLogs = logs
                .filter { $0.subjectID == subject.id && $0.completedCycles > 0 }
                .sorted { $0.startedAt < $1.startedAt }
            let total = max(1, completed.count + subjectLogs.count)
            var idx = 0
            for task in completed {
                let alt = 0.08 + (Double(idx) / Double(total)) * 0.82
                result.append(MountainFlag(id: task.id, subjectIndex: sIdx, altitude: alt, isMastery: false))
                idx += 1
            }
            for log in subjectLogs {
                let alt = 0.08 + (Double(idx) / Double(total)) * 0.82
                result.append(MountainFlag(id: log.id, subjectIndex: sIdx, altitude: alt, isMastery: false))
                idx += 1
            }
            // Mastery flag near summit if 90%+ of tasks done for that subject
            let allForSubject = allTasks.filter { $0.subjectID == subject.id }
            if allForSubject.count >= 3, Double(completed.count) / Double(allForSubject.count) >= 0.9 {
                result.append(MountainFlag(
                    id: UUID(uuidString: subject.id.uuidString) ?? UUID(),
                    subjectIndex: sIdx,
                    altitude: 0.95,
                    isMastery: true
                ))
            }
        }
        return result
    }

    /// Per-subject Duolingo trail: a fixed run of milestone nodes whose completed
    /// count is driven by finished tasks + focus sessions for that subject.
    private var trailNodes: [MountainTrailNode] {
        var result: [MountainTrailNode] = []
        let nodesPerFace = 6
        for (sIdx, subject) in subjects.prefix(faceCount).enumerated() {
            let completedTasks = allTasks.filter { $0.isCompleted && $0.subjectID == subject.id }.count
            let completedLogs = logs.filter { $0.subjectID == subject.id && $0.completedCycles > 0 }.count
            let done = min(nodesPerFace, completedTasks + completedLogs)
            for i in 0..<nodesPerFace {
                let alt = 0.08 + (Double(i) / Double(nodesPerFace - 1)) * 0.5
                result.append(MountainTrailNode(
                    id: UUID(uuidString: "00000000-0000-0000-\(String(format: "%04d", sIdx))-\(String(format: "%012d", i))") ?? UUID(),
                    subjectIndex: sIdx,
                    altitude: alt,
                    completed: i < done
                ))
            }
        }
        return result
    }

    /// Global unlock progress (0..1) that drives the candy-crush fog reveal.
    private var fogReveal: Double {
        let active = Array(subjects.prefix(faceCount))
        guard !active.isEmpty else { return 0 }
        let nodesPerFace = 6
        var total = 0.0
        for subject in active {
            let completedTasks = allTasks.filter { $0.isCompleted && $0.subjectID == subject.id }.count
            let completedLogs = logs.filter { $0.subjectID == subject.id && $0.completedCycles > 0 }.count
            total += Double(min(nodesPerFace, completedTasks + completedLogs)) / Double(nodesPerFace)
        }
        return total / Double(active.count)
    }

    private var monuments: [MountainMonument] {
        // One monument per Subject reaches 100% completion, sculpted at the foot of the mountain
        // with the subject name engraved in low-relief.
        var result: [MountainMonument] = []
        for (sIdx, subject) in subjects.prefix(faceCount).enumerated() {
            let allForSubject = allTasks.filter { $0.subjectID == subject.id }
            guard !allForSubject.isEmpty else { continue }
            let completed = allForSubject.filter(\.isCompleted).count
            if completed == allForSubject.count {
                result.append(MountainMonument(
                    id: subject.id,
                    subjectIndex: sIdx,
                    altitude: 0,
                    subjectName: subject.name,
                    atBase: true
                ))
            }
        }
        return result
    }

    private var gear: [MountainGear] {
        var result: [MountainGear] = [MountainGear(id: "tent", kind: .tent)]
        if totalZiitos >= 5 { result.append(MountainGear(id: "boots", kind: .boots)) }
        if totalZiitos >= 15 { result.append(MountainGear(id: "axe", kind: .axe)) }
        if totalZiitos >= 30 { result.append(MountainGear(id: "rope", kind: .rope)) }
        if totalZiitos >= 50 { result.append(MountainGear(id: "fire", kind: .fire)) }
        return result
    }

    private var dayPhase: DayPhase { DayPhase.current(date: nowTick) }

    private var hasHighGear: Bool { totalZiitos >= 30 }

    /// Stable signature that only changes when the set of completed task ids changes.
    private var completedTaskSignature: String {
        allTasks.filter(\.isCompleted).map(\.id.uuidString).sorted().joined(separator: ",")
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            skyGradient
                .ignoresSafeArea()

            MountainSceneView(
                subjectColors: subjectColors,
                subjectNames: subjectNames,
                flags: flags,
                monuments: monuments,
                gear: gear,
                dayPhase: dayPhase,
                trail: trailNodes,
                fogReveal: fogReveal,
                altitude: altitude,
                rotation: rotation,
                fogMode: inFogMode
            )
            .ignoresSafeArea()
            .gesture(navigationGesture)

            if inFogMode {
                fogOverlay
            }

            // Respect SafeArea so the Zenit beacon + meta texts never collide with
            // the Dynamic Island / status bar (bug fix).
            VStack(spacing: 0) {
                topRidge
                Spacer()
                bottomAltar
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
            .allowsHitTesting(true)
            .safeAreaPadding(.top)

            if let celebration {
                CelebrationToast(celebration: celebration) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { self.celebration = nil }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(clock) { date in nowTick = date }
        .onChange(of: scenePhase) { _, newValue in
            // Fog penalty: if the user leaves the app while Fog Mode is active,
            // transition wind into a colder blizzard layer for feedback.
            guard inFogMode else { return }
            if newValue == .background || newValue == .inactive {
                FlagFXService.shared.transitionToBlizzard()
            } else if newValue == .active {
                FlagFXService.shared.stopWind()
                FlagFXService.shared.startWind(intensity: 0.35)
            }
        }
        .onAppear {
            lastPlantedTaskIds = Set(allTasks.filter(\.isCompleted).map(\.id))
        }
        .onChange(of: completedTaskSignature) { _, _ in
            detectNewlyCompletedTasks()
        }
        .sheet(item: $showSubjectSheet) { subject in
            SubjectRouteSheet(subject: subject, onStartFocus: onStartFocus)
        }
        .sheet(isPresented: $showZenitSheet) {
            ZenitGoalSheet(totalZiitos: totalZiitos, onStartFocus: {
                showZenitSheet = false
                onStartFocus()
            })
        }
        .task(id: subjects.count) {
            // Force a Zenit goal modal the first time the user reaches The Path.
            if zenitGoal.isEmpty && !subjects.isEmpty {
                showZenitSheet = true
            }
        }
        .sheet(isPresented: $showAltarSheet) {
            AltarOfFlagsSheet(
                subjects: Array(subjects.prefix(faceCount)),
                tasks: allTasks,
                logs: logs
            )
        }
    }

    // MARK: - Sky

    private var skyGradient: some View {
        let colors: [Color] = {
            switch dayPhase {
            case .night: return [Color(red: 0.05, green: 0.06, blue: 0.15), Color(red: 0.10, green: 0.10, blue: 0.22)]
            case .dawn: return [Color(red: 0.95, green: 0.66, blue: 0.55), Color(red: 0.5, green: 0.55, blue: 0.78)]
            case .day: return [Color(red: 0.55, green: 0.78, blue: 0.96), Color(red: 0.88, green: 0.92, blue: 0.98)]
            case .goldenHour: return [Color(red: 1.0, green: 0.55, blue: 0.3), Color(red: 0.55, green: 0.35, blue: 0.55)]
            case .dusk: return [Color(red: 0.35, green: 0.28, blue: 0.5), Color(red: 0.12, green: 0.13, blue: 0.28)]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Top Ridge HUD

    private var topRidge: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap(.medium)
                showZenitSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mountain.2.fill")
                        .font(.subheadline.weight(.bold))
                    Text("ZENIT")
                        .font(.caption.weight(.heavy))
                        .tracking(2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(Capsule().stroke(.white.opacity(0.2)))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(currentSubject?.name.uppercased() ?? "RUTA")
                    .font(.caption2.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(.white)
                Text(zenitGoal.isEmpty
                     ? "\(Int(altitude * 100))% · \(currentSubjectIndex + 1)/\(faceCount)"
                     : zenitGoal)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: .capsule)

            Spacer()

            Button {
                Haptics.tap(.medium)
                inFogMode.toggle()
                if inFogMode {
                    FlagFXService.shared.startWind(intensity: 0.35)
                } else {
                    FlagFXService.shared.stopWind()
                }
            } label: {
                Image(systemName: inFogMode ? "cloud.fog.fill" : "cloud.fog")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: .circle)
                    .overlay(Circle().stroke(.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Altar / Base Camp

    private var bottomAltar: some View {
        VStack(spacing: 14) {
            // Subject dots
            HStack(spacing: 10) {
                ForEach(Array(subjects.prefix(faceCount).enumerated()), id: \.element.id) { idx, s in
                    Circle()
                        .fill(s.color)
                        .frame(width: idx == currentSubjectIndex ? 12 : 7, height: idx == currentSubjectIndex ? 12 : 7)
                        .overlay(Circle().stroke(.white.opacity(idx == currentSubjectIndex ? 0.9 : 0.3), lineWidth: 1))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentSubjectIndex)
                        .onTapGesture {
                            Haptics.tap(.light)
                            snapToSubject(idx)
                        }
                }
            }

            HStack(spacing: 12) {
                glassButton(icon: "flag.checkered", label: "Altar") {
                    showAltarSheet = true
                }
                if let s = currentSubject {
                    glassButton(icon: "list.bullet.below.rectangle", label: s.name) {
                        showSubjectSheet = s
                    }
                }
                glassButton(icon: "play.fill", label: "Subir", emphasized: true) {
                    Haptics.tap(.medium)
                    onStartFocus()
                }
            }

            Text(altitude < 0.05 ? "Desliza arriba para ascender · Desliza al lado para cambiar de ruta" : "Toca tu materia para ver el sendero")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Text("Con cada paso avanzas")
                .font(.caption2.italic())
                .tracking(1)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func glassButton(icon: String, label: String, emphasized: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.subheadline.weight(.bold))
                Text(label).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(emphasized ? .black : .white)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background {
                if emphasized {
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.98), Color.white.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().stroke(.white.opacity(0.5)))
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(.white.opacity(0.18)))
                }
            }
        }
        .buttonStyle(.plain)
        .lineLimit(1)
    }

    // MARK: - Fog Overlay

    private var fogOverlay: some View {
        ZStack {
            // Frosted veil
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .ignoresSafeArea()
                .blendMode(.plusLighter)
            // Vignette
            RadialGradient(
                colors: [.clear, Color(white: 0.92, opacity: 0.5)],
                center: .center,
                startRadius: 80,
                endRadius: 380
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Gestures

    private var navigationGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    // Horizontal: swipe RIGHT rotates the mountain physically to the right.
                    let delta = Double(dx) / 220.0
                    rotation = dragStartRotation + delta
                } else {
                    // Vertical: drag UP increases altitude (ascend to the zenit).
                    let delta = Double(-dy) / 420.0
                    altitude = max(0, min(1, dragStartAltitude + delta))
                }
            }
            .onEnded { _ in
                // Free rotation: the mountain stays exactly where the user released it.
                // No autocenter, no spring-back. The HUD subject is the closest face by angle.
                dragStartAltitude = altitude
                dragStartRotation = rotation
                Haptics.tap(.light)
                if hasHighGear {
                    AudioServicesPlaySystemSound(1104)
                }
            }
    }

    private func snapToSubject(_ idx: Int) {
        let step = (2 * .pi) / Double(faceCount)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            rotation = Double(idx) * step
        }
        dragStartRotation = Double(idx) * step
    }

    private func detectNewlyCompletedTasks() {
        let completedNow = Set(allTasks.filter(\.isCompleted).map(\.id))
        let newly = completedNow.subtracting(lastPlantedTaskIds)
        if !newly.isEmpty {
            // Plant flag effect for the most recent completion
            FlagFXService.shared.playFlagPlant(mastery: false)
            // Build a contextual celebration for the most recent completion
            if let id = newly.first,
               let task = allTasks.first(where: { $0.id == id }) {
                let subject = subjects.first { $0.id == task.subjectID }
                let allForSubject = allTasks.filter { $0.subjectID == task.subjectID }
                let doneForSubject = allForSubject.filter(\.isCompleted).count
                let totalForSubject = allForSubject.count
                let monumentJustSculpted = totalForSubject > 0 && doneForSubject == totalForSubject
                if monumentJustSculpted {
                    FlagFXService.shared.playMonumentSculpt()
                }
                let message = celebrationMessage(
                    subjectName: subject?.name,
                    done: doneForSubject,
                    total: totalForSubject,
                    monument: monumentJustSculpted
                )
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    celebration = ZiitoCelebration(
                        title: monumentJustSculpted ? "¡Monumento esculpido!" : "¡Ziito conquistado!",
                        message: message,
                        subjectColor: subject?.color ?? .green,
                        isMonument: monumentJustSculpted
                    )
                }
                // Auto-dismiss after a few seconds
                let activeId = celebration?.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        if celebration?.id == activeId { celebration = nil }
                    }
                }
            }
        }
        lastPlantedTaskIds = completedNow
    }

    private func celebrationMessage(subjectName: String?, done: Int, total: Int, monument: Bool) -> String {
        guard let name = subjectName, total > 0 else {
            return "Cada paso cuenta. Sigue subiendo."
        }
        if monument {
            return "Has esculpido el monumento de \(name) en la falda de la montaña."
        }
        let progress = Double(done) / Double(total)
        switch progress {
        case ..<0.25:
            return "Primer paso en la ruta de \(name). El campamento queda atrás."
        case ..<0.5:
            return "Subes con paso firme en \(name) (\(done)/\(total))."
        case ..<0.75:
            return "Estás a la mitad del camino de la montaña de \(name)."
        case ..<1:
            return "La cumbre de \(name) está a la vista (\(done)/\(total))."
        default:
            return "Cumbre de \(name) conquistada."
        }
    }
}

