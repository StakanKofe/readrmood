import SwiftUI
import Combine
import Foundation

public final class AchievementsRepository: ObservableObject {
    @Published public private(set) var achievements: [Achievement] = [] {
        didSet { persistence.saveAchievements(achievements) }
    }
    @Published public private(set) var newlyUnlocked: [Achievement] = []

    private let persistence: PersistenceStore
    private let engine: AchievementsEngine
    private var cancellables = Set<AnyCancellable>()

    public init(persistence: PersistenceStore = .shared, engine: AchievementsEngine = .init()) {
        self.persistence = persistence
        self.engine = engine

        let loaded = persistence.loadAchievements()
        if loaded.isEmpty {
            let initial = AchievementsCatalog.initialState()
            self.achievements = initial
            self.persistence.saveAchievements(initial)
        } else {
            self.achievements = loaded
        }
    }

    @discardableResult
    public func evaluate(books: [Book], sessions: [ReadingSession], moods: [ReadingMood]) -> [Achievement] {
        let result = engine.evaluateAll(
            books: books,
            sessions: sessions,
            moods: moods,
            current: achievements
        )
        if result.updated != achievements {
            achievements = result.updated
        }
        if !result.newlyUnlocked.isEmpty {
            newlyUnlocked = result.newlyUnlocked
        }
        return result.newlyUnlocked
    }

    public func unlock(code: String) {
        guard let idx = achievements.firstIndex(where: { $0.code == code }) else { return }
        var item = achievements[idx]
        if !item.isUnlocked {
            item.isUnlocked = true
            item.unlockedAt = Date()
            achievements[idx] = item
        }
    }

    public func resetAll() {
        achievements = AchievementsCatalog.initialState()
        newlyUnlocked = []
    }

    public var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }

    public var totalCount: Int {
        achievements.count
    }

    public var totalPoints: Int {
        let defsByCode = Dictionary(uniqueKeysWithValues: AchievementsCatalog.definitions.map { ($0.code, $0.points) })
        return achievements.filter { $0.isUnlocked }.reduce(0) { $0 + (defsByCode[$1.code] ?? 0) }
    }

    public func connect(
        readingRepo: ReadingRepository,
        sessionsRepo: SessionsRepository,
        moodsPublisher: AnyPublisher<[ReadingMood], Never>
    ) {
        Publishers.CombineLatest3(
            readingRepo.$books.removeDuplicates(),
            sessionsRepo.$sessions.removeDuplicates(),
            moodsPublisher.removeDuplicates(by: { lhs, rhs in
                guard lhs.count == rhs.count else { return false }
                return zip(lhs, rhs).allSatisfy { $0.id == $1.id && $0.date == $1.date && $0.mood == $1.mood && $0.note == $1.note }
            })
        )
        .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
        .sink { [weak self] books, sessions, moods in
            self?.evaluate(books: books, sessions: sessions, moods: moods)
        }
        .store(in: &cancellables)
    }
}
