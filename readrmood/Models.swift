import SwiftUI
import Combine

public struct Book: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var author: String
    public var totalPages: Int
    public var currentPage: Int
    public var addedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        totalPages: Int,
        currentPage: Int = 0,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.addedAt = addedAt
    }

    public var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
}

public struct ReadingSession: Identifiable, Codable, Equatable {
    public let id: UUID
    public var bookId: UUID?
    public var start: Date
    public var end: Date
    public var minutes: Int
    public var pages: Int

    public init(
        id: UUID = UUID(),
        bookId: UUID?,
        start: Date,
        end: Date,
        minutes: Int,
        pages: Int
    ) {
        self.id = id
        self.bookId = bookId
        self.start = start
        self.end = end
        self.minutes = minutes
        self.pages = pages
    }
}

public struct ReadingMood: Identifiable, Codable, Equatable {
    public let id: UUID
    public var date: Date
    public var mood: MoodKind
    public var note: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        mood: MoodKind,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.mood = mood
        self.note = note
    }
}

public enum MoodKind: String, CaseIterable, Codable, Identifiable {
    case calm
    case focused
    case sleepy
    case excited
    case neutral

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .calm: return "😊"
        case .focused: return "🧠"
        case .sleepy: return "😴"
        case .excited: return "🤩"
        case .neutral: return "🙂"
        }
    }

    public var label: String {
        switch self {
        case .calm: return "Calm"
        case .focused: return "Focused"
        case .sleepy: return "Sleepy"
        case .excited: return "Excited"
        case .neutral: return "Neutral"
        }
    }
}

public struct Achievement: Identifiable, Codable, Equatable {
    public let id: UUID
    public var code: String
    public var title: String
    public var description: String
    public var isUnlocked: Bool
    public var unlockedAt: Date?

    public init(
        id: UUID = UUID(),
        code: String,
        title: String,
        description: String,
        isUnlocked: Bool = false,
        unlockedAt: Date? = nil
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.description = description
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
    }
}
