import SwiftUI
import Combine

@main
struct ReadrMoodlyticApp: App {
    @StateObject private var theme = AppTheme()
    @StateObject private var persistence = PersistenceStore()
    @StateObject private var settings = SettingsViewModel()
    @StateObject private var readingRepo = ReadingRepository()
    @StateObject private var sessionsRepo = SessionsRepository()
    @StateObject private var achievementsRepo = AchievementsRepository()

    var body: some Scene {
        WindowGroup {
            AppRouter()
                .environmentObject(theme)
                .environmentObject(persistence)
                .environmentObject(settings)
                .environmentObject(readingRepo)
                .environmentObject(sessionsRepo)
                .environmentObject(achievementsRepo)
                .preferredColorScheme(.dark)
        }
    }
}
