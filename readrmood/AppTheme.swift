
import SwiftUI
import Combine

final class AppTheme: ObservableObject {
    @Published private(set) var isDark: Bool = true

    @Published private(set) var primary: Color = Color(red: 0.95, green: 0.75, blue: 0.20)
    @Published private(set) var secondary: Color = Color(red: 0.90, green: 0.40, blue: 0.30)
    @Published private(set) var accent: Color = Color(red: 0.40, green: 0.75, blue: 0.95)

    @Published private(set) var background: Color = Color(red: 0.07, green: 0.07, blue: 0.09)
    @Published private(set) var surface: Color = Color(red: 0.12, green: 0.12, blue: 0.14)
    @Published private(set) var outline: Color = Color.white.opacity(0.12)
    @Published private(set) var textPrimary: Color = .white
    @Published private(set) var textSecondary: Color = .white.opacity(0.7)

    @Published private(set) var cornerRadiusXL: CGFloat = 24
    @Published private(set) var cornerRadiusL: CGFloat = 16
    @Published private(set) var cornerRadiusM: CGFloat = 12
    @Published private(set) var cornerRadiusS: CGFloat = 8

    @Published private(set) var spacingXL: CGFloat = 24
    @Published private(set) var spacingL: CGFloat = 16
    @Published private(set) var spacingM: CGFloat = 12
    @Published private(set) var spacingS: CGFloat = 8

    @Published private(set) var shadowRadius: CGFloat = 10
    @Published private(set) var shadowOpacity: Double = 0.25

    func applyDark() {
        isDark = true
        textPrimary = .white
        textSecondary = .white.opacity(0.7)
        background = Color(red: 0.07, green: 0.07, blue: 0.09)
        surface = Color(red: 0.12, green: 0.12, blue: 0.14)
        outline = Color.white.opacity(0.12)
    }

    func applyLight() {
        isDark = false
        textPrimary = .black
        textSecondary = .black.opacity(0.7)
        background = Color(red: 0.97, green: 0.97, blue: 0.98)
        surface = .white
        outline = Color.black.opacity(0.08)
    }

    func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: cornerRadiusL, style: .continuous)
            .fill(safeSurface())
            .overlay(RoundedRectangle(cornerRadius: cornerRadiusL).stroke(outline))
            .shadow(color: Color.black.opacity(isDark ? shadowOpacity : 0.1), radius: shadowRadius, x: 0, y: 4)
    }

    func safeSurface() -> Color {
        isDark ? surface : surface
    }

    func buttonStyleProminent() -> ButtonStyle {
        ProminentButtonStyle(fg: .black, bg: primary, radius: cornerRadiusM)
    }

    func buttonStyleTonal() -> ButtonStyle {
        TonalButtonStyle(fg: textPrimary, bg: surface, radius: cornerRadiusM, stroke: outline)
    }
}

struct ProminentButtonStyle: ButtonStyle {
    let fg: Color
    let bg: Color
    let radius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(fg)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(bg.opacity(configuration.isPressed ? 0.85 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TonalButtonStyle: ButtonStyle {
    let fg: Color
    let bg: Color
    let radius: CGFloat
    let stroke: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(fg.opacity(configuration.isPressed ? 0.8 : 1.0))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(bg.opacity(configuration.isPressed ? 0.9 : 1.0))
                    .overlay(RoundedRectangle(cornerRadius: radius).stroke(stroke))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
