import SwiftUI
import Combine

public enum ColorTokens {
    public static let brandPrimary = Color(red: 0.95, green: 0.75, blue: 0.20)
    public static let brandSecondary = Color(red: 0.90, green: 0.40, blue: 0.30)
    public static let brandAccent = Color(red: 0.40, green: 0.75, blue: 0.95)

    public static let backgroundDark = Color(red: 0.07, green: 0.07, blue: 0.09)
    public static let surfaceDark = Color(red: 0.12, green: 0.12, blue: 0.14)
    public static let surfaceElevated = Color(red: 0.16, green: 0.16, blue: 0.20)

    public static let textPrimaryDark = Color.white
    public static let textSecondaryDark = Color.white.opacity(0.7)
    public static let outlineDark = Color.white.opacity(0.12)

    public static let success = Color(hex: "#3EC676")
    public static let warning = Color(hex: "#F5A524")
    public static let danger = Color(hex: "#FF5A52")
    public static let info = Color(hex: "#4DA3FF")

    public static let chart1 = Color(hex: "#6CC4A1")
    public static let chart2 = Color(hex: "#A78BFA")
    public static let chart3 = Color(hex: "#F59E0B")
    public static let chart4 = Color(hex: "#F472B6")
    public static let chart5 = Color(hex: "#34D399")

    public static func primaryGradient() -> LinearGradient {
        LinearGradient(
            colors: [brandPrimary, brandAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static func surfaceGradient() -> LinearGradient {
        LinearGradient(
            colors: [surfaceDark, surfaceElevated],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public static func moodGradientPositive() -> LinearGradient {
        LinearGradient(
            colors: [success, brandAccent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public static func moodGradientNeutral() -> LinearGradient {
        LinearGradient(
            colors: [surfaceElevated, surfaceDark],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public static func moodGradientNegative() -> LinearGradient {
        LinearGradient(
            colors: [danger, warning],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

public extension Color {
    init(hex: String, alpha: Double = 1.0) {
        let r, g, b: Double
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") { hexSanitized.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&value)

        switch hexSanitized.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
        case 8:
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
        default:
            r = 1; g = 1; b = 1
        }

        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
