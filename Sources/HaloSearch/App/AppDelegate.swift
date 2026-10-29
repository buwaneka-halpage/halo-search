import AppKit
import HaloSearchCore
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var overlay: OverlayController?
    private var results: ResultsController!
    private var starting = false
    private var keyMonitor: Any?
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        results = ResultsController()
        results.onClose = { [weak self] in self?.dismiss() }
        results.model.onOpenExternal = { [weak self] url in
            NSWorkspace.shared.open(url)
            self?.dismiss(hideApp: false)
        }
        results.model.onFirstResult = { [weak self] in self?.overlay?.setLoading(false) }

        setUpStatusItem()
        registerHotKey()

        if !ScreenCapturer.hasPermission {
            ScreenCapturer.requestPermission()
        }
        if !UserDefaults.standard.bool(forKey: "welcomed") {
            UserDefaults.standard.set(true, forKey: "welcomed")
            showWelcome()
        }
    }

    // MARK: Session

    func toggle() {
        if overlay != nil || results.isVisible { dismiss() } else { begin() }
    }

    private func begin() {
        guard !starting else { return }
        guard ScreenCapturer.hasPermission else {
            showPermissionAlert()
            return
        }
        guard let screen = NSScreen.underPointer else { return }
        starting = true
        Task {
            defer { starting = false }
            do {
                let image = try await ScreenCapturer.capture(screen)
                present(image, on: screen)
            } catch {
                showError("Couldn't capture the screen", error)
            }
        }
    }

    private func present(_ image: CGImage, on screen: NSScreen) {
        let overlay = OverlayController(screen: screen, image: image)
        overlay.onCancel = { [weak self] in self?.dismiss() }
        overlay.onRegion = { [weak self, weak overlay] rect in
            guard let self, let overlay, let crop = overlay.crop(rect), let jpeg = crop.searchJPEG() else { return }
            overlay.setLoading(true)
            self.results.show(on: screen, avoiding: overlay.globalRect(rect))
            self.results.model.search(.image(jpeg: jpeg, image: crop))
        }
        overlay.onText = { [weak self, weak overlay] text in
            guard let self, let overlay else { return }
            self.results.show(on: screen, avoiding: nil)
            self.results.model.search(.text(text))
            overlay.makeKey()
        }
        self.overlay = overlay
        NSApp.activate(ignoringOtherApps: true)
        overlay.show()
        installKeyMonitor()
    }

    private func dismiss(hideApp: Bool = true) {
        overlay?.close()
        overlay = nil
        results.hide()
        results.model.reset()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if hideApp { NSApp.hide(nil) }
    }

    /// Escape closes everything, wherever the focus is.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    private func openSignIn() {
        guard let screen = NSScreen.underPointer else { return }
        NSApp.activate(ignoringOtherApps: true)
        results.show(on: screen, avoiding: nil)
        results.model.search(.page(GoogleSearch.signIn))
        installKeyMonitor()
    }

    // MARK: Menu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.dashed.inset.filled",
                                           accessibilityDescription: "Halo Search")
        menu.delegate = menuDelegate
        statusItem.menu = menu
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let settings = Settings.shared

        menu.addItem(item("Search Screen  (\(settings.hotKey.title))") { [weak self] in self?.begin() })
        menu.addItem(.separator())

        let shortcuts = NSMenu()
        for preset in HotKeyPreset.all {
            let entry = item(preset.title) { [weak self] in
                Settings.shared.hotKey = preset
                self?.registerHotKey()
                self?.rebuildMenu()
            }
            entry.state = preset == settings.hotKey ? .on : .off
            shortcuts.addItem(entry)
        }
        menu.addItem(submenu("Shortcut", shortcuts))

        let tabs = NSMenu()
        for tab in ResultTab.allCases {
            let entry = item(tab.title) { [weak self] in
                Settings.shared.defaultTab = tab
                self?.rebuildMenu()
            }
            entry.state = tab == settings.defaultTab ? .on : .off
            tabs.addItem(entry)
        }
        menu.addItem(submenu("Open Results In", tabs))
        menu.addItem(item("Question for Images…") { [weak self] in self?.editImagePrompt() })

        menu.addItem(.separator())
        menu.addItem(item("Sign in to Google…") { [weak self] in self?.openSignIn() })
        let login = item("Launch at Login") { [weak self] in
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled { try service.unregister() } else { try service.register() }
            } catch {
                self?.showError("Couldn't change Launch at Login", error)
            }
            self?.rebuildMenu()
        }
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        if !ScreenCapturer.hasPermission {
            menu.addItem(item("Allow Screen Recording…") { [weak self] in self?.showPermissionAlert() })
        }
        menu.addItem(.separator())
        menu.addItem(item("Quit Halo Search") { NSApp.terminate(nil) })
    }

    /// Rebuilds the menu each time it opens so permission and login states are current.
    private lazy var menuDelegate = MenuDelegate { [weak self] in self?.rebuildMenu() }

    private func item(_ title: String, _ action: @escaping () -> Void) -> NSMenuItem {
        let entry = ClosureMenuItem(title: title, action: action)
        return entry
    }

    private func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.submenu = menu
        return entry
    }

    private func registerHotKey() {
        hotKey = nil
        let preset = Settings.shared.hotKey
        hotKey = HotKey(keyCode: preset.keyCode, modifiers: preset.modifiers) { [weak self] in self?.toggle() }
        if hotKey?.isRegistered == false {
            showMessage("\(preset.title) is already in use",
                        "Another app owns this shortcut. Choose a different one from the menu bar icon → Shortcut.")
        }
    }

    // MARK: Alerts

    private func editImagePrompt() {
        let alert = NSAlert()
        alert.messageText = "Question for Images"
        alert.informativeText = "AI Mode is asked this about every image you circle. You can still ask follow-ups in the panel."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = Settings.shared.imagePrompt
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { Settings.shared.imagePrompt = value }
        }
    }

    private func showWelcome() {
        showMessage("Halo Search is ready",
                    "Press \(Settings.shared.hotKey.title) anywhere, then circle, scribble or tap what you want to search. "
                        + "Results open in Google AI Mode and Google Search. Find options under the menu bar icon.")
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Allow Screen Recording"
        alert.informativeText = "Halo Search needs to see your screen to search what you circle. "
            + "Turn it on in System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch the app."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Relaunch")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            ScreenCapturer.requestPermission()
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        case .alertSecondButtonReturn:
            relaunch()
        default:
            break
        }
    }

    private func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.6; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func showMessage(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showError(_ title: String, _ error: Error) {
        showMessage(title, error.localizedDescription)
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}

final class MenuDelegate: NSObject, NSMenuDelegate {
    private let willOpen: () -> Void
    init(_ willOpen: @escaping () -> Void) { self.willOpen = willOpen }
    func menuNeedsUpdate(_ menu: NSMenu) { willOpen() }
}

extension CGImage {
    /// Lens accepts large images, but a smaller upload makes results come back sooner.
    func searchJPEG(maxSide: Int = 1600, quality: CGFloat = 0.88) -> Data? {
        var image = self
        let longest = max(width, height)
        if longest > maxSide {
            let scale = CGFloat(maxSide) / CGFloat(longest)
            let size = CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
            guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                          bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
            context.interpolationQuality = .high
            context.draw(self, in: CGRect(origin: .zero, size: size))
            guard let scaled = context.makeImage() else { return nil }
            image = scaled
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
