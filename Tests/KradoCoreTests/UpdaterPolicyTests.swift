import Testing
@testable import KradoCore

@Suite("Updater configuration policy")
struct UpdaterPolicyTests {
    private let key = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    private let feed = "https://github.com/KazinaG/krado/releases/latest/download/appcast.xml"

    @Test("A real Ed25519 public key and HTTPS feed enable updates")
    func configured() {
        #expect(UpdaterPolicy.isConfigured(publicKey: key, feedURL: feed))
    }

    @Test("Missing, placeholder, and malformed keys never enable updates", arguments: [
        nil, "", " ", "KRADO_SPARKLE_PUBLIC_KEY_PLACEHOLDER", "placeholder", "not-a-key", "YQ=="
    ] as [String?])
    func invalidKey(publicKey: String?) {
        #expect(!UpdaterPolicy.isConfigured(publicKey: publicKey, feedURL: feed))
    }

    @Test("Only absolute HTTPS feeds without credentials are accepted", arguments: [
        nil, "", " ", "http://example.com/appcast.xml", "file:///tmp/appcast.xml",
        "appcast.xml", "https:///", "https://", "https://user:password@example.com/appcast.xml"
    ] as [String?])
    func invalidFeed(feedURL: String?) {
        #expect(!UpdaterPolicy.isConfigured(publicKey: key, feedURL: feedURL))
    }

    @Test("A test feed is used only for this repository's release assets")
    func testFeedAccepted() {
        let url = "https://github.com/KazinaG/krado/releases/download/v0.1.1-test/appcast-test.xml"
        #expect(UpdaterPolicy.testFeedURL(url) == url)
    }

    @Test("Anything else falls back to the public feed", arguments: [
        nil, "", "https://github.com/KazinaG/krado/releases/latest/download/appcast.xml",
        "https://github.com/someone/krado/releases/download/v1/appcast-test.xml",
        "http://github.com/KazinaG/krado/releases/download/v0.1.1-test/appcast-test.xml",
        "https://github.com.evil.example/KazinaG/krado/releases/download/v1/appcast-test.xml",
        "https://github.com/KazinaG/krado/releases/download/../../other/appcast-test.xml",
        "https://github.com/KazinaG/krado/releases/download/v1/appcast-test.xml?x=1",
        "https://github.com/KazinaG/krado/releases/download/v1/appcast.xml",
    ] as [String?])
    func testFeedRejected(value: String?) {
        #expect(UpdaterPolicy.testFeedURL(value) == nil)
    }
}
