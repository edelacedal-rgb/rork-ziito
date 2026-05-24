import SwiftUI
import SwiftData

struct SourceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var source: Source

    @Query private var subjects: [Subject]

    @State private var analyzing = false
    @State private var error: String?
    @State private var showingChat = false
    @State private var showingFlashcards = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                actions

                if source.isAnalyzed {
                    analyzedSections
                } else {
                    analyzeCTA
                }

                rawTextPreview
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(source.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Materia", selection: $source.subjectID) {
                        Text("Sin asignar").tag(UUID?.none)
                        ForEach(subjects) { s in
                            Text(s.name).tag(Optional(s.id))
                        }
                    }
                } label: { Image(systemName: "tag") }
            }
        }
        .sheet(isPresented: $showingChat) { ChatView(scopedSources: [source]) }
        .sheet(isPresented: $showingFlashcards) { FlashcardsView(source: source) }
        .alert("Error", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: source.kind.systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title).font(.title3.weight(.bold)).lineLimit(2)
                Text("\(source.kind.label) · \(source.wordCount) palabras")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionButton("Chat IA", icon: "bubble.left.and.text.bubble.right.fill", colors: [.indigo, .purple]) {
                    showingChat = true
                }
                actionButton("Flashcards", icon: "rectangle.stack.fill", colors: [.pink, .orange]) {
                    showingFlashcards = true
                }
            }
            Button {
                Task { await analyze() }
            } label: {
                HStack {
                    if analyzing { ProgressView().tint(.white) }
                    else { Image(systemName: source.isAnalyzed ? "arrow.clockwise" : "sparkles") }
                    Text(source.isAnalyzed ? "Re-analizar fuente" : "Generar resumen, guía y glosario")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [.indigo, .blue], startPoint: .leading, endPoint: .trailing), in: .capsule)
            }
            .disabled(analyzing)
        }
    }

    private func actionButton(_ title: String, icon: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 14))
        }
    }

    private var analyzeCTA: some View {
        VStack(spacing: 10) {
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.purple)
            Text("Convierte esto en una guía de estudio")
                .font(.headline)
            Text("La IA leerá la fuente y creará un resumen, una guía estructurada y un glosario de términos clave.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private var analyzedSections: some View {
        VStack(spacing: 14) {
            sectionCard(title: "Resumen", icon: "text.book.closed.fill", color: .indigo, text: source.summary)
            sectionCard(title: "Guía de estudio", icon: "list.bullet.rectangle.portrait.fill", color: .blue, text: source.studyGuide)
            sectionCard(title: "Glosario", icon: "character.book.closed.fill", color: .purple, text: source.glossary)
        }
    }

    private func sectionCard(title: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(LocalizedStringKey(text.isEmpty ? "—" : text))
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private var rawTextPreview: some View {
        DisclosureGroup("Texto original") {
            Text(source.rawText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private func analyze() async {
        analyzing = true
        defer { analyzing = false }
        do {
            let result = try await AIService.shared.analyzeSource(title: source.title, text: source.rawText)
            source.summary = result.summary
            source.studyGuide = result.studyGuide
            source.glossary = result.glossary
            try? modelContext.save()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
