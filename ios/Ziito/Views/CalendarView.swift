import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PlannerViewModel()
    @Query private var subjects: [Subject]
    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query(sort: \StudyTask.dueDate) private var tasks: [StudyTask]

    @State private var cursor = Calendar.current.startOfDay(for: Date())
    @State private var selected = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current
    private let dow = ["L", "M", "X", "J", "V", "S", "D"]
    private let months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                          "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]

    private func subjectOf(_ id: UUID?) -> Subject? { subjects.first { $0.id == id } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZScreenHeader(title: "Calendario", onBack: { dismiss() })
                monthCard
                dayDetail
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
        }
        .background(Color.zBackground)
        .scrollContentBackground(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadSessions(modelContext: modelContext) }
    }

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: "chevron.left").font(.headline).foregroundStyle(.zForeground).frame(width: 32, height: 32)
                }.buttonStyle(.plain)
                Spacer()
                Text("\(months[calendar.component(.month, from: cursor) - 1]) \(calendar.component(.year, from: cursor))")
                    .font(.headline).foregroundStyle(.zForeground)
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: "chevron.right").font(.headline).foregroundStyle(.zForeground).frame(width: 32, height: 32)
                }.buttonStyle(.plain)
            }

            HStack {
                ForEach(dow, id: \.self) { d in
                    Text(d).font(.system(size: 11, weight: .semibold)).foregroundStyle(.zMuted).frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(days().enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 40) }
                }
            }
        }
        .padding(16)
        .zCard()
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let isSel = calendar.isDate(day, inSameDayAs: selected)
        let dots = dotsFor(day)
        return Button {
            withAnimation(.spring(response: 0.3)) { selected = calendar.startOfDay(for: day) }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSel ? .white : (isToday ? Color.zPrimary : Color.zForeground))
                HStack(spacing: 2) {
                    ForEach(Array(dots.enumerated()), id: \.offset) { _, c in
                        Circle().fill(isSel ? .white : c).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSel ? Color.zPrimary : (isToday ? Color.zSecondaryBG : .clear), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var dayDetail: some View {
        let dayExams = exams.filter { calendar.isDate($0.date, inSameDayAs: selected) }
        let dayTasks = tasks.filter { calendar.isDate($0.dueDate, inSameDayAs: selected) }
        let daySessions = viewModel.sessionsFor(date: selected)
        return VStack(alignment: .leading, spacing: 8) {
            Text(selectedTitle).font(.headline).foregroundStyle(.zForeground)
            if dayExams.isEmpty && dayTasks.isEmpty && daySessions.isEmpty {
                Text("Nada programado este día").font(.subheadline).foregroundStyle(.zMuted)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(dayExams) { e in detailRow(e.title, "Evaluación", subjectOf(e.subjectID)?.color ?? .zPrimary) }
                    ForEach(dayTasks) { t in detailRow(t.title, "Tarea", subjectOf(t.subjectID)?.color ?? .zPrimary) }
                    ForEach(daySessions) { s in
                        let exam = exams.first { $0.id == s.examID }
                        detailRow(exam?.title ?? "Sesión de estudio", "\(s.durationMinutes) min", subjectOf(s.subjectID)?.color ?? .zPrimary)
                    }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ tag: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 4, height: 32)
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(.zForeground)
            Spacer()
            Text(tag).font(.caption).foregroundStyle(.zMuted)
        }
        .padding(14)
        .zCard(radius: 12)
    }

    private var selectedTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f.string(from: selected).capitalized
    }

    private func dotsFor(_ d: Date) -> [Color] {
        var ids = Set<UUID>()
        exams.forEach { if calendar.isDate($0.date, inSameDayAs: d) { ids.insert($0.subjectID) } }
        tasks.forEach { if calendar.isDate($0.dueDate, inSameDayAs: d), let s = $0.subjectID { ids.insert(s) } }
        viewModel.sessionsFor(date: d).forEach { ids.insert($0.subjectID) }
        return ids.prefix(4).compactMap { id in subjectOf(id)?.color }
    }

    private func days() -> [Date?] {
        let year = calendar.component(.year, from: cursor)
        let month = calendar.component(.month, from: cursor)
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let startOffset = (calendar.component(.weekday, from: first) + 5) % 7 // Monday-first
        var cells: [Date?] = Array(repeating: nil, count: startOffset)
        for d in range {
            cells.append(calendar.date(from: DateComponents(year: year, month: month, day: d)))
        }
        return cells
    }

    private func changeMonth(_ delta: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            cursor = calendar.date(byAdding: .month, value: delta, to: cursor) ?? cursor
        }
    }
}
