import ActivityKit
import SwiftUI

/// The data shared between the app and the lyrics card (CarPlay, Lock Screen, Dynamic Island).
struct LyricsAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var currentLine: String
        var nextLine: String
        /// This song's color, as a position on the color wheel (0 to 1).
        var hue: Double
        /// Whether the CarPlay card also shows the upcoming line.
        var showNext: Bool
    }
}

/// Every song gets its own color, worked out from its name.
/// Used by both the app and the lyrics card so they always match.
enum Palette {
    static func hue(for text: String) -> Double {
        var hash: UInt64 = 5381
        for scalar in text.unicodeScalars {
            hash = (hash &* 33) &+ UInt64(scalar.value)
        }
        return Double(hash % 360) / 360.0
    }

    static func wrap(_ value: Double) -> Double {
        let rest = value.truncatingRemainder(dividingBy: 1)
        return rest < 0 ? rest + 1 : rest
    }

    static func accent(_ hue: Double) -> Color {
        Color(hue: wrap(hue), saturation: 0.72, brightness: 1.0)
    }

    static func second(_ hue: Double) -> Color {
        Color(hue: wrap(hue + 0.12), saturation: 0.80, brightness: 0.95)
    }

    static func third(_ hue: Double) -> Color {
        Color(hue: wrap(hue - 0.18), saturation: 0.85, brightness: 0.90)
    }

    /// Dark background for the lyrics card, tinted with the song's color.
    static func cardTop(_ hue: Double) -> Color {
        Color(hue: wrap(hue), saturation: 0.80, brightness: 0.26)
    }

    static func cardBottom(_ hue: Double) -> Color {
        Color(hue: wrap(hue + 0.10), saturation: 0.85, brightness: 0.12)
    }
}
