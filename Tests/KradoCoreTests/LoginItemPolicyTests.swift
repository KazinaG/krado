import Testing
@testable import KradoCore

@Suite("Login item installation policy")
struct LoginItemPolicyTests {
    @Test("Only stable Applications paths count as installed", arguments: [
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
    }

    @Test("Onboarding offers one-click Launch at Login only when it can be turned on", arguments: [
        OnboardingCase(state: .disabled, installed: true, offer: .turnOn),
        OnboardingCase(state: .unavailable, installed: true, offer: .turnOn),
        OnboardingCase(state: .disabled, installed: false, offer: .moveToApplications),
        OnboardingCase(state: .unavailable, installed: false, offer: .moveToApplications),
        OnboardingCase(state: .needsApproval, installed: true, offer: .openSettings),
        OnboardingCase(state: .needsApproval, installed: false, offer: .openSettings),
        OnboardingCase(state: .enabled, installed: true, offer: .alreadyOn),
        OnboardingCase(state: .enabled, installed: false, offer: .alreadyOn),
    ])
    func onboardingOffer(test: OnboardingCase) {
        #expect(LoginItemPolicy.onboardingOffer(state: test.state, installedInApplications: test.installed) == test.offer)
    }

    @Test("The onboarding button and the menu checkbox register the same way")
    func onboardingMatchesMenu() {
        for state in [LoginItemState.disabled, .unavailable] {
            let offer = LoginItemPolicy.onboardingOffer(state: state, installedInApplications: true)
            let action = LoginItemPolicy.toggleAction(state: state, installedInApplications: true)
            #expect(offer == .turnOn)
            #expect(action == .register)
        }
    }
}

struct LoginPathCase: Sendable {
    let path: String
    let eligible: Bool
}

struct OnboardingCase: Sendable {
    let state: LoginItemState
    let installed: Bool
    let offer: LoginOnboardingOffer
}
