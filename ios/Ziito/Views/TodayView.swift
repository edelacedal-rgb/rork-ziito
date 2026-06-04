import SwiftUI
import SwiftData
import Combine

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlannerViewModel()
    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query private var subjects: [Subject]
    @Query(sort: \StudyTask.dueDate) private var tasks: [StudyTask]
    @Query private var classes: [ClassSession]
    @State private var nowTick: Date = Date()
    @State private var showExams = false
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var onStartFocus: () -> Void

    init(onStartFocus: @escaping () -> Void = {}) {
        self.onStartFocus = onStartFocus
    }

    private var schedule: ScheduleService { ScheduleService.shared }
    private var pomodoro: PomodoroService { PomodoroService.shared }

    private var currentClass: ClassSession? { schedule.currentClass(at: nowTick, classes: classes) }
    private var todayClasses: [ClassSession] { schedule.classesFor(date: nowTick, classes: classes) }

    private var todaySessions: [StudySession] { viewModel.sessionsFor(date: Date()) }
    private var todayTasks: [StudyTask] {
        tasks.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: Date()) && !$0.isCompleted }
    }
    private var hasPlan: Bool { !viewModel.studySessions.isEmpty }

    private var nowMin: Int { ClassSession.minutes(from: nowTick) }
    private var nextClass: ClassSession? { todayClasses.first { $0.startMinuteOfDay > nowMin } }
    private var freeMinutes: Int {
        if let next = nextClass { return next.startMinuteOfDay - nowMin }
        return 22 * 60 - nowMin
    }
    private var isStudyMoment: Bool {
        currentClass == nil && freeMinutes >= 25 && nowMin >= 8 * 60 && nowMin < 22 * 60
    }

    private func subjectOf(_ id: UUID?) -> Subject? { subjects.first { $0.id == id } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZScreenHeader(title: "Hoy", trailing: AnyView(planButton))

                GamificationBar()

                headerCard
                studyMomentBanner

                if !todayClasses.isEmpty { scheduleTimeline }

                if !hasPlan {
                    emptyPlanState
                } else if todaySessions.isEmpty && todayTasks.isEmpty {
                    freeDay
                } else {
                    if !todayTasks.isEmpty { todayTasksSection }
                    if !todaySessions.isEmpty { todaySessionsSection }
                }

                upcomingTasksSection
                upcomingExamsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .background(Color.zBackground)
        .scrollContentBackground(.hidden)
        .onAppear {
            viewModel.loadSessions(modelContext: modelContext)
            viewModel.loadTasks(modelContext: modelContext)
        }
        .onReceive(timer) { nowTick = $0 }
        .sheet(isPresented: $showExams) {
            NavigationStack { ExamsView() }
        }
    }

    private var planButton: some View {
        Button(action: generatePlan) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.caption2)
                Text("Plan").font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.zPrimary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.zSecondaryBG, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGeneratingPlan)
    }

    private var headerCard: some View {
        let totalItems = todaySessions.count + todayTasks.count
        let completedItems = todaySessions.filter(\.isCompleted).count
        return VStack(alignment: .leading, spacing: 6) {
            Text(ZDate.greeting()).font(.title3.weight(.bold)).foregroundStyle(.zForeground)
            Text(ZDate.longDate()).font(.subheadline).foregroundStyle(.zMuted)
            if totalItems > 0 {
                HStack(spacing: 8) {
                    Text("\(completedItems)/\(totalItems) completadas")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(completedItems == totalItems ? Color.zPrimary : Color.zMuted)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.zSecondaryBG)
                            Capsule()
                                .fill(completedItems == totalItems ? Color.zPrimary : Color.zAccent)
                                .frame(width: geo.size.width * (totalItems > 0 ? CGFloat(completedItems) / CGFloat(totalItems) : 0))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.zCardBG.opacity(0.7), in: .rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.zPrimary.opacity(0.15), lineWidth: 1))
    }

    @ViewBuilder
    private var studyMomentBanner: some View {
        if let c = currentClass {
            inClassBanner(c)
        } else if isStudyMoment {
            studyMomentCard
        } else {
            startFocusCard
        }
    }

    private func inClassBanner(_ c: ClassSession) -> some View {
        let subject = subjectOf(c.subjectID)
        let color = subject?.color ?? .zPrimary
        return HStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("En clase ahora").font(.caption.weight(.semibold)).foregroundStyle(.zMuted)
                Text(subject?.name ?? (c.customName.isEmpty ? "Clase" : c.customName)).font(.headline)
                Text("Hasta las \(c.endTimeString)").font(.caption).foregroundStyle(.zMuted)
            }
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.10), in: .rect(cornerRadius: 16))
    }

    private var studyMomentCard: some View {
        Button(action: onStartFocus) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(.white.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: "leaf.fill").foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Es momento de estudiar").font(.headline).foregroundStyle(.white)
                    Text("Tienes \(freeMinutes) min libres. Inicia un Pomodoro.")
                        .font(.caption).foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(Color.zPrimary)
                    .frame(width: 40, height: 40)
                    .background(.white, in: .circle)
            }
            .padding(16)
            .background(
                LinearGradient(colors: [.zPrimary, .zPrimaryBright], startPoint: .leading, endPoint: .trailing),
                in: .rect(cornerRadius: 24)
            )
            .shadow(color: .zPrimary.opacity(0.3), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var startFocusCard: some View {
        Button(action: onStartFocus) {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .foregroundStyle(Color.zPrimary)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(Color.zPrimary.opacity(0.1), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pomodoro.isRunning ? "Sesión en curso" : "Inicia una sesión de enfoque")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.zForeground)
                    Text(pomodoro.isRunning ? "Toca para volver al modo enfocado." : "Pomodoro · Modo inmersivo · Sin distracciones")
                        .font(.caption).foregroundStyle(.zMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).foregroundStyle(.zMuted.opacity(0.5))
            }
            .padding(16)
            .zCard()
        }
        .buttonStyle(.plain)
    }

    private var scheduleTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tu día").font(.headline).foregroundStyle(.zForeground)
            VStack(spacing: 0) {
                ForEach(Array(todayClasses.enumerated()), id: \.element.id) { idx, c in
                    timelineRow(c: c, isLast: idx == todayClasses.count - 1)
                }
            }
            .padding(12)
            .zCard()
        }
    }

    private func timelineRow(c: ClassSession, isLast: Bool) -> some View {
        let subject = subjectOf(c.subjectID)
        let color = subject?.color ?? .zPrimary
        let isPast = nowMin >= c.endMinuteOfDay
        let isCurrent = nowMin >= c.startMinuteOfDay && nowMin < c.endMinuteOfDay
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().stroke(color.opacity(0.4), lineWidth: 2).frame(width: 16, height: 16)
                    if isCurrent {
                        Circle().fill(color).frame(width: 9, height: 9)
                    } else if isPast {
                        Circle().fill(color.opacity(0.4)).frame(width: 9, height: 9)
                    }
                }
                if !isLast {
                    Rectangle().fill(color.opacity(0.25)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(c.startTimeString) – \(c.endTimeString)").font(.caption).foregroundStyle(.zMuted)
                Text(subject?.name ?? (c.customName.isEmpty ? "Clase" : c.customName))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPast ? Color.zMuted : Color.zForeground)
                    .strikethrough(isPast)
            }
            Spacer()
            if isCurrent {
                Text("Ahora")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(color.opacity(0.15), in: .capsule)
            }
        }
        .padding(.vertical, 6)
    }

    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tareas de hoy").font(.headline).foregroundStyle(.zForeground)
            VStack(spacing: 8) {
                ForEach(todayTasks) { task in
                    CheckRow(
                        title: task.title,
                        subtitle: subjectOf(task.subjectID)?.name,
                        done: task.isCompleted,
                        color: subjectOf(task.subjectID)?.color,
                        priority: task.priority,
                        onToggle: { viewModel.toggleTaskCompletion(task, modelContext: modelContext) }
                    )
                }
            }
        }
    }

    private var todaySessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Qué estudiar hoy").font(.headline).foregroundStyle(.zForeground)
            VStack(spacing: 8) {
                ForEach(todaySessions) { session in
                    if let exam = exams.first(where: { $0.id == session.examID }),
                       let subject = subjectOf(session.subjectID) {
                        CheckRow(
                            title: exam.title,
                            subtitle: "\(subject.name) · \(session.durationMinutes) min",
                            done: session.isCompleted,
                            color: subject.color,
                            priority: exam.priority,
                            onToggle: { viewModel.toggleSessionCompletion(session, modelContext: modelContext) }
                        )
                    }
                }
            }
        }
    }

    private var upcomingTasksSection: some View {
        let upcoming = tasks
            .filter { !$0.isCompleted && $0.daysUntil >= 0 && !Calendar.current.isDate($0.dueDate, inSameDayAs: Date()) }
            .sorted { $0.dueDate < $1.dueDate }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Próximas tareas").font(.headline).foregroundStyle(.zForeground)
            if upcoming.isEmpty {
                Text("No hay tareas pendientes")
                    .font(.subheadline).foregroundStyle(.zMuted)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(upcoming.prefix(3)) { task in
                        MiniRow(title: task.title, subtitle: subjectOf(task.subjectID)?.name,
                                color: subjectOf(task.subjectID)?.color ?? .zPrimary, days: task.daysUntil)
                    }
                }
            }
        }
    }

    private var upcomingExamsSection: some View {
        let upcoming = exams.filter { $0.daysUntil >= 0 && !$0.isCompleted }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Próximas evaluaciones").font(.headline).foregroundStyle(.zForeground)
            if upcoming.isEmpty {
                Text("No hay evaluaciones registradas")
                    .font(.subheadline).foregroundStyle(.zMuted)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(upcoming.prefix(5)) { exam in
                        if let subject = subjectOf(exam.subjectID) {
                            MiniRow(title: exam.title, subtitle: subject.name, color: subject.color, days: exam.daysUntil)
                        }
                    }
                }
            }
            Button { showExams = true } label: {
                Text("Gestionar evaluaciones")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.zMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(Color.zBorder))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var emptyPlanState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus").font(.system(size: 52)).foregroundStyle(.zPrimary.opacity(0.6))
            VStack(spacing: 4) {
                Text("Genera tu plan de estudio").font(.title3.weight(.semibold)).foregroundStyle(.zForeground)
                Text("La app creará un calendario inteligente basado en tus evaluaciones y prioridades.")
                    .font(.subheadline).foregroundStyle(.zMuted).multilineTextAlignment(.center)
            }
            Button(action: generatePlan) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Crear plan inteligente").fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(Color.zPrimary, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 40).frame(maxWidth: .infinity)
    }

    private var freeDay: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.fill").font(.system(size: 48)).foregroundStyle(.zAccent.opacity(0.7))
            Text("Día libre de estudio").font(.title3.weight(.semibold)).foregroundStyle(.zForeground)
            Text("No tienes sesiones ni tareas para hoy. ¡Descansa o adelanta otra materia!")
                .font(.subheadline).foregroundStyle(.zMuted).multilineTextAlignment(.center)
        }
        .padding(.vertical, 40).frame(maxWidth: .infinity)
    }

    private func generatePlan() {
        Haptics.tap(.light)
        viewModel.generatePlan(modelContext: modelContext)
    }
}

/// Web-style checkbox row used in Hoy.
struct CheckRow: View {
    let title: String
    let subtitle: String?
    let done: Bool
    let color: Color?
    let priority: PriorityLevel
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(done ? Color.zPrimary : (color ?? .zPrimary), lineWidth: 2)
                        .background(Circle().fill(done ? Color.zPrimary : .clear))
                        .frame(width: 24, height: 24)
                    if done {
                        Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(done ? Color.zMuted : Color.zForeground)
                    .strikethrough(done)
                if let subtitle {
                    HStack(spacing: 6) {
                        if let color { Circle().fill(color).frame(width: 8, height: 8) }
                        Text(subtitle).font(.caption).foregroundStyle(.zMuted)
                    }
                }
            }
            Spacer()
            ZPriorityBadge(priority: priority)
        }
        .padding(16)
        .zCard()
    }
}

/// Web-style compact upcoming row.
struct MiniRow: View {
    let title: String
    let subtitle: String?
    let color: Color
    let days: Int

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.zForeground).lineLimit(1)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.zMuted) }
            }
            Spacer()
            if days == 0 {
                Text("Hoy")
                    .font(.caption2.weight(.bold)).foregroundStyle(.red)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.red.opacity(0.1), in: .capsule)
            } else {
                Text("en \(days) d").font(.caption).foregroundStyle(.zMuted)
            }
        }
        .padding(14)
        .zCard(radius: 12)
    }
}
