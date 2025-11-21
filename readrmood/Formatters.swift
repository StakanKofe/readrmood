import SwiftUI
import Combine
import Foundation

public enum Formatters {
    public static func timeShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    public static func dateShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f.string(from: date)
    }

    public static func dateLong(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: date)
    }

    public static func dateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    public static func duration(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let h = minutes / 60
            let m = minutes % 60
            if m == 0 {
                return "\(h) h"
            } else {
                return "\(h) h \(m) min"
            }
        }
    }

    public static func pages(_ pages: Int) -> String {
        pages == 1 ? "1 page" : "\(pages) pages"
    }

    public static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    public static func moodLabel(_ mood: MoodKind) -> String {
        "\(mood.emoji) \(mood.label)"
    }

    public static func streakDays(_ count: Int) -> String {
        if count == 1 { return "1 day" }
        return "\(count) days"
    }

    public static func bookProgress(current: Int, total: Int) -> String {
        guard total > 0 else { return "0%" }
        let percent = (Double(current) / Double(total)) * 100
        return String(format: "%.0f%%", percent)
    }

    public static func readingSummary(minutes: Int, pages: Int) -> String {
        var parts: [String] = []
        if minutes > 0 { parts.append(duration(minutes: minutes)) }
        if pages > 0 { parts.append(pages == 1 ? "1 page" : "\(pages) pages") }
        return parts.joined(separator: ", ")
    }

    public static func achievementDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    public static func relativeDayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }

        let comps = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date()))
        if let diff = comps.day {
            if diff < 0 { return "In \(-diff) days" }
            if diff > 0 { return "\(diff) days ago" }
        }
        return dateShort(date)
    }

    public static func weekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    public static func detailedSummary(session: ReadingSession) -> String {
        let d = dateShort(session.start)
        let t = timeShort(session.start)
        let dur = duration(minutes: session.minutes)
        let pg = pages(session.pages)
        return "\(d) at \(t) — \(dur), \(pg)"
    }
}
