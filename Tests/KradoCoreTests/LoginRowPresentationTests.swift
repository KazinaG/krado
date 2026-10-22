import Testing
@testable import KradoCore

@Suite("Login row presentation")
struct LoginRowPresentationTests {
    @Test("All states and installation paths")
    func allStatesAndInstallationPaths() {
        let cases: [(LoginItemState, String)] = [
            (.enabled, "On"),
            (.disabled, "Off"),
            (.needsApproval, "Needs approval"),
            (.unavailable, "Off"),
        ]
        for (state, text) in cases {
            for installed in [true, false] {
                let row = LoginRowPresentation(state: state, installed: installed)
                #expect(row.title == "Launch at Login")
                #expect(row.stateText == text)
                #expect(row.badge == row.stateText)
                #expect(row.enabled == (installed || state == .enabled || state == .needsApproval))
            }
        }
    }
}
