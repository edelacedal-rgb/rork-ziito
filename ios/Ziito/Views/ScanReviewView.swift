import SwiftUI
import SwiftData

struct ScanReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State var scannedExams: [ScannedExam]
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                if scannedExams.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.indigo.opacity(0.5))
                            Text("No se detectaron evaluaciones")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        HStack {
                            Text("\(scannedExams.filter(\.isSelected).count) de \(scannedExams.count) seleccionadas")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Seleccionar todas") {
                                for i in scannedExams.indices {
                                    scannedExams[i].isSelected = true
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                        }
                    }

                    ForEach($scannedExams) { $exam in
                        ScanExamRow(
                            exam: $exam,
                            subjects: subjects
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Revisar evaluaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveExams()
                    }
                    .disabled(scannedExams.filter(\.isSelected).isEmpty || isSaving)
                }
            }
        }
    }

    private func saveExams() {
        let selected = scannedExams.filter { $0.isSelected }
        guard !selected.isEmpty else { return }

        for scanned in selected {
            guard let subjectID = scanned.subjectID else { continue }
            let exam = Exam(
                title: scanned.title,
                date: scanned.date,
                priority: scanned.priority,
                subjectID: subjectID
            )
            modelContext.insert(exam)
        }

        try? modelContext.save()
        dismiss()
    }
}

struct ScanExamRow: View {
    @Binding var exam: ScannedExam
    let subjects: [Subject]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Toggle("", isOn: $exam.isSelected)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 4) {
                    Text(exam.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Título")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Título", text: $exam.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Materia")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SubjectPicker(selectedID: $exam.subjectID, subjects: subjects)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prioridad")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Prioridad", selection: $exam.priority) {
                            ForEach(PriorityLevel.allCases, id: \.self) { level in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: level.colorName) ?? .gray)
                                        .frame(width: 8, height: 8)
                                    Text(level.label)
                                }
                                .tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.spring(duration: 0.25)) {
                isExpanded.toggle()
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: exam.date)
    }
}

struct SubjectPicker: View {
    @Binding var selectedID: UUID?
    let subjects: [Subject]

    var body: some View {
        Menu {
            ForEach(subjects) { subject in
                Button {
                    selectedID = subject.id
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(subject.color)
                            .frame(width: 8, height: 8)
                        Text(subject.name)
                        if selectedID == subject.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let subject = subjects.first(where: { $0.id == selectedID }) {
                    Circle()
                        .fill(subject.color)
                        .frame(width: 10, height: 10)
                    Text(subject.name)
                        .font(.subheadline)
                } else {
                    Text("Seleccionar materia")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 8))
        }
    }
}
