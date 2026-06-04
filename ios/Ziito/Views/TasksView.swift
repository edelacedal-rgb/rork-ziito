import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PlannerViewModel()
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @Query(sort: \StudyTask.dueDate) private var allTasks: [StudyTask]

    @State private var showingAdd = false
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable {
        case all = "Todas", pending = "Pendientes", completed = "Completadas", overdue = "Vencidas"
    }

    private var filtered: [StudyTask] {
        switch filter {
        case .all: return allTasks
        case .pending: return allTasks.filter { !$0.isCompleted && !$0.isOverdue }
        case .completed: return allTasks.filter(\.isCompleted)
        case .overdue: return allTasks.filter(\.isOverdue)
        }
    }
    private var overdueCount: Int { allTasks.filter(\.isOverdue).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZScreenHeader(title: "Tareas", onBack: { dismiss() }, onAdd: { showingAdd = true })

                if allTasks.isEmpty {
                    ZEmptyState(icon: "checklist", title: "Sin tareas", desc: "Agrega tareas para organizar tu estudio")
                } else {
                    segmented
                    if overdueCount > 0 && filter != .completed {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.zAccent).font(.subheadline)
                            Text("\(overdueCount) tarea(s) vencida(s)").font(.subheadline.weight(.medium)).foregroundStyle(.zForeground)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.zAccent.opacity(0.1), in: .rect(cornerRadius: 12))
                    }
                    VStack(spacing: 8) {
                        ForEach(filtered) { task in
                            taskRow(task)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
        }
        .background(Color.zBackground)
        .scrollContentBackground(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) { AddTaskView() }
        .onAppear { viewModel.loadTasks(modelContext: modelContext) }
    }

    private var segmented: some View {
        HStack(spacing: 4) {
            ForEach(Filter.allCases, id: \.self) { f in
                Button { filter = f } label: {
                    Text(f.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(filter == f ? Color.zForeground : Color.zMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(filter == f ? Color.zCardBG : .clear, in: .rect(cornerRadius: 8))
                        .shadow(color: filter == f ? .black.opacity(0.06) : .clear, radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.zSecondaryBG, in: .rect(cornerRadius: 12))
    }

    private func taskRow(_ task: StudyTask) -> some View {
        let subject = subjects.first { $0.id == task.subjectID }
        let overdue = task.isOverdue
        return HStack(spacing: 12) {
            Button { viewModel.toggleTaskCompletion(task, modelContext: modelContext) } label: {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? Color.zPrimary : (subject?.color ?? Color.zMuted.opacity(0.4)), lineWidth: 2)
                        .background(Circle().fill(task.isCompleted ? Color.zPrimary : .clear))
                        .frame(width: 24, height: 24)
                    if task.isCompleted { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white) }
                }
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(task.isCompleted ? Color.zMuted : Color.zForeground)
                    .strikethrough(task.isCompleted)
                HStack(spacing: 6) {
                    if let subject {
                        Circle().fill(subject.color).frame(width: 8, height: 8)
                        Text(subject.name).font(.caption).foregroundStyle(.zMuted)
                    }
                    Text(ZDate.shortDate(task.dueDate))
                        .font(.caption)
                        .foregroundStyle(overdue ? Color.zAccent : (task.daysUntil <= 1 ? .red : Color.zMuted))
                        .fontWeight(overdue ? .semibold : .regular)
                }
            }
            Spacer()
            ZPriorityBadge(priority: task.priority)
            Button {
                Haptics.tap(.light)
                viewModel.deleteTask(task, modelContext: modelContext)
            } label: {
                Image(systemName: "trash").font(.subheadline).foregroundStyle(.zMuted.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .zCard()
    }
}

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
    @State private var subjectID: UUID?
    @State private var priority: PriorityLevel = .medium

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Título de la tarea", text: $title).textFieldStyle(.roundedBorder)
                    TextField("Notas (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                    DatePicker("Fecha", selection: $dueDate, displayedComponents: .date)
                    SubjectPicker(subjects: subjects, value: $subjectID, allowNone: true)
                    PriorityPicker(value: $priority)
                }
                .padding(20)
            }
            .background(Color.zBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Nueva Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { add() }.disabled(!canSave) }
            }
        }
    }

    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(StudyTask(title: trimmed, notes: notes, dueDate: dueDate, priority: priority, subjectID: subjectID))
        try? modelContext.save()
        dismiss()
    }
}
