import AppKit
import SwiftUI
import WebKit

final class ResultsPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 760),
                   styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        minSize = NSSize(width: 360, height: 420)
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ResultsController {
    let model = SearchModel()
    private let panel = ResultsPanel()
    var onClose: (() -> Void)?

    var isVisible: Bool { panel.isVisible }

    init() {
        let root = ResultsView(model: model, onClose: { [weak self] in self?.onClose?() })
        panel.contentView = NSHostingView(rootView: root)
    }

    /// Shows the panel beside the selection; once visible it stays where the user put it.
    func show(on screen: NSScreen, avoiding selection: CGRect?) {
        if panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let area = screen.visibleFrame.insetBy(dx: 16, dy: 16)
        let width = min(480, max(380, area.width * 0.32))
        let height = min(area.height, 980)
        var x = area.maxX - width
        if let selection, selection.midX > area.midX { x = area.minX }
        let frame = NSRect(x: x, y: area.midY - height / 2, width: width, height: height)

        panel.setFrame(frame.offsetBy(dx: 0, dy: -24), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        let panel = self.panel
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}

// MARK: - SwiftUI

struct ResultsView: View {
    @ObservedObject var model: SearchModel
    var onClose: () -> Void
    @FocusState private var fieldFocused: Bool
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 38, height: 5)
                .padding(.top, 9)
                .padding(.bottom, 8)
            header
            tabs
            if let notice = model.notice {
                Label(notice, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            ProgressStrip(active: model.loading.contains(model.tab))
            ZStack {
                WebViewHost(web: model.aiWeb)
                    .opacity(model.tab == .aiMode && model.ready.contains(.aiMode) ? 1 : 0)
                WebViewHost(web: model.searchWeb)
                    .opacity(model.tab == .search && model.ready.contains(.search) ? 1 : 0)
                if !model.ready.contains(model.tab) {
                    SkeletonView(caption: caption)
                }
            }
        }
        .background(.regularMaterial)
        .ignoresSafeArea()
        .background(hiddenShortcuts)
    }

    private var caption: String {
        switch (model.tab, model.isImage) {
        case (.aiMode, true): return "Looking at your selection…"
        case (.search, true): return "Searching with Google Lens…"
        default: return "Searching…"
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                if let thumbnail = model.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                }
                TextField(model.isImage ? "Ask about this…" : "Search", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($fieldFocused)
                    .onSubmit { model.submitQuery() }
            }
            .padding(.leading, model.thumbnail == nil ? 12 : 5)
            .padding(.trailing, 12)
            .frame(height: 40)
            .background(Capsule().fill(Color.primary.opacity(0.07)))

            IconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: model.isImage ? "Copy image" : "Copy text") {
                model.copySubject()
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
            }
            IconButton(symbol: "safari", help: "Open in browser") { model.openCurrentInBrowser() }
            IconButton(symbol: "xmark", help: "Close (esc)") { onClose() }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            ForEach(ResultTab.allCases, id: \.self) { tab in
                Button {
                    model.tab = tab
                } label: {
                    HStack(spacing: 5) {
                        if tab == .aiMode { Image(systemName: "sparkle") }
                        Text(tab.title)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .foregroundStyle(model.tab == tab ? Color.white : Color.primary)
                    .background(
                        Capsule().fill(model.tab == tab ? Color(nsColor: GoogleColors.blue) : Color.primary.opacity(0.07))
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var hiddenShortcuts: some View {
        ZStack {
            Button("") { model.tab = .aiMode }.keyboardShortcut("1", modifiers: .command)
            Button("") { model.tab = .search }.keyboardShortcut("2", modifiers: .command)
            Button("") { fieldFocused = true }.keyboardShortcut("l", modifiers: .command)
            Button("") { onClose() }.keyboardShortcut("w", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }
}

private struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.primary.opacity(0.07)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct WebViewHost: NSViewRepresentable {
    let web: WKWebView
    func makeNSView(context: Context) -> WKWebView { web }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

/// An indeterminate bar in Google's colours.
private struct ProgressStrip: View {
    let active: Bool

    var body: some View {
        TimelineView(.animation(paused: !active)) { timeline in
            GeometryReader { geometry in
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                LinearGradient(colors: GoogleColors.cycle.map { Color(cgColor: $0) },
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geometry.size.width * 0.45)
                    .offset(x: (geometry.size.width * 1.45) * phase - geometry.size.width * 0.45)
            }
        }
        .frame(height: 2.5)
        .clipped()
        .opacity(active ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: active)
    }
}

private struct SkeletonView: View {
    let caption: String
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(caption)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(0.08))
                    .frame(maxWidth: index % 4 == 3 ? 180 : .infinity)
                    .frame(height: index % 4 == 0 ? 22 : 13)
                    .padding(.top, index % 4 == 0 && index > 0 ? 14 : 0)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .mask(
            LinearGradient(colors: [.black.opacity(0.45), .black, .black.opacity(0.45)],
                           startPoint: shimmer ? UnitPoint(x: 1, y: 0) : UnitPoint(x: -1, y: 0),
                           endPoint: shimmer ? UnitPoint(x: 2, y: 0) : UnitPoint(x: 0, y: 0))
        )
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { shimmer = true }
        }
    }
}
