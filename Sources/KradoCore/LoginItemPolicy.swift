import Foundation

/// Pure installation-path policy. ServiceManagement and UserDefaults belong to the app.
public enum LoginItemPolicy {
    public static func isInstalledInApplications(bundlePath: String, homeDirectory: String) -> Bool {
        guard bundlePath.hasPrefix("/"), !bundlePath.contains("/AppTranslocation/") else { return false }
        let path = (bundlePath as NSString).standardizingPath
        let userApplications = ((homeDirectory as NSString).standardizingPath as NSString)
            .appendingPathComponent("Applications")
        return !path.contains("/AppTranslocation/")
            && (path.hasPrefix("/Applications/") || path.hasPrefix(userApplications + "/"))
    }

    public static func shouldAutoRegister(
        bundlePath: String, homeDirectory: String, didApplyDefaultLoginItem: Bool
    ) -> Bool {
        !didApplyDefaultLoginItem
            && isInstalledInApplications(bundlePath: bundlePath, homeDirectory: homeDirectory)
    }
}
