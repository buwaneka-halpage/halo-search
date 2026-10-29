import CoreGraphics

/// A line of on-screen text found by OCR.
public struct RecognizedLine: Equatable {
    public let text: String
    public let words: [RecognizedWord]

    public init(text: String, words: [RecognizedWord]) {
        self.text = text
        self.words = words
    }
}

/// A word inside a `RecognizedLine`.
public struct RecognizedWord: Equatable {
    public let line: Int
    public let range: Range<String.Index>
    /// In overlay coordinates (points, bottom-left origin).
    public let rect: CGRect

    public init(line: Int, range: Range<String.Index>, rect: CGRect) {
        self.line = line
        self.range = range
        self.rect = rect
    }
}

public enum TextSelection {
    /// Joins the chosen words top to bottom, keeping the punctuation between words on the same line.
    public static func text(of words: [RecognizedWord], in lines: [RecognizedLine]) -> String {
        let byLine = Dictionary(grouping: words, by: \.line)
        let ordered = byLine.keys.sorted { a, b in
            let first = lines[a].words.first?.rect ?? .zero
            let second = lines[b].words.first?.rect ?? .zero
            let sameRow = abs(first.midY - second.midY) <= min(first.height, second.height) / 2
            return sameRow ? first.minX < second.minX : first.midY > second.midY
        }
        return ordered.compactMap { index -> String? in
            guard let chosen = byLine[index],
                  let lower = chosen.map(\.range.lowerBound).min(),
                  let upper = chosen.map(\.range.upperBound).max() else { return nil }
            return String(lines[index].text[lower..<upper])
        }.joined(separator: " ")
    }

    /// Adds the words a quick stroke skipped between the first and last word it touched on each line.
    public static func fillingGaps(_ hits: [RecognizedWord], in lines: [RecognizedLine]) -> [RecognizedWord] {
        Dictionary(grouping: hits, by: \.line)
            .sorted { $0.key < $1.key }
            .flatMap { line, lineHits -> [RecognizedWord] in
                let minX = lineHits.map(\.rect.minX).min() ?? 0
                let maxX = lineHits.map(\.rect.maxX).max() ?? 0
                return lines[line].words.filter { $0.rect.midX >= minX && $0.rect.midX <= maxX }
            }
    }
}
