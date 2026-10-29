import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let arguments = CommandLine.arguments
    if let index = arguments.firstIndex(of: "--selftest"), index + 1 < arguments.count {
        let test = SelfTest()
        app.setActivationPolicy(.prohibited)
        test.run(imagePath: arguments[index + 1])
        app.run()
    }
    if let index = arguments.firstIndex(of: "--render-overlay"), index + 2 < arguments.count {
        Task { await OverlayRenderTest.run(screenshot: arguments[index + 1], output: arguments[index + 2]) }
        app.setActivationPolicy(.prohibited)
        app.run()
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
