import SwiftUI
import Combine
import Foundation

public final class SessionTimerEngine: ObservableObject {
    public enum State: Equatable {
        case idle
        case running
        case paused
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var elapsedSeconds: Int = 0
    @Published public private(set) var bookId: UUID? = nil
    @Published public private(set) var startedAt: Date? = nil

    public var formattedClock: String {
        let s = max(0, elapsedSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%02d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }

    private let sessionsRepo: SessionsRepository
    private var tickCancellable: AnyCancellable?
    private var backgroundCancellable: AnyCancellable?
    private var foregroundCancellable: AnyCancellable?

    private var lastResumeAt: Date?
    private var accumulatedBeforePause: TimeInterval = 0

    public var pagesPerMinute: Double = 0

    public init(sessionsRepo: SessionsRepository = .init()) {
        self.sessionsRepo = sessionsRepo
        observeAppLifecycle()
    }

    deinit {
        tickCancellable?.cancel()
        backgroundCancellable?.cancel()
        foregroundCancellable?.cancel()
    }

    public func start(bookId: UUID?, pagesPerMinute: Double = 0) {
        guard state == .idle else { return }
        self.bookId = bookId
        self.pagesPerMinute = max(0, pagesPerMinute)
        startedAt = Date()
        accumulatedBeforePause = 0
        lastResumeAt = startedAt
        elapsedSeconds = 0
        state = .running
        startTicker()
    }

    public func pause() {
        guard state == .running else { return }
        stopTicker()
        if let resumed = lastResumeAt {
            accumulatedBeforePause += Date().timeIntervalSince(resumed)
        }
        lastResumeAt = nil
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        lastResumeAt = Date()
        state = .running
        startTicker()
    }

    @discardableResult
    public func stop(overridePages: Int? = nil) -> ReadingSession? {
        guard state == .running || state == .paused else { return nil }
        stopTicker()

        let start = startedAt ?? Date()
        let end: Date
        if state == .running, let resumed = lastResumeAt {
            end = Date()
            accumulatedBeforePause += end.timeIntervalSince(resumed)
        } else {
            end = Date()
        }

        let minutes = max(0, Int((accumulatedBeforePause / 60.0).rounded()))
        let pages: Int
        if let p = overridePages {
            pages = max(0, p)
        } else if pagesPerMinute > 0 {
            pages = max(0, Int((Double(minutes) * pagesPerMinute).rounded()))
        } else {
            pages = 0
        }

        let session = sessionsRepo.addSession(
            bookId: bookId,
            start: start,
            end: end,
            minutes: minutes,
            pages: pages
        )

        resetState()
        return session
    }

    public func resetState() {
        state = .idle
        elapsedSeconds = 0
        bookId = nil
        startedAt = nil
        lastResumeAt = nil
        accumulatedBeforePause = 0
        pagesPerMinute = 0
    }

    private func startTicker() {
        stopTicker()
        tickCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.state == .running else { return }
                let base = self.accumulatedBeforePause
                let running = self.lastResumeAt.map { Date().timeIntervalSince($0) } ?? 0
                let total = base + running
                self.elapsedSeconds = max(0, Int(total.rounded()))
            }
    }

    private func stopTicker() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    private func observeAppLifecycle() {
        backgroundCancellable = NotificationCenter.default.publisher(for: UIScene.willDeactivateNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.state == .running {
                    self.pause()
                }
            }

        foregroundCancellable = NotificationCenter.default.publisher(for: UIScene.didActivateNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.state == .paused, self.startedAt != nil {
                    self.resume()
                }
            }
    }
}
