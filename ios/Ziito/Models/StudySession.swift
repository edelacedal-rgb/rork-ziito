import Foundation
import SwiftData
import SwiftUI

@Model
final class StudySession {
    var id: UUID
    var examID: UUID
    var subjectID: UUID
    var date: Date
    var durationMinutes: Int
    var isCompleted: Bool
    var orderIndex: Int

    init(examID: UUID, subjectID: UUID, date: Date, durationMinutes: Int, orderIndex: Int) {
        self.id = UUID()
        self.examID = examID
        self.subjectID = subjectID
        self.date = date
        self.durationMinutes = durationMinutes
        self.isCompleted = false
        self.orderIndex = orderIndex
    }
}

struct StudyBlock: Identifiable {
    let id = UUID()
    let examID: UUID
    let subjectID: UUID
    let subjectName: String
    let subjectColor: Color
    let examTitle: String
    let date: Date
    let durationMinutes: Int
    let priority: PriorityLevel
    let isCompleted: Bool
}
