import SwiftUI
import Combine
import Foundation

public final class SettingsViewModel: ObservableObject {
    @Published public private(set) var appSettings: AppSettings
    @Published public private(set) var lastError: Error?
    @Published public private(set) var lastActionMessage: String = ""

    private let persistence: PersistenceStore
    private var cancellables = Set<AnyCancellable>()

    public init(persistence: PersistenceStore = .shared) {
        self.persistence = persistence
        self.appSettings = persistence.loadSettings()
        enforceDefaults()
        observePersistenceErrors()
    }

    // MARK: - Appearance

    public var isDarkModeEnabled: Bool {
        get { appSettings.isDarkModeEnabled }
        set {
            var s = appSettings
            s.isDarkModeEnabled = newValue
            appSettings = s
            persistence.saveSettings(s)
        }
    }

    // MARK: - Privacy

    public var privacyURL: URL {
        appSettings.privacyURL
    }

    @discardableResult
    public func openPrivacy() -> Bool {
        let url = appSettings.privacyURL
        #if canImport(UIKit)
        guard UIApplication.shared.canOpenURL(url) else { return false }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
        #elseif canImport(AppKit)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }

    public func setPrivacyURLString(_ value: String) {
        var s = appSettings
        s.privacyURLString = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if URL(string: s.privacyURLString) == nil {
            s.privacyURLString = "https://stakankofe.github.io/MyBookApp/"
        }
        appSettings = s
        persistence.saveSettings(s)
    }

    // MARK: - Data Management

    public func eraseAllData(
        readingRepo: ReadingRepository,
        sessionsRepo: SessionsRepository,
        achievementsRepo: AchievementsRepository
    ) {
        readingRepo.clearAll()
        sessionsRepo.clearAll()
        achievementsRepo.resetAll()
        persistence.saveMoods([])
        lastActionMessage = "All local data erased"
    }

    // MARK: - Helpers

    private func enforceDefaults() {
        var s = appSettings
        if s.privacyURL.scheme == nil { s.privacyURLString = "https://stakankofe.github.io/MyBookApp/" }
        s.isDarkModeEnabled = true
        appSettings = s
        persistence.saveSettings(s)
    }

    private func observePersistenceErrors() {
        persistence.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] err in
                guard let self = self else { return }
                if let e = err { self.lastError = e }
            }
            .store(in: &cancellables)
    }
}
