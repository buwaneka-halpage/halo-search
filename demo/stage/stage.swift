// Shows stage.html full screen, above the menu bar and Dock, as a clean backdrop for recording the demo.
// Writes the screen positions of the photo and the scribble target to the given JSON file.
// Usage: swift stage.swift <layout.json>
// Quits on any click, Esc or ⌘Q, and on its own after three minutes, so it can never trap the screen.
import AppKit
import WebKit

final class Stage: NSObject, WKNavigationDelegate {
    let window: NSWindow
    let web: WKWebView
    let layoutPath: String

    init(layoutPath: String) {
        self.layoutPath = layoutPath
        let screen = NSScreen.main!
        window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        web = WKWebView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init()
        window.contentView = web
        web.navigationDelegate = self
        let page = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("stage.html")
        web.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for the photo and fonts so the measured rectangles are final.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let script = """
                (() => {
                  const box = id => { const r = document.getElementById(id).getBoundingClientRect();
                                      return { x: r.x, y: r.y, width: r.width, height: r.height }; };
                  return JSON.stringify({ hero: box("hero"), term: box("term"), followUp: "When was it built?" });
                })()
                """
            webView.evaluateJavaScript(script) { value, error in
                guard let json = value as? String else { print("measure failed:", error ?? "?"); return }
                try? json.write(toFile: self.layoutPath, atomically: true, encoding: .utf8)
                print("stage ready:", json)
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let stage = Stage(layoutPath: CommandLine.arguments[1])

// Park the pointer at the left edge, over the wallpaper, where it can be cropped out; put it back on quit.
let screenHeight = NSScreen.main!.frame.height
let pointer = NSEvent.mouseLocation
CGWarpMouseCursorPosition(CGPoint(x: 6, y: screenHeight - 80))
func quit() -> Never {
    CGWarpMouseCursorPosition(CGPoint(x: pointer.x, y: screenHeight - pointer.y))
    exit(0)
}
signal(SIGTERM, SIG_IGN)
let terminate = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
terminate.setEventHandler { quit() }
terminate.resume()

NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { event in
    if event.type != .keyDown || event.keyCode == 53 || event.modifierFlags.contains(.command) { quit() }
    return event
}
DispatchQueue.main.asyncAfter(deadline: .now() + 180) { quit() }
app.run()
