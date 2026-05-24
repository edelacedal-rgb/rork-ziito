import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Source.createdAt, order: .reverse) private var sources: [Source]
    @Query private var subjects: [Subject]

    @State private var showingPDFPicker = false
    @State private var showingAddText = false
    @State private var showingAddURL = false
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    headerCard
                    if sources.isEmpty {
                        emptyState
                    } else {
                        ForEach(sources) { src in
                            NavigationLink(value: src.id) {
                                sourceRow(src)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Notebook")
            .navigationDestination(for: UUID.self) { id in
                if let s = sources.first(where: { $0.id == id }) {
                    SourceDetailView(source: s)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingPDFPicker = true } label: { Label("Subir PDF", systemImage: "doc.fill") }
                        Button { showingAddURL = true } label: { Label("Agregar enlace", systemImage: "link") }
                        Button { showingAddText = true } label: { Label("Pegar texto", systemImage: "text.alignleft") }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3).foregroundStyle(.indigo)
                    }
                }
            }
            .fileImporter(isPresented: $showingPDFPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                handlePDF(result)
            }
            .sheet(isPresented: $showingAddText) { AddTextSourceView() }
            .sheet(isPresented: $showingAddURL) { AddURLSourceView() }
            .alert("Importación", isPresented: .init(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importError ?? "") }
            .overlay {
                if importing {
                    ProgressView("Importando…")
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tus fuentes")
                .font(.title3.weight(.bold))
            Text("Sube PDFs, pega texto o añade enlaces. La IA generará resúmenes, guías de estudio, glosario y flashcards a partir de tu material — todo guardado offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(LinearGradient(colors: [Color.indigo.opacity(0.18), Color.purple.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 16))
    }

    private func sourceRow(_ s: Source) -> some View {
        let subject = subjects.first { $0.id == s.subjectID }
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill((subject?.color ?? .indigo).opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: s.kind.systemImage)
                    .foregroundStyle(subject?.color ?? .indigo)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(s.title).font(.headline).lineLimit(1)
                HStack(spacing: 6) {
                    Text(s.kind.label)
                    Text("·")
                    Text("\(s.wordCount) palabras")
                    if s.pageCount > 0 {
                        Text("·")
                        Text("\(s.pageCount) págs")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if s.isAnalyzed {
                Image(systemName: "sparkles").foregroundStyle(.purple)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .swipeActions {
            Button(role: .destructive) {
                modelContext.delete(s)
                try? modelContext.save()
            } label: { Label("Eliminar", systemImage: "trash") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 56))
                .foregroundStyle(.indigo.opacity(0.5))
            Text("Aún sin fuentes")
                .font(.title3.weight(.semibold))
            Text("Toca el + arriba para empezar.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func handlePDF(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importing = true
            Task {
                do {
                    let src = try await SourceImportService.shared.importPDF(from: url, title: nil)
                    modelContext.insert(src)
                    try? modelContext.save()
                } catch {
                    importError = error.localizedDescription
                }
                importing = false
            }
        case .failure(let err):
            importError = err.localizedDescription
        }
    }
}

struct AddTextSourceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Título") { TextField("Ej. Resumen capítulo 4", text: $title) }
                Section("Contenido") {
                    TextEditor(text: $text).frame(minHeight: 240)
                }
            }
            .navigationTitle("Texto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let s = SourceImportService.shared.importText(title: title.isEmpty ? "Sin título" : title, text: text)
                        modelContext.insert(s)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct AddURLSourceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("URL") {
                    TextField("https://…", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                Section {
                    Text("Se descargará el contenido de la página y se almacenará localmente para análisis offline.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Enlace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loading ? "Cargando…" : "Importar") {
                        Task { await load() }
                    }
                    .disabled(urlString.isEmpty || loading)
                }
            }
        }
    }

    private func load() async {
        loading = true
        do {
            let s = try await SourceImportService.shared.importURL(urlString)
            modelContext.insert(s)
            try? modelContext.save()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
