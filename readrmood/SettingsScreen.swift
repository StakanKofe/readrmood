import SwiftUI
import Combine
import Foundation

public struct SettingsScreen: View {
    @EnvironmentObject private var settingsVM: SettingsViewModel
    @EnvironmentObject private var readingRepo: ReadingRepository
    @EnvironmentObject private var sessionsRepo: SessionsRepository
    @EnvironmentObject private var achievementsRepo: AchievementsRepository
    @EnvironmentObject private var theme: AppTheme

    @State private var showEraseAlert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Privacy")) {
                    Button {
                        _ = settingsVM.openPrivacy()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.app.fill")
                                .foregroundStyle(.blue)
                            Text("Open Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("open_privacy_button")

//                    HStack {
//                        Text("Privacy URL")
//                            .foregroundStyle(.secondary)
//                        Spacer()
////                        Text(settingsVM.privacyURL.absoluteString)
////                            .lineLimit(1)
////                            .truncationMode(.middle)
////                            .font(.footnote)
////                            .foregroundStyle(.secondary)
//                    }
                }

//                Section(header: Text("Appearance")) {
//                    Toggle(isOn: Binding(
//                        get: { settingsVM.isDarkModeEnabled },
//                        set: { newVal in
//                            settingsVM.isDarkModeEnabled = newVal
//                            if newVal { theme.applyDark() } else { theme.applyLight() }
//                        })
//                    ) {
//                        Text("Dark Mode")
//                    }
//                }

                Section(header: Text("Data")) {
                    Button(role: .destructive) {
                        showEraseAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Erase All Data")
                        }
                    }
                    .accessibilityIdentifier("erase_all_button")
                }

                if let err = settingsVM.lastError {
                    Section {
                        Text("Error: \(err.localizedDescription)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if !settingsVM.lastActionMessage.isEmpty {
                    Section {
                        Text(settingsVM.lastActionMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Erase all data?", isPresented: $showEraseAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Erase", role: .destructive) {
                    settingsVM.eraseAllData(
                        readingRepo: readingRepo,
                        sessionsRepo: sessionsRepo,
                        achievementsRepo: achievementsRepo
                    )
                }
            } message: {
                Text("This removes books, sessions, moods, and achievements from this device.")
            }
        }
        .onAppear {
            if settingsVM.isDarkModeEnabled { theme.applyDark() } else { theme.applyLight() }
        }
        .background(ColorTokens.backgroundDark.ignoresSafeArea())
    }
}
