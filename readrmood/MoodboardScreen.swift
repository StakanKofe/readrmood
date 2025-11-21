import SwiftUI
import Combine
import Foundation

public struct MoodboardScreen: View {
    @EnvironmentObject private var theme: AppTheme
    @EnvironmentObject private var readingRepo: ReadingRepository
    @EnvironmentObject private var sessionsRepo: SessionsRepository
    @EnvironmentObject private var achievementsRepo: AchievementsRepository

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    topBooksCard
                    achievementsCard
                    recentSessionsCard
                    moodLogCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Moodboard")
            .background(ColorTokens.backgroundDark.ignoresSafeArea())
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        let moods: [ReadingMood] = []
        let dominant = MoodTaxonomy.dominantKind(from: moods)
        let agg = MoodTaxonomy.aggregateMetrics(from: moods)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.headline)

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(dominant.emoji).font(.system(size: 22))
                    Text(dominant.label).font(.subheadline)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ColorTokens.surfaceElevated)
                )
                Spacer()
            }

            VStack(spacing: 10) {
                ProgressRow(title: "Energy", value: agg.energy)
                ProgressRow(title: "Valence", value: agg.valence)
            }

            HStack(spacing: 10) {
                StatPill(iconSystem: "flame", title: "Streak", value: "\(streakDays())d")
                    .frame(maxWidth: .infinity)
                let m7 = sumLast7d()
                StatPill(iconSystem: "timer", title: "7d Minutes", value: "\(m7.minutes)")
                    .frame(maxWidth: .infinity)
                StatPill(iconSystem: "book", title: "7d Pages", value: "\(m7.pages)")
                    .frame(maxWidth: .infinity)
                StatPill(iconSystem: "list.bullet", title: "7d Sessions", value: "\(m7.count)")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTokens.outlineDark)
        )
    }

    // MARK: - Top Books

    private var topBooksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Books")
                .font(.headline)

            let top = topBooksLast30d()
            if top.isEmpty {
                EmptyStateView(systemImage: "books.vertical", title: "No activity yet.", message: nil)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(top.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.title).lineLimit(1)
                            Spacer()
                            Label("\(item.minutes)m", systemImage: "timer")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Label("\(item.pages)p", systemImage: "book")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTokens.outlineDark)
        )
    }

    // MARK: - Achievements

    private var achievementsCard: some View {
        let done = achievementsRepo.unlockedCount
        let total = achievementsRepo.totalCount

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                Text("\(done)/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if done == 0 {
                Text("No achievements unlocked yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                Text("Keep going!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTokens.outlineDark)
        )
    }

    // MARK: - Recent Sessions

    private var recentSessionsCard: some View {
        let items = recentSessions(limit: 5)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.headline)

            if items.isEmpty {
                EmptyStateView(systemImage: "timer", title: "No sessions to show.", message: nil)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { s in
                        HStack {
                            Text(bookTitle(s.bookId)).lineLimit(1)
                            Spacer()
                            Label(Formatters.duration(minutes: s.minutes), systemImage: "timer")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Label("\(s.pages)p", systemImage: "book")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTokens.outlineDark)
        )
    }

    // MARK: - Mood Log

    private var moodLogCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mood Log")
                .font(.headline)
            EmptyStateView(systemImage: "face.smiling", title: "No moods logged yet.", message: nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTokens.outlineDark)
        )
    }

    // MARK: - Helpers (metrics)

    private func sumLast7d() -> (minutes: Int, pages: Int, count: Int) {
        let from = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        let items = sessionsRepo.sessions.filter { $0.start >= startOfDay(from) }
        let minutes = items.reduce(0) { $0 + $1.minutes }
        let pages = items.reduce(0) { $0 + $1.pages }
        return (minutes, pages, items.count)
    }

    private func streakDays() -> Int {
        var streak = 0
        var day = startOfDay(Date())
        let set = Set(sessionsRepo.sessions.map { startOfDay($0.start) })
        while set.contains(day) {
            streak += 1
            day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    // теперь учитываем, что bookId может быть nil
    private func topBooksLast30d() -> [(id: UUID?, title: String, minutes: Int, pages: Int)] {
        let from = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
        let items = sessionsRepo.sessions.filter { $0.start >= startOfDay(from) }
        var dict: [UUID?: (minutes: Int, pages: Int)] = [:]
        for s in items {
            var current = dict[s.bookId, default: (0, 0)]
            current.minutes += s.minutes
            current.pages += s.pages
            dict[s.bookId] = current
        }
        let merged: [(UUID?, String, Int, Int)] = dict.map { key, val in
            let title = bookTitle(key)
            return (key, title, val.minutes, val.pages)
        }
        return merged.sorted { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
            return lhs.3 > rhs.3
        }.prefix(5).map { ($0.0, $0.1, $0.2, $0.3) }
    }

    private func recentSessions(limit: Int) -> [ReadingSession] {
        Array(sessionsRepo.sessions.sorted { $0.start > $1.start }.prefix(limit))
    }

    private func bookTitle(_ id: UUID?) -> String {
        guard let id = id else { return "Unassigned" }
        return readingRepo.find(by: id)?.title ?? "Unassigned"
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

// MARK: - Small views

private struct ProgressRow: View {
    let title: String
    let value: Double // 0...1

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.subheadline)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.surfaceDark)
                    Capsule()
                        .fill(ColorTokens.info) // заменил несуществующий ColorTokens.accent
                        .frame(width: max(0, min(CGFloat(value) * geo.size.width, geo.size.width)))
                }
            }
            .frame(height: 6)
            Text("\(Int(round(value * 100)))%")
                .font(.caption)
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .frame(height: 20)
    }
}
