import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlannerViewModel()
    @Query private var subjects: [Subject]
    @Query(sort: \Exam.date) private var exams: [Exam]

    @State private var currentMonth: Date = Date()
    @State private var selectedDay: Date? = nil

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthHeader
                    weekdayHeader
                    daysGrid

                    if let selected = selectedDay {
                        dayDetailSection(date: selected)
                    }

                    legendSection
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendario")
            .onAppear {
                viewModel.loadSessions(modelContext: modelContext)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.zPrimary)
            }

            Spacer()

            Text(monthYearString)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.zPrimary)
            }
        }
        .padding(.vertical, 8)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day.prefix(1).uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDay ?? Date.distantPast),
                        isToday: calendar.isDateInToday(date),
                        sessions: viewModel.sessionsFor(date: date),
                        hasExam: exams.contains(where: { calendar.isDate($0.date, inSameDayAs: date) })
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDay = date
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
    }

    private func dayDetailSection(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(dayDetailTitle(date: date))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if calendar.isDateInToday(date) {
                    Text("Hoy")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.zPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.zPrimary.opacity(0.12))
                        .clipShape(.capsule)
                }
            }

            let sessions = viewModel.sessionsFor(date: date)
            if sessions.isEmpty {
                Text("Sin sesiones de estudio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        if let exam = exams.first(where: { $0.id == session.examID }),
                           let subject = subjects.first(where: { $0.id == session.subjectID }) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(subject.color)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exam.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text("\(subject.name) · \(session.durationMinutes) min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if session.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                }
                            }
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            }
                        }
                    }
                }
            }

            let dayExams = exams.filter { calendar.isDate($0.date, inSameDayAs: date) }
            if !dayExams.isEmpty {
                Text("Evaluaciones")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.top, 8)

                ForEach(dayExams) { exam in
                    if let subject = subjects.first(where: { $0.id == exam.subjectID }) {
                        HStack(spacing: 12) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(subject.color)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(exam.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(subject.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            PriorityBadge(priority: exam.priority)
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        }
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.zPrimary.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Leyenda")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.zPrimary)
                        .frame(width: 8, height: 8)
                    Text("Sesión")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Evaluación")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayDetailTitle(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE d"
        return formatter.string(from: date).capitalized
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth).capitalized
    }

    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
        }
    }

    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let sessions: [StudySession]
    let hasExam: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 32, height: 32)
                .background {
                    if isToday {
                        Circle()
                            .fill(Color.zPrimary)
                    } else if isSelected {
                        Circle()
                            .fill(Color.zPrimary.opacity(0.2))
                    }
                }

            HStack(spacing: 2) {
                if !sessions.isEmpty {
                    Circle()
                        .fill(Color.zPrimary)
                        .frame(width: 5, height: 5)
                }
                if hasExam {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 50)
        .contentShape(.rect)
    }
}
