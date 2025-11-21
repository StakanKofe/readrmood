import SwiftUI
import Combine
import Foundation

public struct SessionsScreen: View {
    @EnvironmentObject private var sessionsRepo: SessionsRepository
    @EnvironmentObject private var readingRepo: ReadingRepository
    @EnvironmentObject private var theme: AppTheme

    @StateObject private var holder = VMHolder()
    @State private var exportDoc: ExportDoc?
    @State private var showExportError = false

    public init() {}

    public var body: some View {
        Group {
            if let vm = holder.vm {
                NavigationStack {
                    VStack(spacing: 0) {
                        ControlsView(vm: vm, readingRepo: readingRepo, onExport: handleExport)
                        ListView(vm: vm)
                    }
                    .navigationTitle("Sessions")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                    }
                    .sheet(item: $exportDoc) { doc in
                        ShareView(items: [doc.url])
                    }
                    .alert("Export failed", isPresented: $showExportError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("Unable to create CSV file.")
                    }
                }
            } else {
                ProgressView()
                    .onAppear {
                        holder.ensure(sessionsRepo: sessionsRepo, readingRepo: readingRepo)
                    }
            }
        }
        .background(ColorTokens.backgroundDark.ignoresSafeArea())
    }

    // MARK: - Export

    private func handleExport(_ vm: SessionsViewModel) {
        do {
            let url = try vm.exportCSV()
            exportDoc = ExportDoc(url: url)
        } catch {
            exportDoc = nil
            showExportError = true
        }
    }

    private final class VMHolder: ObservableObject {
        @Published var vm: SessionsViewModel?
        func ensure(sessionsRepo: SessionsRepository, readingRepo: ReadingRepository) {
            guard vm == nil else { return }
            vm = SessionsViewModel(sessionsRepo: sessionsRepo, readingRepo: readingRepo)
        }
    }
}

// MARK: - Helpers

private struct ExportDoc: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Subviews

private struct ControlsView: View {
    @ObservedObject var vm: SessionsViewModel
    let readingRepo: ReadingRepository
    let onExport: (SessionsViewModel) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Picker("Range", selection: $vm.rangeFilter) {
                    ForEach(SessionsViewModel.DateRange.allCases) { r in
                        Text(label(for: r)).tag(r)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Picker("Sort", selection: $vm.sort) {
                    Text("Newest").tag(SessionsViewModel.SortMode.newestFirst)
                    Text("Oldest").tag(SessionsViewModel.SortMode.oldestFirst)
                    Text("Minutes").tag(SessionsViewModel.SortMode.longestFirst)
                    Text("Pages").tag(SessionsViewModel.SortMode.pagesFirst)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Menu {
                    Button("All books") { vm.bookFilter = nil }
                    Divider()
                    ForEach(readingRepo.books) { b in
                        Button(b.title) { vm.bookFilter = b.id }
                    }
                } label: {
                    HStack {
                        Image(systemName: "books.vertical")
                        Text(vm.bookFilter.flatMap { readingRepo.find(by: $0)?.title } ?? "All books")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ColorTokens.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ColorTokens.outlineDark)
                    )
                }

                Spacer()

                statsBar(vm.stats)

                Button {
                    onExport(vm)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export CSV")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(ColorTokens.surfaceDark)
    }

    private func statsBar(_ s: SessionsViewModel.SessionsStats) -> some View {
        HStack(spacing: 12) {
            Label("\(s.count)", systemImage: "list.number")
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondaryDark)
            Label("\(s.minutes)m", systemImage: "timer")
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondaryDark)
            Label("\(s.pages)p", systemImage: "book")
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondaryDark)
        }
    }

    private func label(for range: SessionsViewModel.DateRange) -> String {
        switch range {
        case .today: return "Today"
        case .last7: return "7d"
        case .last30: return "30d"
        case .all: return "All"
        }
    }
}

private struct ListView: View {
    @ObservedObject var vm: SessionsViewModel

    var body: some View {
        List {
            ForEach(vm.sections) { section in
                Section(header: sectionHeader(section)) {
                    ForEach(section.items) { s in
                        sessionRow(s)
                    }
                    .onDelete { idx in
                        vm.remove(at: idx, in: section)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func sectionHeader(_ section: SessionsViewModel.DaySection) -> some View {
        HStack {
            Text(section.title)
            Spacer()
            Label("\(section.minutes) min", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("\(section.pages) p.", systemImage: "book")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sessionRow(_ s: ReadingSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(vm.titleForBook(s.bookId))
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(Formatters.timeShort(s.start))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(Formatters.duration(minutes: s.minutes), systemImage: "timer")
                    .font(.subheadline)
                Label("\(s.pages) pages", systemImage: "book.pages.fill")
                    .font(.subheadline)
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Share

private struct ShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
