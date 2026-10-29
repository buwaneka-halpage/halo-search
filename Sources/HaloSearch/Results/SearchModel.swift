import AppKit
import HaloSearchCore
import WebKit

/// Drives the two result tabs. Both web views share the default data store, so a Google sign-in persists.
@MainActor
final class SearchModel: NSObject, ObservableObject {
    enum Subject {
        case image(jpeg: Data, image: CGImage)
        case text(String)
        case page(URL)
    }

    @Published var tab: ResultTab = Settings.shared.defaultTab
    @Published var query = ""
    @Published private(set) var isImage = false
    @Published private(set) var thumbnail: NSImage?
    @Published private(set) var loading: Set<ResultTab> = []
    @Published private(set) var ready: Set<ResultTab> = []
    @Published var notice: String?

    let aiWeb: WKWebView
    let searchWeb: WKWebView

    var onFirstResult: (() -> Void)?
    var onOpenExternal: ((URL) -> Void)?

    private var subject: Subject?
    private var generation = 0
    private var tokenTask: Task<Void, Never>?
    private var aiHasImage = false
    private var pendingQuestion: String?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "Version/\(SearchModel.safariVersion) Safari/605.1.15"
        config.preferences.isElementFullscreenEnabled = true
        aiWeb = WKWebView(frame: .zero, configuration: config)
        searchWeb = WKWebView(frame: .zero, configuration: config)
        super.init()
        for web in [aiWeb, searchWeb] {
            web.navigationDelegate = self
            web.uiDelegate = self
            web.allowsBackForwardNavigationGestures = true
            web.allowsMagnification = true
        }
    }

    /// Google serves a reduced page to WebKit user agents that don't look like Safari.
    private static let safariVersion: String = {
        let plist = URL(fileURLWithPath: "/Applications/Safari.app/Contents/Info.plist")
        let info = NSDictionary(contentsOf: plist)
        return info?["CFBundleShortVersionString"] as? String ?? "26.0"
    }()

    func web(for tab: ResultTab) -> WKWebView { tab == .aiMode ? aiWeb : searchWeb }

    private func tab(of web: WKWebView) -> ResultTab { web === aiWeb ? .aiMode : .search }

    // MARK: Searching

    func search(_ subject: Subject) {
        self.subject = subject
        generation += 1
        tokenTask?.cancel()
        aiHasImage = false
        pendingQuestion = nil
        notice = nil
        ready = []

        switch subject {
        case .image(let jpeg, let image):
            isImage = true
            query = ""
            thumbnail = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            tab = Settings.shared.defaultTab
            loading = [.aiMode, .search]
            aiWeb.stopLoading()
            searchWeb.load(GoogleSearch.lensUpload(jpeg: jpeg))
        case .text(let text):
            isImage = false
            query = text
            thumbnail = nil
            tab = Settings.shared.defaultTab
            loading = [.aiMode, .search]
            aiWeb.load(URLRequest(url: GoogleSearch.aiMode(text)))
            searchWeb.load(URLRequest(url: GoogleSearch.textSearch(text)))
        case .page(let url):
            isImage = false
            query = ""
            thumbnail = nil
            tab = .aiMode
            loading = [.aiMode]
            aiWeb.load(URLRequest(url: url))
        }
    }

    /// The text field: refines a text search, or asks AI Mode a follow-up about the image.
    func submitQuery() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard isImage else {
            search(.text(text))
            return
        }
        tab = .aiMode
        guard aiHasImage else {
            // The image is still uploading; ask this instead of the default question.
            pendingQuestion = text
            return
        }
        query = ""
        aiWeb.callAsyncJavaScript(PageScripts.askFollowUp, arguments: ["question": text],
                                  in: nil, in: .page) { [weak self] result in
            guard let self else { return }
            // A failure here usually means the page navigated away after taking the question.
            if case .success(let status as String) = result, status != "sent" {
                // The page changed its layout; ask without the image rather than not at all.
                self.notice = "Couldn't reach AI Mode's follow-up box, so this was asked without the image."
                self.aiWeb.load(URLRequest(url: GoogleSearch.aiMode(text)))
            }
        }
    }

    func reset() {
        generation += 1
        tokenTask?.cancel()
        subject = nil
        loading = []
        ready = []
        notice = nil
        for web in [aiWeb, searchWeb] {
            web.stopLoading()
            web.loadHTMLString("", baseURL: nil)
        }
    }

    // MARK: Actions

    func openCurrentInBrowser() {
        guard let url = web(for: tab).url, url.scheme?.hasPrefix("http") == true else { return }
        onOpenExternal?(url)
    }

    func copySubject() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch subject {
        case .image(_, let image):
            pasteboard.writeObjects([NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))])
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .page, .none:
            if let url = web(for: tab).url { pasteboard.setString(url.absoluteString, forType: .string) }
        }
    }

    // MARK: AI Mode continuation

    private func continueInAIMode() {
        guard !aiHasImage else { return }
        tokenTask?.cancel()
        let generation = self.generation
        tokenTask = Task { [weak self] in
            for _ in 0..<100 {
                guard let self, !Task.isCancelled, generation == self.generation else { return }
                let token = await self.evaluate(PageScripts.lensToken, in: self.searchWeb) as? String
                if let token, !token.isEmpty,
                   let session = self.searchWeb.url.flatMap(GoogleSearch.LensSession.init(resultsURL:)) {
                    let question = self.pendingQuestion ?? Settings.shared.imagePrompt
                    self.aiHasImage = true
                    self.pendingQuestion = nil
                    self.aiWeb.load(URLRequest(url: GoogleSearch.aiMode(about: session, token: token, question: question)))
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard let self, generation == self.generation else { return }
            self.loading.remove(.aiMode)
            self.notice = "AI Mode didn't accept this image, so here are the Search results."
            self.tab = .search
        }
    }

    private func evaluate(_ script: String, in web: WKWebView) async -> Any? {
        await withCheckedContinuation { continuation in
            web.evaluateJavaScript(script) { value, _ in continuation.resume(returning: value) }
        }
    }

    private func markReady(_ tab: ResultTab) {
        let first = ready.isEmpty
        ready.insert(tab)
        if first { onFirstResult?() }
    }
}

extension SearchModel: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, action.targetFrame?.isMainFrame != false else {
            decisionHandler(.allow)
            return
        }
        let userClicked = action.navigationType == .linkActivated
        let wantsNewWindow = action.modifierFlags.contains(.command)
        if userClicked && (wantsNewWindow || !GoogleSearch.staysInPanel(url)) {
            decisionHandler(.cancel)
            onOpenExternal?(GoogleSearch.unwrapRedirect(url))
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if GoogleSearch.staysInPanel(url) { webView.load(URLRequest(url: url)) } else { onOpenExternal?(GoogleSearch.unwrapRedirect(url)) }
        }
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard webView.url?.scheme?.hasPrefix("http") == true else { return }
        loading.insert(tab(of: webView))
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView.url?.scheme?.hasPrefix("http") == true else { return }
        markReady(tab(of: webView))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let tab = tab(of: webView)
        guard webView.url?.scheme?.hasPrefix("http") == true else { return }
        loading.remove(tab)
        if GoogleSearch.isTrafficCheck(webView.url) {
            notice = "Google wants to check you're not a robot. Solve it here and the search will continue."
            self.tab = tab
            return
        }
        if tab == .search, isImage, !aiHasImage, GoogleSearch.isLensResults(webView.url) {
            notice = nil
            continueInAIMode()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failed(webView, error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failed(webView, error)
    }

    private func failed(_ webView: WKWebView, _ error: Error) {
        let tab = tab(of: webView)
        loading.remove(tab)
        let nsError = error as NSError
        // Cancelled loads are replaced searches; 102 is a navigation handed to another app.
        if nsError.code == NSURLErrorCancelled || (nsError.domain == "WebKitErrorDomain" && nsError.code == 102) { return }
        notice = error.localizedDescription
        markReady(tab)
        if tab == .search, isImage { self.loading.remove(.aiMode) }
    }
}
