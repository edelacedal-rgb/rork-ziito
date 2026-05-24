import Foundation
import SwiftData

enum SourceKind: String, Codable {
    case pdf
    case text
    case url

    var label: String {
        switch self {
        case .pdf: return "PDF"
        case .text: return "Texto"
        case .url: return "Enlace"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: return "doc.richtext.fill"
        case .text: return "text.alignleft"
        case .url: return "link"
        }
    }
}

@Model
final class Source {
    var id: UUID
    var title: String
    var kindRaw: String
    var subjectID: UUID?
    var notebookPageID: UUID?
    var sourceURL: String?
    var localFileName: String?
    var rawText: String
    var summary: String
    var studyGuide: String
    var glossary: String
    var pageCount: Int
    var createdAt: Date

    init(
        title: String,
        kind: SourceKind,
        rawText: String,
        subjectID: UUID? = nil,
        notebookPageID: UUID? = nil,
        sourceURL: String? = nil,
        localFileName: String? = nil,
        pageCount: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.kindRaw = kind.rawValue
        self.subjectID = subjectID
        self.notebookPageID = notebookPageID
        self.sourceURL = sourceURL
        self.localFileName = localFileName
        self.rawText = rawText
        self.summary = ""
        self.studyGuide = ""
        self.glossary = ""
        self.pageCount = pageCount
        self.createdAt = Date()
    }

    var kind: SourceKind {
        SourceKind(rawValue: kindRaw) ?? .text
    }

    var isAnalyzed: Bool {
        !summary.isEmpty
    }

    var wordCount: Int {
        rawText.split { $0.isWhitespace || $0.isNewline }.count
    }

    /// Returns trimmed snippet used as grounding context for the LLM.
    func context(limit: Int = 6000) -> String {
        if rawText.count <= limit { return rawText }
        return String(rawText.prefix(limit))
    }
}

@Model
final class NotebookPage {
    var id: UUID
    var title: String
    var subjectID: UUID?
    var parentID: UUID?
    var bodyMarkdown: String
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        subjectID: UUID? = nil,
        parentID: UUID? = nil,
        bodyMarkdown: String = "",
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.subjectID = subjectID
        self.parentID = parentID
        self.bodyMarkdown = bodyMarkdown
        self.orderIndex = orderIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class Flashcard {
    var id: UUID
    var sourceID: UUID?
    var subjectID: UUID?
    var front: String
    var back: String
    var ease: Double
    var nextReview: Date
    var createdAt: Date

    init(
        front: String,
        back: String,
        sourceID: UUID? = nil,
        subjectID: UUID? = nil
    ) {
        self.id = UUID()
        self.front = front
        self.back = back
        self.sourceID = sourceID
        self.subjectID = subjectID
        self.ease = 2.5
        self.nextReview = Date()
        self.createdAt = Date()
    }
}
