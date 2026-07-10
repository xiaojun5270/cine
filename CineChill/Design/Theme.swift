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

    static let cardCorner: CGFloat = 16
    static let posterCorner: CGFloat = 12
    static let screenPadding: CGFloat = 16

    /// A subtle cinematic background gradient that sits behind glass-style chrome.
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.07, blue: 0.10),
                Color(red: 0.08, green: 0.10, blue: 0.14),
                Color(red: 0.06, green: 0.08, blue: 0.11)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ShapeStyle where Self == Color {
    static var ccAccent: Color { Theme.accent }
}
