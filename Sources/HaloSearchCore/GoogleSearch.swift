import Foundation

/// Builds the Google requests Halo Search makes and recognises the pages that come back.
public enum GoogleSearch {
    /// Two-letter code of the user's first preferred language, so results match the system.
    public static let preferredLanguage: String = language(for: Locale.preferredLanguages.first)

    static func language(for identifier: String?) -> String {
        guard let identifier else { return "en" }
        return Locale(identifier: identifier).language.languageCode?.identifier ?? "en"
    }

    /// Percent-encodes a query value, including the characters that would otherwise be read as query syntax.
    public static func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    // MARK: Requests

    public static func textSearch(_ text: String, language: String = preferredLanguage) -> URL {
        URL(string: "https://www.google.com/search?q=\(encode(text))&hl=\(language)")!
    }

    public static func aiMode(_ text: String, language: String = preferredLanguage) -> URL {
        URL(string: "https://www.google.com/search?udm=50&q=\(encode(text))&hl=\(language)")!
    }

    public static let signIn =
        URL(string: "https://accounts.google.com/ServiceLogin?continue=https://www.google.com/search%3Fudm%3D50")!

    /// A browser form post to Lens. Google replies with a redirect to the visual-match results page.
    public static func lensUpload(jpeg: Data, language: String = preferredLanguage,
                                  boundary: String = "HaloSearch-\(UUID().uuidString)") -> URLRequest {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"encoded_image\"; filename=\"selection.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: URL(string: "https://lens.google.com/v3/upload?hl=\(language)")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    /// The identifiers of an uploaded image, read from a Lens results URL.
    public struct LensSession: Equatable {
        public let visualSearchID: String
        public let sessionID: String?

        public init?(resultsURL url: URL) {
            guard GoogleSearch.isGoogleHost(url), url.path.hasPrefix("/search"),
                  let id = GoogleSearch.parameter("vsrid", in: url), !id.isEmpty else { return nil }
            visualSearchID = id
            sessionID = GoogleSearch.parameter("gsessionid", in: url)
        }
    }

    /// AI Mode with the uploaded image attached. `token` is the single-use `data-mstk` value Lens renders
    /// once it has analysed the image; without it AI Mode only sees the text.
    public static func aiMode(about session: LensSession, token: String, question: String,
                              language: String = preferredLanguage) -> URL {
        var query = ["vsrid=\(encode(session.visualSearchID))"]
        if let sessionID = session.sessionID { query.append("gsessionid=\(encode(sessionID))") }
        query += ["udm=50", "mstk=\(encode(token))", "q=\(encode(question))", "hl=\(language)"]
        return URL(string: "https://www.google.com/search?" + query.joined(separator: "&"))!
    }

    // MARK: Recognising pages

    public static func isGoogleHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.range(of: #"(^|\.)google\.[a-z]{2,3}(\.[a-z]{2})?$"#, options: .regularExpression) != nil
    }

    public static func parameter(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    public static func isLensResults(_ url: URL?) -> Bool {
        url.flatMap(LensSession.init(resultsURL:)) != nil
    }

    /// Google's "unusual traffic" check, which the user solves in the panel.
    public static func isTrafficCheck(_ url: URL?) -> Bool {
        guard let url, isGoogleHost(url) else { return false }
        return url.path.hasPrefix("/sorry")
    }

    private static let panelHosts: Set<String> =
        ["consent.google.com", "accounts.google.com", "lens.google.com", "myaccount.google.com"]

    /// Search, sign-in and consent pages stay in the panel; everything else opens in the default browser.
    public static func staysInPanel(_ url: URL) -> Bool {
        guard url.scheme == "https" || url.scheme == "http" else { return true }
        guard let host = url.host?.lowercased() else { return true }
        if panelHosts.contains(host) { return true }
        guard isGoogleHost(url) else { return false }
        let path = url.path
        return path.isEmpty || path == "/"
            || ["/search", "/sorry", "/webhp", "/setprefs", "/preferences"].contains { path.hasPrefix($0) }
    }

    /// Unwraps Google's `/url?q=` click-tracking redirects to the real destination.
    public static func unwrapRedirect(_ url: URL) -> URL {
        guard isGoogleHost(url), url.path == "/url" else { return url }
        for name in ["q", "url"] {
            if let value = parameter(name, in: url), let target = URL(string: value), target.scheme != nil {
                return target
            }
        }
        return url
    }
}
