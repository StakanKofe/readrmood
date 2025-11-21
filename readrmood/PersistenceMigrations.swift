import SwiftUI
import Combine
import Foundation

public final class PersistenceMigrations {
    private let persistence: PersistenceStore
    private let userDefaults: UserDefaults
    private let metaFile = "meta.json"
    private let queue = DispatchQueue(label: "readr.migrations.queue", qos: .userInitiated)

    private struct Meta: Codable {
        var schemaVersion: Int
        var migratedAt: Date
    }

    public init(persistence: PersistenceStore = .shared, userDefaults: UserDefaults = .standard) {
        self.persistence = persistence
        self.userDefaults = userDefaults
    }

    public func run() {
        queue.sync {
            let current = currentVersion()
            let target = latestVersion()
            guard current < target else { return }
            var version = current

            if version < 2 { migrate_1_to_2(); version = 2; writeVersion(version) }
            if version < 3 { migrate_2_to_3(); version = 3; writeVersion(version) }
            if version < 4 { migrate_3_to_4(); version = 4; writeVersion(version) }
            if version < 5 { migrate_4_to_5(); version = 5; writeVersion(version) }
        }
    }

    private func latestVersion() -> Int { 5 }

    private func currentVersion() -> Int {
        do {
            let url = try metaURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return 1 }
            let data = try Data(contentsOf: url)
            let meta = try JSONDecoder().decode(Meta.self, from: data)
            return meta.schemaVersion
        } catch {
            return 1
        }
    }

    private func writeVersion(_ version: Int) {
        do {
            let url = try metaURL()
            let meta = Meta(schemaVersion: version, migratedAt: Date())
            let data = try JSONEncoder().encode(meta)
            try data.write(to: url, options: [.atomic])
        } catch {
            DispatchQueue.main.async { self.persistence.lastError = error }
        }
    }

    private func metaURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ReadrMoodlytic", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(metaFile)
    }

    // MARK: - v1 -> v2
    // Move legacy UserDefaults JSON blobs into file-based store.
    private func migrate_1_to_2() {
        let books: [Book] = decodeDefaults([Book].self, key: "books") ?? []
        let sessions: [ReadingSession] = decodeDefaults([ReadingSession].self, key: "sessions") ?? []
        let moods: [ReadingMood] = decodeDefaults([ReadingMood].self, key: "moods") ?? []
        let achievements: [Achievement] = decodeDefaults([Achievement].self, key: "achievements") ?? []
        let settings: AppSettings = decodeDefaults(AppSettings.self, key: "settings") ?? .default

        persistence.saveBooks(books)
        persistence.saveSessions(sessions)
        persistence.saveMoods(moods)
        persistence.saveAchievements(achievements)
        persistence.saveSettings(settings)

        userDefaults.removeObject(forKey: "books")
        userDefaults.removeObject(forKey: "sessions")
        userDefaults.removeObject(forKey: "moods")
        userDefaults.removeObject(forKey: "achievements")
        userDefaults.removeObject(forKey: "settings")
    }

    // MARK: - v2 -> v3
    // Normalize sessions: ensure end >= start, recompute minutes if mismatch, clamp negatives to zero.
    private func migrate_2_to_3() {
        var sessions = persistence.loadSessions()
        var changed = false
        sessions = sessions.map { s in
            var copy = s
            if copy.end < copy.start {
                copy.end = copy.start
                changed = true
            }
            let computedMinutes = max(0, Int(copy.end.timeIntervalSince(copy.start) / 60.0.rounded()))
            if computedMinutes != copy.minutes {
                copy.minutes = computedMinutes
                changed = true
            }
            if copy.pages < 0 {
                copy.pages = 0
                changed = true
            }
            return copy
        }
        if changed { persistence.saveSessions(sessions) }
    }

    // MARK: - v3 -> v4
    // Deduplicate books by normalized title+author, repair invalid totals, ensure progress not exceeding totals.
    private func migrate_3_to_4() {
        var books = persistence.loadBooks()
        var seen = Set<String>()
        var filtered: [Book] = []
        for b in books {
            let key = normalize(b.title) + "::" + normalize(b.author)
            if seen.contains(key) { continue }
            seen.insert(key)
            var fixed = b
            if fixed.totalPages < 0 { fixed.totalPages = 0 }
            if fixed.currentPage < 0 { fixed.currentPage = 0 }
            if fixed.totalPages > 0, fixed.currentPage > fixed.totalPages {
                fixed.currentPage = fixed.totalPages
            }
            filtered.append(fixed)
        }
        if filtered != books { persistence.saveBooks(filtered) }
    }

    // MARK: - v4 -> v5
    // Ensure settings have a valid privacy URL and dark mode default, fix empty strings.
    private func migrate_4_to_5() {
        var settings = persistence.loadSettings()
        if settings.privacyURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.privacyURLString = "https://stakankofe.github.io/MyBookApp/"
        }
        if settings.privacyURL.scheme == nil {
            settings.privacyURLString = "https://stakankofe.github.io/MyBookApp/"
        }
        settings.isDarkModeEnabled = true
        persistence.saveSettings(settings)
    }

    private func decodeDefaults<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try? d.decode(T.self, from: data)
    }

    private func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
