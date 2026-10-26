import Testing
@testable import KradoCore

@Suite struct LoginRowStyleTests {
    @Test func titleAndIconShareOneInkAndNeverUseSelectionInk() {
        #expect(LoginRowStyle.ink(enabled: true) == .label)
        #expect(LoginRowStyle.ink(enabled: false) == .disabled)
    }

    @Test func rowFitsSwitchWithoutOverlap() {
        let titleX = 39.0, titleWidth = 96.0
        let widths = [28.0, 30.0, 48.0] // Representative fitting widths.
        let rowWidth = LoginRowLayout.width(titleX: titleX, titleWidth: titleWidth, switchWidth: widths.max()!, minimum: 260)
        #expect(rowWidth >= 260)
        for switchWidth in widths {
            let x = LoginRowLayout.switchX(rowMaxX: rowWidth, switchWidth: switchWidth)
            #expect(x >= titleX + titleWidth + LoginRowLayout.gap - 0.5)
            #expect(x + switchWidth <= rowWidth - LoginRowLayout.trailingInset + 0.5)
        }
        // A long title grows the row instead of colliding with the switch.
        let long = LoginRowLayout.width(titleX: titleX, titleWidth: 300, switchWidth: widths.max()!, minimum: 260)
        #expect(long > 260)
        #expect(LoginRowLayout.switchX(rowMaxX: long, switchWidth: 48) >= titleX + 300 + LoginRowLayout.gap - 0.5)
    }

    @Test func switchIsRightAligned() {
        // Switches of different widths end at the same trailing edge.
        let a = LoginRowLayout.switchX(rowMaxX: 300, switchWidth: 20) + 20
        let b = LoginRowLayout.switchX(rowMaxX: 300, switchWidth: 40) + 40
        #expect(a == b)
        #expect(a == 300 - LoginRowLayout.trailingInset)
    }

    @Test func switchUsesMiniAndReflectsRequestedLoginState() {
        #expect(LoginRowStyle.switchSize == .mini)
        #expect(LoginRowStyle.switchIsOn(for: .enabled))
        #expect(LoginRowStyle.switchIsOn(for: .needsApproval))
        #expect(!LoginRowStyle.switchIsOn(for: .disabled))
        #expect(!LoginRowStyle.switchIsOn(for: .unavailable))
    }

    /// Maintainer 2026-10-26 17:16/17:17: only the switch can be pressed, the row never
    /// lights up, and on/off, pressed, focus and disabled must all look different.
    @Test func everySwitchStateLooksDifferentAndTheRowNeverHighlights() {
        enum Kind: CaseIterable { case normal, pressed, focus, disabled }
        var looks: [LoginRowStyle.SwitchLook] = []
        for state in [LoginItemState.disabled, .enabled] {
            for kind in Kind.allCases {
                let look = LoginRowStyle.switchLook(state: state, enabled: kind != .disabled,
                                                    pressed: kind == .pressed, keyboardFocused: kind == .focus)
                #expect(!look.rowHighlight)
                #expect(look.isOn == (state == .enabled))
                #expect(look.pressed == (kind == .pressed))
                #expect(look.focusRing == (kind == .focus))
                #expect(look.isEnabled == (kind != .disabled))
                #expect(look.titleInk == (kind == .disabled ? .disabled : .label))
                looks.append(look)
            }
        }
        // Needs approval keeps the switch on (the user asked for it) and adds the hint row.
        let approval = LoginRowStyle.switchLook(state: .needsApproval, enabled: true, pressed: false, keyboardFocused: false)
        #expect(approval.isOn && approval.approvalHint && !approval.rowHighlight)
        looks.append(approval)
        #expect(Set(looks).count == looks.count)
    }

    @Test func aDisabledSwitchShowsNeitherPressNorFocus() {
        let look = LoginRowStyle.switchLook(state: .enabled, enabled: false, pressed: true, keyboardFocused: true)
        #expect(!look.pressed && !look.focusRing && !look.isEnabled)
    }

    @Test func focusRingOnlyForKeyboardSelection() {
        var focus = LoginRowStyle.KeyboardFocus()
        focus.menuWillHighlight(thisRow: true, byKeyboard: false)
        #expect(!focus.isFocused) // pointer hover
        focus.menuWillHighlight(thisRow: true, byKeyboard: true)
        #expect(focus.isFocused)
        focus.menuWillHighlight(thisRow: nil, byKeyboard: false)
        #expect(!focus.isFocused) // AppKit cleared the selection
        focus.menuWillHighlight(thisRow: true, byKeyboard: true)
        focus.menuWillHighlight(thisRow: false, byKeyboard: true)
        #expect(!focus.isFocused) // keyboard moved on
        focus.menuWillHighlight(thisRow: true, byKeyboard: true)
        focus.menuDidClose()
        #expect(!focus.isFocused)
    }
}
