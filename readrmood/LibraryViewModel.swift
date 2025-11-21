import SwiftUI
import Combine
import Foundation

public final class LibraryViewModel: ObservableObject {
    @Published public private(set) var books: [Book] = []
    @Published public var searchQuery: String = "" { didSet { applyFilters() } }
    @Published public var sort: SortMode = .recent { didSet { applyFilters() } }
    @Published public var filter: FilterMode = .all { didSet { applyFilters() } }
    @Published public private(set) var filtered: [Book] = []
    @Published public private(set) var stats: LibraryStats = .empty

    private let readingRepo: ReadingRepository
    private let sessionsRepo: SessionsRepository
    private var cancellables = Set<AnyCancellable>()

    public init(readingRepo: ReadingRepository = .init(), sessionsRepo: SessionsRepository = .init()) {
        self.readingRepo = readingRepo
        self.sessionsRepo = sessionsRepo
        bind()
        recomputeStats()
        applyFilters()
    }

    public enum SortMode: String, CaseIterable, Identifiable {
        case recent
        case title
        case author
        case progress
        public var id: String { rawValue }
    }

    public enum FilterMode: String, CaseIterable, Identifiable {
        case all
        case notStarted
        case inProgress
        case completed
        public var id: String { rawValue }
    }

    public struct LibraryStats: Equatable {
        public let total: Int
        public let completed: Int
        public let inProgress: Int
        public let notStarted: Int
        public static let empty = LibraryStats(total: 0, completed: 0, inProgress: 0, notStarted: 0)
    }

    // MARK: - CRUD

    @discardableResult
    public func add(title: String, author: String, totalPages: Int, currentPage: Int = 0) -> Book {
        let b = readingRepo.addBook(title: title, author: author, totalPages: totalPages, currentPage: currentPage)
        syncFromRepo()
        return b
    }

    public func update(id: UUID,
                       title: String? = nil,
                       author: String? = nil,
                       totalPages: Int? = nil,
                       currentPage: Int? = nil) {
        readingRepo.updateBook(id: id, title: title, author: author, totalPages: totalPages, currentPage: currentPage)
        syncFromRepo()
    }

    public func remove(id: UUID) {
        readingRepo.removeBook(id: id)
        syncFromRepo()
    }

    public func move(from source: IndexSet, to destination: Int) {
        readingRepo.reorder(from: source, to: destination)
        syncFromRepo()
    }

    public func addProgress(id: UUID, pages delta: Int) {
        readingRepo.addProgress(for: id, pages: delta)
        syncFromRepo()
    }

    public func setCurrentPage(id: UUID, page: Int) {
        readingRepo.setCurrentPage(for: id, to: page)
        syncFromRepo()
    }

    public func clearAll() {
        readingRepo.clearAll()
        syncFromRepo()
    }

    // MARK: - Queries

    public func book(by id: UUID) -> Book? {
        books.first(where: { $0.id == id })
    }

    public func minutesForBook(_ id: UUID) -> Int {
        sessionsRepo.totalMinutes(bookId: id)
    }

    public func pagesForBook(_ id: UUID) -> Int {
        sessionsRepo.totalPages(bookId: id)
    }

    // MARK: - Private

    private func bind() {
        readingRepo.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncFromRepo()
            }
            .store(in: &cancellables)
    }

    private func syncFromRepo() {
        books = readingRepo.books
        recomputeStats()
        applyFilters()
    }

    private func recomputeStats() {
        let total = books.count
        let completed = books.filter { $0.totalPages > 0 && $0.currentPage >= $0.totalPages }.count
        let inProgress = books.filter { $0.totalPages > 0 && $0.currentPage > 0 && $0.currentPage < $0.totalPages }.count
        let notStarted = books.filter { $0.currentPage == 0 }.count
        stats = LibraryStats(total: total, completed: completed, inProgress: inProgress, notStarted: notStarted)
    }

    private func applyFilters() {
        var result = books

        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = norm(searchQuery)
            result = result.filter { norm($0.title).contains(q) || norm($0.author).contains(q) }
        }

        switch filter {
        case .all: break
        case .notStarted:
            result = result.filter { $0.currentPage == 0 }
        case .inProgress:
            result = result.filter { $0.totalPages > 0 && $0.currentPage > 0 && $0.currentPage < $0.totalPages }
        case .completed:
            result = result.filter { $0.totalPages > 0 && $0.currentPage >= $0.totalPages }
        }

        switch sort {
        case .recent:
            result.sort { $0.addedAt > $1.addedAt }
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            result.sort { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        case .progress:
            result.sort { $0.progress > $1.progress }
        }

        filtered = result
    }

    private func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
