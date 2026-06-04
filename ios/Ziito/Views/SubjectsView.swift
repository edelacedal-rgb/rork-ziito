import SwiftUI
import SwiftData

let zPresetColors: [(name: String, hex: String)] = [
    ("Rojo", "FF3B30"), ("Naranja", "FF9500"), ("Amarillo", "FFCC00"),
    ("Verde", "34C759"), ("Verde Azulado", "5AC8FA"), ("Azul", "007AFF"),
    ("Índigo", "5856D6"), ("Morado", "AF52DE"), ("Rosa", "FF2D55"),
    ("Café", "A2845E"), ("Gris", "8E8E93"), ("Coral", "FF6B6B")
]

struct SubjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]
    @State private var showingAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZScreenHeader(title: "Materias", onBack: { dismiss() }, onAdd: { showingAdd = true })

                if subjects.isEmpty {
                    ZEmptyState(icon: "books.vertical", title: "Sin materias",
                                desc: "Agrega tus materias para empezar a planificar")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(subjects.enumerated()), id: \.element.id) { idx, s in
                            HStack(spacing: 12) {
                                Circle().fill(s.color).frame(width: 14, height: 14)
                                Text(s.name).font(.body.weight(.medium)).foregroundStyle(.zForeground)
                                Spacer()
                                Button {
                                    Haptics.tap(.light)
                                    modelContext.delete(s); try? modelContext.save()
                                } label: {
                                    Image(systemName: "trash").font(.subheadline).foregroundStyle(.zMuted.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            if idx < subjects.count - 1 { Divider().background(Color.zBorder) }
                        }
                    }
                    .zCard()
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
        }
        .background(Color.zBackground)
        .scrollContentBackground(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAdd) { AddSubjectView(presetColors: zPresetColors) }
    }
}

struct AddSubjectView: View {
    let presetColors: [(name: String, hex: String)]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedHex = "007AFF"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TextField("Nombre de la materia", text: $name)
                        .textFieldStyle(.roundedBorder)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(presetColors, id: \.hex) { c in
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: c.hex) ?? .blue)
                                    .frame(width: 44, height: 44)
                                    .overlay(Circle().stroke(selectedHex == c.hex ? Color.zForeground : .clear, lineWidth: 3).padding(-3))
                                Text(c.name).font(.system(size: 10)).foregroundStyle(.zMuted).lineLimit(1)
                            }
                            .onTapGesture { selectedHex = c.hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(20)
            }
            .background(Color.zBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Nueva Materia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { add() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Subject(name: trimmed, colorHex: selectedHex))
        try? modelContext.save()
        dismiss()
    }
}

/// Shared empty-state block matching the web `Empty`.
struct ZEmptyState: View {
    let icon: String
    let title: String
    let desc: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 48)).foregroundStyle(.zPrimary.opacity(0.4))
            Text(title).font(.headline).foregroundStyle(.zMuted)
            Text(desc).font(.subheadline).foregroundStyle(.zMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}
