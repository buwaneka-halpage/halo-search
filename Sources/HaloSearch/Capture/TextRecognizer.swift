import CoreGraphics
import Foundation
import HaloSearchCore
import Vision

enum TextRecognizer {
    /// Finds on-screen text so a scribble over words can become a text search.
    static func recognize(_ image: CGImage, in size: CGSize) async -> [RecognizedLine] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: recognizeSync(image, in: size))
            }
        }
    }

    private static func recognizeSync(_ image: CGImage, in size: CGSize) -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            return []
        }

        // Vision's normalized rects share the overlay's bottom-left origin, so they only need scaling.
        func toView(_ box: CGRect) -> CGRect {
            CGRect(x: box.minX * size.width, y: box.minY * size.height,
                   width: box.width * size.width, height: box.height * size.height)
        }

        var lines: [RecognizedLine] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let lineIndex = lines.count
            var words: [RecognizedWord] = []
            text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { _, range, _, _ in
                guard let box = try? candidate.boundingBox(for: range) else { return }
                words.append(RecognizedWord(line: lineIndex, range: range, rect: toView(box.boundingBox)))
            }
            lines.append(RecognizedLine(text: text, words: words))
        }
        return lines
    }
}
