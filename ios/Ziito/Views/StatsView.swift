import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \FocusLog.startedAt, order: .reverse) private var logs: [FocusLog]
    @Query private var subjects: [Subject]

    @State private var rangeDays: Int = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCards
                    rangePicker
                    chartCard
                    subjectBreakdown
                    recentSessions
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Estadísticas")
        }
    }

    private var bucketed: [(date: Date, minutes: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var buckets: [(Date, Int)] = []
        for offset in (0..<rangeDays).reversed() {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let total = logs.filter { cal.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.focusMinutes }
            buckets.append((day, total))
        }
        return buckets
    }

    private var totalThisWeek: Int { bucketed.reduce(0) { $0 + $1.minutes } }
    private var streak: Int {
        let cal = Calendar.current
        var count = 0
        var day = cal.startOfDay(for: Date())
        while logs.contains(where: { cal.isDate($0.startedAt, inSameDayAs: day) }) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            StatCard(icon: "clock.fill", color: .zPrimary, label: "Total \(rangeDays)d", value: "\(totalThisWeek / 60)h \(totalThisWeek % 60)m")
            StatCard(icon: "flame.fill", color: .orange, label: "Racha", value: "\(streak) d")
            StatCard(icon: "checkmark.seal.fill", color: .green, label: "Sesiones", value: "\(logs.count)")
        }
    }

    private var rangePicker: some View {
        Picker("Rango", selection: $rangeDays) {
            Text("7 días").tag(7)
            Text("14 días").tag(14)
            Text("30 días").tag(30)
        }
        .pickerStyle(.segmented)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Minutos enfocados por día")
                .font(.headline)
            Chart(bucketed, id: \.date) { item in
                BarMark(
                    x: .value("Día", item.date, unit: .day),
                    y: .value("Minutos", item.minutes)
                )
                .foregroundStyle(LinearGradient(colors: [.zPrimary, .zPrimaryBright], startPoint: .top, endPoint: .bottom))
                .cornerRadius(6)
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var subjectBreakdown: some View {
        let grouped: [(Subject, Int)] = subjects.compactMap { s in
            let total = logs.filter { $0.subjectID == s.id }.reduce(0) { $0 + $1.focusMinutes }
            return total > 0 ? (s, total) : nil
        }.sorted { $0.1 > $1.1 }

        return VStack(alignment: .leading, spacing: 10) {
            Text("Por materia")
                .font(.headline)
            if grouped.isEmpty {
                Text("Aún sin sesiones registradas por materia.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(grouped, id: \.0.id) { item in
                    HStack {
                        Circle().fill(item.0.color).frame(width: 10, height: 10)
                        Text(item.0.name).font(.subheadline)
                        Spacer()
                        Text("\(item.1) min").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sesiones recientes")
                .font(.headline)
            if logs.isEmpty {
                Text("Aún no has completado sesiones.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(logs.prefix(8)) { log in
                    HStack(spacing: 12) {
                        Image(systemName: log.mode == .pomodoro ? "timer" : "infinity")
                            .foregroundStyle(.zPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline.weight(.medium))
                            if log.completedCycles > 0 {
                                Text("\(log.completedCycles) ciclos completados")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(log.focusMinutes) min").font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

struct StatCard: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }
}
