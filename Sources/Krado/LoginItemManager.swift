import Foundation
import ServiceManagement
import KradoCore

@MainActor
final class LoginItemManager {
    private static let defaultAppliedKey = "didApplyDefaultLoginItem"
    private(set) var errorMessage: String?
    var status: SMAppService.Status { SMAppService.mainApp.status }
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

    func toggle() {
        // An explicit choice also prevents a later launch from undoing an opt-out.
        if status == .enabled || status == .requiresApproval {
            UserDefaults.standard.set(true, forKey: Self.defaultAppliedKey)
            do {
                try SMAppService.mainApp.unregister()
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        } else if isInstalled {
            UserDefaults.standard.set(true, forKey: Self.defaultAppliedKey)
            register()
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
