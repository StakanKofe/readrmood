import SwiftUI
import Combine
import Foundation

public struct AchievementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: AppTheme
    @EnvironmentObject private var achievementsRepo: AchievementsRepository

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if !unlocked.isEmpty {
                    Section(header: Text("Unlocked")) {
                        ForEach(unlocked) { a in
                            AchievementRow(achievement: a)
                        }
                    }
                }
                Section(header: Text("Locked")) {
                    ForEach(locked) { a in
                        AchievementRow(achievement: a)
                            .opacity(0.6)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Achievements")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    progressPill
                }
            }
            .background(ColorTokens.backgroundDark.ignoresSafeArea())
        }
    }

    private var unlocked: [Achievement] {
        achievementsRepo.achievements
            .filter { $0.isUnlocked }
            .sorted {
                ($0.unlockedAt ?? .distantPast, $0.title)
                >
                ($1.unlockedAt ?? .distantPast, $1.title)
            }
    }

    private var locked: [Achievement] {
        achievementsRepo.achievements
            .filter { !$0.isUnlocked }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var progressPill: some View {
        let total = achievementsRepo.totalCount
        let done = achievementsRepo.unlockedCount
        let pct = total > 0 ? Double(done) / Double(total) : 0
        return HStack(spacing: 8) {
            ProgressView(value: pct)
                .frame(width: 70)
            Text("\(done)/\(total)")
                .font(.footnote)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ColorTokens.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ColorTokens.outlineDark)
        )
    }
}

private struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        let def = AchievementsCatalog.definition(for: achievement.code)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: def?.sfSymbol ?? "medal.fill")
                .imageScale(.large)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(achievement.title)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    if achievement.isUnlocked, let date = achievement.unlockedAt {
                        Text(Formatters.achievementDate(date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if let pts = def?.points {
                        Label("\(pts)", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(achievement.isUnlocked ? "Unlocked" : "Locked")
                        .font(.caption)
                        .foregroundStyle(achievement.isUnlocked ? .green : .secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
