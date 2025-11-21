import SwiftUI
import Combine
import Foundation

public final class AchievementsEngine {
    public init() {}

    public func evaluateAll(
        books: [Book],
        sessions: [ReadingSession],
        moods: [ReadingMood],
        current: [Achievement]
    ) -> (updated: [Achievement], newlyUnlocked: [Achievement]) {
        let defs = AchievementsCatalog.definitions
        var stateByCode = Dictionary(uniqueKeysWithValues: current.map { ($0.code, $0) })
        var newly: [Achievement] = []

        for def in defs {
            let satisfied = check(rule: def.rule, books: books, sessions: sessions, moods: moods)
            let existing = stateByCode[def.code] ?? Achievement(code: def.code, title: def.title, description: def.detail)
            if satisfied, existing.isUnlocked == false {
                var unlocked = existing
                unlocked.isUnlocked = true
                unlocked.unlockedAt = Date()
                stateByCode[def.code] = unlocked
                newly.append(unlocked)
            } else if !satisfied, existing.isUnlocked == true {
                stateByCode[def.code] = existing
            } else {
                stateByCode[def.code] = existing
            }
        }

        let ordered = AchievementsCatalog.definitions.compactMap { stateByCode[$0.code] }
        return (updated: ordered, newlyUnlocked: newly)
    }

    public func evaluateOnNewSession(
        _ session: ReadingSession,
        allBooks: [Book],
        allSessions: [ReadingSession],
        allMoods: [ReadingMood],
        current: [Achievement]
    ) -> (updated: [Achievement], newlyUnlocked: [Achievement]) {
        return evaluateAll(books: allBooks, sessions: allSessions, moods: allMoods, current: current)
    }

    public func evaluateOnNewMood(
        _ mood: ReadingMood,
        allBooks: [Book],
        allSessions: [ReadingSession],
        allMoods: [ReadingMood],
        current: [Achievement]
    ) -> (updated: [Achievement], newlyUnlocked: [Achievement]) {
        return evaluateAll(books: allBooks, sessions: allSessions, moods: allMoods, current: current)
    }

    public func evaluateOnBooksChanged(
        allBooks: [Book],
        allSessions: [ReadingSession],
        allMoods: [ReadingMood],
        current: [Achievement]
    ) -> (updated: [Achievement], newlyUnlocked: [Achievement]) {
        return evaluateAll(books: allBooks, sessions: allSessions, moods: allMoods, current: current)
    }

    private func check(rule: AchievementRule, books: [Book], sessions: [ReadingSession], moods: [ReadingMood]) -> Bool {
        switch rule {
        case .totalSessions(let min):
            return sessions.count >= min

        case .totalMinutes(let min):
            let total = sessions.reduce(0) { $0 + max(0, $1.minutes) }
            return total >= min

        case .totalPages(let min):
            let total = sessions.reduce(0) { $0 + max(0, $1.pages) }
            return total >= min

        case .streakDays(let min):
            return longestReadingStreak(from: sessions) >= min

        case .booksAdded(let min):
            return books.count >= min

        case .sessionMinutesAtLeast(let min):
            return sessions.contains(where: { $0.minutes >= min })

        case .weekendSessions(let min):
            let count = sessions.filter { Calendar.current.isDateInWeekend($0.start) }.count
            return count >= min

        case .nightSessions(let min, let startHour, let endHour):
            let count = sessions.filter { isNight(date: $0.start, startHour: startHour, endHour: endHour) }.count
            return count >= min

        case .firstMood(let kind):
            guard let first = moods.sorted(by: { $0.date < $1.date }).first else { return false }
            return first.mood == kind

        case .distinctMoods(let min):
            let distinct = Set(moods.map { $0.mood }).count
            return distinct >= min
        }
    }

    private func longestReadingStreak(from sessions: [ReadingSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let cal = Calendar.current
        let uniqueDays = Set(sessions.map { cal.startOfDay(for: $0.start) })
        let days = uniqueDays.sorted()
        var longest = 0
        var current = 0
        var prev: Date?

        for day in days {
            if let p = prev, cal.isDate(day, inSameDayAs: cal.date(byAdding: .day, value: 1, to: p) ?? p) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            prev = day
        }
        return longest
    }

    private func isNight(date: Date, startHour: Int, endHour: Int) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if startHour <= endHour {
            return (hour >= startHour && hour < endHour)
        } else {
            return hour >= startHour || hour < endHour
        }
    }
}
