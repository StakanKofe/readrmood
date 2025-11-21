import SwiftUI
import Combine

public enum AppIcons {
    public static let today = Image(systemName: "checkmark.circle")
    public static let library = Image(systemName: "books.vertical")
    public static let sessions = Image(systemName: "timer")
    public static let moodboard = Image(systemName: "sparkles")
    public static let settings = Image(systemName: "gearshape")

    public static let add = Image(systemName: "plus.circle.fill")
    public static let edit = Image(systemName: "pencil")
    public static let delete = Image(systemName: "trash")
    public static let confirm = Image(systemName: "checkmark")
    public static let cancel = Image(systemName: "xmark")
    public static let info = Image(systemName: "info.circle")
    public static let quote = Image(systemName: "quote.bubble")
    public static let streak = Image(systemName: "flame.fill")
    public static let mood = Image(systemName: "face.smiling")
    public static let progress = Image(systemName: "chart.bar.fill")
    public static let goal = Image(systemName: "target")
    public static let book = Image(systemName: "book.closed")
    public static let timer = Image(systemName: "clock.arrow.circlepath")
    public static let stats = Image(systemName: "waveform.path.ecg")
    public static let achievement = Image(systemName: "medal.fill")

    public static func tabIcon(for tab: TabKind) -> Image {
        switch tab {
        case .today: return today
        case .library: return library
        case .sessions: return sessions
        case .moodboard: return moodboard
        case .settings: return settings
        }
    }

    public enum TabKind: CaseIterable {
        case today, library, sessions, moodboard, settings
    }
}
