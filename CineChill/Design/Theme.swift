import SwiftUI

/// Central design tokens for CineChill.
///
/// Visual direction: a calm, cinematic dark-first palette. Content (posters,
/// backdrops) supplies the colour; chrome stays neutral so glass-style
/// navigation reads cleanly on top of artwork.
enum Theme {
    /// Brand accent — a cool cinema teal.
    static let accent = Color(red: 0.10, green: 0.78, blue: 0.75)
    static let accentWarm = Color(red: 0.98, green: 0.66, blue: 0.25)
    static let accentBlue = Color(red: 0.30, green: 0.54, blue: 0.98)
    static let accentPink = Color(red: 0.94, green: 0.32, blue: 0.64)
    static let success = Color(red: 0.25, green: 0.82, blue: 0.48)
    static let danger = Color(red: 1.00, green: 0.35, blue: 0.35)
    static let cardTint = Color.white.opacity(0.055)
    static let cardStroke = Color.white.opacity(0.13)

    static let cardCorner: CGFloat = 16
    static let posterCorner: CGFloat = 12
    static let screenPadding: CGFloat = 16

    /// A subtle cinematic background gradient that sits behind glass-style chrome.
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.035, green: 0.045, blue: 0.070),
                Color(red: 0.070, green: 0.092, blue: 0.130),
                Color(red: 0.050, green: 0.075, blue: 0.090),
                Color(red: 0.035, green: 0.042, blue: 0.060)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.26),
                accentBlue.opacity(0.18),
                accentWarm.opacity(0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func tintGradient(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.95), tint.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ShapeStyle where Self == Color {
    static var ccAccent: Color { Theme.accent }
}
