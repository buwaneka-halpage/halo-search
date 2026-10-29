import AppKit
import HaloSearchCore
import QuartzCore

enum GoogleColors {
    static let blue = NSColor(srgbRed: 0.259, green: 0.522, blue: 0.957, alpha: 1)
    static let red = NSColor(srgbRed: 0.918, green: 0.263, blue: 0.208, alpha: 1)
    static let yellow = NSColor(srgbRed: 0.984, green: 0.737, blue: 0.020, alpha: 1)
    static let green = NSColor(srgbRed: 0.204, green: 0.659, blue: 0.325, alpha: 1)
    static let cycle: [CGColor] = [blue, red, yellow, green, blue].map(\.cgColor)
}

// MARK: - Window

final class OverlayPanel: NSPanel {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = true
        hasShadow = false
        backgroundColor = .black
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Controller

@MainActor
final class OverlayController {
    let screen: NSScreen
    let image: CGImage
    private let window: OverlayPanel
    let view: OverlayView

    var onRegion: ((CGRect) -> Void)?
    var onText: ((String) -> Void)?
    var onCancel: (() -> Void)?

    init(screen: NSScreen, image: CGImage) {
        self.screen = screen
        self.image = image
        window = OverlayPanel(screen: screen)
        view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size), image: image)
        window.contentView = view
        view.onRegion = { [weak self] rect in self?.onRegion?(rect) }
        view.onText = { [weak self] text in self?.onText?(text) }
        view.onCancel = { [weak self] in self?.onCancel?() }
    }

    func show() {
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            window.animator().alphaValue = 1
        }
        view.playIntro()
        let size = view.bounds.size
        Task { [weak self, image] in
            let lines = await TextRecognizer.recognize(image, in: size)
            self?.view.lines = lines
        }
    }

    func close() {
        let window = self.window
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
    }

    func makeKey() { window.makeKeyAndOrderFront(nil) }

    func setLoading(_ loading: Bool) { view.setLoading(loading) }

    /// The circled region in screen (global) coordinates.
    func globalRect(_ rect: CGRect) -> CGRect { rect.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY) }

    /// Cuts the region out of the frozen screenshot at full pixel resolution.
    func crop(_ rect: CGRect) -> CGImage? {
        let scale = CGFloat(image.width) / view.bounds.width
        let pixels = CGRect(x: rect.minX * scale,
                            y: (view.bounds.height - rect.maxY) * scale,
                            width: rect.width * scale,
                            height: rect.height * scale).integral
        return image.cropping(to: pixels)
    }
}

// MARK: - View

final class OverlayView: NSView {
    var onRegion: ((CGRect) -> Void)?
    var onText: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var lines: [RecognizedLine] = []

    private let image: CGImage
    private let imageLayer = CALayer()
    private let dimLayer = CAShapeLayer()
    private let glowContainer = CALayer()
    private let glowGradient = CAGradientLayer()
    private let glowMask = CAShapeLayer()
    private let textLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()
    private let selectionLayer = CAShapeLayer()
    private let shimmerLayer = CAGradientLayer()
    private let shimmerMask = CAShapeLayer()
    private let hint = NSVisualEffectView()

    private enum Drag {
        case none
        case drawing
        case resizing(anchor: CGPoint)
    }

    private var drag = Drag.none
    private var points: [CGPoint] = []
    private var selection: CGRect?

    private let cornerRadius: CGFloat = 18
    private let idleDim: Float = 0.12
    private let selectedDim: Float = 0.45

    init(frame: NSRect, image: CGImage) {
        self.image = image
        super.init(frame: frame)
        wantsLayer = true
        setUpLayers()
        setUpHint()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    private func setUpLayers() {
        guard let root = layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        imageLayer.frame = bounds
        imageLayer.contents = image
        imageLayer.contentsGravity = .resize
        root.addSublayer(imageLayer)

        dimLayer.frame = bounds
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = NSColor.black.cgColor
        dimLayer.opacity = idleDim
        dimLayer.path = CGPath(rect: bounds, transform: nil)
        root.addSublayer(dimLayer)

        textLayer.frame = bounds
        textLayer.fillColor = GoogleColors.blue.withAlphaComponent(0.38).cgColor
        root.addSublayer(textLayer)

        // A conic gradient spins behind a soft border mask, like the Pixel edge glow.
        glowContainer.frame = bounds
        let side = hypot(bounds.width, bounds.height)
        glowGradient.type = .conic
        glowGradient.colors = GoogleColors.cycle
        glowGradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowGradient.endPoint = CGPoint(x: 0.5, y: 0)
        glowGradient.frame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        glowContainer.addSublayer(glowGradient)
        glowMask.frame = bounds
        glowMask.path = CGPath(rect: bounds, transform: nil)
        glowMask.fillColor = nil
        glowMask.strokeColor = NSColor.black.cgColor
        glowMask.lineWidth = 10
        glowMask.shadowColor = NSColor.black.cgColor
        glowMask.shadowOpacity = 1
        glowMask.shadowRadius = 14
        glowMask.shadowOffset = .zero
        glowContainer.mask = glowMask
        glowContainer.opacity = 0
        root.addSublayer(glowContainer)

        strokeLayer.frame = bounds
        strokeLayer.fillColor = nil
        strokeLayer.strokeColor = NSColor.white.cgColor
        strokeLayer.lineWidth = 6
        strokeLayer.lineCap = .round
        strokeLayer.lineJoin = .round
        strokeLayer.shadowColor = NSColor.white.cgColor
        strokeLayer.shadowOpacity = 0.9
        strokeLayer.shadowRadius = 8
        strokeLayer.shadowOffset = .zero
        root.addSublayer(strokeLayer)

        shimmerLayer.colors = [NSColor.white.withAlphaComponent(0).cgColor,
                               NSColor.white.withAlphaComponent(0.32).cgColor,
                               NSColor.white.withAlphaComponent(0).cgColor]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [-0.4, -0.2, 0]
        shimmerLayer.mask = shimmerMask
        shimmerLayer.opacity = 0
        root.addSublayer(shimmerLayer)

        selectionLayer.frame = bounds
        selectionLayer.fillColor = nil
        selectionLayer.strokeColor = NSColor.white.cgColor
        selectionLayer.lineWidth = 5
        selectionLayer.lineCap = .round
        selectionLayer.shadowColor = NSColor.black.cgColor
        selectionLayer.shadowOpacity = 0.35
        selectionLayer.shadowRadius = 6
        selectionLayer.shadowOffset = .zero
        root.addSublayer(selectionLayer)

        CATransaction.commit()
    }

    private func setUpHint() {
        hint.material = .hudWindow
        hint.blendingMode = .withinWindow
        hint.state = .active
        hint.wantsLayer = true
        hint.layer?.cornerRadius = 20
        hint.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: "Circle, scribble or tap text to search")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        let esc = NSTextField(labelWithString: "esc to close")
        esc.font = .systemFont(ofSize: 12)
        esc.textColor = NSColor.white.withAlphaComponent(0.6)
        let stack = NSStackView(views: [label, esc])
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        hint.addSubview(stack)
        hint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hint)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: hint.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: hint.trailingAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: hint.centerYAnchor),
            hint.heightAnchor.constraint(equalToConstant: 40),
            hint.centerXAnchor.constraint(equalTo: centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -56),
        ])
    }

    // MARK: Animation

    func playIntro() {
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = -2 * Double.pi
        spin.duration = 3.5
        spin.repeatCount = .infinity
        glowGradient.add(spin, forKey: "spin")

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0.55]
        fade.keyTimes = [0, 0.15, 0.6, 1]
        fade.duration = 1.4
        glowContainer.opacity = 0.55
        glowContainer.add(fade, forKey: "intro")
    }

    private func animate(_ layer: CALayer, _ keyPath: String, to value: Any, duration: CFTimeInterval = 0.25) {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = layer.presentation()?.value(forKeyPath: keyPath) ?? layer.value(forKeyPath: keyPath)
        animation.toValue = value
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setValue(value, forKeyPath: keyPath)
        CATransaction.commit()
        layer.add(animation, forKey: keyPath)
    }

    func setLoading(_ loading: Bool) {
        if loading, let selection {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            shimmerLayer.frame = selection
            shimmerMask.frame = CGRect(origin: .zero, size: selection.size)
            shimmerMask.path = CGPath(roundedRect: shimmerMask.frame, cornerWidth: cornerRadius,
                                      cornerHeight: cornerRadius, transform: nil)
            CATransaction.commit()
            let sweep = CABasicAnimation(keyPath: "locations")
            sweep.fromValue = [-0.4, -0.2, 0]
            sweep.toValue = [1, 1.2, 1.4]
            sweep.duration = 1.1
            sweep.repeatCount = .infinity
            shimmerLayer.add(sweep, forKey: "sweep")
            animate(shimmerLayer, "opacity", to: Float(1), duration: 0.2)
        } else {
            animate(shimmerLayer, "opacity", to: Float(0), duration: 0.35)
        }
    }

    // MARK: Input

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if hint.alphaValue > 0 {
            NSAnimationContext.runAnimationGroup { $0.duration = 0.2; hint.animator().alphaValue = 0 }
        }
        if let selection, let anchor = resizeAnchor(for: point, in: selection) {
            drag = .resizing(anchor: anchor)
            return
        }
        drag = .drawing
        points = [point]
        strokeLayer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        strokeLayer.opacity = 1
        strokeLayer.path = nil
        CATransaction.commit()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch drag {
        case .drawing:
            guard let last = points.last, hypot(point.x - last.x, point.y - last.y) > 1.5 else { return }
            points.append(point)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            strokeLayer.path = smoothPath(points)
            CATransaction.commit()
        case .resizing(let anchor):
            var rect = CGRect(x: min(anchor.x, point.x), y: min(anchor.y, point.y),
                              width: abs(point.x - anchor.x), height: abs(point.y - anchor.y))
            rect.size.width = max(rect.width, 40)
            rect.size.height = max(rect.height, 40)
            showSelection(rect.intersection(bounds), from: nil)
        case .none:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer { drag = .none }
        switch drag {
        case .resizing:
            if let selection { onRegion?(selection) }
        case .drawing:
            finishStroke()
        case .none:
            break
        }
    }

    private func finishStroke() {
        fadeStroke()
        switch StrokeAnalyzer.gesture(for: points, lines: lines, in: bounds) {
        case .none:
            break
        case .text(let words):
            selectText(words)
        case .region(let rect):
            showSelection(rect, from: StrokeAnalyzer.boundingBox(of: points))
            onRegion?(rect)
        }
    }

    private func selectText(_ words: [RecognizedWord]) {
        let text = TextSelection.text(of: words, in: lines)
        guard !text.isEmpty else { return }
        selection = nil
        let path = CGMutablePath()
        for (_, lineWords) in Dictionary(grouping: words, by: \.line) {
            let rect = lineWords.map(\.rect).reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -4, dy: -3)
            path.addRoundedRect(in: rect, cornerWidth: 5, cornerHeight: 5)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionLayer.path = nil
        dimLayer.path = CGPath(rect: bounds, transform: nil)
        textLayer.path = path
        CATransaction.commit()
        animate(dimLayer, "opacity", to: Float(0.3))
        animate(glowContainer, "opacity", to: Float(0), duration: 0.4)
        onText?(text)
    }

    private func showSelection(_ rect: CGRect, from start: CGRect?) {
        selection = rect
        let holePath = { (hole: CGRect) -> CGPath in
            let path = CGMutablePath()
            path.addRect(self.bounds)
            path.addRoundedRect(in: hole, cornerWidth: min(self.cornerRadius, hole.width / 2),
                                cornerHeight: min(self.cornerRadius, hole.height / 2))
            return path
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textLayer.path = nil
        CATransaction.commit()

        if let start {
            // Grow the brackets and the cut-out from the drawn stroke to the padded selection.
            let fromHole = start.intersection(bounds).insetBy(dx: -1, dy: -1)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dimLayer.path = holePath(fromHole)
            selectionLayer.path = bracketPath(fromHole)
            CATransaction.commit()
            animate(dimLayer, "path", to: holePath(rect), duration: 0.3)
            animate(selectionLayer, "path", to: bracketPath(rect), duration: 0.3)
            animate(dimLayer, "opacity", to: selectedDim, duration: 0.3)
            animate(glowContainer, "opacity", to: Float(0), duration: 0.4)
            selectionLayer.opacity = 1
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dimLayer.path = holePath(rect)
            selectionLayer.path = bracketPath(rect)
            CATransaction.commit()
        }
    }

    private func fadeStroke() {
        animate(strokeLayer, "opacity", to: Float(0), duration: 0.3)
    }

    // MARK: Geometry

    private func resizeAnchor(for point: CGPoint, in rect: CGRect) -> CGPoint? {
        let corners = [(CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)),
                       (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY)),
                       (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.minY)),
                       (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.minY))]
        return corners.first { hypot($0.0.x - point.x, $0.0.y - point.y) < 30 }?.1
    }

    private func bracketPath(_ rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let length = min(36, rect.width / 3, rect.height / 3)
        let radius = min(cornerRadius, length * 0.8)
        let corners: [(CGPoint, CGVector, CGVector)] = [
            (CGPoint(x: rect.minX, y: rect.minY), CGVector(dx: 0, dy: 1), CGVector(dx: 1, dy: 0)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGVector(dx: -1, dy: 0), CGVector(dx: 0, dy: 1)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGVector(dx: 0, dy: -1), CGVector(dx: -1, dy: 0)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: -1)),
        ]
        for (corner, a, b) in corners {
            let start = CGPoint(x: corner.x + a.dx * length, y: corner.y + a.dy * length)
            let end = CGPoint(x: corner.x + b.dx * length, y: corner.y + b.dy * length)
            path.move(to: start)
            path.addArc(tangent1End: corner, tangent2End: end, radius: radius)
            path.addLine(to: end)
        }
        return path
    }

    private func smoothPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            points.dropFirst().forEach { path.addLine(to: $0) }
            return path
        }
        for index in 1..<points.count - 1 {
            let mid = CGPoint(x: (points[index].x + points[index + 1].x) / 2,
                              y: (points[index].y + points[index + 1].y) / 2)
            path.addQuadCurve(to: mid, control: points[index])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
