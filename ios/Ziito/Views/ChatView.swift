import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Source.createdAt, order: .reverse) private var allSources: [Source]

    let scopedSources: [Source]

    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    @State private var sourcesOnly: Bool = true
    @State private var sending: Bool = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modeBar
                messagesList
                composer
            }
            .navigationTitle("Astra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
            .alert("Error", isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(error ?? "") }
        }
    }

    private var activeSources: [Source] {
        scopedSources.isEmpty ? allSources : scopedSources
    }

    private var modeBar: some View {
        HStack {
            Toggle(isOn: $sourcesOnly) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(.indigo)
                    Text("Solo fuentes")
                        .font(.subheadline.weight(.medium))
                }
            }
            .toggleStyle(.switch)
            .tint(.indigo)
            Spacer()
            Text("\(activeSources.count) fuente\(activeSources.count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        emptyState.padding(.top, 40)
                    }
                    ForEach(messages) { m in
                        MessageBubble(message: m).id(m.id)
                    }
                    if sending {
                        HStack { ProgressView().tint(.indigo); Text("Pensando…").font(.caption).foregroundStyle(.secondary) }
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

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Pregúntale a tus apuntes…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: .capsule)
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(input.isEmpty || sending ? Color.gray.opacity(0.4) : Color.indigo, in: .circle)
            }
            .disabled(input.isEmpty || sending)
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(.bar)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.purple)
            Text("Tu tutor offline-first")
                .font(.headline)
            Text(sourcesOnly
                 ? "Astra responderá usando solo tus fuentes y citará dónde lo encontró."
                 : "Astra puede usar conocimiento general además de tus fuentes.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        let userMsg = ChatMessage(role: "user", content: text)
        messages.append(userMsg)
        sending = true
        let history = messages
        let scope = activeSources
        let only = sourcesOnly
        Task {
            do {
                let reply = try await AIService.shared.chat(history: history, sources: scope, sourcesOnly: only)
                messages.append(reply)
            } catch {
                self.error = error.localizedDescription
            }
            sending = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(message.content))
                    .font(.callout)
                    .foregroundStyle(isUser ? .white : .primary)
                if !message.citations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(message.citations) { c in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "quote.opening").font(.caption2).foregroundStyle(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.sourceTitle).font(.caption.weight(.semibold))
                                    if !c.snippet.isEmpty {
                                        Text("\"\(c.snippet)\"").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(.purple.opacity(0.10), in: .rect(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                isUser ? AnyShapeStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                       : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                in: .rect(cornerRadius: 16)
            )
            if !isUser { Spacer(minLength: 40) }
        }
    }
}
