import Foundation
import Testing
@testable import HaloSearchCore

@Suite struct GoogleSearchTests {
    let lensResults = URL(string: "https://www.google.com/search?vsrid=CAIQ_abc&vsint=x&udm=26&lns_mode=un"
        + "&source=lns.web.ukn&gsessionid=sess-1&lsessionid=l1&lns_surface=26&hl=en")!

    @Test func encodesQuerySyntaxInsideValues() {
        #expect(GoogleSearch.encode("c++ & rust = fun?") == "c%2B%2B%20%26%20rust%20%3D%20fun%3F")
    }

    @Test func buildsTextSearches() {
        #expect(GoogleSearch.textSearch("eiffel tower", language: "en").absoluteString
            == "https://www.google.com/search?q=eiffel%20tower&hl=en")
        #expect(GoogleSearch.aiMode("what is 1+1", language: "fr").absoluteString
            == "https://www.google.com/search?udm=50&q=what%20is%201%2B1&hl=fr")
    }

    @Test func languageFallsBackToEnglish() {
        #expect(GoogleSearch.language(for: "si-LK") == "si")
        #expect(GoogleSearch.language(for: nil) == "en")
    }

    @Test func lensUploadIsAMultipartPost() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let request = GoogleSearch.lensUpload(jpeg: jpeg, language: "en", boundary: "B")
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://lens.google.com/v3/upload?hl=en")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=B")
        let body = try #require(request.httpBody)
        let head = String(decoding: body.prefix(120), as: UTF8.self)
        #expect(head.hasPrefix("--B\r\nContent-Disposition: form-data; name=\"encoded_image\""))
        #expect(body.range(of: jpeg) != nil)
        #expect(body.suffix(7) == Data("\r\n--B--\r\n".utf8).suffix(7))
    }

    @Test func readsLensSession() throws {
        let session = try #require(GoogleSearch.LensSession(resultsURL: lensResults))
        #expect(session.visualSearchID == "CAIQ_abc")
        #expect(session.sessionID == "sess-1")
        #expect(GoogleSearch.isLensResults(lensResults))
        #expect(!GoogleSearch.isLensResults(URL(string: "https://www.google.com/search?q=x")!))
        #expect(!GoogleSearch.isLensResults(URL(string: "https://example.com/search?vsrid=1")!))
    }

    @Test func aiModeCarriesTheImageSession() throws {
        let session = try #require(GoogleSearch.LensSession(resultsURL: lensResults))
        let url = GoogleSearch.aiMode(about: session, token: "tok+en/=", question: "What is this?", language: "en")
        #expect(url.absoluteString == "https://www.google.com/search?vsrid=CAIQ_abc&gsessionid=sess-1&udm=50"
            + "&mstk=tok%2Ben/%3D&q=What%20is%20this%3F&hl=en")
        #expect(GoogleSearch.parameter("mstk", in: url) == "tok+en/=")
    }

    @Test(arguments: [
        ("https://www.google.com/search?q=x", true),
        ("https://www.google.co.uk/search?q=x", true),
        ("https://accounts.google.com/signin", true),
        ("https://www.google.com/sorry/index", true),
        ("https://www.google.com/maps/place/x", false),
        ("https://en.wikipedia.org/wiki/Eiffel_Tower", false),
        ("https://google.evil.com/search", false),
    ])
    func decidesWhatStaysInThePanel(url: String, stays: Bool) {
        #expect(GoogleSearch.staysInPanel(URL(string: url)!) == stays)
    }

    @Test func unwrapsClickTrackingRedirects() {
        let wrapped = URL(string: "https://www.google.com/url?sa=t&url=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1")!
        #expect(GoogleSearch.unwrapRedirect(wrapped).absoluteString == "https://example.com/a?b=1")
        let plain = URL(string: "https://example.com")!
        #expect(GoogleSearch.unwrapRedirect(plain) == plain)
    }

    @Test func spotsTheTrafficCheck() {
        #expect(GoogleSearch.isTrafficCheck(URL(string: "https://www.google.com/sorry/index?continue=x")))
        #expect(!GoogleSearch.isTrafficCheck(URL(string: "https://www.google.com/search?q=sorry")))
        #expect(!GoogleSearch.isTrafficCheck(nil))
    }
}
