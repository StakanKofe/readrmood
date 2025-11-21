import SwiftUI
import Combine
import Foundation

public struct TodayScreen: View {
    @EnvironmentObject private var readingRepo: ReadingRepository
    @EnvironmentObject private var sessionsRepo: SessionsRepository
    @EnvironmentObject private var achievementsRepo: AchievementsRepository
    @EnvironmentObject private var theme: AppTheme

    @StateObject private var holder = VMHolder()

    public init() {}

    public var body: some View {
        Group {
            if let vm = holder.vm {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            QuickLogCard(vm: vm, readingRepo: readingRepo)
                            TimerCard(vm: vm)
                            SummaryCard(summary: vm.todaySummary())
                            if let id = vm.selectedBookId, let book = readingRepo.find(by: id) {
                                BookProgressCard(book: book)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .navigationTitle("Today")
                }
            } else {
                ProgressView()
                    .onAppear {
                        holder.ensure(
                            readingRepo: readingRepo,
                            sessionsRepo: sessionsRepo,
                            achievementsRepo: achievementsRepo
                        )
                    }
            }
        }
        .background(ColorTokens.backgroundDark.ignoresSafeArea())
    }

    private final class VMHolder: ObservableObject {
        @Published var vm: TodayViewModel?
        func ensure(readingRepo: ReadingRepository, sessionsRepo: SessionsRepository, achievementsRepo: AchievementsRepository) {
            guard vm == nil else { return }
            let timer = SessionTimerEngine(sessionsRepo: sessionsRepo)
            vm = TodayViewModel(
                readingRepo: readingRepo,
                sessionsRepo: sessionsRepo,
                achievementsRepo: achievementsRepo,
                persistence: .shared,
                timer: timer
            )
        }
    }
}

// MARK: - Cards

private struct QuickLogCard: View {
    @EnvironmentObject private var theme: AppTheme
    @ObservedObject var vm: TodayViewModel
    let readingRepo: ReadingRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick log")
                .font(.headline)

            // Book picker
            Menu {
                Button("Unassigned") { vm.setBook(nil) }
                Divider()
                ForEach(readingRepo.books) { b in
                    Button(b.title) { vm.setBook(b.id) }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(vm.selectedBookId.flatMap { readingRepo.find(by: $0)?.title } ?? "Unassigned")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ColorTokens.surfaceDark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ColorTokens.outlineDark)
                )
            }

            // Minutes / Pages steppers
            VStack(spacing: 10) {
                StepperRow(title: "Minutes", value: vm.minutes, range: 1...240) { vm.setMinutes($0) }
                StepperRow(title: "Pages", value: vm.pages, range: 0...2000) { vm.setPages($0) }
            }

            // Mood chips horizontal
            VStack(alignment: .leading, spacing: 8) {
                Text("Mood")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondaryDark)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MoodKind.allCases, id: \.self) { kind in
                            MoodChip(
                                title: kind.label,
                                emoji: kind.emoji,
                                isOn: vm.selectedMood == kind
                            ) {
                                vm.selectedMood = kind
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            // Note
            TextField("Note", text: Binding(
                get: { vm.note },
                set: { vm.note = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            // Save
            Button {
                vm.saveQuickToday()
            } label: {
                Text("Save").frame(maxWidth: .infinity)
            }
            .buttonStyle(
                ProminentButtonStyle(
                    fg: .black,
                    bg: theme.primary,
                    radius: theme.cornerRadiusM
                )
            )
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
}

private struct TimerCard: View {
    @EnvironmentObject private var theme: AppTheme
    @ObservedObject var vm: TodayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timer")
                .font(.headline)

            HStack {
                Text(vm.clockString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
            }

            HStack(spacing: 12) {
                if vm.isTimerRunning {
                    Button("Pause") { vm.pauseTimer() }
                        .buttonStyle(
                            TonalButtonStyle(
                                fg: theme.textPrimary,
                                bg: theme.surface,
                                radius: theme.cornerRadiusM,
                                stroke: theme.outline
                            )
                        )
                    Button("Stop") {
                        _ = vm.stopTimer()
                    }
                    .buttonStyle(
                        ProminentButtonStyle(
                            fg: .black,
                            bg: theme.primary,
                            radius: theme.cornerRadiusM
                        )
                    )
                } else {
                    Button("Start") { vm.startTimer() }
                        .buttonStyle(
                            ProminentButtonStyle(
                                fg: .black,
                                bg: theme.primary,
                                radius: theme.cornerRadiusM
                            )
                        )
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
}

private struct SummaryCard: View {
    let summary: (minutes: Int, pages: Int, sessions: Int)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.headline)
            HStack {
                Label("\(summary.sessions) sessions", systemImage: "timer")
                Spacer()
                Label("\(summary.minutes) min", systemImage: "clock")
                Spacer()
                Label("\(summary.pages) pages", systemImage: "book.pages.fill")
            }
            .font(.subheadline)
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
}

private struct BookProgressCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.title)
                .font(.headline)
            ProgressView(value: book.progress)
            HStack {
                Text("\(book.currentPage)/\(book.totalPages) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formatters.bookProgress(current: book.currentPage, total: book.totalPages))
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
}

// MARK: - Reusable pieces

private struct StepperRow: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(title): \(value)")
                .font(.subheadline)
            Spacer()
            HStack(spacing: 0) {
                Button {
                    let next = max(range.lowerBound, value - 1)
                    if next != value { onChange(next) }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 36)
                }
                .contentShape(Rectangle())
                .background(RoundedCorners.left.fill(ColorTokens.surfaceDark))
                .overlay(RoundedCorners.left.stroke(ColorTokens.outlineDark))

                Button {
                    let next = min(range.upperBound, value + 1)
                    if next != value { onChange(next) }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 36)
                }
                .contentShape(Rectangle())
                .background(RoundedCorners.right.fill(ColorTokens.surfaceDark))
                .overlay(RoundedCorners.right.stroke(ColorTokens.outlineDark))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private enum RoundedCorners {
    static var left: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 12,
            bottomLeadingRadius: 12,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
    }
    static var right: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 12,
            topTrailingRadius: 12
        )
    }
}

private struct MoodChip: View {
    let title: String
    let emoji: String
    let isOn: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                Text(emoji)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minWidth: 54)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? ColorTokens.surfaceDark : ColorTokens.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isOn ? ColorTokens.info : ColorTokens.outlineDark, lineWidth: isOn ? 2 : 1)
            )
        }
    }
}
