import Foundation
import Testing

/// The app's Info.plist is written by scripts/build-app.sh; these checks pin the
/// update defaults chosen for 0.1.0.
@Suite("Info.plist update defaults")
struct InfoPlistDefaultsTests {
    private static let script: String = {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return (try? String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)) ?? ""
    }()

    private func value(_ key: String) -> String? {
        let pattern = "<key>\(key)</key><(true|false)/>"
        guard let range = Self.script.range(of: pattern, options: .regularExpression) else { return nil }
        return Self.script[range].contains("<true/>") ? "true" : "false"
    }

    @Test("Automatic checks are on, so Sparkle never shows its permission prompt")
    func automaticChecksOn() {
        #expect(value("SUEnableAutomaticChecks") == "true")
    }

    @Test("Updates are never downloaded or installed silently")
    func noSilentInstall() {
        #expect(value("SUAutomaticallyUpdate") == "false")
        #expect(value("SUAllowsAutomaticUpdates") == "false")
    }
}
