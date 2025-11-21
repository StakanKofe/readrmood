import SwiftUI
import Combine
import Foundation

public final class MoodboardViewModel: ObservableObject {
    @Published public private(set) var moods: [ReadingMood] = []
    @Published public private(set) var recentSessions: [ReadingSession] = []
    @Published public private(set) var recentAchievements: [Achievement] = []
    @Published public private(set) var summary: MoodboardSummary = .empty
    @Published public private(set) var topBooks: [TopBook] = []

    private let sessionsRepo: SessionsRepository
    private let readingRepo: ReadingRepository
    private let achievementsRepo: AchievementsRepository
    private let persistence: PersistenceStore
    private var cancellables = Set<AnyCancellable>()
    private let cal = Calendar.current

    public init(
        sessionsRepo: SessionsRepository = .init(),
        readingRepo: ReadingRepository = .init(),
        achievementsRepo: AchievementsRepository = .init(),
        persistence: PersistenceStore = .shared
    ) {
        self.sessionsRepo = sessionsRepo
        self.readingRepo = readingRepo
        self.achievementsRepo = achievementsRepo
        self.persistence = persistence

        self.moods = persistence.loadMoods()
        bind()
        refresh()
    }

    public struct MoodboardSummary: Equatable {
        public let dominant: MoodKind
        public let avgEnergy: Double
        public let avgValence: Double
        public let longestStreakDays: Int
        public let minutes7d: Int
        public let pages7d: Int
        public let sessions7d: Int

        public static let empty = MoodboardSummary(
            dominant: .neutral,
            avgEnergy: 0.5,
            avgValence: 0.6,
            longestStreakDays: 0,
            minutes7d: 0,
            pages7d: 0,
            sessions7d: 0
        )
    }

    public struct TopBook: Identifiable, Equatable {
        public let id: UUID
        public let title: String
        public let minutes: Int
        public let pages: Int
        public let progress: Double
    }

    public func connect(moodsPublisher: AnyPublisher<[ReadingMood], Never>) {
        moodsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self = self else { return }
                self.moods = list
                self.persistence.saveMoods(list)
                self.recomputeSummary()
            }
            .store(in: &cancellables)
    }

    public func addMood(_ mood: MoodKind, note: String? = nil) {
        var updated = moods
        updated.append(ReadingMood(id: UUID(), date: Date(), mood: mood, note: (note ?? "").isEmpty ? nil : note))
        moods = updated
        persistence.saveMoods(updated)
        refresh()
    }

    public func refresh() {
        recentSessions = Array(sessionsRepo.sessions.prefix(50))
        recentAchievements = achievementsRepo.achievements
            .filter { $0.isUnlocked }
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
            .prefix(20)
            .map { $0 }
        recomputeSummary()
        recomputeTopBooks()
    }

    private func bind() {
        sessionsRepo.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        achievementsRepo.$achievements
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        readingRepo.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recomputeTopBooks() }
            .store(in: &cancellables)
    }

    private func recomputeSummary() {
        let dominant = MoodTaxonomy.dominantKind(from: moods)
        let agg = MoodTaxonomy.aggregateMetrics(from: moods)

        let bounds7 = lastNDaysBounds(7)
        let sessions7 = sessionsRepo.sessions(range: bounds7)
        let minutes7 = sessions7.reduce(0) { $0 + max(0, $1.minutes) }
        let pages7 = sessions7.reduce(0) { $0 + max(0, $1.pages) }

        summary = MoodboardSummary(
            dominant: dominant,
            avgEnergy: agg.energy,
            avgValence: agg.valence,
            longestStreakDays: sessionsRepo.longestStreakDays,
            minutes7d: minutes7,
            pages7d: pages7,
            sessions7d: sessions7.count
        )
    }

    private func recomputeTopBooks() {
        var totals: [UUID: (minutes: Int, pages: Int)] = [:]
        for s in sessionsRepo.sessions {
            guard let id = s.bookId else { continue }
            let prev = totals[id] ?? (0, 0)
            totals[id] = (prev.minutes + max(0, s.minutes), prev.pages + max(0, s.pages))
        }

        let items: [TopBook] = totals.compactMap { id, stat in
            guard let b = readingRepo.find(by: id) else { return nil }
            return TopBook(
                id: id,
                title: b.title,
                minutes: stat.minutes,
                pages: stat.pages,
                progress: b.progress
            )
        }
        .sorted { (l, r) in
            if l.minutes != r.minutes { return l.minutes > r.minutes }
            return l.pages > r.pages
        }
        .prefix(5)
        .map { $0 }

        topBooks = items
    }

    private func lastNDaysBounds(_ n: Int) -> ClosedRange<Date> {
        let startOfToday = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(n - 1), to: startOfToday) ?? startOfToday
        let end = cal.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        return start...end
    }
}
