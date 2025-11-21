import SwiftUI
import Combine
import Foundation

public struct AppRouter: View {
    @EnvironmentObject private var theme: AppTheme
    @EnvironmentObject private var settings: SettingsViewModel
    @EnvironmentObject private var achievementsRepo: AchievementsRepository

    @State private var selected: AppIcons.TabKind = .today
    @State private var showAchievementsSheet = false

    public init() {}

    public var body: some View {
        TabView(selection: $selected) {
            TodayScreen()
                .tabItem {
                    AppIcons.today
                    Text("Today")
                }
                .tag(AppIcons.TabKind.today)

            LibraryScreen()
                .tabItem {
                    AppIcons.library
                    Text("Library")
                }
                .tag(AppIcons.TabKind.library)

            SessionsScreen()
                .tabItem {
                    AppIcons.sessions
                    Text("Sessions")
                }
                .tag(AppIcons.TabKind.sessions)

            MoodboardScreen()
                .tabItem {
                    AppIcons.moodboard
                    Text("Moodboard")
                }
                .tag(AppIcons.TabKind.moodboard)

            SettingsScreen()
                .tabItem {
                    AppIcons.settings
                    Text("Settings")
                }
                .tag(AppIcons.TabKind.settings)
        }
        .onAppear {
            settings.isDarkModeEnabled ? theme.applyDark() : theme.applyLight()
        }
        .onReceive(achievementsRepo.$newlyUnlocked) { list in
            if !list.isEmpty { showAchievementsSheet = true }
        }
        .sheet(isPresented: $showAchievementsSheet) {
            AchievementsSheet()
        }
    }
}
