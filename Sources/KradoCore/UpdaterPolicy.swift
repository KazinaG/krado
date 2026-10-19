import Foundation

/// Configuration only; this helper never starts an updater or accesses the network.
public enum UpdaterPolicy {
    public static func isConfigured(publicKey: String?, feedURL: String?) -> Bool {
        guard let publicKey, let feedURL,
              !publicKey.isEmpty,
              !publicKey.uppercased().contains("PLACEHOLDER"),
              let key = Data(base64Encoded: publicKey), key.count == 32,
              let url = URLComponents(string: feedURL),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return false }
        return true
    }

    /// UserDefaults key for an opt-in test feed (`defaults write io.github.kazinag.krado
    /// KradoTestFeedURL <url>`). Used only to try an update between unpublished releases.
    public static let testFeedDefaultsKey = "KradoTestFeedURL"

    /// Only assets of this repository's own releases may replace the public feed. Every
    /// update is still checked against the app's EdDSA public key, so this cannot load
    /// code that was not signed with krado's release key.
    public static let testFeedPrefix = "https://github.com/KazinaG/krado/releases/download/"

    /// The test feed to use instead of the Info.plist feed, or nil for the public feed.
    public static func testFeedURL(_ value: String?) -> String? {
        guard let value, value.hasPrefix(testFeedPrefix),
              let url = URLComponents(string: value),
              url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !url.path.contains(".."), url.path.hasSuffix("/appcast-test.xml") else { return nil }
        return value
    }
}
