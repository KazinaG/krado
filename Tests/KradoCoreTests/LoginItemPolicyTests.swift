import Testing
@testable import KradoCore

@Suite("Login item installation policy")
struct LoginItemPolicyTests {
    @Test("Only stable Applications paths can receive the first-run default", arguments: [
        LoginPathCase(path: "/Applications/krado.app", eligible: true),
        LoginPathCase(path: "/Applications/Utilities/krado.app", eligible: true),
        LoginPathCase(path: "/Users/test/Applications/krado.app", eligible: true),
        LoginPathCase(path: "/ApplicationsOther/krado.app", eligible: false),
        LoginPathCase(path: "/Users/test/ApplicationsOther/krado.app", eligible: false),
        LoginPathCase(path: "/Users/other/Applications/krado.app", eligible: false),
        LoginPathCase(path: "/Users/test/Downloads/krado.app", eligible: false),
        LoginPathCase(path: "/Volumes/krado/krado.app", eligible: false),
        LoginPathCase(path: "/private/var/folders/id/AppTranslocation/id/d/krado.app", eligible: false),
        LoginPathCase(path: "/Applications/AppTranslocation/id/krado.app", eligible: false),
        LoginPathCase(path: "/Applications/../Downloads/krado.app", eligible: false),
        LoginPathCase(path: "Applications/krado.app", eligible: false),
    ])
    func eligibility(test: LoginPathCase) {
        #expect(LoginItemPolicy.isInstalledInApplications(bundlePath: test.path, homeDirectory: "/Users/test") == test.eligible)
        #expect(LoginItemPolicy.shouldAutoRegister(
            bundlePath: test.path, homeDirectory: "/Users/test", didApplyDefaultLoginItem: false
        ) == test.eligible)
        #expect(!LoginItemPolicy.shouldAutoRegister(
            bundlePath: test.path, homeDirectory: "/Users/test", didApplyDefaultLoginItem: true
        ))
    }

    @Test("Moving to Applications preserves the unapplied default")
    func movedInstallation() {
        #expect(!LoginItemPolicy.shouldAutoRegister(
            bundlePath: "/Users/test/Downloads/krado.app", homeDirectory: "/Users/test", didApplyDefaultLoginItem: false
        ))
        #expect(LoginItemPolicy.shouldAutoRegister(
            bundlePath: "/Applications/krado.app", homeDirectory: "/Users/test", didApplyDefaultLoginItem: false
        ))
    }
}

struct LoginPathCase: Sendable {
    let path: String
    let eligible: Bool
}
