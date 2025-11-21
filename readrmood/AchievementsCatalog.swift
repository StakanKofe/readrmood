import SwiftUI
import Combine
import Foundation

public struct AchievementDefinition: Identifiable, Codable, Equatable {
    public let id: UUID
    public let code: String
    public let title: String
    public let detail: String
    public let rule: AchievementRule
    public let sfSymbol: String
    public let points: Int

    public init(
        id: UUID = UUID(),
        code: String,
        title: String,
        detail: String,
        rule: AchievementRule,
        sfSymbol: String,
        points: Int = 10
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.detail = detail
        self.rule = rule
        self.sfSymbol = sfSymbol
        self.points = points
    }
}

public enum AchievementRule: Codable, Equatable {
    case totalSessions(min: Int)
    case totalMinutes(min: Int)
    case totalPages(min: Int)
    case streakDays(min: Int)
    case booksAdded(min: Int)
    case sessionMinutesAtLeast(min: Int)
    case weekendSessions(min: Int)
    case nightSessions(min: Int, startHour: Int, endHour: Int)
    case firstMood(kind: MoodKind)
    case distinctMoods(min: Int)
}

public enum AchievementsCatalog {
    public static let definitions: [AchievementDefinition] = [
        AchievementDefinition(
            code: "first_steps",
            title: "First Steps",
            detail: "Log your first reading session.",
            rule: .totalSessions(min: 1),
            sfSymbol: "figure.walk.circle.fill",
            points: 10
        ),
        AchievementDefinition(
            code: "tiny_habit",
            title: "Tiny Habit",
            detail: "Read 3 days in a row.",
            rule: .streakDays(min: 3),
            sfSymbol: "leaf.fill",
            points: 15
        ),
        AchievementDefinition(
            code: "weekly_flow",
            title: "Weekly Flow",
            detail: "Read 7 days in a row.",
            rule: .streakDays(min: 7),
            sfSymbol: "calendar.badge.checkmark",
            points: 25
        ),
        AchievementDefinition(
            code: "page_turner_100",
            title: "Page Turner",
            detail: "Read 100 pages in total.",
            rule: .totalPages(min: 100),
            sfSymbol: "book.pages.fill",
            points: 15
        ),
        AchievementDefinition(
            code: "deep_diver_500",
            title: "Deep Diver",
            detail: "Read 500 pages in total.",
            rule: .totalPages(min: 500),
            sfSymbol: "books.vertical.fill",
            points: 30
        ),
        AchievementDefinition(
            code: "time_keeper_300",
            title: "Time Keeper",
            detail: "Read for 300 minutes in total.",
            rule: .totalMinutes(min: 300),
            sfSymbol: "clock.badge.checkmark",
            points: 20
        ),
        AchievementDefinition(
            code: "marathon_reader_1200",
            title: "Marathon Reader",
            detail: "Read for 1200 minutes in total.",
            rule: .totalMinutes(min: 1200),
            sfSymbol: "stopwatch.fill",
            points: 40
        ),
        AchievementDefinition(
            code: "library_starter",
            title: "Library Starter",
            detail: "Add 3 books to your library.",
            rule: .booksAdded(min: 3),
            sfSymbol: "books.vertical",
            points: 15
        ),
        AchievementDefinition(
            code: "library_builder",
            title: "Library Builder",
            detail: "Add 10 books to your library.",
            rule: .booksAdded(min: 10),
            sfSymbol: "books.vertical.circle.fill",
            points: 30
        ),
        AchievementDefinition(
            code: "focus_burst",
            title: "Focus Burst",
            detail: "Complete a single session of 30 minutes or longer.",
            rule: .sessionMinutesAtLeast(min: 30),
            sfSymbol: "timer",
            points: 20
        ),
        AchievementDefinition(
            code: "night_owl",
            title: "Night Owl",
            detail: "Complete 3 sessions between 23:00 and 05:00.",
            rule: .nightSessions(min: 3, startHour: 23, endHour: 5),
            sfSymbol: "moon.stars.fill",
            points: 20
        ),
        AchievementDefinition(
            code: "weekend_reader",
            title: "Weekend Reader",
            detail: "Complete 4 sessions on Saturday or Sunday.",
            rule: .weekendSessions(min: 4),
            sfSymbol: "sun.max.trianglebadge.exclamationmark",
            points: 15
        ),
        AchievementDefinition(
            code: "mood_explorer",
            title: "Mood Explorer",
            detail: "Log 4 distinct reading moods.",
            rule: .distinctMoods(min: 4),
            sfSymbol: "face.smiling.inverse",
            points: 20
        ),
        AchievementDefinition(
            code: "zen_chapter",
            title: "Zen Chapter",
            detail: "First logged mood is Calm.",
            rule: .firstMood(kind: .calm),
            sfSymbol: "water.waves",
            points: 10
        ),
        AchievementDefinition(
            code: "laser_focus",
            title: "Laser Focus",
            detail: "First logged mood is Focused.",
            rule: .firstMood(kind: .focused),
            sfSymbol: "target",
            points: 10
        )
    ]

    public static func definition(for code: String) -> AchievementDefinition? {
        definitions.first(where: { $0.code == code })
    }

    public static func initialState() -> [Achievement] {
        definitions.map {
            Achievement(code: $0.code, title: $0.title, description: $0.detail, isUnlocked: false, unlockedAt: nil)
        }
    }
}
