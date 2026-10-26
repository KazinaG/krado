import Testing
@testable import KradoCore

@Suite struct StatusMenuActivationTests {
    @Test func onlyMacOS26ActivatesBeforeOpening() {
        #expect(StatusMenuActivation.activatesBeforeOpening(macOS26OrLater: true))
        #expect(!StatusMenuActivation.activatesBeforeOpening(macOS26OrLater: false))
    }

    @Test func focusGoesBackOnlyWhenNothingOfKradoIsShowing() {
        #expect(StatusMenuActivation.returnsFocus(previousWasKrado: false, previousStillRunning: true, kradoWindowShowing: false))
        #expect(!StatusMenuActivation.returnsFocus(previousWasKrado: false, previousStillRunning: true, kradoWindowShowing: true))
        #expect(!StatusMenuActivation.returnsFocus(previousWasKrado: true, previousStillRunning: true, kradoWindowShowing: false))
        #expect(!StatusMenuActivation.returnsFocus(previousWasKrado: false, previousStillRunning: false, kradoWindowShowing: false))
    }
}
