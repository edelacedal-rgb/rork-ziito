import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showingFocus = false
    @State private var selection: Tab = .today
    var pomodoro = PomodoroService.shared

    enum Tab: Hashable {
        case today, schedule, path, more
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView(onStartFocus: { showingFocus = true })
            }
            .tabItem { Label("Hoy", systemImage: "sun.max.fill") }
            .tag(Tab.today)

            NavigationStack {
                ScheduleView()
            }
            .tabItem { Label("Horario", systemImage: "calendar.day.timeline.left") }
            .tag(Tab.schedule)

            PathTab(onStartFocus: { showingFocus = true })
                .tabItem { Label("Montaña", systemImage: "mountain.2.fill") }
                .tag(Tab.path)

            NavigationStack {
                MoreList()
            }
            .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
            .tag(Tab.more)
        }
        // Use a bottom safe-area inset so the paused/active timer bar PUSHES content up
        // instead of overlapping vital buttons like "Subir" on The Path.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pomodoro.isRunning && !showingFocus {
                ActiveFocusBar(onTap: { showingFocus = true })
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pomodoro.isRunning)
        .fullScreenCover(isPresented: $showingFocus) {
            NavigationStack {
                FocusModeView(onMinimize: { showingFocus = false })
            }
        }
    }
}

/// Wraps the 3D mountain experience as a single dedicated section.
private struct PathTab: View {
    let onStartFocus: () -> Void

    var body: some View {
        PathView(onStartFocus: onStartFocus)
            .ignoresSafeArea(edges: .bottom)
    }
}

struct ActiveFocusBar: View {
    var pomodoro = PomodoroService.shared
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 36, height: 36)
                    Image(systemName: pomodoro.phase == .focus ? "figure.climbing" : "cup.and.saucer.fill")
                        .foregroundStyle(.white)
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
            .background(.ultraThinMaterial, in: .capsule)
            .overlay(Capsule().stroke(.white.opacity(0.22)))
        }
        .buttonStyle(.plain)
    }
}

/// Secondary planning & focus screens kept intact from the previous structure.
struct MoreList: View {
    var body: some View {
        List {
            Section("Planificación") {
                NavigationLink { TasksView() } label: {
                    Label("Tareas", systemImage: "checklist")
                }
                NavigationLink { ExamsView() } label: {
                    Label("Evaluaciones", systemImage: "pencil.and.list.clipboard")
                }
                NavigationLink { CalendarView() } label: {
                    Label("Calendario", systemImage: "calendar")
                }
                NavigationLink { SubjectsView() } label: {
                    Label("Materias", systemImage: "books.vertical")
                }
            }

            Section("Estudio") {
                NavigationLink { StatsView() } label: {
                    Label("Estadísticas", systemImage: "chart.bar.xaxis")
                }
            }

            Section("Enfoque") {
                NavigationLink { PomodoroSettingsView() } label: {
                    Label("Configurar Pomodoro", systemImage: "timer")
                }
            }

            Section {
                Text("Ziito funciona offline. Usa la pestaña Montaña para visualizar tu ascenso, y el resto de secciones para planificar tu estudio.\n\nCon cada paso avanzas.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Más")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Subject.self, Exam.self, StudySession.self, StudyTask.self, ClassSession.self, FocusLog.self, Source.self, NotebookPage.self, Flashcard.self], inMemory: true)
}
