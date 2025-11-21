import SwiftUI
import Combine
import Foundation

public final class SessionsViewModel: ObservableObject {
    @Published public private(set) var sessions: [ReadingSession] = []
    @Published public private(set) var sections: [DaySection] = []
    @Published public private(set) var stats: SessionsStats = .zero
    @Published public var bookFilter: UUID? { didSet { apply() } }
    @Published public var rangeFilter: DateRange = .last30 { didSet { apply() } }
    @Published public var sort: SortMode = .newestFirst { didSet { apply() } }

    private let sessionsRepo: SessionsRepository
    private let readingRepo: ReadingRepository
    private var cancellables = Set<AnyCancellable>()
    private let cal = Calendar.current

    public init(sessionsRepo: SessionsRepository = .init(),
                readingRepo: ReadingRepository = .init()) {
        self.sessionsRepo = sessionsRepo
        self.readingRepo = readingRepo
        self.bookFilter = nil
        bind()
        sync()
    }

    public enum SortMode: String, CaseIterable, Identifiable {
        case newestFirst
        case oldestFirst
        case longestFirst
        case pagesFirst
        public var id: String { rawValue }
    }

    public enum DateRange: String, CaseIterable, Identifiable {
        case today
        case last7
        case last30
        case all
        public var id: String { rawValue }

        public func bounds(now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date>? {
            let startOfToday = calendar.startOfDay(for: now)
            switch self {
            case .today:
                let end = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
                return startOfToday...end
            case .last7:
                let start = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
                let end = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
                return start...end
            case .last30:
                let start = calendar.date(byAdding: .day, value: -29, to: startOfToday)!
                let end = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
                return start...end
            case .all:
                return nil
            }
        }
    }

    public struct SessionsStats: Equatable {
        public let count: Int
        public let minutes: Int
        public let pages: Int
        public let longestStreakDays: Int
        public static let zero = SessionsStats(count: 0, minutes: 0, pages: 0, longestStreakDays: 0)
    }

    public struct DaySection: Identifiable, Equatable {
        public let id: Date
        public let day: Date
        public let title: String
        public let items: [ReadingSession]
        public let minutes: Int
        public let pages: Int
    }

    // MARK: - CRUD

    @discardableResult
    public func add(bookId: UUID?, start: Date, end: Date, minutes: Int, pages: Int) -> ReadingSession {
        let s = sessionsRepo.addSession(bookId: bookId, start: start, end: end, minutes: minutes, pages: pages)
        sync()
        return s
    }

    public func update(id: UUID,
                       bookId: UUID? = nil,
                       start: Date? = nil,
                       end: Date? = nil,
                       minutes: Int? = nil,
                       pages: Int? = nil) {
        sessionsRepo.updateSession(id: id, bookId: bookId, start: start, end: end, minutes: minutes, pages: pages)
        sync()
    }

    public func remove(id: UUID) {
        sessionsRepo.removeSession(id: id)
        sync()
    }

    public func remove(at offsets: IndexSet, in section: DaySection) {
        let ids = offsets.map { section.items[$0].id }
        ids.forEach { sessionsRepo.removeSession(id: $0) }
        sync()
    }

    public func clearAll() {
        sessionsRepo.clearAll()
        sync()
    }

    // MARK: - Export

    public func exportCSV() throws -> URL {
        let url = try temporaryCSVURL()
        let csv = buildCSV(for: sessions)
        try csv.data(using: .utf8)?.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - Queries

    public func titleForBook(_ id: UUID?) -> String {
        guard let id = id, let b = readingRepo.find(by: id) else { return "Unassigned" }
        return b.title
    }

    public func sessionsForDay(_ date: Date) -> [ReadingSession] {
        sessionsRepo.sessions(on: date)
    }

    // MARK: - Private

    private func bind() {
        sessionsRepo.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &cancellables)

        readingRepo.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.apply() }
            .store(in: &cancellables)
    }

    private func sync() {
        sessions = sessionsRepo.sessions
        apply()
    }

    private func apply() {
        var list = sessions

        if let bounds = rangeFilter.bounds(), let lower = bounds.lowerBound as Date?, let upper = bounds.upperBound as Date? {
            list = list.filter { $0.start >= lower && $0.start <= upper }
        }

        if let filterBook = bookFilter {
            list = list.filter { $0.bookId == filterBook }
        }

        switch sort {
        case .newestFirst:
            list.sort { $0.start > $1.start }
        case .oldestFirst:
            list.sort { $0.start < $1.start }
        case .longestFirst:
            list.sort { ($0.minutes, $0.start) > ($1.minutes, $1.start) }
        case .pagesFirst:
            list.sort { ($0.pages, $0.start) > ($1.pages, $1.start) }
        }

        sections = groupByDay(list)
        stats = computeStats(from: list)
    }

    private func groupByDay(_ items: [ReadingSession]) -> [DaySection] {
        let grouped = Dictionary(grouping: items) { cal.startOfDay(for: $0.start) }
        let days = grouped.keys.sorted(by: >)
        return days.map { day in
            let arr = (grouped[day] ?? []).sorted { $0.start > $1.start }
            let mins = arr.reduce(0) { $0 + max(0, $1.minutes) }
            let pgs = arr.reduce(0) { $0 + max(0, $1.pages) }
            let title = sectionTitle(for: day)
            return DaySection(id: day, day: day, title: title, items: arr, minutes: mins, pages: pgs)
        }
    }

    private func sectionTitle(for day: Date) -> String {
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: day)
    }

    private func computeStats(from list: [ReadingSession]) -> SessionsStats {
        let count = list.count
        let minutes = list.reduce(0) { $0 + max(0, $1.minutes) }
        let pages = list.reduce(0) { $0 + max(0, $1.pages) }
        let streak = sessionsRepo.longestStreakDays
        return SessionsStats(count: count, minutes: minutes, pages: pages, longestStreakDays: streak)
    }

    private func temporaryCSVURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let name = "sessions-\(Int(Date().timeIntervalSince1970)).csv"
        return dir.appendingPathComponent(name)
    }

    private func buildCSV(for items: [ReadingSession]) -> String {
        var lines: [String] = ["id,book,title,start,end,minutes,pages"]
        for s in items {
            let id = s.id.uuidString
            let bookTitle = titleForBook(s.bookId).replacingOccurrences(of: ",", with: " ")
            let start = iso8601(s.start)
            let end = iso8601(s.end)
            let m = "\(max(0, s.minutes))"
            let p = "\(max(0, s.pages))"
            let bookIdString = s.bookId?.uuidString ?? ""
            lines.append("\(id),\(bookIdString),\(bookTitle),\(start),\(end),\(m),\(p)")
        }
        return lines.joined(separator: "\n")
    }

    private func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}
