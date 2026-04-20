import SwiftUI

/// Brand palette aligned with CSS variables on https://serpapi.com (see `:root` in landing styles).
enum SerpApiTheme {
    /// `--blue-color`
    static let accentBlue = Color(red: 55 / 255, green: 127 / 255, blue: 234 / 255)
    /// `--purple-color`
    static let accentPurple = Color(red: 105 / 255, green: 55 / 255, blue: 234 / 255)
    /// `--dark-blue-color`
    static let darkBlue = Color(red: 26 / 255, green: 31 / 255, blue: 54 / 255)
    /// `--serpapi-blue-color`
    static let serpapiNavy = Color(red: 35 / 255, green: 47 / 255, blue: 62 / 255)
    /// `--light-gray-color`
    static let lightGray = Color(red: 247 / 255, green: 250 / 255, blue: 252 / 255)
    /// `.background-grey` sections
    static let sectionTint = Color(red: 248 / 255, green: 250 / 255, blue: 255 / 255)
    /// `--green-color`
    static let mint = Color(red: 62 / 255, green: 207 / 255, blue: 142 / 255)
    /// `--yellow-color`
    static let amber = Color(red: 255 / 255, green: 157 / 255, blue: 0 / 255)
    /// `--red-color`
    static let danger = Color(red: 192 / 255, green: 57 / 255, blue: 43 / 255)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accentBlue, accentPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func appBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkBlue : sectionTint
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? serpapiNavy : Color.white
    }

    static func cardBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    static func cardFillOpacity(for scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.12 : 0.06
    }
}
