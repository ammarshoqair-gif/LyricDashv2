import Foundation

/// Prepares lyrics for the small CarPlay card.
///
/// Two problems it solves:
/// 1. Long lines don't fit, so the text shrinks or gets cut off.
///    Fix: split a long line into short pieces shown one after another.
/// 2. iOS only lets the card change about once every 2 seconds.
///    Fix: join lines that come faster than that into one piece.
enum LinePacer {
    /// The shortest time one piece stays on the card.
    static let minGap: Double = 2.2

    /// - Parameter maxChars: longest piece to show. 0 means "never split lines".
    static func pace(_ lines: [LyricLine], maxChars: Int) -> [LyricLine] {
        let pieces = maxChars > 0 ? splitLong(lines, maxChars: maxChars) : lines
        return joinFast(pieces, limit: maxChars > 0 ? maxChars + 12 : 64)
    }

    // MARK: Split long lines

    private static func splitLong(_ lines: [LyricLine], maxChars: Int) -> [LyricLine] {
        var result: [LyricLine] = []

        for (index, line) in lines.enumerated() {
            let words = line.text.split(separator: " ").map { String($0) }
            let total = line.text.count
            guard total > maxChars, words.count > 1 else {
                result.append(line)
                continue
            }

            // How long the singer probably takes for this line.
            let natural = Double(total) * 0.09 + 0.5
            let untilNext = index + 1 < lines.count ? lines[index + 1].time - line.time : natural
            let span = max(0, min(untilNext, natural))

            let wanted = Int((Double(total) / Double(maxChars)).rounded(.up))
            let affordable = Int(span / minGap)
            let parts = min(wanted, affordable, words.count)
            guard parts > 1 else {
                result.append(line)
                continue
            }

            // Spread the words over the pieces so the pieces are about equal length.
            var chunks: [[String]] = []
            var starts: [Int] = []
            for _ in 0..<parts {
                chunks.append([])
            }
            starts.append(0)
            var chunk = 0
            var used = 0

            for (wordIndex, word) in words.enumerated() {
                let boundary = total * (chunk + 1) / parts
                let wordsLeft = words.count - wordIndex
                let chunksLeft = parts - chunk - 1
                let pastBoundary = used + word.count / 2 >= boundary
                if !chunks[chunk].isEmpty && chunk < parts - 1 && (pastBoundary || wordsLeft <= chunksLeft) {
                    chunk += 1
                    starts.append(used)
                }
                chunks[chunk].append(word)
                used += word.count + 1
            }

            for piece in 0..<parts {
                if chunks[piece].isEmpty || piece >= starts.count { continue }
                let time = line.time + span * Double(starts[piece]) / Double(max(total, 1))
                result.append(LyricLine(time: time, text: chunks[piece].joined(separator: " ")))
            }
        }
        return result
    }

    // MARK: Join lines that come too fast

    private static func joinFast(_ lines: [LyricLine], limit: Int) -> [LyricLine] {
        var result: [LyricLine] = []
        for line in lines {
            if let last = result.last,
               line.time - last.time < minGap,
               !last.text.isEmpty,
               !line.text.isEmpty,
               last.text.count + line.text.count + 3 <= limit {
                result[result.count - 1] = LyricLine(time: last.time, text: last.text + " / " + line.text)
            } else {
                result.append(line)
            }
        }
        return result
    }
}
