import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlannerViewModel()
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @Query(sort: \StudyTask.dueDate) private var allTasks: [StudyTask]

    @State private var showingAddSheet = false
    @State private var selectedFilter: TaskFilter = .all

    enum TaskFilter: String, CaseIterable {
        case all = "Todas"
        case pending = "Pendientes"
        case completed = "Completadas"
        case overdue = "Vencidas"
    }

    private var filteredTasks: [StudyTask] {
        switch selectedFilter {
        case .all:
            return allTasks
        case .pending:
            return allTasks.filter { !$0.isCompleted && !$0.isOverdue }
        case .completed:
            return allTasks.filter(\.isCompleted)
        case .overdue:
            return allTasks.filter(\.isOverdue)
        }
    }

    private var overdueCount: Int {
        allTasks.filter(\.isOverdue).count
    }

    var body: some View {
        NavigationStack {
            List {
                if allTasks.isEmpty {
                    Section {
                        emptyState
                    }
                } else {
                    filterSection

                    if overdueCount > 0 && selectedFilter != .completed {
                        overdueBanner
                    }

                    Section {
                        ForEach(filteredTasks) { task in
                            TaskRow(
                                task: task,
                                subject: subjects.first(where: { $0.id == task.subjectID }),
                                onToggle: {
                                    viewModel.toggleTaskCompletion(task, modelContext: modelContext)
                                },
                                onSync: {
                                    Task {
                                        await syncTask(task)
                                    }
                                }
                            )
                        }
                        .onDelete { offsets in
                            deleteTasks(at: offsets, in: filteredTasks)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tareas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(.zPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTaskView()
            }
            .onAppear {
                viewModel.loadTasks(modelContext: modelContext)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.zPrimary.opacity(0.5))

            Text("Sin tareas")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Agrega tareas para organizar tu estudio")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }

    private var filterSection: some View {
        Section {
            Picker("Filtro", selection: $selectedFilter) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(Color.clear)
    }

    private var overdueBanner: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("\(overdueCount) tarea(s) vencida(s)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private func syncTask(_ task: StudyTask) async {
        let subject = subjects.first(where: { $0.id == task.subjectID })
        await viewModel.syncTaskToCalendar(task, subject: subject, modelContext: modelContext)
        await viewModel.scheduleTaskNotifications(task, subject: subject)
    }

    private func deleteTasks(at offsets: IndexSet, in array: [StudyTask]) {
        for index in offsets {
            let task = array[index]
            viewModel.deleteTask(task, modelContext: modelContext)
        }
    }
}

struct TaskRow: View {
    let task: StudyTask
    let subject: Subject?
    let onToggle: () -> Void
    let onSync: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : (subject?.color ?? .zPrimary))
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

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(dateColor)
                        .fontWeight(task.isOverdue && !task.isCompleted ? .semibold : .regular)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if task.isSyncedToCalendar {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.zPrimary)
                }

                PriorityBadge(priority: task.priority)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // Handled by onDelete
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                onSync()
            } label: {
                Label("Sincronizar", systemImage: "calendar.badge.plus")
            }
            .tint(.zPrimary)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: task.dueDate)
    }

    private var dateColor: Color {
        if task.isCompleted {
            return .secondary
        }
        if task.isOverdue {
            return .orange
        }
        if task.daysUntil <= 1 {
            return .red
        }
        return .secondary
    }
}

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @State private var viewModel = PlannerViewModel()

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
    @State private var selectedSubjectID: UUID? = nil
    @State private var priority: PriorityLevel = .medium
    @State private var syncToCalendar = false
    @State private var enableReminder = true

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles") {
                    TextField("Título de la tarea", text: $title)
                    TextField("Notas (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)

                    DatePicker("Fecha de vencimiento", selection: $dueDate, displayedComponents: .date)
                }

                Section("Materia") {
                    if subjects.isEmpty {
                        Text("Primero crea una materia en la pestaña Materias")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(subjects) { subject in
                            HStack {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(subject.color)
                                        .frame(width: 12, height: 12)

                                    Text(subject.name)
                                        .font(.body)
                                }

                                Spacer()

                                if selectedSubjectID == subject.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.zPrimary)
                                }
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                selectedSubjectID = subject.id
                            }
                        }
                    }
                }

                Section("Prioridad") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Nivel: \(priority.label)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            Circle()
                                .fill(Color(hex: priority.colorName) ?? .gray)
                                .frame(width: 12, height: 12)
                        }

                        Picker("Prioridad", selection: $priority) {
                            ForEach(PriorityLevel.allCases, id: \.self) { level in
                                Text(level.label).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Sincronización") {
                    Toggle("Sincronizar con Calendario", isOn: $syncToCalendar)
                    Toggle("Recordatorio push", isOn: $enableReminder)
                }
            }
            .navigationTitle("Nueva Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        addTask()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = StudyTask(
            title: trimmed,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            subjectID: selectedSubjectID
        )
        modelContext.insert(task)

        do {
            try modelContext.save()
        } catch {
            print("Error saving task: \(error)")
            return
        }

        Task {
            let subject = subjects.first(where: { $0.id == selectedSubjectID })

            if syncToCalendar {
                await viewModel.syncTaskToCalendar(task, subject: subject, modelContext: modelContext)
            }

            if enableReminder {
                await viewModel.scheduleTaskNotifications(task, subject: subject)
            }
        }

        dismiss()
    }
}
