import Testing
@testable import KradoCore

private struct StepError: Error {}

@Suite("Uninstall plan")
struct UninstallPlanTests {
    private let installed = "/Applications/krado.app"

    @Test("Steps run in order and the app quits after it is trashed")
    func order() {
        var calls: [UninstallStep] = []
        let outcome = UninstallPlan.run(bundlePath: installed) { calls.append($0) }
        #expect(calls == [.loginItem, .accessibility, .preferences, .caches, .trashApp])
        #expect(outcome.succeeded)
        #expect(outcome.shouldQuit)
        #expect(!outcome.shouldOpenAccessibilitySettings)
    }

    @Test("A failed step keeps cleaning up, keeps the app, and opens Accessibility settings")
    func failureInMiddle() {
        var calls: [UninstallStep] = []
        let outcome = UninstallPlan.run(bundlePath: installed) { step in
            calls.append(step)
            if step == .accessibility { throw StepError() }
        }
        #expect(calls == [.loginItem, .accessibility, .preferences, .caches])
        #expect(outcome.failed == [.accessibility, .trashApp])
        #expect(outcome.completed == [.loginItem, .preferences, .caches])
        #expect(!outcome.shouldQuit)
        #expect(outcome.shouldOpenAccessibilitySettings)
    }

    @Test("Running from a disk image or App Translocation never trashes the bundle", arguments: [
        "/Volumes/krado/krado.app",
        "/private/var/folders/xy/AppTranslocation/ABC/d/krado.app",
        "relative/krado.app",
    ])
    func notTrashable(path: String) {
        var calls: [UninstallStep] = []
        let outcome = UninstallPlan.run(bundlePath: path) { calls.append($0) }
        #expect(!calls.contains(.trashApp))
        #expect(outcome.failed == [.trashApp])
        #expect(!outcome.shouldQuit)
        #expect(outcome.shouldOpenAccessibilitySettings)
    }

    @Test("A failure to trash is reported and the app stays open")
    func trashFails() {
        let outcome = UninstallPlan.run(bundlePath: installed) { step in
            if step == .trashApp { throw StepError() }
        }
        #expect(outcome.failed == [.trashApp])
        #expect(!outcome.shouldQuit)
    }

    @Test("Normal folders are trashable", arguments: [
        "/Applications/krado.app", "/Users/test/Applications/krado.app", "/Users/test/Desktop/krado.app",
    ])
    func trashable(path: String) {
        #expect(UninstallPlan.canTrashApp(bundlePath: path))
    }
}
