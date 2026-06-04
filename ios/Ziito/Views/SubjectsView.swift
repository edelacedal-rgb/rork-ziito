import SwiftUI
import SwiftData

struct SubjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @State private var showingAddSheet = false

    let presetColors: [(name: String, hex: String)] = [
        ("Rojo", "FF3B30"), ("Naranja", "FF9500"), ("Amarillo", "FFCC00"),
        ("Verde", "34C759"), ("Verde Azulado", "5AC8FA"), ("Azul", "007AFF"),
        ("Índigo", "5856D6"), ("Morado", "AF52DE"), ("Rosa", "FF2D55"),
        ("Café", "A2845E"), ("Gris", "8E8E93"), ("Coral", "FF6B6B")
    ]

    var body: some View {
        NavigationStack {
            List {
                if subjects.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "books.vertical")
                                .font(.system(size: 48))
                                .foregroundStyle(.zPrimary.opacity(0.5))

                            Text("Sin materias")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Agrega tus materias para empezar a planificar")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(subjects) { subject in
                            SubjectRow(subject: subject)
                        }
                        .onDelete(perform: deleteSubjects)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Materias")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(.zPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddSubjectView(presetColors: presetColors)
            }
        }
    }

    private func deleteSubjects(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(subjects[index])
        }
        try? modelContext.save()
    }
}

struct SubjectRow: View {
    let subject: Subject

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(subject.color)
                .frame(width: 14, height: 14)

            Text(subject.name)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct AddSubjectView: View {
    let presetColors: [(name: String, hex: String)]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedHex: String = "007AFF"

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre de la materia", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(presetColors, id: \.hex) { color in
                            ColorOption(
                                hex: color.hex,
                                name: color.name,
                                isSelected: selectedHex == color.hex
                            )
                            .onTapGesture {
                                selectedHex = color.hex
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Nueva Materia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        addSubject()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addSubject() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let subject = Subject(name: trimmed, colorHex: selectedHex)
        modelContext.insert(subject)
        try? modelContext.save()
        dismiss()
    }
}

struct ColorOption: View {
    let hex: String
    let name: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color(hex: hex) ?? .blue)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                )

            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
