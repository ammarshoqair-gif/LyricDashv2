import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

@main
struct LyricDashWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricsLiveActivity()
    }
}

/// The lyrics card shown on CarPlay, the Lock Screen and the Dynamic Island.
struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsAttributes.self) { context in
            LyricsCard(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Palette.cardBottom(context.state.hue))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    FittedText(text: context.state.currentLine.isEmpty ? "♪" : context.state.currentLine,
                               maxSize: 20, minSize: 12, centered: true)
                        .frame(height: 60)
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .foregroundStyle(Palette.accent(context.state.hue))
            } compactTrailing: {
                Image(systemName: "quote.bubble.fill")
                    .foregroundStyle(Palette.accent(context.state.hue))
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundStyle(Palette.accent(context.state.hue))
            }
        }
        // "small" is the size CarPlay (and Apple Watch) use for this card.
        .supplementalActivityFamilies([.small])
    }
}

struct LyricsCard: View {
    @Environment(\.activityFamily) private var family
    let state: LyricsAttributes.ContentState
    let isStale: Bool

    // If the app stopped refreshing the card, say so instead of showing a frozen line.
    private var mainText: String {
        if isStale { return "Lyrics paused" }
        return state.currentLine.isEmpty ? "♪" : state.currentLine
    }

    private var subText: String {
        isStale ? "Open LyricDash to resume" : state.nextLine
    }

    private var header: String {
        if state.title.isEmpty { return "LyricDash" }
        return state.artist.isEmpty ? state.title : state.title + " · " + state.artist
    }

    private var cardFill: LinearGradient {
        LinearGradient(colors: [Palette.cardTop(state.hue), Palette.cardBottom(state.hue)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        switch family {
        case .small:
            carPlayLayout
        default:
            lockScreenLayout
        }
    }

    /// CarPlay: the whole card is given to the words being sung, as big as they fit.
    private var carPlayLayout: some View {
        VStack(spacing: 2) {
            FittedText(text: mainText, maxSize: 34, minSize: 12, centered: true)
            if (state.showNext || isStale) && !subText.isEmpty {
                Text(subText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardFill)
    }

    private var lockScreenLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.accent(state.hue))
                Text(header)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            FittedText(text: mainText, maxSize: 24, minSize: 13, centered: false)
                .frame(height: 60)
            Text(subText.isEmpty ? " " : subText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill)
    }
}

/// Shows text at the biggest size that fits its box without being cut off.
struct FittedText: View {
    let text: String
    let maxSize: CGFloat
    let minSize: CGFloat
    let centered: Bool

    var body: some View {
        GeometryReader { box in
            let size = TextFitter.bestSize(for: text, in: box.size, maxSize: maxSize, minSize: minSize)
            Text(text)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(centered ? .center : .leading)
                .lineLimit(6)
                .minimumScaleFactor(0.7)
                .frame(width: box.size.width, height: box.size.height, alignment: centered ? .center : .leading)
        }
    }
}

/// Measures text to find the biggest font size that fits a box.
enum TextFitter {
    static func bestSize(for text: String, in box: CGSize, maxSize: CGFloat, minSize: CGFloat) -> CGFloat {
        // Leave a small margin: measuring and drawing differ by a point or two.
        let width = box.width * 0.93
        let height = box.height * 0.97
        guard width > 20, height > 10 else { return minSize }

        var size = maxSize
        while size > minSize {
            if fits(text, size: size, width: width, height: height) {
                return size
            }
            size -= 1
        }
        return minSize
    }

    private static func fits(_ text: String, size: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size, weight: .bold)]

        // No single word may be wider than the box (it would be cut in half).
        for word in text.split(separator: " ") {
            let wordWidth = (String(word) as NSString).size(withAttributes: attributes).width
            if wordWidth > width {
                return false
            }
        }

        let wrapped = (text as NSString).boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(wrapped.height) <= height
    }
}
