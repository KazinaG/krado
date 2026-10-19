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

    /// What the single "Launch at Login" menu item does when chosen.
    public static func toggleAction(state: LoginItemState, installedInApplications: Bool) -> LoginToggleAction {
        switch state {
        case .enabled: .unregister
        case .needsApproval: .openSettings
        case .disabled, .unavailable: installedInApplications ? .register : .moveToApplications
        }
    }

    /// The one-line hint under the menu item, if any. Nothing is shown in the normal states.
    public static func hint(state: LoginItemState, installedInApplications: Bool) -> LoginHint? {
        switch state {
        case .enabled: nil
        case .needsApproval: .allowInSettings
        case .disabled, .unavailable: installedInApplications ? nil : .moveToApplications
        }
    }
}

/// SMAppService.Status reduced to what the menu needs.
public enum LoginItemState: Equatable, Sendable {
    case enabled, needsApproval, disabled, unavailable
}

public enum LoginToggleAction: Equatable, Sendable {
    case register, unregister, openSettings, moveToApplications
}

public enum LoginHint: Equatable, Sendable {
    case allowInSettings, moveToApplications
}
