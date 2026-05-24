import Foundation

struct ScannedExam: Identifiable {
    let id = UUID()
    var title: String
    var date: Date
    var priority: PriorityLevel = .medium
    var subjectID: UUID?
    var isSelected: Bool = true
}
