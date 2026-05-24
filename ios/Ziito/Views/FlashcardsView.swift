import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let source: Source

    @Query private var allCards: [Flashcard]
    @State private var generating = false
    @State private var error: String?
    @State private var index = 0
    @State private var flipped = false

    private var cards: [Flashcard] {
        allCards.filter { $0.sourceID == source.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if cards.isEmpty {
                    emptyState
                } else {
                    progressBar
                    cardView
                    controls
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await generate() }
                    } label: {
                        if generating { ProgressView() }
                        else { Image(systemName: cards.isEmpty ? "sparkles" : "arrow.clockwise") }
                    }
                    .disabled(generating)
                }
            }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 56)).foregroundStyle(.pink)
            Text("Genera flashcards desde esta fuente")
                .font(.headline)
            Text("La IA creará tarjetas pregunta-respuesta listas para repasar.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await generate() }
            } label: {
                Label(generating ? "Generando…" : "Generar 10 flashcards", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing), in: .capsule)
            }
            .disabled(generating)
        }
        .padding(.vertical, 60)
    }

    private var safeIndex: Int { min(max(0, index), max(0, cards.count - 1)) }
    private var current: Flashcard? { cards.indices.contains(safeIndex) ? cards[safeIndex] : nil }

    private var progressBar: some View {
        HStack {
            Text("\(safeIndex + 1) / \(cards.count)")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ProgressView(value: Double(safeIndex + 1), total: Double(max(1, cards.count)))
                .tint(.pink)
        }
    }

    private var cardView: some View {
        ZStack {
            if let c = current {
                cardFace(text: flipped ? c.back : c.front, label: flipped ? "Respuesta" : "Pregunta", isBack: flipped)
                    .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { flipped.toggle() }
        }
    }

    private func cardFace(text: String, label: String, isBack: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(text)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer()
            Text("Toca para girar").font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(LinearGradient(
            colors: isBack ? [.purple, .indigo] : [.pink, .red],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ), in: .rect(cornerRadius: 22))
        .rotation3DEffect(.degrees(isBack ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation { flipped = false; index = max(0, safeIndex - 1) }
            } label: {
                Image(systemName: "chevron.left").font(.title3).frame(width: 50, height: 50)
                    .background(Color(.secondarySystemGroupedBackground), in: .circle)
            }
            Button {
                withAnimation { flipped.toggle() }
            } label: {
                Label("Girar", systemImage: "arrow.left.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.indigo, in: .capsule).foregroundStyle(.white)
            }
            Button {
                withAnimation { flipped = false; index = min(cards.count - 1, safeIndex + 1) }
            } label: {
                Image(systemName: "chevron.right").font(.title3).frame(width: 50, height: 50)
                    .background(Color(.secondarySystemGroupedBackground), in: .circle)
            }
        }
    }

    private func generate() async {
        generating = true
        defer { generating = false }
        do {
            let cards = try await AIService.shared.generateFlashcards(title: source.title, text: source.rawText, count: 10)
            // Remove old cards for this source
            for c in self.cards { modelContext.delete(c) }
            for c in cards {
                modelContext.insert(Flashcard(front: c.front, back: c.back, sourceID: source.id, subjectID: source.subjectID))
            }
            try? modelContext.save()
            index = 0
            flipped = false
        } catch {
            self.error = error.localizedDescription
        }
    }
}
