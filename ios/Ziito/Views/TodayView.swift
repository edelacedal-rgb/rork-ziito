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
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var onStartFocus: () -> Void

    init(onStartFocus: @escaping () -> Void = {}) {
        self.onStartFocus = onStartFocus
    }

    private var schedule: ScheduleService { ScheduleService.shared }
    private var pomodoro: PomodoroService { PomodoroService.shared }

    private var currentClass: ClassSession? { schedule.currentClass(at: nowTick, classes: classes) }
    private var currentFreeSlot: FreeSlot? { schedule.currentFreeSlot(now: nowTick, classes: classes) }
    private var todayClasses: [ClassSession] { schedule.classesFor(date: nowTick, classes: classes) }

    private var todaySessions: [StudySession] {
        viewModel.sessionsFor(date: Date())
    }

    private var todayTasks: [StudyTask] {
        tasks.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: Date()) && !$0.isCompleted }
    }

    private var hasPlan: Bool {
        !viewModel.studySessions.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard

                    studyMomentBanner

                    if !todayClasses.isEmpty {
                        scheduleTimeline
                    }

                    if !hasPlan {
                        emptyPlanState
                    } else if todaySessions.isEmpty && todayTasks.isEmpty {
                        noSessionsToday
                    } else {
                        if !todayTasks.isEmpty {
                            todayTasksSection
                        }
                        if !todaySessions.isEmpty {
                            todayTasksSection_old
                        }
                    }

                    upcomingTasksSection
                    upcomingExamsSection
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hoy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: generatePlan) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.indigo)
                    }
                    .disabled(viewModel.isGeneratingPlan)
                }
            }
            .onAppear {
                viewModel.loadSessions(modelContext: modelContext)
                viewModel.loadTasks(modelContext: modelContext)
            }
            .onReceive(timer) { date in
                nowTick = date
            }
        }
    }

    @ViewBuilder
    private var studyMomentBanner: some View {
        if let c = currentClass {
            inClassBanner(c)
        } else if let slot = currentFreeSlot, slot.durationMinutes >= 25 {
            studyMomentCard(slot: slot)
        } else {
            startFocusCard
        }
    }

    private func inClassBanner(_ c: ClassSession) -> some View {
        let subject = subjects.first { $0.id == c.subjectID }
        let color = subject?.color ?? .indigo
        return HStack(spacing: 14) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text("En clase ahora").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(subject?.name ?? (c.customName.isEmpty ? "Clase" : c.customName))
                    .font(.headline)
                Text("Hasta las \(c.endTimeString)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(color.opacity(0.10), in: .rect(cornerRadius: 16))
    }

    private func studyMomentCard(slot: FreeSlot) -> some View {
        let mins = slot.durationMinutes
        let endsAt = slot.end.formatted(date: .omitted, time: .shortened)
        return Button(action: onStartFocus) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 50, height: 50)
                    Image(systemName: "leaf.fill").foregroundStyle(.white).font(.title3)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Es momento de estudiar")
                        .font(.headline).foregroundStyle(.white)
                    Text("Tienes \(mins) min libres hasta las \(endsAt). Inicia un Pomodoro.")
                        .font(.caption).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(.indigo)
                    .padding(10)
                    .background(.white, in: .circle)
            }
            .padding()
            .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing), in: .rect(cornerRadius: 18))
            .shadow(color: .indigo.opacity(0.35), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var startFocusCard: some View {
        Button(action: onStartFocus) {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .foregroundStyle(.indigo)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(Color.indigo.opacity(0.12), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pomodoro.isRunning ? "Sesión en curso" : "Inicia una sesión de enfoque")
                        .font(.headline)
                    Text(pomodoro.isRunning ? "Toca para volver al modo enfocado." : "Pomodoro · Modo inmersivo · Sin distracciones")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var scheduleTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tu día").font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(todayClasses.enumerated()), id: \.element.id) { idx, c in
                    timelineRow(c: c, isLast: idx == todayClasses.count - 1)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        }
    }

    private func timelineRow(c: ClassSession, isLast: Bool) -> some View {
        let subject = subjects.first { $0.id == c.subjectID }
        let color = subject?.color ?? .indigo
        let nowMin = ClassSession.minutes(from: nowTick)
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
                Text("\(c.startTimeString) – \(c.endTimeString)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(subject?.name ?? (c.customName.isEmpty ? "Clase" : c.customName))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPast ? .secondary : .primary)
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let totalItems = todaySessions.count + todayTasks.count
            let completedItems = todaySessions.filter(\.isCompleted).count
            if totalItems > 0 {
                HStack(spacing: 4) {
                    Text("\(completedItems)/\(totalItems) completadas")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(completedItems == totalItems ? .green : .indigo)

                    ProgressView(value: Double(completedItems), total: Double(totalItems))
                        .tint(completedItems == totalItems ? .green : .indigo)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
                )
        }
    }

    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tareas de hoy")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                ForEach(todayTasks) { task in
                    TaskRowToday(
                        task: task,
                        subject: subjects.first(where: { $0.id == task.subjectID }),
                        onToggle: {
                            viewModel.toggleTaskCompletion(task, modelContext: modelContext)
                        }
                    )
                }
            }
        }
    }

    private var todayTasksSection_old: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Qué estudiar hoy")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                ForEach(todaySessions) { session in
                    if let exam = exams.first(where: { $0.id == session.examID }),
                       let subject = subjects.first(where: { $0.id == session.subjectID }) {
                        SessionRow(
                            session: session,
                            exam: exam,
                            subject: subject,
                            onToggle: {
                                viewModel.toggleSessionCompletion(session, modelContext: modelContext)
                            }
                        )
                    }
                }
            }
        }
    }

    private var upcomingTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Próximas tareas")
                .font(.headline)
                .foregroundStyle(.primary)

            let upcoming = tasks.filter { !$0.isCompleted && $0.daysUntil >= 0 && !Calendar.current.isDate($0.dueDate, inSameDayAs: Date()) }
                .sorted { $0.dueDate < $1.dueDate }

            if upcoming.isEmpty {
                Text("No hay tareas pendientes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(upcoming.prefix(3)) { task in
                        if let subject = subjects.first(where: { $0.id == task.subjectID }) {
                            TaskMiniRow(task: task, subject: subject)
                        } else {
                            TaskMiniRow(task: task, subject: nil)
                        }
                    }
                }
            }
        }
    }

    private var upcomingExamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Próximas evaluaciones")
                .font(.headline)
                .foregroundStyle(.primary)

            if exams.filter({ $0.daysUntil >= 0 && !$0.isCompleted }).isEmpty {
                Text("No hay evaluaciones registradas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(exams.filter { $0.daysUntil >= 0 && !$0.isCompleted }.prefix(5)) { exam in
                        if let subject = subjects.first(where: { $0.id == exam.subjectID }) {
                            ExamMiniRow(exam: exam, subject: subject)
                        }
                    }
                }
            }
        }
    }

    private var emptyPlanState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.indigo.opacity(0.6))

            Text("Genera tu plan de estudio")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("La app creará un calendario inteligente basado en tus evaluaciones y prioridades.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: generatePlan) {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    Text("Crear plan inteligente")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.indigo)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var noSessionsToday: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.6))

            Text("Día libre de estudio")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("No tienes sesiones de estudio ni tareas programadas para hoy. ¡Descansa o adelanta otra materia!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func generatePlan() {
        viewModel.generatePlan(modelContext: modelContext)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Buenos días"
        case 12..<18: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: Date()).capitalized
    }
}

struct TaskRowToday: View {
    let task: StudyTask
    let subject: Subject?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : (subject?.color ?? .indigo))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)

                HStack(spacing: 6) {
                    if let subject = subject {
                        Circle()
                            .fill(subject.color)
                            .frame(width: 8, height: 8)

                        Text(subject.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            PriorityBadge(priority: task.priority)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }
}

struct TaskMiniRow: View {
    let task: StudyTask
    let subject: Subject?

    var body: some View {
        HStack(spacing: 12) {
            if let subject = subject {
                Circle()
                    .fill(subject.color)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(.indigo)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let subject = subject {
                    Text(subject.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if task.daysUntil == 0 {
                Text("Hoy")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .clipShape(.capsule)
            } else {
                Text("en \(task.daysUntil) d")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }
}

struct SessionRow: View {
    let session: StudySession
    let exam: Exam
    let subject: Subject
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(session.isCompleted ? .green : subject.color)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(exam.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(session.isCompleted ? .secondary : .primary)
                    .strikethrough(session.isCompleted)

                HStack(spacing: 6) {
                    Circle()
                        .fill(subject.color)
                        .frame(width: 8, height: 8)

                    Text(subject.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(session.durationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            PriorityBadge(priority: exam.priority)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }
}

struct ExamMiniRow: View {
    let exam: Exam
    let subject: Subject

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(subject.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(exam.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(subject.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if exam.daysUntil == 0 {
                Text("Hoy")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .clipShape(.capsule)
            } else {
                Text("en \(exam.daysUntil) d")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }
}

struct PriorityBadge: View {
    let priority: PriorityLevel

    var body: some View {
        Text(priority.shortLabel)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Color(hex: priority.colorName) ?? .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (Color(hex: priority.colorName) ?? .gray).opacity(0.12)
            )
            .clipShape(.capsule)
    }
}
