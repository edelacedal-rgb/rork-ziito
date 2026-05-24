import SwiftUI
import SwiftData

@main
struct ZiitoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            Exam.self,
            StudySession.self,
            StudyTask.self,
            ClassSession.self,
            FocusLog.self,
            Source.self,
            NotebookPage.self,
            Flashcard.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
