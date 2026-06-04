import SwiftUI
import SwiftData

/// Weekly schedule that mirrors the web app: a weekday strip plus a vertical
/// hour timeline with colored class blocks and a red "now" line.
struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ClassSession.weekdayRaw), SortDescriptor(\ClassSession.startMinuteOfDay)])
    private var classes: [ClassSession]
    @Query private var subjects: [Subject]

    @State private var selectedDay: Weekday = ScheduleView.todayWeekday()
    @State private var showingAdd = false
    @State private var editing: ClassSession?

    private let hourHeight: CGFloat = 64
    private let startHour = 6
    private let endHour = 23
    private let gutter: CGFloat = 48

    private var dayClasses: [ClassSession] {
        classes.filter { $0.weekdayRaw == selectedDay.rawValue }
            .sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
    }
    private var totalHeight: CGFloat { CGFloat(endHour - startHour + 1) * hourHeight }
    private var nowMin: Int { ClassSession.minutes(from: Date()) }

    var body: some View {
        VStack(spacing: 12) {
            ZScreenHeader(title: "Horario", onAdd: { showingAdd = true })
            weekdayStrip
            timeline
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 96)
        .background(Color.zBackground)
        .sheet(isPresented: $showingAdd) { ClassDialog(editing: nil, defaultDay: selectedDay) }
        .sheet(item: $editing) { c in ClassDialog(editing: c, defaultDay: c.weekday) }
    }

    private var weekdayStrip: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.weekOrdered) { day in
                let isSelected = day == selectedDay
                let isToday = day == Self.todayWeekday()
                let count = classes.filter { $0.weekdayRaw == day.rawValue }.count
                Button {
                    Haptics.tap(.light)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedDay = day }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.shortLabel.uppercased())
                            .font(.system(size: 10, weight: .heavy)).tracking(0.5)
                            .foregroundStyle(isSelected ? .white : (isToday ? Color.zPrimary : Color.zMuted))
                        Text("\(count)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundStyle(isSelected ? .white : Color.zForeground)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.zPrimary : Color.zSecondaryBG, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isToday && !isSelected ? Color.zPrimary.opacity(0.5) : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    hourGrid
                    blocksLayer
                    if selectedDay == Self.todayWeekday() && nowMin >= startHour * 60 && nowMin <= endHour * 60 {
                        nowLine
                    }
                }
                .frame(height: totalHeight + 16)
                .padding(.vertical, 8)
            }
            .zCard()
            .onAppear {
                let h = max(startHour, min(endHour - 2, Calendar.current.component(.hour, from: Date()) - 1))
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("hour-\(h)", anchor: .top) }
            }
        }
    }

    private var hourGrid: some View {
        ForEach(startHour...endHour, id: \.self) { hour in
            HStack(alignment: .top, spacing: 0) {
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.zMuted)
                    .frame(width: gutter, alignment: .trailing)
                    .padding(.trailing, 8)
                    .offset(y: -6)
                Rectangle().fill(Color.zBorder.opacity(0.6)).frame(height: 0.5)
            }
            .frame(height: hourHeight, alignment: .top)
            .offset(y: yOffset(forMinute: hour * 60))
            .id("hour-\(hour)")
        }
    }

    private var blocksLayer: some View {
        ForEach(dayClasses) { c in
            let subject = subjects.first { $0.id == c.subjectID }
            let color = subject?.color ?? .zPrimary
            let top = yOffset(forMinute: c.startMinuteOfDay)
            let height = max(28, yOffset(forMinute: c.endMinuteOfDay) - top - 2)
            Button { editing = c } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject?.name ?? (c.customName.isEmpty ? "Clase" : c.customName))
                        .font(.caption.weight(.bold)).foregroundStyle(.white).lineLimit(2)
                    Text("\(c.startTimeString) – \(c.endTimeString)")
                        .font(.system(size: 10).monospacedDigit()).foregroundStyle(.white.opacity(0.9))
                    if !c.location.isEmpty && height > 56 {
                        Text(c.location).font(.system(size: 10)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 10)
                )
            }
            .buttonStyle(.plain)
            .frame(height: height)
            .padding(.leading, gutter + 8)
            .padding(.trailing, 12)
            .offset(y: top)
        }
    }

    private var nowLine: some View {
        HStack(spacing: 0) {
            Circle().fill(.red).frame(width: 10, height: 10)
            Rectangle().fill(.red).frame(height: 1.5)
        }
        .padding(.leading, gutter - 6)
        .padding(.trailing, 8)
        .offset(y: yOffset(forMinute: nowMin) - 5)
    }

    private func yOffset(forMinute m: Int) -> CGFloat {
        max(0, (CGFloat(m - startHour * 60) / 60) * hourHeight)
    }

    private static func todayWeekday() -> Weekday {
        Weekday(rawValue: Calendar.current.component(.weekday, from: Date())) ?? .monday
    }
}

/// Add / edit class sheet styled to match the web dialog (subject chips, day grid).
struct ClassDialog: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]

    let editing: ClassSession?
    let defaultDay: Weekday

    @State private var subjectID: UUID?
    @State private var customName = ""
    @State private var weekday: Weekday = .monday
    @State private var startDate = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var location = ""

    private var canSave: Bool {
        ClassSession.minutes(from: endDate) > ClassSession.minutes(from: startDate)
            && (subjectID != nil || !customName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldLabel("Materia")
                    FlowChips {
                        chip(label: "Personalizada", selected: subjectID == nil, color: nil) { subjectID = nil }
                        ForEach(subjects) { s in
                            chip(label: s.name, selected: subjectID == s.id, color: s.color) { subjectID = s.id }
                        }
                    }

                    TextField("Nombre personalizado (opcional)", text: $customName)
                        .textFieldStyle(.roundedBorder)

                    fieldLabel("Día")
                    HStack(spacing: 4) {
                        ForEach(Weekday.weekOrdered) { d in
                            Button { weekday = d } label: {
                                Text(d.shortLabel)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(weekday == d ? .white : Color.zForeground)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(weekday == d ? Color.zPrimary : Color.zSecondaryBG, in: .rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Inicio")
                            DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            fieldLabel("Fin")
                            DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        Spacer()
                    }

                    TextField("Aula, edificio, etc.", text: $location)
                        .textFieldStyle(.roundedBorder)

                    if editing != nil {
                        Button(role: .destructive) {
                            if let c = editing { modelContext.delete(c); try? modelContext.save() }
                            dismiss()
                        } label: {
                            Label("Eliminar clase", systemImage: "trash").frame(maxWidth: .infinity)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            .background(Color.zBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(editing == nil ? "Nueva clase" : "Editar clase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.disabled(!canSave) }
            }
            .onAppear {
                if let c = editing {
                    subjectID = c.subjectID
                    customName = c.customName
                    weekday = c.weekday
                    startDate = dateFromMinutes(c.startMinuteOfDay)
                    endDate = dateFromMinutes(c.endMinuteOfDay)
                    location = c.location
                } else {
                    weekday = defaultDay
                }
            }
        }
    }

    private func fieldLabel(_ s: String) -> some View {
        Text(s).font(.caption.weight(.medium)).foregroundStyle(.zMuted)
    }

    private func chip(label: String, selected: Bool, color: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let color { Circle().fill(color).frame(width: 8, height: 8) }
                Text(label).font(.caption.weight(.medium))
            }
            .foregroundStyle(selected ? Color.zPrimary : Color.zForeground)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(selected ? Color.zPrimary.opacity(0.1) : Color.zCardBG, in: .capsule)
            .overlay(Capsule().stroke(selected ? Color.zPrimary : Color.zBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func dateFromMinutes(_ m: Int) -> Date {
        Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }

    private func save() {
        let s = ClassSession.minutes(from: startDate)
        let e = ClassSession.minutes(from: endDate)
        let name = customName.trimmingCharacters(in: .whitespaces)
        if let c = editing {
            c.subjectID = subjectID
            c.customName = name
            c.weekdayRaw = weekday.rawValue
            c.startMinuteOfDay = s
            c.endMinuteOfDay = e
            c.location = location
        } else {
            modelContext.insert(ClassSession(subjectID: subjectID, customName: name, weekday: weekday,
                                              startMinuteOfDay: s, endMinuteOfDay: e, location: location))
        }
        try? modelContext.save()
        dismiss()
    }
}

/// Simple wrapping chip container.
struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        // Approximate wrapping with a lazy grid of adaptive chips.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            content
        }
    }
}
