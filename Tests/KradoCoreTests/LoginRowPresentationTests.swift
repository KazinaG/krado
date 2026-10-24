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
                #expect(LoginRowPresentation.allStateTexts.contains(row.stateText))
                #expect(row.enabled == (installed || state == .enabled || state == .needsApproval))
            }
        }
    }

    @Test("On and Off are different words, and the menu stays open on toggle")
    func onAndOffReadAsText() {
        let on = LoginRowPresentation(state: .enabled, installed: true).stateText
        let off = LoginRowPresentation(state: .disabled, installed: true).stateText
        #expect(on != off)
        #expect(LoginRowPresentation.keepsMenuOpenOnToggle)
    }
}
