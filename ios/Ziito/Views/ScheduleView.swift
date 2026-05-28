import SwiftUI
import SwiftData

/// Google-Calendar-style weekly timeline.
/// Horizontal page = day, vertical scroll = hours of the day.
/// Class blocks render as colored cards with heights proportional to duration.
struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ClassSession.weekdayRaw), SortDescriptor(\ClassSession.startMinuteOfDay)])
    private var classes: [ClassSession]
    @Query private var subjects: [Subject]

    @State private var selectedDay: Weekday = ScheduleView.todayWeekday()
    @State private var showingAdd = false
    @State private var editing: ClassSession?

    // Layout constants
    private let hourHeight: CGFloat = 64
    private let startHour: Int = 6
    private let endHour: Int = 23
    private let gutterWidth: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            weekdayStrip
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))

            Divider().opacity(0.4)

            TabView(selection: $selectedDay) {
                ForEach(Weekday.weekOrdered) { day in
                    dayTimeline(day: day)
                        .tag(day)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Horario")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddClassView()
        }
        .sheet(item: $editing) { c in
            AddClassView(editing: c)
        }
    }

    // MARK: - Weekday strip (no more dots)

    private var weekdayStrip: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.weekOrdered) { day in
                let isSelected = day == selectedDay
                let isToday = day == Self.todayWeekday()
                Button {
                    Haptics.tap(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedDay = day
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.shortLabel.uppercased())
                            .font(.caption2.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(isSelected ? .white : (isToday ? .indigo : .secondary))
                        Text("\(classes.filter { $0.weekdayRaw == day.rawValue }.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.indigo : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isToday && !isSelected ? Color.indigo.opacity(0.5) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Day timeline

    private func dayTimeline(day: Weekday) -> some View {
        let dayClasses = classes.filter { $0.weekdayRaw == day.rawValue }
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    hourGrid
                    blocksLayer(dayClasses: dayClasses)
                        .padding(.leading, gutterWidth)
                        .padding(.trailing, 12)
                    if day == Self.todayWeekday() {
                        nowLine
                            .padding(.leading, gutterWidth - 6)
                            .padding(.trailing, 8)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(minHeight: totalHeight + 32)
            }
            .background(Color(.systemGroupedBackground))
            .onAppear {
                let scrollHour = max(startHour, min(endHour - 2, Calendar.current.component(.hour, from: Date()) - 1))
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("hour-\(scrollHour)", anchor: .top)
                }
            }
        }
    }

    private var totalHeight: CGFloat {
        CGFloat(endHour - startHour + 1) * hourHeight
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour...endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: gutterWidth, alignment: .trailing)
                        .padding(.trailing, 8)
                        .offset(y: -7)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 0.5)
                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight, alignment: .top)
                .id("hour-\(hour)")
            }
        }
    }

    private func blocksLayer(dayClasses: [ClassSession]) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(height: totalHeight)
            ForEach(layoutBlocks(for: dayClasses)) { block in
                blockCard(block: block)
                    .frame(width: max(0, block.width), height: max(28, block.height))
                    .offset(x: block.x, y: block.y)
            }
        }
    }

    private func blockCard(block: LaidOutBlock) -> some View {
        let c = block.session
        let subject = subjects.first { $0.id == c.subjectID }
        let color = subject?.color ?? .indigo
        let name = subject?.name ?? (c.customName.isEmpty ? "Clase" : c.customName)
        return Button {
            editing = c
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(c.startTimeString) – \(c.endTimeString)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.92))
                if !c.location.isEmpty, block.height > 56 {
                    Text(c.location)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .background(
                LinearGradient(colors: [color, color.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 10)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(color.opacity(0.95))
                    .frame(width: 3)
                    .clipShape(.rect(cornerRadius: 1.5))
                    .padding(.vertical, 2)
                    .padding(.leading, 2)
            }
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(c)
                try? modelContext.save()
            } label: { Label("Eliminar", systemImage: "trash") }
        }
    }

    private var nowLine: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: Date())
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let y = yOffset(forMinute: minutes)
        return HStack(spacing: 0) {
            Circle().fill(Color.red).frame(width: 10, height: 10)
            Rectangle().fill(Color.red).frame(height: 1.5)
        }
        .offset(y: y - 5)
    }

    // MARK: - Block layout (overlap aware)

    private struct LaidOutBlock: Identifiable {
        let id: UUID
        let session: ClassSession
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private func layoutBlocks(for dayClasses: [ClassSession]) -> [LaidOutBlock] {
        guard !dayClasses.isEmpty else { return [] }
        let sorted = dayClasses.sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
        // Group overlapping events
        var groups: [[ClassSession]] = []
        var current: [ClassSession] = []
        var currentEnd = 0
        for c in sorted {
            if current.isEmpty || c.startMinuteOfDay < currentEnd {
                current.append(c)
                currentEnd = max(currentEnd, c.endMinuteOfDay)
            } else {
                groups.append(current)
                current = [c]
                currentEnd = c.endMinuteOfDay
            }
        }
        if !current.isEmpty { groups.append(current) }

        let availableWidth = UIScreen.main.bounds.width - gutterWidth - 24
        var result: [LaidOutBlock] = []
        for group in groups {
            let n = max(1, group.count)
            let colWidth = (availableWidth - CGFloat(max(0, n - 1)) * 4) / CGFloat(n)
            for (i, c) in group.enumerated() {
                let y = yOffset(forMinute: c.startMinuteOfDay)
                let h = max(28, yOffset(forMinute: c.endMinuteOfDay) - y - 2)
                let x = CGFloat(i) * (colWidth + 4)
                result.append(LaidOutBlock(id: c.id, session: c, x: x, y: y, width: colWidth, height: h))
            }
        }
        return result
    }

    private func yOffset(forMinute m: Int) -> CGFloat {
        let minutesFromStart = CGFloat(m - startHour * 60)
        return max(0, (minutesFromStart / 60) * hourHeight)
    }

    private static func todayWeekday() -> Weekday {
        let rawWeekday = Calendar.current.component(.weekday, from: Date())
        return Weekday(rawValue: rawWeekday) ?? .monday
    }
}

struct AddClassView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]

    let editing: ClassSession?

    @State private var subjectID: UUID?
    @State private var customName: String = ""
    @State private var weekday: Weekday = .monday
    @State private var startDate: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endDate: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var location: String = ""

    init(editing: ClassSession? = nil) {
        self.editing = editing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Materia") {
                    if subjects.isEmpty {
                        Text("Crea una materia primero (o usa el nombre personalizado).")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Picker("Materia", selection: $subjectID) {
                            Text("Personalizada").tag(UUID?.none)
                            ForEach(subjects) { s in
                                Text(s.name).tag(Optional(s.id))
                            }
                        }
                    }
                    TextField("Nombre personalizado (opcional)", text: $customName)
                }
                Section("Día y hora") {
                    Picker("Día", selection: $weekday) {
                        ForEach(Weekday.weekOrdered) { d in
                            Text(d.fullLabel).tag(d)
                        }
                    }
                    DatePicker("Inicio", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("Fin", selection: $endDate, displayedComponents: .hourAndMinute)
                }
                Section("Lugar") {
                    TextField("Aula, edificio, etc.", text: $location)
                }
                if editing != nil {
                    Section {
                        Button(role: .destructive) {
                            if let c = editing {
                                modelContext.delete(c)
                                try? modelContext.save()
                            }
                            dismiss()
                        } label: {
                            Label("Eliminar clase", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Nueva clase" : "Editar clase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                guard let c = editing else { return }
                subjectID = c.subjectID
                customName = c.customName
                weekday = c.weekday
                startDate = dateFromMinutes(c.startMinuteOfDay)
                endDate = dateFromMinutes(c.endMinuteOfDay)
                location = c.location
            }
        }
    }

    private func dateFromMinutes(_ m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }

    private var canSave: Bool {
        let s = ClassSession.minutes(from: startDate)
        let e = ClassSession.minutes(from: endDate)
        return e > s && (subjectID != nil || !customName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func save() {
        let s = ClassSession.minutes(from: startDate)
        let e = ClassSession.minutes(from: endDate)
        if let c = editing {
            c.subjectID = subjectID
            c.customName = customName.trimmingCharacters(in: .whitespaces)
            c.weekdayRaw = weekday.rawValue
            c.startMinuteOfDay = s
            c.endMinuteOfDay = e
            c.location = location
        } else {
            let c = ClassSession(
                subjectID: subjectID,
                customName: customName.trimmingCharacters(in: .whitespaces),
                weekday: weekday,
                startMinuteOfDay: s,
                endMinuteOfDay: e,
                location: location
            )
            modelContext.insert(c)
        }
        try? modelContext.save()
        dismiss()
    }
}
