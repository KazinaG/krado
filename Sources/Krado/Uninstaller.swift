import AppKit
import KradoCore
import ServiceManagement

/// "Uninstall krado…": removes what krado itself created, using only public APIs and the
/// current user's own rights (no sudo, no privileged helper).
@MainActor
enum Uninstaller {
    private static let bundleID = Bundle.main.bundleIdentifier ?? "io.github.kazinag.krado"
    private static let accessibilitySettings =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    struct Failure: Error {}

    static func confirmAndRun() {
        NSApp.activate(ignoringOtherApps: true)
        let confirm = NSAlert()
        confirm.messageText = L10n.text("Uninstall krado?")
        confirm.informativeText = L10n.text("krado will turn off Launch at Login, remove its Accessibility permission, settings and caches, move itself to the Trash, and quit.")
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: L10n.text("Uninstall"))
        confirm.addButton(withTitle: L10n.text("Cancel"))
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        let outcome = UninstallPlan.run(bundlePath: Bundle.main.bundlePath, perform: perform)
        if outcome.shouldOpenAccessibilitySettings {
            let alert = NSAlert()
            alert.messageText = L10n.text("krado could not finish uninstalling.")
            alert.informativeText = L10n.text("In System Settings → Privacy & Security → Accessibility, select krado and click −. Then remove krado in General → Login Items & Extensions and move krado.app to the Trash.")
            alert.addButton(withTitle: L10n.text("Open System Settings"))
            alert.runModal()
            if let url = URL(string: accessibilitySettings) { NSWorkspace.shared.open(url) }
        }
        if outcome.shouldQuit { NSApp.terminate(nil) }
    }

    private static func perform(_ step: UninstallStep) throws {
        let fileManager = FileManager.default
        let library = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        switch step {
        case .loginItem:
            let service = SMAppService.mainApp
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        case .accessibility:
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "Accessibility", bundleID]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw Failure() }
        case .preferences:
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        case .caches:
            for url in [
                library.appendingPathComponent("Caches/\(bundleID)"),
                library.appendingPathComponent("HTTPStorages/\(bundleID)"),
                library.appendingPathComponent("HTTPStorages/\(bundleID).binarycookies"),
            ] where fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        case .trashApp:
            try fileManager.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)
        }
    }
}
