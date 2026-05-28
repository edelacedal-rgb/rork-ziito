import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var role: String // "user" | "assistant" | "system"
    var content: String
    var citations: [Citation]
    var createdAt: Date

    init(role: String, content: String, citations: [Citation] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.citations = citations
        self.createdAt = Date()
    }
}

struct Citation: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var sourceTitle: String
    var snippet: String
    var page: Int?

    enum CodingKeys: String, CodingKey {
        case sourceTitle, snippet, page
    }
}

struct CoreMessage: Encodable {
    let role: String
    let content: String
}

struct LLMResponse: Decodable {
    let completion: String
}

enum AIError: Error, LocalizedError {
    case http(Int)
    case noContent
    case decoding

    var errorDescription: String? {
        switch self {
        case .http(let code): return "Error de red (\(code))"
        case .noContent: return "Respuesta vacía"
        case .decoding: return "No se pudo procesar la respuesta"
        }
    }
}

@Observable
@MainActor
final class AIService {
    static let shared = AIService()

    private let endpoint = URL(string: "https://toolkit.rork.com/text/llm/")!

    private init() {}

    // MARK: - Core

    func complete(messages: [CoreMessage]) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["messages": messages.map { ["role": $0.role, "content": $0.content] }]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIError.http(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)
        let trimmed = decoded.completion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.noContent }
        return trimmed
    }

    // MARK: - Source analysis

    func analyzeSource(title: String, text: String) async throws -> (summary: String, studyGuide: String, glossary: String) {
        let context = String(text.prefix(8000))
        let prompt = """
        Analiza el siguiente material de estudio y devuelve EXCLUSIVAMENTE un JSON válido con tres claves: "summary", "studyGuide", "glossary".

        - summary: resumen ejecutivo (máx 180 palabras) de los conceptos clave en español.
        - studyGuide: guía de estudio en formato Markdown con 5-8 secciones, cada una con 2-4 viñetas concretas.
        - glossary: lista en Markdown de 8-15 términos clave, formato "**Término** — definición breve".

        Título: \(title)

        Texto fuente:
        ```
        \(context)
        ```

        Devuelve solo el JSON, sin texto adicional, sin bloques de código.
        """
        let raw = try await complete(messages: [
            CoreMessage(role: "system", content: "Eres un asistente experto en pedagogía. Respondes únicamente con JSON válido cuando se solicita."),
            CoreMessage(role: "user", content: prompt)
        ])
        let json = Self.extractJSON(from: raw)
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.decoding
        }
        return (
            dict["summary"] as? String ?? "",
            dict["studyGuide"] as? String ?? "",
            dict["glossary"] as? String ?? ""
        )
    }

    func generateFlashcards(title: String, text: String, count: Int = 10) async throws -> [(front: String, back: String)] {
        let context = String(text.prefix(7000))
        let prompt = """
        Crea \(count) flashcards de estudio a partir del texto. Devuelve SOLO un JSON con esta forma:
        { "cards": [ { "front": "pregunta", "back": "respuesta" }, ... ] }

        Las preguntas deben evaluar comprensión real, no solo memoria literal. Respuestas concisas.

        Título: \(title)
        Texto:
        ```
        \(context)
        ```
        """
        let raw = try await complete(messages: [
            CoreMessage(role: "system", content: "Eres un tutor que crea flashcards de alta calidad. Solo devuelves JSON válido."),
            CoreMessage(role: "user", content: prompt)
        ])
        let json = Self.extractJSON(from: raw)
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = dict["cards"] as? [[String: Any]] else {
            throw AIError.decoding
        }
        return arr.compactMap { c in
            guard let f = c["front"] as? String, let b = c["back"] as? String else { return nil }
            return (f, b)
        }
    }

    // MARK: - Schedule extraction

    func parseSchedule(text: String) async throws -> String {
        let context = String(text.prefix(8000))
        let prompt = """
        Extrae el horario escolar/universitario del siguiente texto. Devuelve EXCLUSIVAMENTE un JSON válido con esta forma:

        {
          "classes": [
            { "name": "Matemáticas", "day": "lunes", "start": "08:00", "end": "09:30", "location": "A201" }
          ]
        }

        Reglas:
        - day debe ser uno de: lunes, martes, miercoles, jueves, viernes, sabado, domingo.
        - start y end en formato 24h "HH:MM".
        - Si una clase se repite varios días, genérala una vez por día.
        - Si el aula/sala está entre paréntesis o aparte, inclúyela en location (puede ir vacía).
        - Ignora encabezados, totales o filas que no representen una clase.
        - No inventes clases. Si no encuentras nada, devuelve { "classes": [] }.

        Texto OCR:
        ```
        \(context)
        ```

        Devuelve solo el JSON, sin explicaciones ni bloques de código.
        """
        let raw = try await complete(messages: [
            CoreMessage(role: "system", content: "Eres un asistente que extrae horarios escolares estructurados. Solo devuelves JSON válido."),
            CoreMessage(role: "user", content: prompt)
        ])
        return Self.extractJSON(from: raw)
    }

    // MARK: - Chat (with optional source grounding)

    func chat(history: [ChatMessage], sources: [Source], sourcesOnly: Bool) async throws -> ChatMessage {
        var system = """
        Eres Astra, un tutor académico amable y preciso. Respondes en español. Estructura tus respuestas con claridad usando Markdown cuando ayude.
        """
        if !sources.isEmpty {
            let pack = sources.enumerated().map { idx, s in
                "[FUENTE \(idx + 1)] \(s.title) (\(s.kind.label)):\n\(s.context(limit: 4000))"
            }.joined(separator: "\n\n---\n\n")
            if sourcesOnly {
                system += """


                MODO 'SOLO FUENTES': Responde EXCLUSIVAMENTE con información presente en las FUENTES proporcionadas. Si la información no está, responde literalmente: "No encuentro esa información en tus fuentes." Cita siempre la fuente al final usando el formato [Fuente: Título, fragmento: "..."].
                """
            } else {
                system += """


                Cuando uses información de las fuentes, cita la fuente al final con el formato [Fuente: Título, fragmento: "..."].
                """
            }
            system += "\n\nFUENTES:\n\(pack)"
        }

        var messages: [CoreMessage] = [CoreMessage(role: "system", content: system)]
        for m in history {
            messages.append(CoreMessage(role: m.role, content: m.content))
        }
        let raw = try await complete(messages: messages)
        let citations = Self.extractCitations(from: raw, sources: sources)
        return ChatMessage(role: "assistant", content: raw, citations: citations)
    }

    // MARK: - Socratic tutor (Home hero)

    /// Astra in Socratic mode: never gives the final answer outright; guides with
    /// counter-questions and step-by-step challenges to verify real understanding.
    func socraticChat(history: [ChatMessage], sources: [Source]) async throws -> ChatMessage {
        var system = """
        Eres Astra, un tutor socrático para estudiantes. Respondes en español, con calidez y precisión.

        MÉTODO SOCRÁTICO (obligatorio):
        - NUNCA entregues la solución o respuesta final de golpe.
        - Descompón el problema en pasos pequeños y guía con contrapreguntas.
        - Haz UNA pregunta clave a la vez para verificar la comprensión real.
        - Si el estudiante se equivoca, no lo corrijas directamente: ofrece una pista o una pregunta que lo lleve a notar el error.
        - Solo cuando el estudiante haya razonado los pasos, confirma y resume brevemente lo aprendido.
        - Sé conciso (2-5 frases). Usa Markdown ligero cuando ayude.
        """
        if !sources.isEmpty {
            let pack = sources.enumerated().map { idx, s in
                "[FUENTE \(idx + 1)] \(s.title) (\(s.kind.label)):\n\(s.context(limit: 3000))"
            }.joined(separator: "\n\n---\n\n")
            system += "\n\nApóyate en los apuntes del estudiante cuando sea relevante:\n\(pack)"
        }

        var messages: [CoreMessage] = [CoreMessage(role: "system", content: system)]
        for m in history {
            messages.append(CoreMessage(role: m.role, content: m.content))
        }
        let raw = try await complete(messages: messages)
        return ChatMessage(role: "assistant", content: raw)
    }

    // MARK: - Helpers

    private static func extractJSON(from text: String) -> String {
        var t = text
        if let range = t.range(of: "```json") {
            t = String(t[range.upperBound...])
        } else if let range = t.range(of: "```") {
            t = String(t[range.upperBound...])
        }
        if let end = t.range(of: "```") {
            t = String(t[..<end.lowerBound])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractCitations(from text: String, sources: [Source]) -> [Citation] {
        let pattern = #"\[Fuente:\s*([^,\]]+)(?:,\s*fragmento:\s*"([^"]+)")?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var result: [Citation] = []
        for m in matches {
            let title = m.range(at: 1).location != NSNotFound ? ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces) : ""
            let snippet = m.numberOfRanges > 2 && m.range(at: 2).location != NSNotFound
                ? ns.substring(with: m.range(at: 2))
                : ""
            result.append(Citation(sourceTitle: title, snippet: snippet, page: nil))
            _ = sources.first { $0.title == title }
        }
        return result
    }
}
