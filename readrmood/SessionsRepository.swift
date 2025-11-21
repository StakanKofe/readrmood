import SwiftUI
import Combine
import Foundation

public final class SessionsRepository: ObservableObject {
    @Published public private(set) var sessions: [ReadingSession] = [] {
        didSet { persistence.saveSessions(sessions) }
    }

    private let persistence: PersistenceStore
    private let cal = Calendar.current

    public init(persistence: PersistenceStore = .shared) {
        self.persistence = persistence
        self.sessions = persistence.loadSessions()
        normalize()
    }

    @discardableResult
    public func addSession(bookId: UUID?, start: Date, end: Date, minutes: Int, pages: Int) -> ReadingSession {
        let fixed = fixSession(bookId: bookId, start: start, end: end, minutes: minutes, pages: pages)
        sessions.append(fixed)
        sortInPlace()
        return fixed
    }

    public func updateSession(id: UUID,
                              bookId: UUID? = nil,
                              start: Date? = nil,
                              end: Date? = nil,
                              minutes: Int? = nil,
                              pages: Int? = nil) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        var s = sessions[idx]
        if let b = bookId { s.bookId = b }
        if let st = start { s.start = st }
        if let en = end { s.end = en }
        if let m = minutes { s.minutes = m }
        if let p = pages { s.pages = p }
        s = fixSession(bookId: s.bookId, start: s.start, end: s.end, minutes: s.minutes, pages: s.pages, id: s.id)
        sessions[idx] = s
        sortInPlace()
    }

    public func removeSession(id: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions.remove(at: idx)
    }

    public func removeSessions(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
    }

    public func clearAll() {
        sessions.removeAll()
    }

    public func sessions(on day: Date) -> [ReadingSession] {
        let startOfDay = cal.startOfDay(for: day)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        return sessions.filter { $0.start >= startOfDay && $0.start < endOfDay }
    }

    public func sessions(range: ClosedRange<Date>) -> [ReadingSession] {
        sessions.filter { range.contains($0.start) }
    }

    public var totalMinutes: Int {
        sessions.reduce(0) { $0 + max(0, $1.minutes) }
    }

    public var totalPages: Int {
        sessions.reduce(0) { $0 + max(0, $1.pages) }
    }

    public func totalMinutes(bookId: UUID) -> Int {
        sessions.filter { $0.bookId == bookId }.reduce(0) { $0 + max(0, $1.minutes) }
    }

    public func totalPages(bookId: UUID) -> Int {
        sessions.filter { $0.bookId == bookId }.reduce(0) { $0 + max(0, $1.pages) }
    }

    public var longestStreakDays: Int {
        longestStreak(from: sessions)
    }

    public func longestStreak(from input: [ReadingSession]) -> Int {
        guard !input.isEmpty else { return 0 }
        let daysSet = Set(input.map { cal.startOfDay(for: $0.start) })
        let sortedDays = daysSet.sorted()
        var longest = 0
        var current = 0
        var prev: Date?

        for d in sortedDays {
            if let p = prev, cal.isDate(d, inSameDayAs: cal.date(byAdding: .day, value: 1, to: p) ?? p) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            prev = d
        }
        return longest
    }

    public func countWeekendSessions() -> Int {
        sessions.filter { cal.isDateInWeekend($0.start) }.count
    }

    public func countNightSessions(startHour: Int = 23, endHour: Int = 5) -> Int {
        sessions.filter { isNight(date: $0.start, startHour: startHour, endHour: endHour) }.count
    }

    private func normalize() {
        var cleaned: [ReadingSession] = []
        var seen = Set<UUID>()
        for s in sessions {
            if seen.contains(s.id) { continue }
            seen.insert(s.id)
            cleaned.append(fixSession(bookId: s.bookId, start: s.start, end: s.end, minutes: s.minutes, pages: s.pages, id: s.id))
        }
        sessions = cleaned.sorted(by: { $0.start > $1.start })
    }

    private func sortInPlace() {
        sessions.sort { $0.start > $1.start }
    }

    private func fixSession(bookId: UUID?, start: Date, end: Date, minutes: Int, pages: Int, id: UUID = UUID()) -> ReadingSession {
        var sStart = start
        var sEnd = end
        if sEnd < sStart { sEnd = sStart }
        let computed = max(0, Int((sEnd.timeIntervalSince(sStart) / 60.0).rounded()))
        let finalMinutes = max(computed, minutes)
        let finalPages = max(0, pages)
        return ReadingSession(id: id, bookId: bookId, start: sStart, end: sEnd, minutes: finalMinutes, pages: finalPages)
    }

    private func isNight(date: Date, startHour: Int, endHour: Int) -> Bool {
        let hour = cal.component(.hour, from: date)
        if startHour <= endHour {
            return hour >= startHour && hour < endHour
        } else {
            return hour >= startHour || hour < endHour
        }
    }
}
