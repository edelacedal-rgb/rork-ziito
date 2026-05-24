import SwiftUI
import SwiftData

struct ScanScheduleReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State var scannedClasses: [ScannedClass]
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                if scannedClasses.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundStyle(.indigo.opacity(0.5))
                            Text("No se detectaron clases")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Prueba con una imagen más nítida o un horario en formato tabla.")
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
                        HStack {
                            Text("\(scannedClasses.filter(\.isSelected).count) de \(scannedClasses.count) seleccionadas")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Seleccionar todas") {
                                for i in scannedClasses.indices {
                                    scannedClasses[i].isSelected = true
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                        }
                    }

                    ForEach(Weekday.weekOrdered) { day in
                        let dayItems = scannedClasses.enumerated().filter { $0.element.weekday == day }
                        if !dayItems.isEmpty {
                            Section(day.fullLabel) {
                                ForEach(dayItems, id: \.element.id) { pair in
                                    ScanClassRow(
                                        item: $scannedClasses[pair.offset],
                                        subjects: subjects
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Revisar horario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(scannedClasses.filter(\.isSelected).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let selected = scannedClasses.filter { $0.isSelected }
        for item in selected {
            let session = ClassSession(
                subjectID: item.subjectID,
                customName: item.subjectID == nil ? item.name : "",
                weekday: item.weekday,
                startMinuteOfDay: item.startMinuteOfDay,
                endMinuteOfDay: item.endMinuteOfDay,
                location: item.location
            )
            modelContext.insert(session)
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct ScanClassRow: View {
    @Binding var item: ScannedClass
    let subjects: [Subject]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Toggle("", isOn: $item.isSelected)
                    .labelsHidden()

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(item.startTimeString) – \(item.endTimeString)")
                            .font(.caption)
                        if !item.location.isEmpty {
                            Text("·").font(.caption)
                            Text(item.location).font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre").font(.caption).foregroundStyle(.secondary)
                        TextField("Nombre", text: $item.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Materia").font(.caption).foregroundStyle(.secondary)
                        SubjectPicker(selectedID: $item.subjectID, subjects: subjects)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Día").font(.caption).foregroundStyle(.secondary)
                        Picker("Día", selection: $item.weekday) {
                            ForEach(Weekday.weekOrdered) { d in
                                Text(d.shortLabel).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack(spacing: 12) {
                        timeStepper(label: "Inicio", minutes: $item.startMinuteOfDay)
                        timeStepper(label: "Fin", minutes: $item.endMinuteOfDay)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lugar").font(.caption).foregroundStyle(.secondary)
                        TextField("Aula, edificio…", text: $item.location)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
        .onTapGesture {
            withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
        }
    }

    private func timeStepper(label: String, minutes: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            DatePicker(
                label,
                selection: Binding(
                    get: {
                        Calendar.current.date(
                            bySettingHour: minutes.wrappedValue / 60,
                            minute: minutes.wrappedValue % 60,
                            second: 0,
                            of: Date()
                        ) ?? Date()
                    },
                    set: { newDate in
                        minutes.wrappedValue = ClassSession.minutes(from: newDate)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }
}
