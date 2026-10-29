import CoreGraphics
import Foundation
import Testing
@testable import HaloSearchCore

/// One line of text laid out with 10pt per character, 20pt tall, starting at `origin`.
func line(_ text: String, index: Int, origin: CGPoint) -> RecognizedLine {
    var words: [RecognizedWord] = []
    text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { _, range, _, _ in
        let start = CGFloat(text.distance(from: text.startIndex, to: range.lowerBound))
        let length = CGFloat(text.distance(from: range.lowerBound, to: range.upperBound))
        words.append(RecognizedWord(line: index, range: range,
                                    rect: CGRect(x: origin.x + start * 10, y: origin.y, width: length * 10, height: 20)))
    }
    return RecognizedLine(text: text, words: words)
}

@Suite struct StrokeAnalyzerTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let lines = [line("Visit Paris, in autumn.", index: 0, origin: CGPoint(x: 100, y: 800)),
                 line("Book tickets early", index: 1, origin: CGPoint(x: 100, y: 760))]

    func circle(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        (0...48).map { step in
            let angle = CGFloat(step) / 48 * 2 * .pi
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
    }

    @Test func circleSearchesThePaddedArea() {
        let gesture = StrokeAnalyzer.gesture(for: circle(center: CGPoint(x: 700, y: 400), radius: 100),
                                             lines: lines, in: screen)
        guard case .region(let rect) = gesture else { Issue.record("expected a region, got \(gesture)"); return }
        #expect(abs(rect.minX - 588) < 1 && abs(rect.width - 224) < 1)
    }

    @Test func circleAroundTextIsStillAnImageSearch() {
        let gesture = StrokeAnalyzer.gesture(for: circle(center: CGPoint(x: 215, y: 810), radius: 140),
                                             lines: lines, in: screen)
        guard case .region = gesture else { Issue.record("expected a region, got \(gesture)"); return }
    }

    @Test func scribbleOverWordsSelectsThemWithPunctuation() {
        let stroke = stride(from: 105, through: 320, by: 15).map { CGPoint(x: CGFloat($0), y: 810) }
        let gesture = StrokeAnalyzer.gesture(for: stroke, lines: lines, in: screen)
        guard case .text(let words) = gesture else { Issue.record("expected text, got \(gesture)"); return }
        #expect(TextSelection.text(of: words, in: lines) == "Visit Paris, in autumn")
    }

    @Test func tapOnAWordSelectsIt() {
        let gesture = StrokeAnalyzer.gesture(for: [CGPoint(x: 175, y: 810)], lines: lines, in: screen)
        guard case .text(let words) = gesture else { Issue.record("expected text, got \(gesture)"); return }
        #expect(TextSelection.text(of: words, in: lines) == "Paris")
    }

    @Test func tapOnNothingDoesNothing() {
        #expect(StrokeAnalyzer.gesture(for: [CGPoint(x: 900, y: 100)], lines: lines, in: screen) == .none)
        #expect(StrokeAnalyzer.gesture(for: [], lines: lines, in: screen) == .none)
    }

    @Test func tinyRegionsGrowAndStayOnScreen() {
        let rect = StrokeAnalyzer.region(around: CGRect(x: 2, y: 2, width: 10, height: 10), in: screen)
        #expect(rect.minX == 0 && rect.minY == 0)
        #expect(rect.width >= 30 && rect.height >= 30)
        let middle = StrokeAnalyzer.region(around: CGRect(x: 500, y: 500, width: 4, height: 4), in: screen)
        #expect(middle.size == CGSize(width: 48, height: 48))
    }

    @Test func resamplingIsEvenRegardlessOfInputDensity() {
        let sparse = StrokeAnalyzer.resample([CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)], spacing: 4)
        let dense = StrokeAnalyzer.resample((0...100).map { CGPoint(x: CGFloat($0), y: 0) }, spacing: 4)
        #expect(sparse.count == 26)
        #expect(dense.count == sparse.count)
        #expect(zip(sparse, dense).allSatisfy { abs($0.x - $1.x) < 0.001 })
    }
}
