import SwiftUI
import Combine
import Foundation

public final class ReadingRepository: ObservableObject {
    @Published public private(set) var books: [Book] = [] {
        didSet { persist() }
    }

    private let persistence: PersistenceStore
    private var cancellables = Set<AnyCancellable>()

    public init(persistence: PersistenceStore = .shared) {
        self.persistence = persistence
        self.books = persistence.loadBooks()
        normalize()
    }

    @discardableResult
    public func addBook(title: String, author: String, totalPages: Int, currentPage: Int = 0) -> Book {
        let safeTotal = max(0, totalPages)
        let safeCurrent = min(max(0, currentPage), safeTotal)
        let book = Book(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                        totalPages: safeTotal,
                        currentPage: safeCurrent)
        books.append(book)
        sortInPlace()
        return book
    }

    public func updateBook(id: UUID,
                           title: String? = nil,
                           author: String? = nil,
                           totalPages: Int? = nil,
                           currentPage: Int? = nil) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        var b = books[idx]
        if let t = title { b.title = t.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let a = author { b.author = a.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let total = totalPages { b.totalPages = max(0, total) }
        if let cur = currentPage { b.currentPage = max(0, cur) }
        if b.currentPage > b.totalPages, b.totalPages > 0 { b.currentPage = b.totalPages }
        books[idx] = b
        sortInPlace()
    }

    public func removeBook(id: UUID) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        books.remove(at: idx)
    }

    public func removeBooks(at offsets: IndexSet) {
        books.remove(atOffsets: offsets)
    }

    public func clearAll() {
        books.removeAll()
    }

    public func setCurrentPage(for id: UUID, to page: Int) {
        guard let idx = books.firstIndex(where: { $0.id == id }) else { return }
        var b = books[idx]
        let clamped = max(0, min(page, b.totalPages))
        b.currentPage = clamped
        books[idx] = b
    }

    public func addProgress(for id: UUID, pages delta: Int) {
        guard delta != 0, let idx = books.firstIndex(where: { $0.id == id }) else { return }
        var b = books[idx]
        let target = max(0, min(b.currentPage + delta, b.totalPages))
        b.currentPage = target
        books[idx] = b
    }

    public func reorder(from source: IndexSet, to destination: Int) {
        books.move(fromOffsets: source, toOffset: destination)
    }

    public func find(by id: UUID) -> Book? {
        books.first(where: { $0.id == id })
    }

    public var totalBooks: Int {
        books.count
    }

    public var completedBooks: Int {
        books.filter { $0.totalPages > 0 && $0.currentPage >= $0.totalPages }.count
    }

    public var inProgressBooks: Int {
        books.filter { $0.totalPages > 0 && $0.currentPage > 0 && $0.currentPage < $0.totalPages }.count
    }

    public var notStartedBooks: Int {
        books.filter { $0.currentPage == 0 }.count
    }

    private func persist() {
        persistence.saveBooks(books)
    }

    private func sortInPlace() {
        books.sort { l, r in
            if l.addedAt != r.addedAt { return l.addedAt > r.addedAt }
            if l.title.caseInsensitiveCompare(r.title) != .orderedSame {
                return l.title.localizedCaseInsensitiveCompare(r.title) == .orderedAscending
            }
            return l.author.localizedCaseInsensitiveCompare(r.author) == .orderedAscending
        }
    }

    private func normalize() {
        var seen = Set<String>()
        var unique: [Book] = []
        for b in books {
            let key = norm(b.title) + "::" + norm(b.author)
            if seen.contains(key) { continue }
            seen.insert(key)
            var fixed = b
            if fixed.totalPages < 0 { fixed.totalPages = 0 }
            if fixed.currentPage < 0 { fixed.currentPage = 0 }
            if fixed.totalPages > 0, fixed.currentPage > fixed.totalPages {
                fixed.currentPage = fixed.totalPages
            }
            unique.append(fixed)
        }
        books = unique
        sortInPlace()
    }

    private func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
