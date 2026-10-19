import Foundation
import ServiceManagement
import KradoCore

@MainActor
final class LoginItemManager {
    private(set) var errorMessage: String?
    var status: SMAppService.Status { SMAppService.mainApp.status }
    var state: LoginItemState {
        switch status {
        case .enabled: .enabled
        case .requiresApproval: .needsApproval
        case .notRegistered: .disabled
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
    var isInstalled: Bool {
        LoginItemPolicy.isInstalledInApplications(
            bundlePath: Bundle.main.bundlePath, homeDirectory: NSHomeDirectory()
        )
    }

    /// Launch at Login is off by default. It is only registered when the user asks, from
    /// the onboarding button or the menu checkbox.
    var onboardingOffer: LoginOnboardingOffer {
        LoginItemPolicy.onboardingOffer(state: state, installedInApplications: isInstalled)
    }

    /// The onboarding guide's one-click button.
    func enableFromOnboarding() {
        switch onboardingOffer {
        case .turnOn: register()
        case .openSettings: openSettings()
        case .moveToApplications, .alreadyOn: break
        }
    }

    /// One menu item does everything: turn on, turn off, or open Login Items when macOS
    /// is waiting for approval.
    func toggle() {
        switch LoginItemPolicy.toggleAction(state: state, installedInApplications: isInstalled) {
        case .register:
            register()
        case .unregister:
            do {
                try SMAppService.mainApp.unregister()
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        case .openSettings:
            openSettings()
        case .moveToApplications:
            break // The hint already explains this; the item stays harmless.
        }
    }

    private func register() {
        do {
            try SMAppService.mainApp.register()
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
