import AppKit
import HaloSearchCore

/// `HaloSearch --selftest <image>` runs a real image search offscreen and reports each stage,
/// so a change on Google's side shows up without clicking through the UI.
@MainActor
final class SelfTest {
    private let model = SearchModel()
    private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 900),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
    private var asked = false

    func run(imagePath: String) {
        guard let source = NSImage(contentsOfFile: imagePath),
              let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let jpeg = image.searchJPEG() else {
            finish("could not read \(imagePath)", ok: false)
            return
        }
        let host = NSView(frame: window.contentRect(forFrameRect: window.frame))
        for web in [model.aiWeb, model.searchWeb] {
            web.frame = host.bounds
            host.addSubview(web)
        }
        window.contentView = host
        model.onOpenExternal = { print("would open externally:", $0) }
        print("uploading \(jpeg.count) bytes")
        model.search(.image(jpeg: jpeg, image: image))
        poll(0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { self.finish("timed out", ok: false) }
    }

    private func poll(_ second: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.model.aiWeb.evaluateJavaScript("document.body ? document.body.innerText : ''") { value, _ in
                let text = (value as? String) ?? ""
                let url = self.model.aiWeb.url?.absoluteString ?? "-"
                if let notice = self.model.notice { print("notice:", notice) }
                if GoogleSearch.isTrafficCheck(self.model.searchWeb.url) || GoogleSearch.isTrafficCheck(self.model.aiWeb.url) {
                    self.finish("Google showed its traffic check", ok: false)
                    return
                }
                let answered = url.contains("udm=50") && text.count > 300 && !text.contains("is thinking")
                if answered && !self.asked {
                    print("[\(second)s] AI Mode answered with the image:\n", text.prefix(500), "\n")
                    self.asked = true
                    self.model.query = "When was it built?"
                    self.model.submitQuery()
                    self.followUpStart = second
                } else if self.asked, second - self.followUpStart > 3, text.contains("When was it built?"),
                          !text.contains("is thinking") {
                    print("[\(second)s] follow-up answered:\n", text.suffix(700))
                    self.finish("ok", ok: true)
                    return
                }
                self.poll(second + 1)
            }
        }
    }

    private var followUpStart = 0

    private func finish(_ message: String, ok: Bool) {
        print("selftest:", message)
        exit(ok ? 0 : 1)
    }
}

/// `HaloSearch --render-overlay <screenshot> <outdir>` replays a circle and a scribble on the overlay
/// and saves what it draws, for checking the overlay without Screen Recording permission.
@MainActor
enum OverlayRenderTest {
    static func run(screenshot path: String, output: String) async {
        guard let source = NSImage(contentsOfFile: path),
              let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("could not read \(path)")
            exit(1)
        }
        let size = NSSize(width: 1440, height: 900)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        let view = OverlayView(frame: NSRect(origin: .zero, size: size), image: image)
        window.contentView = view
        view.lines = await TextRecognizer.recognize(image, in: size)
        print("recognized \(view.lines.count) lines:", view.lines.prefix(4).map(\.text))
        view.onRegion = { print("region selected:", $0) }
        view.onText = { print("text selected:", $0) }
        view.playIntro()
        save(view, "\(output)/1-idle.png")

        // A loose circle around the photo on the right.
        let circle = (0...40).map { step -> CGPoint in
            let angle = Double(step) / 40 * 2.1 * Double.pi
            return CGPoint(x: 1080 + cos(angle) * 230, y: 450 + sin(angle) * 300)
        }
        stroke(view, window, circle)
        view.setLoading(true)
        save(view, "\(output)/2-circled.png")

        // A scribble along the headline text.
        if let word = view.lines.first?.words.first, let last = view.lines.first?.words.last {
            let y = word.rect.midY
            let scribble = stride(from: word.rect.minX + 2, through: last.rect.maxX - 2, by: 12).map { CGPoint(x: $0, y: y) }
            stroke(view, window, scribble)
            save(view, "\(output)/3-text.png")
        }
        exit(0)
    }

    private static func stroke(_ view: NSView, _ window: NSWindow, _ points: [CGPoint]) {
        func event(_ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                               windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                               clickCount: 1, pressure: 1)!
        }
        view.mouseDown(with: event(.leftMouseDown, points[0]))
        points.dropFirst().forEach { view.mouseDragged(with: event(.leftMouseDragged, $0)) }
        view.mouseUp(with: event(.leftMouseUp, points.last!))
    }

    private static func save(_ view: NSView, _ path: String) {
        guard let layer = view.layer,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        layer.render(in: context.cgContext)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
