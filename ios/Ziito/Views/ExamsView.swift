import SwiftUI
import SwiftData

struct ExamsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @State private var showingAdd = false

    private var upcoming: [Exam] { exams.filter { $0.daysUntil >= 0 && !$0.isCompleted }.sorted { $0.date < $1.date } }
    private var past: [Exam] { exams.filter { $0.daysUntil < 0 || $0.isCompleted }.sorted { $0.date > $1.date } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZScreenHeader(title: "Evaluaciones", onBack: { dismiss() }, onAdd: { showingAdd = true })

                if exams.isEmpty {
                    ZEmptyState(icon: "pencil.and.list.clipboard", title: "Sin evaluaciones",
                                desc: "Registra tus pruebas para generar un plan de estudio inteligente")
                } else {
                    if !upcoming.isEmpty { group("Próximas", upcoming, faded: false) }
                    if !past.isEmpty { group("Pasadas", past, faded: true) }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
        }
        .background(Color.zBackground)
        .scrollContentBackground(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) { AddExamView() }
    }

    private func group(_ title: String, _ items: [Exam], faded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(0.5).foregroundStyle(.zMuted).padding(.horizontal, 4)
            VStack(spacing: 8) {
                ForEach(items) { e in
                    ExamRow(exam: e, subject: subjects.first { $0.id == e.subjectID },
                            onToggle: { e.isCompleted.toggle(); try? modelContext.save() },
                            onDelete: { modelContext.delete(e); try? modelContext.save() })
                    .opacity(faded ? 0.6 : 1)
                }
            }
        }
    }
}

struct ExamRow: View {
    let exam: Exam
    let subject: Subject?
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(exam.isCompleted ? Color.zPrimary : Color.zMuted.opacity(0.4), lineWidth: 2)
                        .background(Circle().fill(exam.isCompleted ? Color.zPrimary : .clear))
                        .frame(width: 24, height: 24)
                    if exam.isCompleted { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white) }
                }
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(exam.title).font(.subheadline.weight(.semibold)).foregroundStyle(.zForeground).lineLimit(1)
                HStack(spacing: 6) {
                    if let subject { Circle().fill(subject.color).frame(width: 8, height: 8) }
                    Text("\(subject?.name ?? "") · \(ZDate.shortDate(exam.date))").font(.caption).foregroundStyle(.zMuted)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                ZPriorityBadge(priority: exam.priority)
                if exam.daysUntil >= 0 {
                    Text(exam.daysUntil == 0 ? "Hoy" : "en \(exam.daysUntil) d")
                        .font(.system(size: 11))
                        .foregroundStyle(exam.daysUntil <= 3 ? .red : Color.zMuted)
                        .fontWeight(exam.daysUntil <= 3 ? .semibold : .regular)
                }
            }
            Button(action: onDelete) {
                Image(systemName: "trash").font(.subheadline).foregroundStyle(.zMuted.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .zCard()
    }
}

struct AddExamView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var subjectID: UUID?
    @State private var priority: PriorityLevel = .medium

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && subjectID != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Título de la evaluación", text: $title).textFieldStyle(.roundedBorder)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    SubjectPicker(subjects: subjects, value: $subjectID, allowNone: false)
                    PriorityPicker(value: $priority)
                }
                .padding(20)
            }
            .background(Color.zBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Nueva Evaluación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { add() }.disabled(!canSave) }
            }
        }
    }

    private func add() {
        guard let subjectID else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Exam(title: trimmed, date: date, priority: priority, subjectID: subjectID))
        try? modelContext.save()
        dismiss()
    }
}

/// Web-style subject chip picker.
struct SubjectPicker: View {
    let subjects: [Subject]
    @Binding var value: UUID?
    var allowNone: Bool

    var body: some View {
        if subjects.isEmpty {
            Text("Primero crea una materia en Materias.").font(.subheadline).foregroundStyle(.zMuted)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Materia").font(.caption.weight(.medium)).foregroundStyle(.zMuted)
                FlowChips {
                    if allowNone {
                        chip(label: "Ninguna", selected: value == nil, color: nil) { value = nil }
                    }
                    ForEach(subjects) { s in
                        chip(label: s.name, selected: value == s.id, color: s.color) { value = s.id }
                    }
                }
            }
        }
    }

    private func chip(label: String, selected: Bool, color: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let color { Circle().fill(color).frame(width: 8, height: 8) }
                Text(label).font(.caption.weight(.medium))
            }
            .foregroundStyle(selected ? Color.zPrimary : Color.zForeground)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(selected ? Color.zPrimary.opacity(0.1) : Color.zCardBG, in: .capsule)
            .overlay(Capsule().stroke(selected ? Color.zPrimary : Color.zBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Web-style 5-segment priority picker.
struct PriorityPicker: View {
    @Binding var value: PriorityLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prioridad: \(value.label)").font(.caption.weight(.medium)).foregroundStyle(.zMuted)
            HStack(spacing: 6) {
                ForEach(PriorityLevel.allCases, id: \.self) { p in
                    let c = Color(hex: p.colorName) ?? .gray
                    Button { value = p } label: {
                        Text(p.shortLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(value == p ? .white : Color.zMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(value == p ? c : Color.zSecondaryBG, in: .rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
