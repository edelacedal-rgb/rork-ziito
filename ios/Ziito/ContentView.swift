import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingFocus = false
    @State private var selection: Tab = .today
    var pomodoro = PomodoroService.shared
    var tour = TourManager.shared

    @Query private var subjects: [Subject]
    @Query private var classes: [ClassSession]
    @Query private var exams: [Exam]

    enum Tab: Hashable, CaseIterable {
        case today, schedule, path, more

        var label: String {
            switch self {
            case .today: return "Hoy"
            case .schedule: return "Horario"
            case .path: return "Montaña"
            case .more: return "Más"
            }
        }

        var icon: String {
            switch self {
            case .today: return "sun.max"
            case .schedule: return "calendar"
            case .path: return "mountain.2"
            case .more: return "ellipsis"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.zBackground.ignoresSafeArea()

            // Active screen
            Group {
                switch selection {
                case .today:
                    TodayView(onStartFocus: { showingFocus = true })
                case .schedule:
                    ScheduleView()
                case .path:
                    PathView(onStartFocus: { showingFocus = true })
                        .ignoresSafeArea(edges: .bottom)
                case .more:
                    NavigationStack { MoreView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom stack: active-focus bar + custom tab bar
            VStack(spacing: 0) {
                if pomodoro.isRunning && !showingFocus {
                    ActiveFocusBar(onTap: { showingFocus = true })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ZTabBar(selection: $selection)
            }

            // Guided tour overlay (above the tab bar)
            if tour.isActive {
                GuidedTourView(onFinish: { selection = .today })
                    .padding(.bottom, 96)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pomodoro.isRunning)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: tour.isActive)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: tour.step)
        .fullScreenCover(isPresented: $showingFocus) {
            NavigationStack {
                FocusModeView(onMinimize: { showingFocus = false })
            }
        }
        .task {
            let isEmpty = subjects.isEmpty && classes.isEmpty && exams.isEmpty
            tour.autoStartIfNeeded(isEmpty: isEmpty)
        }
    }
}

/// Custom bottom tab bar matching the web's `TabBar` (card surface, fill-on-active icons).
private struct ZTabBar: View {
    @Binding var selection: ContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                let isActive = tab == selection
                Button {
                    Haptics.tap(.light)
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isActive ? "\(tab.icon).fill" : tab.icon)
                            .font(.system(size: 22, weight: isActive ? .bold : .regular))
                            .symbolRenderingMode(.monochrome)
                        Text(tab.label)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(isActive ? Color.zPrimary : Color.zMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .background(
            Color.zCardBG
                .overlay(Rectangle().fill(Color.zBorder).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// "Más" hub matching the web More page (grouped rows of links).
struct MoreView: View {
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ZScreenHeader(title: "Más")

                section("Planificación") {
                    NavigationLink { TasksView() } label: { row("Tareas", "checklist") }
                    Divider().background(Color.zBorder)
                    NavigationLink { ExamsView() } label: { row("Evaluaciones", "pencil.and.list.clipboard") }
                    Divider().background(Color.zBorder)
                    NavigationLink { CalendarView() } label: { row("Calendario", "calendar") }
                    Divider().background(Color.zBorder)
                    NavigationLink { SubjectsView() } label: { row("Materias", "books.vertical") }
                }

                section("Estudio") {
                    NavigationLink { StatsView() } label: { row("Estadísticas", "chart.bar.xaxis") }
                }

                section("Enfoque") {
                    Button { showSettings = true } label: { row("Configurar Pomodoro", "timer") }
                        .buttonStyle(.plain)
                }

                section("Primeros pasos") {
                    Button { TourManager.shared.start() } label: { row("Guía del plan inteligente", "sparkles") }
                        .buttonStyle(.plain)
                }

                Text("Ziito funciona offline. Usa la pestaña Montaña para visualizar tu ascenso, y el resto de secciones para planificar tu estudio. Con cada paso avanzas.")
                    .font(.footnote)
                    .foregroundStyle(.zMuted)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .background(Color.zBackground)
        .scrollContentBackground(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) { PomodoroSettingsView() }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.zMuted)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .zCard()
        }
    }

    private func row(_ label: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.zPrimary)
                .frame(width: 36, height: 36)
                .background(Color.zPrimary.opacity(0.1), in: .rect(cornerRadius: 9))
            Text(label)
                .font(.body.weight(.medium))
                .foregroundStyle(.zForeground)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.zMuted.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(.rect)
    }
}

struct ActiveFocusBar: View {
    var pomodoro = PomodoroService.shared
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: pomodoro.phase == .focus ? "mountain.2.fill" : "cup.and.saucer.fill")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(pomodoro.phase.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(pomodoro.formattedRemaining)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.zPrimary, in: .capsule)
            .shadow(color: Color.zPrimary.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Subject.self, Exam.self, StudySession.self, StudyTask.self, ClassSession.self, FocusLog.self], inMemory: true)
}
