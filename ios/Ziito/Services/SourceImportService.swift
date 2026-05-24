import Foundation
import PDFKit

enum SourceImportError: Error, LocalizedError {
    case unreadable
    case empty
    case invalidURL
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .unreadable: return "No se pudo leer el archivo."
        case .empty: return "El contenido está vacío."
        case .invalidURL: return "URL inválida."
        case .http(let c): return "Error al descargar (\(c))."
        }
    }
}

@MainActor
final class SourceImportService {
    static let shared = SourceImportService()
    private init() {}

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Imports a PDF: copies to Documents, extracts text.
    func importPDF(from url: URL, title: String?) async throws -> Source {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        guard let pdf = PDFDocument(url: url) else { throw SourceImportError.unreadable }

        var text = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i), let s = page.string {
                text += "\n\n--- Página \(i + 1) ---\n\n" + s
            }
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SourceImportError.empty
        }

        // Copy file
        let fileName = "src_\(UUID().uuidString).pdf"
        let dest = documentsDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try? FileManager.default.copyItem(at: url, to: dest)

        let resolvedTitle = title?.isEmpty == false ? title! : url.deletingPathExtension().lastPathComponent
        return Source(
            title: resolvedTitle,
            kind: .pdf,
            rawText: text,
            localFileName: fileName,
            pageCount: pdf.pageCount
        )
    }

    func importText(title: String, text: String) -> Source {
        Source(title: title, kind: .text, rawText: text)
    }

    func importURL(_ urlString: String) async throws -> Source {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
            throw SourceImportError.invalidURL
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 30
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SourceImportError.http(http.statusCode)
        }
        let html = String(data: data, encoding: .utf8) ?? ""
        let text = Self.stripHTML(html)
        guard !text.isEmpty else { throw SourceImportError.empty }
        let title = Self.extractTitle(from: html) ?? url.host ?? "Enlace"
        return Source(
            title: title,
            kind: .url,
            rawText: text,
            sourceURL: urlString
        )
    }

    private static func stripHTML(_ html: String) -> String {
        // Remove script/style blocks
        var s = html
        for tag in ["script", "style", "nav", "footer", "header"] {
            let pattern = "(?is)<\(tag).*?>.*?</\(tag)>"
            if let r = try? NSRegularExpression(pattern: pattern) {
                s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
            }
        }
        // Remove tags
        if let r = try? NSRegularExpression(pattern: "<[^>]+>") {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }
        // Decode common entities
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        // Collapse whitespace
        if let r = try? NSRegularExpression(pattern: "\\s+") {
            s = r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractTitle(from html: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: "(?is)<title>(.*?)</title>"),
              let m = r.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(m.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
