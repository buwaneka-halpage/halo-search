import CoreGraphics

/// What a finished stroke on the overlay asks for.
public enum Gesture: Equatable {
    /// Nothing to search, such as a tap on empty space.
    case none
    /// Search these words as text.
    case text([RecognizedWord])
    /// Search this area as an image.
    case region(CGRect)
}

/// Turns a freehand stroke into a gesture. A circle searches the area it encloses; a scribble that
/// mostly runs over words, or a tap on a word, searches the text instead.
public enum StrokeAnalyzer {
    public static let tapSize: CGFloat = 8
    public static let regionPadding: CGFloat = 12
    public static let minimumRegion: CGFloat = 48
    /// Share of the stroke that must lie on words for it to count as selecting text.
    public static let textCoverage = 0.45

    public static func gesture(for points: [CGPoint], lines: [RecognizedLine], in bounds: CGRect) -> Gesture {
        guard let first = points.first else { return .none }
        let words = lines.flatMap(\.words)
        let box = boundingBox(of: points)

        if box.width < tapSize && box.height < tapSize {
            let word = words.first { $0.rect.insetBy(dx: -2, dy: -2).contains(first) }
            return word.map { .text([$0]) } ?? .none
        }

        let samples = resample(points, spacing: 4)
        var touched: [Int] = []
        var onText = 0
        for sample in samples {
            guard let index = words.firstIndex(where: { $0.rect.insetBy(dx: -3, dy: -3).contains(sample) }) else { continue }
            onText += 1
            if !touched.contains(index) { touched.append(index) }
        }
        if !touched.isEmpty, Double(onText) / Double(samples.count) >= textCoverage {
            return .text(TextSelection.fillingGaps(touched.map { words[$0] }, in: lines))
        }

        return .region(region(around: box, in: bounds))
    }

    /// Pads the stroke's bounds and keeps the result at least `minimumRegion` across and on screen.
    public static func region(around box: CGRect, in bounds: CGRect) -> CGRect {
        var rect = box.insetBy(dx: -regionPadding, dy: -regionPadding)
        if rect.width < minimumRegion { rect = rect.insetBy(dx: (rect.width - minimumRegion) / 2, dy: 0) }
        if rect.height < minimumRegion { rect = rect.insetBy(dx: 0, dy: (rect.height - minimumRegion) / 2) }
        return rect.intersection(bounds)
    }

    public static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Evenly spaced points along the stroke, so fast and slow drawing are judged alike.
    public static func resample(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard var previous = points.first else { return [] }
        var result = [previous]
        var carried: CGFloat = 0
        for point in points.dropFirst() {
            let length = hypot(point.x - previous.x, point.y - previous.y)
            var travelled = spacing - carried
            while travelled <= length {
                let t = travelled / length
                result.append(CGPoint(x: previous.x + (point.x - previous.x) * t,
                                      y: previous.y + (point.y - previous.y) * t))
                travelled += spacing
            }
            carried = length - (travelled - spacing)
            previous = point
        }
        return result
    }
}
