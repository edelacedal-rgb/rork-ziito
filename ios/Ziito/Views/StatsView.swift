import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FocusLog.startedAt, order: .reverse) private var logs: [FocusLog]
    @Query private var subjects: [Subject]
    @State private var rangeDays = 7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZScreenHeader(title: "Estadísticas", onBack: { dismiss() })
                summaryCards
                segmented
                chartCard
                subjectBreakdown
                recentSessions
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
        }
        .background(Color.zBackground)
        .scrollContentBackground(.hidden)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var bucketed: [(date: Date, minutes: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<rangeDays).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let total = logs.filter { cal.isDate($0.startedAt, inSameDayAs: day) }.reduce(0) { $0 + $1.focusMinutes }
            return (day, total)
        }
    }
    private var total: Int { bucketed.reduce(0) { $0 + $1.minutes } }
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
            card("clock.fill", .zPrimary, "\(total / 60)h \(total % 60)m", "Total \(rangeDays)d")
            card("flame.fill", .zAccent, "\(streak) d", "Racha")
            card("checkmark.seal.fill", .green, "\(logs.count)", "Sesiones")
        }
    }

    private func card(_ icon: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.callout.weight(.bold)).foregroundStyle(.zForeground)
            Text(label).font(.caption).foregroundStyle(.zMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .zCard()
    }

    private var segmented: some View {
        HStack(spacing: 4) {
            ForEach([7, 14, 30], id: \.self) { r in
                Button { rangeDays = r } label: {
                    Text("\(r) días")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(rangeDays == r ? Color.zForeground : Color.zMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(rangeDays == r ? Color.zCardBG : .clear, in: .rect(cornerRadius: 8))
                        .shadow(color: rangeDays == r ? .black.opacity(0.06) : .clear, radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.zSecondaryBG, in: .rect(cornerRadius: 12))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Minutos enfocados por día").font(.headline).foregroundStyle(.zForeground)
            Chart(bucketed, id: \.date) { item in
                BarMark(x: .value("Día", item.date, unit: .day), y: .value("Minutos", item.minutes))
                    .foregroundStyle(Color.zPrimary)
                    .cornerRadius(6)
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) }
            }
        }
        .padding(16)
        .zCard()
    }

    private var subjectBreakdown: some View {
        let grouped: [(Subject, Int)] = subjects.compactMap { s in
            let t = logs.filter { $0.subjectID == s.id }.reduce(0) { $0 + $1.focusMinutes }
            return t > 0 ? (s, t) : nil
        }.sorted { $0.1 > $1.1 }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Por materia").font(.headline).foregroundStyle(.zForeground)
            if grouped.isEmpty {
                Text("Aún sin sesiones registradas por materia.").font(.subheadline).foregroundStyle(.zMuted)
            } else {
                ForEach(grouped, id: \.0.id) { item in
                    HStack {
                        Circle().fill(item.0.color).frame(width: 10, height: 10)
                        Text(item.0.name).font(.subheadline).foregroundStyle(.zForeground)
                        Spacer()
                        Text("\(item.1) min").font(.subheadline.weight(.semibold)).foregroundStyle(.zMuted)
                    }
                }
            }
        }
        .padding(16)
        .zCard()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sesiones recientes").font(.headline).foregroundStyle(.zForeground)
            if logs.isEmpty {
                Text("Aún no has completado sesiones.").font(.subheadline).foregroundStyle(.zMuted)
            } else {
                ForEach(logs.prefix(8)) { log in
                    HStack(spacing: 12) {
                        Image(systemName: log.mode == .pomodoro ? "timer" : "infinity").foregroundStyle(.zPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline.weight(.medium)).foregroundStyle(.zForeground)
                            if log.completedCycles > 0 {
                                Text("\(log.completedCycles) ciclos completados").font(.caption).foregroundStyle(.zMuted)
                            }
                        }
                        Spacer()
                        Text("\(log.focusMinutes) min").font(.subheadline.weight(.semibold)).foregroundStyle(.zForeground)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .zCard()
    }
}
