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

    /// What the onboarding guide offers. Launch at Login is off by default and is only
    /// ever turned on by the user, from this offer or from the menu checkbox.
    public static func onboardingOffer(state: LoginItemState, installedInApplications: Bool) -> LoginOnboardingOffer {
        switch state {
        case .enabled: .alreadyOn
        case .needsApproval: .openSettings
        case .disabled, .unavailable: installedInApplications ? .turnOn : .moveToApplications
        }
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

public enum LoginOnboardingOffer: Equatable, Sendable {
    /// One-click button that registers the login item.
    case turnOn
    /// macOS is waiting for approval; the button opens Login Items settings.
    case openSettings
    /// Registration is not possible from this location; show a hint, no button.
    case moveToApplications
    /// Nothing to offer.
    case alreadyOn
}

public enum LoginHint: Equatable, Sendable {
    case allowInSettings, moveToApplications
}
