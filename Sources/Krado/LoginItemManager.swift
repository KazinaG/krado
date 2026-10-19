import Foundation
import ServiceManagement
import KradoCore

@MainActor
final class LoginItemManager {
    private static let defaultAppliedKey = "didApplyDefaultLoginItem"
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

    func applyFirstRunDefault() {
        let defaults = UserDefaults.standard
        guard LoginItemPolicy.shouldAutoRegister(
            bundlePath: Bundle.main.bundlePath, homeDirectory: NSHomeDirectory(),
            didApplyDefaultLoginItem: defaults.bool(forKey: Self.defaultAppliedKey)
        ) else { return }
        // Consume the default only at a stable install location. Never override a later opt-out.
        defaults.set(true, forKey: Self.defaultAppliedKey)
        if status == .notRegistered || status == .notFound { register() }
    }

    /// One menu item does everything: turn on, turn off, or open Login Items when macOS
    /// is waiting for approval. Any explicit choice also stops the first-run default.
    func toggle() {
        switch LoginItemPolicy.toggleAction(state: state, installedInApplications: isInstalled) {
        case .register:
            UserDefaults.standard.set(true, forKey: Self.defaultAppliedKey)
            register()
        case .unregister:
            UserDefaults.standard.set(true, forKey: Self.defaultAppliedKey)
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
