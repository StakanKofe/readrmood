import SwiftUI
import Combine

public struct MoodProfile: Equatable {
    public let kind: MoodKind
    public let energy: Double          // 0.0–1.0
    public let valence: Double         // 0.0–1.0
    public let tags: [MoodTag]
    public let color: Color
    public let gradient: LinearGradient

    public static func == (lhs: MoodProfile, rhs: MoodProfile) -> Bool {
        lhs.kind == rhs.kind &&
        lhs.energy == rhs.energy &&
        lhs.valence == rhs.valence &&
        lhs.tags == rhs.tags
        // color и gradient намеренно не сравниваем: они не Equatable
    }
}

public enum MoodTag: String, CaseIterable, Codable, Hashable {
    case deepFocus
    case relaxed
    case sleepy
    case energized
    case neutral
    case reflective
    case evening
    case morning
}

public enum MoodTaxonomy {
    private static let profiles: [MoodKind: MoodProfile] = [
        .calm: MoodProfile(
            kind: .calm,
            energy: 0.35,
            valence: 0.80,
            tags: [.relaxed, .reflective, .evening],
            color: ColorTokens.chart1,
            gradient: ColorTokens.moodGradientPositive()
        ),
        .focused: MoodProfile(
            kind: .focused,
            energy: 0.65,
            valence: 0.85,
            tags: [.deepFocus, .morning, .reflective],
            color: ColorTokens.info,
            gradient: ColorTokens.primaryGradient()
        ),
        .sleepy: MoodProfile(
            kind: .sleepy,
            energy: 0.15,
            valence: 0.55,
            tags: [.sleepy, .evening],
            color: ColorTokens.chart2,
            gradient: ColorTokens.moodGradientNeutral()
        ),
        .excited: MoodProfile(
            kind: .excited,
            energy: 0.85,
            valence: 0.95,
            tags: [.energized, .morning],
            color: ColorTokens.chart5,
            gradient: ColorTokens.moodGradientPositive()
        ),
        .neutral: MoodProfile(
            kind: .neutral,
            energy: 0.50,
            valence: 0.60,
            tags: [.neutral],
            color: ColorTokens.surfaceElevated,
            gradient: ColorTokens.moodGradientNeutral()
        )
    ]

    public static func profile(for kind: MoodKind) -> MoodProfile {
        profiles[kind]!
    }

    public static func color(for kind: MoodKind) -> Color {
        profile(for: kind).color
    }

    public static func gradient(for kind: MoodKind) -> LinearGradient {
        profile(for: kind).gradient
    }

    public static func tags(for kind: MoodKind) -> [MoodTag] {
        profile(for: kind).tags
    }

    public static func energy(for kind: MoodKind) -> Double {
        profile(for: kind).energy
    }

    public static func valence(for kind: MoodKind) -> Double {
        profile(for: kind).valence
    }

    public static func suggestedSessionMinutes(for kind: MoodKind) -> Int {
        switch kind {
        case .calm: return 20
        case .focused: return 30
        case .sleepy: return 10
        case .excited: return 25
        case .neutral: return 15
        }
    }

    public static func suggestedPagesDelta(for kind: MoodKind) -> Int {
        switch kind {
        case .calm: return 8
        case .focused: return 12
        case .sleepy: return 4
        case .excited: return 10
        case .neutral: return 6
        }
    }

    public static func dominantKind(from moods: [ReadingMood]) -> MoodKind {
        guard !moods.isEmpty else { return .neutral }
        var accumulator: [MoodKind: Double] = [:]
        for m in moods {
            let p = profile(for: m.mood)
            let weight = 0.6 * p.valence + 0.4 * p.energy
            accumulator[m.mood, default: 0.0] += weight
        }
        return accumulator.max(by: { $0.value < $1.value })?.key ?? .neutral
    }

    public static func aggregateMetrics(from moods: [ReadingMood]) -> (energy: Double, valence: Double) {
        guard !moods.isEmpty else { return (energy: 0.5, valence: 0.6) }
        var e: Double = 0
        var v: Double = 0
        for m in moods {
            let p = profile(for: m.mood)
            e += p.energy
            v += p.valence
        }
        let count = Double(moods.count)
        return (energy: e / count, valence: v / count)
    }

    public static func suggestReadingWindow(for kind: MoodKind) -> ReadingWindow {
        switch kind {
        case .calm: return ReadingWindow(targetMinutes: 20, breakAfterMinutes: 0, paceHint: .slow)
        case .focused: return ReadingWindow(targetMinutes: 30, breakAfterMinutes: 0, paceHint: .steady)
        case .sleepy: return ReadingWindow(targetMinutes: 10, breakAfterMinutes: 0, paceHint: .light)
        case .excited: return ReadingWindow(targetMinutes: 25, breakAfterMinutes: 0, paceHint: .dynamic)
        case .neutral: return ReadingWindow(targetMinutes: 15, breakAfterMinutes: 0, paceHint: .steady)
        }
    }
}

public struct ReadingWindow: Equatable {
    public enum PaceHint: String, Codable, CaseIterable {
        case light
        case slow
        case steady
        case dynamic
    }
    public let targetMinutes: Int
    public let breakAfterMinutes: Int
    public let paceHint: PaceHint
}
