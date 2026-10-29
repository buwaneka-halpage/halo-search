import AppKit
import HaloSearchCore
import QuartzCore
import WebKit

/// `HaloSearch --demo <layout.json> <log.json>` performs the scripted session used for the demo video:
/// the real capture, overlay and Google searches, with strokes replayed smoothly and a touch dot in place of
/// the pointer. `layout.json` gives the on-screen rectangles to circle and scribble over (points, top-left
/// origin); every step is written to `log.json` with its time so the recording can be edited to match.
@MainActor
final class DemoDirector {
    private struct Layout: Decodable {
        struct Rect: Decodable {
            let x, y, width, height: CGFloat
        }

        let hero: Rect
        let term: Rect
        let followUp: String
    }

    private let layoutPath: String
    private let logPath: String
    private var events: [[String: Any]] = []
    private let start = CACurrentMediaTime()
    private let startDate = Date()

    init(layoutPath: String, logPath: String) {
        self.layoutPath = layoutPath
        self.logPath = logPath
    }

    func run(_ app: AppDelegate) {
        // Never leave the overlay on screen, whatever happens on Google's side.
        DispatchQueue.main.asyncAfter(deadline: .now() + 150) { [self] in
            mark("watchdog")
            save()
            exit(1)
        }
        Task {
            do {
                try await perform(app)
                save()
                exit(0)
            } catch {
                mark("error: \(error)")
                app.dismiss()
                save()
                exit(2)
            }
        }
    }

    private func perform(_ app: AppDelegate) async throws {
        let layout = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: URL(fileURLWithPath: layoutPath)))
        let screenHeight = NSScreen.underPointer?.frame.height ?? 0
        func flip(_ rect: Layout.Rect) -> CGRect {
            CGRect(x: rect.x, y: screenHeight - rect.y - rect.height, width: rect.width, height: rect.height)
        }
        let model = app.results.model

        mark("start")
        try await pause(1.5)

        mark("shortcut")
        app.begin()
        try await until(timeout: 5) { app.overlay != nil }
        mark("overlay")
        try await pause(1.6)

        guard let overlay = app.overlay else { return }
        mark("circle")
        await overlay.view.replay(circle(around: flip(layout.hero)), duration: 1.35)
        mark("circled")

        try await until(timeout: 15) { !model.ready.isEmpty }
        mark("panel")
        try await until(timeout: 15) { model.searchWeb.url != nil && !model.loading.contains(.search) }
        if GoogleSearch.isTrafficCheck(model.searchWeb.url) { throw DemoError.trafficCheck }
        try await answer(to: Settings.shared.imagePrompt, in: model.aiWeb)
        mark("ai-answer")
        try await pause(3.5)
        scroll(model.aiWeb, by: 320)
        try await pause(3)

        model.tab = .search
        mark("search-tab")
        try await until(timeout: 15) { model.ready.contains(.search) }
        try await pause(3)
        scroll(model.searchWeb, by: 420)
        try await pause(2.5)

        model.tab = .aiMode
        mark("ai-tab")
        try await pause(1)
        mark("typing")
        for character in layout.followUp {
            model.query.append(character)
            try await pause(0.075)
        }
        try await pause(0.5)
        model.submitQuery()
        mark("follow-up")
        try await pause(1.5)
        try await answer(to: layout.followUp, in: model.aiWeb)
        mark("follow-up-answer")
        try await pause(3)
        scroll(model.aiWeb, by: 360)
        try await pause(2.5)

        overlay.makeKey()
        mark("scribble")
        await overlay.view.replay(scribble(over: flip(layout.term)), duration: 0.8)
        mark("scribbled")
        try await pause(1.5)
        try await answer(to: model.query, in: model.aiWeb)
        mark("text-answer")
        try await pause(4)

        app.dismiss()
        mark("closed")
        try await pause(2)
        mark("end")
    }

    // MARK: Strokes

    /// A slightly wobbly loop around the rectangle that overshoots its start, like a finger would draw it.
    private func circle(around rect: CGRect) -> [CGPoint] {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width / 2 + 34
        let radiusY = rect.height / 2 + 28
        let startAngle = 0.62 * Double.pi
        let sweep = -2.12 * Double.pi
        return (0...150).map { step in
            let progress = ease(Double(step) / 150)
            let angle = startAngle + sweep * progress
            let wobble = 1 + 0.035 * sin(progress * 9) + 0.02 * cos(progress * 23)
            return CGPoint(x: center.x + cos(angle) * radiusX * wobble,
                           y: center.y + sin(angle) * radiusY * wobble)
        }
    }

    /// A left-to-right swipe along the middle of the text.
    private func scribble(over rect: CGRect) -> [CGPoint] {
        (0...80).map { step in
            let progress = ease(Double(step) / 80)
            return CGPoint(x: rect.minX + 3 + (rect.width - 6) * progress,
                           y: rect.midY + 1.5 * sin(progress * 11))
        }
    }

    private func ease(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }

    // MARK: Waiting

    private func pause(_ seconds: Double) async throws {
        try await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }

    private func until(timeout: Double, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw DemoError.timedOut }
            try await pause(0.1)
        }
    }

    /// Waits until AI Mode has finished answering `question`: there is a substantial reply after the first time
    /// the question appears, nothing is still loading, and the text has stopped growing.
    private func answer(to question: String, in web: WKWebView, timeout: Double = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var previous = -1
        var steady = 0
        while Date() < deadline {
            if GoogleSearch.isTrafficCheck(web.url) { throw DemoError.trafficCheck }
            let text = await bodyText(web)
            let reply = text.range(of: question).map { String(text[$0.upperBound...]) } ?? ""
            let busy = ["is thinking", "Searching", "Thinking"].contains { reply.contains($0) }
            let finished = !busy && reply.count > 350
            steady = finished && reply.count == previous ? steady + 1 : 0
            previous = reply.count
            if steady >= 3 { return }
            try await pause(0.5)
        }
        throw DemoError.timedOut
    }

    private func bodyText(_ web: WKWebView) async -> String {
        await withCheckedContinuation { continuation in
            web.evaluateJavaScript("document.body ? document.body.innerText : ''") { value, _ in
                continuation.resume(returning: value as? String ?? "")
            }
        }
    }

    private func scroll(_ web: WKWebView, by distance: Int) {
        web.evaluateJavaScript("""
            (() => {
              const scrollable = [document.scrollingElement, ...document.querySelectorAll('*')]
                .find(element => element && element.scrollHeight > element.clientHeight + 50
                      && getComputedStyle(element).overflowY !== 'hidden' && element.clientHeight > 300);
              scrollable?.scrollBy({ top: \(distance), behavior: 'smooth' });
            })()
            """)
    }

    // MARK: Log

    private enum DemoError: Error {
        case timedOut
        case trafficCheck
    }

    private func mark(_ event: String) {
        events.append(["event": event, "t": CACurrentMediaTime() - start])
    }

    private func save() {
        let log: [String: Any] = ["startEpoch": startDate.timeIntervalSince1970, "events": events]
        if let data = try? JSONSerialization.data(withJSONObject: log, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }
    }
}

extension OverlayView {
    /// Plays a stroke through the normal mouse handlers, with a touch dot following it.
    func replay(_ points: [CGPoint], duration: Double) async {
        guard let window, let first = points.first, let last = points.last else { return }
        func event(_ type: NSEvent.EventType, at point: CGPoint) -> NSEvent? {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                               clickCount: 1, pressure: 1)
        }

        let dot = CAShapeLayer()
        dot.path = CGPath(ellipseIn: CGRect(x: -15, y: -15, width: 30, height: 30), transform: nil)
        dot.fillColor = NSColor.white.withAlphaComponent(0.85).cgColor
        dot.strokeColor = NSColor.black.withAlphaComponent(0.12).cgColor
        dot.lineWidth = 1
        dot.shadowColor = NSColor.black.cgColor
        dot.shadowOpacity = 0.3
        dot.shadowRadius = 6
        dot.shadowOffset = .zero
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dot.position = first
        layer?.addSublayer(dot)
        CATransaction.commit()
        let appear = CABasicAnimation(keyPath: "transform.scale")
        appear.fromValue = 0.3
        appear.toValue = 1
        appear.duration = 0.15
        dot.add(appear, forKey: "appear")
        try? await Task.sleep(for: .milliseconds(180))

        if let down = event(.leftMouseDown, at: first) { mouseDown(with: down) }
        let interval = duration / Double(points.count)
        for point in points.dropFirst() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dot.position = point
            CATransaction.commit()
            if let drag = event(.leftMouseDragged, at: point) { mouseDragged(with: drag) }
            try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
        }
        if let up = event(.leftMouseUp, at: last) { mouseUp(with: up) }

        CATransaction.begin()
        CATransaction.setCompletionBlock { dot.removeFromSuperlayer() }
        dot.opacity = 0
        dot.transform = CATransform3DMakeScale(0.4, 0.4, 1)
        CATransaction.commit()
    }
}
