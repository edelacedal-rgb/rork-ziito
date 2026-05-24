import SwiftUI
import SwiftData

// MARK: - Subject Route Sheet (L2 contents along the slope)

struct SubjectRouteSheet: View {
    let subject: Subject
    let onStartFocus: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [StudyTask]
    @Query private var exams: [Exam]

    private var tasks: [StudyTask] {
        allTasks.filter { $0.subjectID == subject.id }.sorted { $0.dueDate < $1.dueDate }
    }

    private var subjectExams: [Exam] {
        exams.filter { $0.subjectID == subject.id }.sorted { $0.date < $1.date }
    }

    private var progress: Double {
        let total = tasks.count
        guard total > 0 else { return 0 }
        return Double(tasks.filter(\.isCompleted).count) / Double(total)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    if !subjectExams.isEmpty { examsSection }
                    contentsSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .navigationTitle("La Ruta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle().fill(subject.color).frame(width: 14, height: 14)
                Text(subject.name).font(.title2.weight(.bold))
                Spacer()
            }
            ProgressView(value: progress)
                .tint(subject.color)
            Text("\(Int(progress * 100))% completado en esta vía")
                .font(.caption).foregroundStyle(.secondary)

            Button {
                onStartFocus()
            } label: {
                Label("Escalar ahora", systemImage: "figure.climbing")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(subject.color, in: .capsule)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    private var examsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cumbres próximas")
                .font(.subheadline.weight(.semibold))
            ForEach(subjectExams.prefix(3)) { exam in
                HStack(spacing: 12) {
                    Image(systemName: "flag.fill").foregroundStyle(subject.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exam.title).font(.subheadline.weight(.semibold))
                        Text(exam.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            }
        }
    }

    private var contentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Contenidos (L2)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(tasks.filter(\.isCompleted).count)/\(tasks.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if tasks.isEmpty {
                Text("Aún no hay contenidos para esta vía. Añade tareas o evaluaciones para empezar a escalar.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(tasks) { task in
                    Button {
                        toggle(task)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: task.isCompleted ? "flag.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? subject.color : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.subheadline.weight(.semibold))
                                    .strikethrough(task.isCompleted)
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                Text(task.dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggle(_ task: StudyTask) {
        task.isCompleted.toggle()
        try? modelContext.save()
        if task.isCompleted {
            FlagFXService.shared.playFlagPlant(mastery: false)
        }
    }
}

// MARK: - Zenit Goal Sheet (summit beacon)

struct ZenitGoalSheet: View {
    let totalZiitos: Int
    let onStartFocus: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ziito.zenit.goal") private var zenitGoal: String = ""
    @AppStorage("ziito.monthly.pact") private var monthlyPact: String = ""
    @State private var goalDraft: String = ""
    @State private var pactDraft: String = ""
    @FocusState private var goalFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.yellow.opacity(0.5), .clear], center: .center, startRadius: 10, endRadius: 110))
                        .frame(width: 200, height: 200)
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 74, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .yellow.opacity(0.6), radius: 18)
                }
                .padding(.top, 4)

                VStack(spacing: 8) {
                    Text("EL ZENIT")
                        .font(.caption.weight(.heavy))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Tu cumbre te espera")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(totalZiitos) Ziitos esculpidos en piedra.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("OBJETIVO DEL ZENIT")
                        .font(.caption2.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("Ej: Aprobar Cálculo 2", text: $goalDraft)
                        .focused($goalFocused)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15)))
                        .foregroundStyle(.white)
                        .tint(.yellow)

                    Text("PACTO DE LA CUMBRE (MES)")
                        .font(.caption2.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 6)
                    TextField("Ej: 60 sesiones este mes", text: $pactDraft)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15)))
                        .foregroundStyle(.white)
                        .tint(.yellow)
                }
                .padding(.horizontal, 24)

                Button {
                    zenitGoal = goalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    monthlyPact = pactDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    onStartFocus()
                } label: {
                    Label("Guardar e iniciar ascenso", systemImage: "figure.climbing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: .capsule)
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .disabled(goalDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(goalDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                Spacer(minLength: 12)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                goalDraft = zenitGoal
                pactDraft = monthlyPact
            }
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.22), Color(red: 0.18, green: 0.14, blue: 0.30)], startPoint: .top, endPoint: .bottom))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }
}

// MARK: - Altar of Flags (trophy inventory)

struct AltarOfFlagsSheet: View {
    let subjects: [Subject]
    let tasks: [StudyTask]
    let logs: [FocusLog]
    @Environment(\.dismiss) private var dismiss

    private var dailyFlags: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return tasks.filter { $0.isCompleted && cal.isDate($0.dueDate, inSameDayAs: start) }.count
    }

    private var subjectMasteries: [(Subject, Double)] {
        subjects.map { s in
            let all = tasks.filter { $0.subjectID == s.id }
            guard !all.isEmpty else { return (s, 0.0) }
            let done = all.filter(\.isCompleted).count
            return (s, Double(done) / Double(all.count))
        }
    }

    private var monthFulfilled: Bool {
        // Pacto de la Cumbre: completed at least 1 task each day this month
        let cal = Calendar.current
        let now = Date()
        guard let interval = cal.dateInterval(of: .month, for: now) else { return false }
        var date = interval.start
        let today = cal.startOfDay(for: now)
        var allDaysHave = true
        while date <= min(today, interval.end) {
            let hasOne = tasks.contains { $0.isCompleted && cal.isDate($0.dueDate, inSameDayAs: date) }
            if !hasOne { allDaysHave = false; break }
            guard let next = cal.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return allDaysHave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section(title: "Diarias", subtitle: "Banderas grises del día") {
                        HStack(spacing: 8) {
                            ForEach(0..<max(1, dailyFlags), id: \.self) { _ in
                                flagIcon(color: .gray, gold: false)
                            }
                            Spacer()
                            Text("\(dailyFlags)")
                                .font(.title3.monospacedDigit().weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }

                    section(title: "Maestría de Materia", subtitle: "Banderas doradas") {
                        VStack(spacing: 10) {
                            ForEach(subjectMasteries, id: \.0.id) { s, p in
                                HStack(spacing: 12) {
                                    flagIcon(color: s.color, gold: p >= 0.9)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                        ProgressView(value: p).tint(s.color)
                                    }
                                    Text("\(Int(p * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                    }

                    section(title: "Pacto de la Cumbre", subtitle: "Holograma mensual") {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(LinearGradient(colors: [.cyan, .indigo], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                                    .frame(width: 80, height: 80)
                                Image(systemName: monthFulfilled ? "crown.fill" : "crown")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(monthFulfilled ? .yellow : .white.opacity(0.4))
                            }
                            .opacity(monthFulfilled ? 1 : 0.55)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(monthFulfilled ? "¡Pacto cumplido!" : "Holograma traslúcido")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(monthFulfilled
                                     ? "Has completado una tarea cada día de este mes."
                                     : "Completa al menos una tarea cada día del mes para solidificarlo.")
                                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.14), Color(red: 0.12, green: 0.10, blue: 0.20)], startPoint: .top, endPoint: .bottom))
            .navigationTitle("Altar de Banderas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption.weight(.heavy)).tracking(2)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption2).foregroundStyle(.white.opacity(0.55))
            }
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
        }
    }

    private func flagIcon(color: Color, gold: Bool) -> some View {
        Image(systemName: gold ? "flag.fill" : "flag")
            .font(.callout.weight(.bold))
            .foregroundStyle(gold ? .yellow : color)
            .padding(8)
            .background(.white.opacity(0.06), in: .circle)
    }
}
