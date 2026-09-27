// Tests which update feeds this build will trust.
import Foundation
import Testing

@testable import UttrflowUX

/// This rule decides where an update may come from, so a feed it wrongly accepts is one Sparkle will read.
@Suite("The feed an updater may read")
struct UpdateFeedTests {
    private func accepts(_ text: String) -> Bool {
        guard let url = URL(string: text) else { return false }
        return UpdateFeed.isAcceptable(url)
    }

    @Test(
        "accepts https anywhere, and plain http only to this Mac",
        arguments: [
            "https://example.com/appcast.xml",
            "http://127.0.0.1:8080/a.xml",
            "http://localhost/a.xml",
            "http://[::1]/a.xml",
        ])
    func accepted(_ feed: String) {
        #expect(accepts(feed))
    }

    /// A rehearsal feed is the only reason plain http exists here; every other one is somebody else's server.
    @Test(
        "refuses plain http anywhere else, and every scheme that is neither",
        arguments: [
            "http://example.com/a.xml",
            "http://127.0.0.1.example.com/a.xml",
            "http://localhost.example.com/a.xml",
            "http://localhost@example.com/a.xml",
            "ftp://127.0.0.1/a.xml",
            "file:///tmp/a.xml",
        ])
    func refused(_ feed: String) {
        #expect(!accepts(feed))
    }

    /// A host in the user part is not the host, which is the oldest way of dressing a URL up as another.
    @Test("reads the host, not a name put before the @")
    func theHostIsNotTheUser() throws {
        let url = try #require(URL(string: "http://localhost@example.com/a.xml"))

        #expect(url.host == "example.com")
        #expect(!UpdateFeed.isAcceptable(url))
    }

    /// A scheme and a host are case-insensitive, so a feed written in capitals is the same feed.
    @Test(
        "reads a scheme and a host whatever their case",
        arguments: ["HTTPS://example.com/a.xml", "HTTP://LOCALHOST/a.xml", "http://LocalHost/a.xml"])
    func caseIsNotPartOfTheRule(_ feed: String) {
        #expect(accepts(feed))
    }

    @Test("refuses a URL with no scheme at all")
    func noScheme() {
        #expect(!accepts("//127.0.0.1/a.xml"))
        #expect(!accepts("appcast.xml"))
    }

    @Test("refuses an https URL with no host")
    func httpsNeedsAHost() {
        #expect(!accepts("https:///no-host"))
        #expect(!accepts("https://:443/a.xml"))
    }

    /// The build gate in `Scripts/update_feed_gate.py` is tested against this same table.
    @Test("agrees with the build gate on every URL in the shared table")
    func sharedTable() throws {
        let table = URL(filePath: #filePath).deletingLastPathComponent().appending(
            path: "../../Scripts/update_feed_cases.json")
        let cases = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: table))
        let accepted = try #require(cases["accepted"])
        let refused = try #require(cases["refused"])
        #expect(!accepted.isEmpty && !refused.isEmpty)
        for feed in accepted { #expect(accepts(feed), "\(feed)") }
        for feed in refused { #expect(!accepts(feed), "\(feed)") }
    }
}
