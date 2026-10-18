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
}
