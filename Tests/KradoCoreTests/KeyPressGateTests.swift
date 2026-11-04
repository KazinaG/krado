import Testing
@testable import KradoCore

/// Sequences the login row's key tap sees: one toggle per physical press.
@Suite struct KeyPressGateTests {
    /// Drives the gate like LoginRowView.keyTapEvent and counts toggles.
    private struct Tap {
        var gate = KeyPressGate()
        var toggles = 0
        var handles = true
        mutating func down(_ time: UInt64, isRepeat: Bool = false) {
            guard gate.admit(isRepeat: isRepeat, time: time) else { return }
            if handles { toggles += 1; gate.handled() }
        }
        mutating func up() { gate.keyUp() }
    }

    @Test func onePressTogglesOnce() {
        var tap = Tap()
        tap.down(100); tap.up()
        #expect(tap.toggles == 1)
        #expect(tap.gate.armed)
    }

    @Test func theSameKeyDownDeliveredTwiceTogglesOnce() {
        var tap = Tap()
        tap.down(100); tap.down(100); tap.up(); tap.up()
        #expect(tap.toggles == 1)
    }

    @Test func autoRepeatWhileHeldDoesNotToggleAgain() {
        var tap = Tap()
        tap.down(100); tap.down(200, isRepeat: true); tap.down(300, isRepeat: true); tap.up()
        #expect(tap.toggles == 1)
    }

    @Test func aSecondKeyDownBeforeKeyUpDoesNotToggle() {
        var tap = Tap()
        tap.down(100); tap.down(200)
        #expect(tap.toggles == 1)
        #expect(!tap.gate.armed)
    }

    @Test func twoPressesToggleTwice() {
        var tap = Tap()
        tap.down(100); tap.up(); tap.down(200); tap.up()
        #expect(tap.toggles == 2)
    }

    @Test func anUnhandledKeyLeavesTheGateArmed() {
        var tap = Tap()
        tap.handles = false
        tap.down(100)
        #expect(tap.toggles == 0)
        #expect(tap.gate.armed)
        #expect(tap.gate.lastKeyDownTime == 100)
        // The duplicate of that key down is still dropped; a new one may act.
        tap.handles = true
        tap.down(100)
        #expect(tap.toggles == 0)
        tap.down(200)
        #expect(tap.toggles == 1)
    }

    @Test func rearmLetsTheNextPressActAfterAReinstall() {
        var tap = Tap()
        tap.down(100)
        #expect(!tap.gate.armed)
        tap.gate.rearm()
        tap.down(200)
        #expect(tap.toggles == 2)
    }

    @Test func aDisarmedGateRemembersOnlyAdmittedTimes() {
        var tap = Tap()
        tap.down(100); tap.down(200)
        #expect(tap.gate.lastKeyDownTime == 100)
    }
}
