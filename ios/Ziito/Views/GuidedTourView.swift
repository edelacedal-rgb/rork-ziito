import SwiftUI
import SwiftData

/// Bottom coach card that guides the user through creating subjects, the
/// schedule, exams, and finally generating the smart study plan.
struct GuidedTourView: View {
    var tour = TourManager.shared
    @Environment(\.modelContext) private var modelContext

    @Query private var subjects: [Subject]
    @Query private var classes: [ClassSession]
    @Query private var exams: [Exam]

    /// Called when the plan is generated so the host can jump to the Today tab.
    let onFinish: () -> Void

    @State private var activeSheet: TourSheet?
    @State private var planner = PlannerViewModel()

    private let presetColors: [(name: String, hex: String)] = [
        ("Rojo", "FF3B30"), ("Naranja", "FF9500"), ("Amarillo", "FFCC00"),
        ("Verde", "34C759"), ("Verde Azulado", "5AC8FA"), ("Azul", "007AFF"),
        ("Índigo", "5856D6"), ("Morado", "AF52DE"), ("Rosa", "FF2D55"),
        ("Café", "A2845E"), ("Gris", "8E8E93"), ("Coral", "FF6B6B")
    ]

    private enum TourSheet: Int, Identifiable {
        case subject, classSession, exam
        var id: Int { rawValue }
    }

    private struct StepInfo {
        let icon: String
        let title: String
        let body: String
        let count: Int
        let done: Bool
        let addLabel: String
        let hint: String
    }

    private var step: Int { min(tour.step, TourManager.stepCount - 1) }

    private var info: StepInfo {
        switch step {
        case 0:
            return StepInfo(
                icon: "sparkles",
                title: "Crea tu plan inteligente",
                body: "En 4 pasos tendrás un calendario de estudio armado solo. Empecemos por tus materias.",
                count: 0, done: true, addLabel: "", hint: ""
            )
        case 1:
            return StepInfo(
                icon: "books.vertical.fill",
                title: "1 · Agrega tus materias",
                body: "Registra cada asignatura y dale un color. Serán la base de todo tu plan.",
                count: subjects.count, done: !subjects.isEmpty,
                addLabel: "Agregar materia",
                hint: "Crea al menos una materia para continuar."
            )
        case 2:
            return StepInfo(
                icon: "calendar",
                title: "2 · Arma tu horario",
                body: "Coloca tus clases en la semana usando las materias que creaste. Así Ziito sabe cuándo tienes tiempo libre.",
                count: classes.count, done: !classes.isEmpty,
                addLabel: "Agregar clase",
                hint: "Elige materia, día y hora de tu clase."
            )
        case 3:
            return StepInfo(
                icon: "pencil.and.list.clipboard",
                title: "3 · Registra tus evaluaciones",
                body: "Añade tus pruebas con fecha y prioridad por materia. Esto alimenta el plan inteligente.",
                count: exams.count, done: !exams.isEmpty,
                addLabel: "Agregar evaluación",
                hint: "Registra título, fecha, materia y prioridad."
            )
        default:
            return StepInfo(
                icon: "mountain.2.fill",
                title: "4 · Genera tu plan",
                body: "Listo. Ziito repartirá sesiones de estudio hasta cada evaluación según su prioridad y fecha.",
                count: 0, done: true, addLabel: "", hint: ""
            )
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // progress
            HStack(spacing: 6) {
                ForEach(0..<TourManager.stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i < step ? Color.indigo : (i == step ? Color.orange : Color.secondary.opacity(0.25)))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
                Button {
                    Haptics.tap(.light)
                    tour.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: info.icon)
                        .font(.title3)
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(info.title)
                        .font(.headline)
                    Text(info.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if step >= 1 && step <= 3 {
                        if info.done {
                            Label("\(info.count) agregada\(info.count == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.top, 4)
                        } else {
                            Text(info.hint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            actionRow
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .padding(.horizontal, 14)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .subject: AddSubjectView(presetColors: presetColors)
            case .classSession: AddClassView()
            case .exam: AddExamView()
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 10) {
            switch step {
            case 0:
                primaryButton(title: "Empezar", icon: "arrow.right") { advance() }
            case TourManager.stepCount - 1:
                primaryButton(title: "Crear plan inteligente", icon: "sparkles") { generate() }
            default:
                if info.done {
                    primaryButton(title: "Continuar", icon: "arrow.right") { advance() }
                } else {
                    primaryButton(title: info.addLabel, icon: "plus") { openSheet() }
                    Button("Omitir") {
                        Haptics.tap(.light)
                        advance()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    private func primaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold))
                Image(systemName: icon).font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.indigo, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func openSheet() {
        Haptics.tap(.light)
        switch step {
        case 1: activeSheet = .subject
        case 2: activeSheet = .classSession
        case 3: activeSheet = .exam
        default: break
        }
    }

    private func advance() {
        Haptics.tap(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            tour.next()
        }
    }

    private func generate() {
        Haptics.notify(.success)
        planner.generatePlan(modelContext: modelContext)
        tour.finish()
        onFinish()
    }
}
