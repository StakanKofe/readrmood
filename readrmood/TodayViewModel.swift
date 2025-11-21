import SwiftUI
import Combine
import Foundation

public final class TodayViewModel: ObservableObject {
    @Published public private(set) var moods: [ReadingMood] = [] {
        didSet { persistence.saveMoods(moods) }
    }

    @Published public var selectedBookId: UUID?
    @Published public var selectedMood: MoodKind = .neutral
    @Published public var note: String = ""
    @Published public var minutes: Int = 15
    @Published public var pages: Int = 5

    @Published public private(set) var isTimerRunning: Bool = false
    @Published public private(set) var clockString: String = "00:00"

    public var moodsPublisher: AnyPublisher<[ReadingMood], Never> {
        $moods.eraseToAnyPublisher()
    }

    private let readingRepo: ReadingRepository
    private let sessionsRepo: SessionsRepository
    private let achievementsRepo: AchievementsRepository
    private let persistence: PersistenceStore
    private let timer: SessionTimerEngine
    private var cancellables = Set<AnyCancellable>()

    public init(
        readingRepo: ReadingRepository = .init(),
        sessionsRepo: SessionsRepository = .init(),
        achievementsRepo: AchievementsRepository = .init(),
        persistence: PersistenceStore = .shared,
        timer: SessionTimerEngine? = nil
    ) {
        self.readingRepo = readingRepo
        self.sessionsRepo = sessionsRepo
        self.achievementsRepo = achievementsRepo
        self.persistence = persistence
        self.moods = persistence.loadMoods()
        if let t = timer {
            self.timer = t
        } else {
            self.timer = SessionTimerEngine(sessionsRepo: sessionsRepo)
        }
        bindTimer()
        achievementsRepo.connect(
            readingRepo: readingRepo,
            sessionsRepo: sessionsRepo,
            moodsPublisher: moodsPublisher
        )
        if selectedBookId == nil { selectedBookId = readingRepo.books.first?.id }
    }

    public func saveQuickToday() {
        let bookId = selectedBookId
        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        let session = sessionsRepo.addSession(
            bookId: bookId,
            start: start,
            end: end,
            minutes: minutes,
            pages: pages
        )
        if let id = bookId, pages > 0 {
            readingRepo.addProgress(for: id, pages: pages)
        }
        let mood = ReadingMood(id: UUID(), date: Date(), mood: selectedMood, note: note.isEmpty ? nil : note)
        moods.append(mood)
        achievementsRepo.evaluate(
            books: readingRepo.books,
            sessions: sessionsRepo.sessions,
            moods: moods
        )
        clearInputsAfterSave(sessionSaved: session)
    }

    public func logMoodOnly(kind: MoodKind, note: String? = nil) {
        let mood = ReadingMood(id: UUID(), date: Date(), mood: kind, note: (note ?? "").isEmpty ? nil : note)
        moods.append(mood)
        achievementsRepo.evaluate(
            books: readingRepo.books,
            sessions: sessionsRepo.sessions,
            moods: moods
        )
    }

    public func startTimer(pagesPerMinute: Double = 0) {
        guard !isTimerRunning else { return }
        timer.start(bookId: selectedBookId, pagesPerMinute: pagesPerMinute)
    }

    public func pauseTimer() {
        timer.pause()
    }

    public func resumeTimer() {
        timer.resume()
    }

    @discardableResult
    public func stopTimer(overridePages: Int? = nil, mood: MoodKind? = nil, note: String? = nil) -> ReadingSession? {
        let session = timer.stop(overridePages: overridePages)
        isTimerRunning = false
        clockString = "00:00"
        if let s = session {
            if let id = s.bookId, s.pages > 0 {
                readingRepo.addProgress(for: id, pages: s.pages)
            }
            let moodKind = mood ?? selectedMood
            let moodNote = (note ?? self.note)
            let entry = ReadingMood(id: UUID(), date: Date(), mood: moodKind, note: moodNote.isEmpty ? nil : moodNote)
            moods.append(entry)
            achievementsRepo.evaluate(
                books: readingRepo.books,
                sessions: sessionsRepo.sessions,
                moods: moods
            )
        }
        return session
    }

    public func setBook(_ id: UUID?) {
        selectedBookId = id
    }

    public func setMinutes(_ value: Int) {
        minutes = max(1, min(240, value))
    }

    public func setPages(_ value: Int) {
        pages = max(0, min(2000, value))
    }

    public func todaySummary() -> (minutes: Int, pages: Int, sessions: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let all = sessionsRepo.sessions(on: today)
        let mins = all.reduce(0) { $0 + max(0, $1.minutes) }
        let pgs = all.reduce(0) { $0 + max(0, $1.pages) }
        return (minutes: mins, pages: pgs, sessions: all.count)
    }

    public var longestStreakDays: Int {
        sessionsRepo.longestStreakDays
    }

    private func bindTimer() {
        timer.$elapsedSeconds
            .receive(on: DispatchQueue.main)
            .map { s -> String in
                let h = s / 3600
                let m = (s % 3600) / 60
                let sec = s % 60
                if h > 0 { return String(format: "%02d:%02d:%02d", h, m, sec) }
                return String(format: "%02d:%02d", m, sec)
            }
            .assign(to: &$clockString)

        timer.$state
            .receive(on: DispatchQueue.main)
            .map { $0 == .running }
            .assign(to: &$isTimerRunning)
    }

    private func clearInputsAfterSave(sessionSaved: ReadingSession?) {
        note = ""
        if let s = sessionSaved, let id = s.bookId {
            selectedBookId = id
        } else if selectedBookId == nil {
            selectedBookId = readingRepo.books.first?.id
        }
    }
}
