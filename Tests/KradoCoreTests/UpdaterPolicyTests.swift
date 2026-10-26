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
}
