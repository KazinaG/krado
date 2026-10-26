import Testing
@testable import KradoCore

@Suite struct StatusMenuActivationTests {
    @Test func onlyMacOS26ActivatesBeforeOpening() {
        #expect(StatusMenuActivation.activatesBeforeOpening(macOS26OrLater: true))
        #expect(!StatusMenuActivation.activatesBeforeOpening(macOS26OrLater: false))
    }

    @Test func focusGoesBackOnlyWhenNothingOfKradoIsShowing() {
        #expect(StatusMenuActivation.returnsFocus(previousWasKrado: false, previousStillRunning: true, kradoWindowShowing: false, kradoStillActive: true))
        #expect(!StatusMenuActivation.returnsFocus(previousWasKrado: false, previousStillRunning: true, kradoWindowShowing: true, kradoStillActive: true))
        #expect(!StatusMenuActivation.returnsFocus(previousWasKrado: true, previousStillRunning: true, kradoWindowShowing: false, kradoStillActive: true))
        #expect(!StatusMenuActivation.returnsFocus(previousWasKrado: false, previousStillRunning: false, kradoWindowShowing: false, kradoStillActive: true))
        // Another app took focus after the menu closed (app switch, System Settings).
        #expect(!StatusMenuActivation.returnsFocus(previousWasKrado: false, previousStillRunning: true, kradoWindowShowing: false, kradoStillActive: false))
    }
}
