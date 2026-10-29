import CoreGraphics
import Testing
@testable import HaloSearchCore

@Suite struct TextSelectionTests {
    let lines = [line("Book tickets early", index: 0, origin: CGPoint(x: 100, y: 760)),
                 line("Visit Paris, in autumn.", index: 1, origin: CGPoint(x: 100, y: 800))]

    @Test func ordersLinesTopToBottom() {
        let words = lines[0].words.prefix(1) + lines[1].words.suffix(1)
        #expect(TextSelection.text(of: Array(words), in: lines) == "autumn Book")
    }

    @Test func fillsWordsAStrokeSkipped() {
        let ends = [lines[1].words[0], lines[1].words[3]]
        let filled = TextSelection.fillingGaps(ends, in: lines)
        #expect(filled.count == 4)
        #expect(TextSelection.text(of: filled, in: lines) == "Visit Paris, in autumn")
    }
}
