import SwiftUI
import Combine
import Foundation

public struct LibraryScreen: View {
    @EnvironmentObject private var readingRepo: ReadingRepository
    @EnvironmentObject private var sessionsRepo: SessionsRepository
    @EnvironmentObject private var theme: AppTheme

    @StateObject private var vm = LibraryViewModel()
    @State private var showAdd = false
    @State private var editing: Book? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                listView
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { AppIcons.add }
                        .accessibilityLabel("Add Book")
                }
            }
            .background(ColorTokens.backgroundDark.ignoresSafeArea())
        }
        .sheet(isPresented: $showAdd) {
            AddOrEditBookSheet(
                title: "Add Book",
                initial: nil,
                onSubmit: { title, author, total, current in
                    let b = vm.add(title: title, author: author, totalPages: total, currentPage: current)
                    editing = b
                }
            )
        }
        .sheet(item: $editing) { book in
            AddOrEditBookSheet(
                title: "Edit Book",
                initial: book,
                onSubmit: { t, a, total, current in
                    vm.update(id: book.id, title: t, author: a, totalPages: total, currentPage: current)
                }
            )
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack { SearchField(text: $vm.searchQuery, placeholder: "Search by title or author") }
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                FilterChipsRow(selection: $vm.filter)
                SortMenuButton(selection: $vm.sort)
            }
            .padding(.horizontal, 16)

            HStack {
                Label("\(vm.stats.total) total", systemImage: "books.vertical")
                Spacer()
                Label("\(vm.stats.inProgress) in progress", systemImage: "clock")
                Spacer()
                Label("\(vm.stats.completed) done", systemImage: "checkmark.circle")
            }
            .font(.footnote)
            .foregroundStyle(ColorTokens.textSecondaryDark)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(ColorTokens.surfaceDark)
    }

    private var listView: some View {
        Group {
            if vm.filtered.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        EmptyStateView(
                            systemImage: "books.vertical",
                            title: "No books yet.",
                            message: "Add your first book to start tracking."
                        )
                        .padding(.top, 40)
                    }
                    .padding(.horizontal, 16)
                }
                .background(ColorTokens.backgroundDark.ignoresSafeArea())
            } else {
                List {
                    ForEach(vm.filtered) { book in
                        Button { editing = book } label: {
                            BookRow(
                                title: book.title,
                                author: book.author,
                                current: book.currentPage,
                                total: book.totalPages,
                                minutes: vm.minutesForBook(book.id),
                                pages: vm.pagesForBook(book.id)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { vm.remove(id: book.id) } label: { AppIcons.delete }
                        }
                    }
                    .onMove(perform: vm.move)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(ColorTokens.backgroundDark)
            }
        }
    }
}

private struct BookRow: View {
    let title: String
    let author: String
    let current: Int
    let total: Int
    let minutes: Int
    let pages: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(Formatters.bookProgress(current: current, total: total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Label("\(minutes) min", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("\(pages) p.", systemImage: "book")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: total > 0 ? Double(current) / Double(total) : 0)
        }
        .padding(.vertical, 6)
    }
}

private struct SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
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

public struct AddOrEditBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: AppTheme

    let title: String
    let initial: Book?
    let onSubmit: (_ title: String, _ author: String, _ totalPages: Int, _ currentPage: Int) -> Void

    @State private var t: String = ""
    @State private var a: String = ""
    @State private var total: String = ""
    @State private var current: String = ""

    public init(title: String, initial: Book?, onSubmit: @escaping (_ t: String, _ a: String, _ total: Int, _ current: Int) -> Void) {
        self.title = title
        self.initial = initial
        self.onSubmit = onSubmit
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Info")) {
                    TextField("Title", text: $t)
                    TextField("Author", text: $a)
                }
                Section(header: Text("Progress")) {
                    TextField("Total pages", text: $total)
                        .keyboardType(.numberPad)
                    TextField("Current page", text: $current)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(self.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let b = initial {
                    t = b.title
                    a = b.author
                    total = String(b.totalPages)
                    current = String(b.currentPage)
                }
            }
        }
    }

    private var canSave: Bool {
        let totalInt = Int(total) ?? -1
        let currentInt = Int(current) ?? -1
        return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && totalInt >= 0
        && currentInt >= 0
        && currentInt <= max(0, totalInt)
    }

    private func save() {
        let totalInt = max(0, Int(total) ?? 0)
        let currentInt = max(0, min(Int(current) ?? 0, totalInt))
        onSubmit(
            t.trimmingCharacters(in: .whitespacesAndNewlines),
            a.trimmingCharacters(in: .whitespacesAndNewlines),
            totalInt,
            currentInt
        )
        dismiss()
    }
}

private struct FilterChipsRow: View {
    @Binding var selection: LibraryViewModel.FilterMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(.all,        label: "All")
                chip(.notStarted, label: "Not started")
                chip(.inProgress, label: "In progress")
                chip(.completed,  label: "Completed")
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func chip(_ mode: LibraryViewModel.FilterMode, label: String) -> some View {
        let isOn = selection == mode
        Button {
            selection = mode
        } label: {
            Text(label)
                .font(.subheadline)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isOn ? ColorTokens.surfaceElevated : ColorTokens.surfaceDark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isOn ? ColorTokens.info : ColorTokens.outlineDark, lineWidth: isOn ? 2 : 1)
                )
        }
    }
}

private struct SortMenuButton: View {
    @Binding var selection: LibraryViewModel.SortMode

    var body: some View {
        Menu {
            Button { selection = .recent }   label: { Label("Recent", systemImage: "clock") }
            Button { selection = .title }    label: { Label("Title", systemImage: "textformat") }
            Button { selection = .author }   label: { Label("Author", systemImage: "person") }
            Button { selection = .progress } label: { Label("Progress", systemImage: "chart.bar") }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                Text(currentTitle).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
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
        .accessibilityLabel("Sort")
    }

    private var currentTitle: String {
        switch selection {
        case .recent:   return "Recent"
        case .title:    return "Title"
        case .author:   return "Author"
        case .progress: return "Progress"
        }
    }
}
