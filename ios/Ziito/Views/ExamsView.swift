import SwiftUI
import SwiftData

struct ExamsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                if exams.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.system(size: 48))
                                .foregroundStyle(.indigo.opacity(0.5))

                            Text("Sin evaluaciones")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Registra tus pruebas para generar un plan de estudio inteligente")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    let upcoming = exams.filter { $0.daysUntil >= 0 && !$0.isCompleted }
                    let past = exams.filter { $0.daysUntil < 0 || $0.isCompleted }

                    if !upcoming.isEmpty {
                        Section("Próximas") {
                            ForEach(upcoming) { exam in
                                if let subject = subjects.first(where: { $0.id == exam.subjectID }) {
                                    ExamRow(exam: exam, subject: subject)
                                }
                            }
                            .onDelete { offsets in
                                deleteExams(from: upcoming, at: offsets)
                            }
                        }
                    }

                    if !past.isEmpty {
                        Section("Pasadas") {
                            ForEach(past) { exam in
                                if let subject = subjects.first(where: { $0.id == exam.subjectID }) {
                                    ExamRow(exam: exam, subject: subject)
                                        .opacity(0.6)
                                }
                            }
                            .onDelete { offsets in
                                deleteExams(from: past, at: offsets)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Evaluaciones")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddExamView()
            }
        }
    }

    private func deleteExams(from array: [Exam], at offsets: IndexSet) {
        for index in offsets {
            let exam = array[index]
            modelContext.delete(exam)
        }
        try? modelContext.save()
    }
}

struct ExamRow: View {
    let exam: Exam
    let subject: Subject

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(exam.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if exam.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(subject.color)
                            .frame(width: 8, height: 8)
                        Text(subject.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                PriorityBadge(priority: exam.priority)

                if exam.daysUntil >= 0 {
                    Text(exam.daysUntil == 0 ? "Hoy" : "en \(exam.daysUntil) d")
                        .font(.caption2)
                        .foregroundStyle(exam.daysUntil <= 3 ? .red : .secondary)
                        .fontWeight(exam.daysUntil <= 3 ? .semibold : .regular)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            Button {
                exam.isCompleted.toggle()
                try? exam.modelContext?.save()
            } label: {
                Label(exam.isCompleted ? "Pendiente" : "Completada", systemImage: exam.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: exam.date)
    }
}

struct AddExamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var title: String = ""
    @State private var date: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var selectedSubjectID: UUID? = nil
    @State private var priority: PriorityLevel = .medium

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedSubjectID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles") {
                    TextField("Título de la evaluación", text: $title)

                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
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
                                        .foregroundStyle(.indigo)
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
            }
            .navigationTitle("Nueva Evaluación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        addExam()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func addExam() {
        guard let subjectID = selectedSubjectID else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let exam = Exam(title: trimmed, date: date, priority: priority, subjectID: subjectID)
        modelContext.insert(exam)
        try? modelContext.save()
        dismiss()
    }
}
