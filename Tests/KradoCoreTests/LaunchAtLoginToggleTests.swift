import Testing
@testable import KradoCore

@Suite("Launch at Login menu toggle")
struct LaunchAtLoginToggleTests {
    @Test("Choosing the item turns it off, asks for approval, or turns it on")
    func actions() {
        #expect(LoginItemPolicy.toggleAction(state: .enabled, installedInApplications: true) == .unregister)
        #expect(LoginItemPolicy.toggleAction(state: .enabled, installedInApplications: false) == .unregister)
        #expect(LoginItemPolicy.toggleAction(state: .needsApproval, installedInApplications: true) == .openSettings)
        #expect(LoginItemPolicy.toggleAction(state: .disabled, installedInApplications: true) == .register)
        #expect(LoginItemPolicy.toggleAction(state: .unavailable, installedInApplications: true) == .register)
        #expect(LoginItemPolicy.toggleAction(state: .disabled, installedInApplications: false) == .moveToApplications)
    }

    @Test("A hint appears only when the user must do something")
    func hints() {
        #expect(LoginItemPolicy.hint(state: .enabled, installedInApplications: true) == nil)
        #expect(LoginItemPolicy.hint(state: .disabled, installedInApplications: true) == nil)
        #expect(LoginItemPolicy.hint(state: .needsApproval, installedInApplications: true) == .allowInSettings)
        #expect(LoginItemPolicy.hint(state: .disabled, installedInApplications: false) == .moveToApplications)
        #expect(LoginItemPolicy.hint(state: .unavailable, installedInApplications: false) == .moveToApplications)
    }
}
