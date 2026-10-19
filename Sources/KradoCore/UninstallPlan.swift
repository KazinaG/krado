import Foundation

/// The uninstall steps, in the order they run. Pure orchestration: the app supplies the
/// side effects, so ordering and failure handling are tested without touching the system.
public enum UninstallStep: String, CaseIterable, Sendable {
    /// SMAppService.mainApp.unregister(), skipped when not registered.
    case loginItem
    /// `/usr/bin/tccutil reset Accessibility io.github.kazinag.krado` for the current user.
    case accessibility
    /// UserDefaults.removePersistentDomain(forName:) for krado's domain (Sparkle keys included).
    case preferences
    /// ~/Library/Caches/<bundle id> (Sparkle downloads and staging) and ~/Library/HTTPStorages/<bundle id>.
    case caches
    /// Move krado.app to the Trash.
    case trashApp
}

public struct UninstallOutcome: Equatable, Sendable {
    public var completed: [UninstallStep] = []
    public var failed: [UninstallStep] = []

    public var succeeded: Bool { failed.isEmpty }
    /// Quit once the app itself is gone; otherwise stay so the user can read the message.
    public var shouldQuit: Bool { completed.contains(.trashApp) }
    /// On any failure, open Privacy & Security → Accessibility so the user can remove krado with −.
    public var shouldOpenAccessibilitySettings: Bool { !failed.isEmpty }
}

public enum UninstallPlan {
    /// A bundle can be trashed from a normal folder, not from a disk image or App Translocation.
    public static func canTrashApp(bundlePath: String) -> Bool {
        let path = (bundlePath as NSString).standardizingPath
        return path.hasPrefix("/") && path.hasSuffix(".app")
            && !path.contains("/AppTranslocation/") && !path.hasPrefix("/Volumes/")
    }

    /// Runs every step in order. A failed step does not stop the cleanup of the others,
    /// except that the app is not trashed when an earlier step failed (so the user can retry
    /// from the app) or when the bundle cannot be trashed from where it runs.
    public static func run(bundlePath: String, perform: (UninstallStep) throws -> Void) -> UninstallOutcome {
        var outcome = UninstallOutcome()
        for step in UninstallStep.allCases {
            if step == .trashApp && (!outcome.failed.isEmpty || !canTrashApp(bundlePath: bundlePath)) {
                outcome.failed.append(step)
                continue
            }
            do {
                try perform(step)
                outcome.completed.append(step)
            } catch {
                outcome.failed.append(step)
            }
        }
        return outcome
    }
}
