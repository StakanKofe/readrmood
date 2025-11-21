import SwiftUI
import Combine
import Foundation

public final class PersistenceStore: ObservableObject {
    public static let shared = PersistenceStore()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "readr.persistence.queue", qos: .utility)
    @Published public  var lastError: Error?

    public init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        ensureFolder()
    }

    
    
    public func saveBooks(_ value: [Book]) { save(value, file: .books) }
    public func loadBooks() -> [Book] { load([Book].self, file: .books) ?? [] }

    public func saveSessions(_ value: [ReadingSession]) { save(value, file: .sessions) }
    public func loadSessions() -> [ReadingSession] { load([ReadingSession].self, file: .sessions) ?? [] }

    public func saveMoods(_ value: [ReadingMood]) { save(value, file: .moods) }
    public func loadMoods() -> [ReadingMood] { load([ReadingMood].self, file: .moods) ?? [] }

    public func saveAchievements(_ value: [Achievement]) { save(value, file: .achievements) }
    public func loadAchievements() -> [Achievement] { load([Achievement].self, file: .achievements) ?? [] }

    public func saveSettings(_ value: AppSettings) { save(value, file: .settings) }
    public func loadSettings() -> AppSettings { load(AppSettings.self, file: .settings) ?? .default }

    private func ensureFolder() {
        do {
            let url = try baseURL()
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
        } catch {
            lastError = error
        }
    }

    private func baseURL() throws -> URL {
        let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return appSupport.appendingPathComponent("ReadrMoodlytic", isDirectory: true)
    }

    private func fileURL(_ file: StoreFile) throws -> URL {
        try baseURL().appendingPathComponent(file.rawValue)
    }

    private func save<T: Encodable>(_ value: T, file: StoreFile) {
        queue.async {
            do {
                let data = try self.encoder.encode(value)
                let url = try self.fileURL(file)
                try data.write(to: url, options: [.atomic])
            } catch {
                DispatchQueue.main.async { self.lastError = error }
            }
        }
    }

    private func load<T: Decodable>(_ type: T.Type, file: StoreFile) -> T? {
        do {
            let url = try fileURL(file)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            DispatchQueue.main.async { self.lastError = error }
            return nil
        }
    }
}

public enum StoreFile: String {
    case books = "books.json"
    case sessions = "sessions.json"
    case moods = "moods.json"
    case achievements = "achievements.json"
    case settings = "settings.json"
}

public struct AppSettings: Codable, Equatable {
    public var isDarkModeEnabled: Bool
    public var privacyURLString: String

    public init(isDarkModeEnabled: Bool = true, privacyURLString: String = "https://stakankofe.github.io/MyBookApp/") {
        self.isDarkModeEnabled = isDarkModeEnabled
        self.privacyURLString = privacyURLString
    }

    public var privacyURL: URL {
        URL(string: privacyURLString) ?? URL(string: "https://stakankofe.github.io/MyBookApp/")!
    }

    public static let `default` = AppSettings()
}
