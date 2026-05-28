import SwiftUI
import SwiftData

/// Conversational hero that lives at the very top of the Home tab.
/// First thing the user sees: a clean input that opens Astra in Socratic mode.
struct SocraticTutorHero: View {
    @State private var draft: String = ""
    @State private var showChat: Bool = false
    @State private var seed: String?
    @FocusState private var focused: Bool

    private let placeholders = [
        "¿Qué vamos a dominar hoy?",
        "Sube un apunte para empezar el ascenso",
        "Explícame lo que no entiendes…",
        "Ponme a prueba con un tema"
    ]
    @State private var placeholderIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Text("🦉").font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Owl · Tutor Socrático")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("No te da la respuesta: te guía a encontrarla.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.white.opacity(0.85))
                TextField("", text: $draft, prompt: Text(placeholders[placeholderIndex]).foregroundColor(.white.opacity(0.65)))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(launch)
                Button(action: launch) {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.indigo)
                        .frame(width: 32, height: 32)
                        .background(.white, in: .circle)
                }
                .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.16), in: .capsule)
            .overlay(Capsule().stroke(.white.opacity(0.25)))

            HStack(spacing: 8) {
                quickChip("Repasar", "arrow.counterclockwise")
                quickChip("Resolver paso a paso", "function")
                quickChip("Tomarme un quiz", "questionmark.bubble")
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.30, blue: 0.24), Color(red: 0.16, green: 0.45, blue: 0.36)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 22)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .onAppear {
            placeholderIndex = Int.random(in: 0..<placeholders.count)
        }
        .sheet(isPresented: $showChat, onDismiss: { seed = nil }) {
            SocraticChatView(seed: seed)
        }
    }

    private func quickChip(_ title: String, _ icon: String) -> some View {
        Button {
            seed = title
            showChat = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2)
                Text(title).font(.caption.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.14), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func launch() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        focused = false
        seed = text.isEmpty ? nil : text
        draft = ""
        showChat = true
    }
}

/// Full Socratic conversation, presented as a sheet from the Home hero.
struct SocraticChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Source.createdAt, order: .reverse) private var sources: [Source]

    let seed: String?

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var sending: Bool = false
    @State private var error: String?
    @State private var didSeed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesList
                composer
            }
            .navigationTitle("Owl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
            .onAppear {
                guard !didSeed else { return }
                didSeed = true
                if let seed, !seed.isEmpty { send(seed) }
            }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty && !sending {
                        emptyState.padding(.top, 50)
                    }
                    ForEach(messages) { m in
                        MessageBubble(message: m).id(m.id)
                    }
                    if sending {
                        HStack(spacing: 8) {
                            ProgressView().tint(.green)
                            Text("Owl está pensando una pregunta…")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.leading, 12)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🦉").font(.system(size: 44))
            Text("Aprende razonando")
                .font(.headline)
            Text("Owl no te dará la respuesta directa. Te hará preguntas para que llegues tú mismo a la solución.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Escribe tu respuesta o pregunta…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: .capsule)
            Button {
                let t = input
                input = ""
                send(t)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(input.trimmingCharacters(in: .whitespaces).isEmpty || sending ? Color.gray.opacity(0.4) : Color.green, in: .circle)
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || sending)
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(.bar)
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: "user", content: trimmed))
        sending = true
        let history = messages
        let scope = sources
        Task {
            do {
                let reply = try await AIService.shared.socraticChat(history: history, sources: scope)
                messages.append(reply)
            } catch {
                self.error = error.localizedDescription
            }
            sending = false
        }
    }
}
