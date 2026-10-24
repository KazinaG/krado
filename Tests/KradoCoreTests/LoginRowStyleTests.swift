import Testing
@testable import KradoCore

@Suite struct LoginRowStyleTests {
    @Test func highlightFollowsAppKitUntilAClick() {
        let highlight = LoginRowStyle.Highlight()
        #expect(highlight.isHighlighted(menuItemHighlighted: true, enabled: true))
        #expect(!highlight.isHighlighted(menuItemHighlighted: false, enabled: true))
        #expect(!highlight.isHighlighted(menuItemHighlighted: true, enabled: false))
    }

    @Test func clickStaysHighlightedAcrossAppKitMouseUpReset() {
        var highlight = LoginRowStyle.Highlight()
        highlight.menuWillHighlight(thisRow: true)
        highlight.clickedInside()
        highlight.menuWillHighlight(thisRow: nil)
        #expect(highlight.pointerInsideSinceClick)
        #expect(highlight.isHighlighted(menuItemHighlighted: false, enabled: true))
        #expect(!highlight.isHighlighted(menuItemHighlighted: false, enabled: false))
        highlight.mouseExited()
        #expect(!highlight.isHighlighted(menuItemHighlighted: false, enabled: true))
    }

    @Test func anotherItemWinsEvenWithPointerStillInsideAndStaleAppKitBit() {
        var highlight = LoginRowStyle.Highlight()
        highlight.clickedInside()
        highlight.menuWillHighlight(thisRow: false)
        #expect(!highlight.pointerInsideSinceClick)
        #expect(!highlight.isHighlighted(menuItemHighlighted: true, enabled: true))
        highlight.menuWillHighlight(thisRow: nil)
        #expect(!highlight.isHighlighted(menuItemHighlighted: false, enabled: true))
        highlight.menuWillHighlight(thisRow: true)
        #expect(highlight.isHighlighted(menuItemHighlighted: true, enabled: true))
        #expect(!highlight.isHighlighted(menuItemHighlighted: false, enabled: true))
    }

    @Test func closingAndReopeningCannotReviveAClickHighlight() {
        var highlight = LoginRowStyle.Highlight()
        highlight.clickedInside()
        highlight.menuDidClose()
        #expect(!highlight.pointerInsideSinceClick)
        #expect(!highlight.isHighlighted(menuItemHighlighted: true, enabled: true))
        highlight.menuWillHighlight(thisRow: nil)
        #expect(!highlight.isHighlighted(menuItemHighlighted: false, enabled: true))
        highlight.menuWillHighlight(thisRow: true)
        #expect(highlight.isHighlighted(menuItemHighlighted: true, enabled: true))
    }

    @Test(arguments: [false, true])
    func onAndOffBadgeStyles(highlighted: Bool) {
        let on = LoginRowStyle.badge(state: .enabled, highlighted: highlighted, enabled: true)
        let off = LoginRowStyle.badge(state: .disabled, highlighted: highlighted, enabled: true)
        #expect(on.fill)
        #expect(on.showsCheckmark)
        #expect(on.symbolName == "checkmark")
        #expect(off.fill == highlighted)
        #expect(!off.showsCheckmark)
        #expect(off.symbolName == nil)
        #expect(LoginRowStyle.badge(state: .unavailable, highlighted: highlighted, enabled: true) == off)
        #expect(off.pill == (highlighted ? .black : .label))
        #expect(off.pillAlpha == (highlighted ? 0.4 : 0.45))
        #expect(off.ring == (highlighted ? .white : .label))
        #expect(off.ringAlpha == (highlighted ? 1 : 0.45))
        #expect(on.ring == nil)
        #expect(off.text == (highlighted ? .white : .secondaryLabel))
        if highlighted {
            #expect(on.pill == .white)
            #expect(on.pillAlpha == 1)
            #expect(on.text == .badgeInk)
            #expect(LoginRowStyle.contrast(LoginRowStyle.badgeInk, .white) >= 3)
        } else {
            #expect(on.pill == .label)
            #expect(on.pillAlpha == 0.14)
            #expect(on.text == .label)
        }
    }

    @Test(arguments: [false, true])
    func approvalAndDisabledStates(highlighted: Bool) {
        let approval = LoginRowStyle.badge(state: .needsApproval, highlighted: highlighted, enabled: true)
        #expect(approval.fill)
        #expect(!approval.showsCheckmark)
        #expect(approval.symbolName == "exclamationmark")
        #expect(approval.pillAlpha == 0.1)
        #expect(approval.text == (highlighted ? .selectedText : .label))
        for state in [LoginItemState.enabled, .disabled, .unavailable, .needsApproval] {
            let disabled = LoginRowStyle.badge(state: state, highlighted: highlighted, enabled: false)
            #expect(disabled.text == .disabled)
            #expect(disabled.fill == (state == .enabled || state == .needsApproval))
            #expect(disabled.showsCheckmark == (state == .enabled))
            #expect(disabled.ring == (state == .disabled || state == .unavailable ? .label : nil))
            #expect(disabled.ringAlpha == 0.1)
        }
    }

    @Test func highlightedOffRingContrastsWithInnerFillAcrossAccents() {
        // The boundary is measured against the recessed fill, never the accent.
        let accents: [LoginRowStyle.RGB] = [.init(0, 122, 255), .init(255, 204, 0),
                                            .init(142, 142, 147), .init(255, 45, 85)]
        for accent in accents {
            let fill = LoginRowStyle.composite(.init(0, 0, 0), alpha: 0.4, over: accent)
            #expect(LoginRowStyle.contrast(.white, fill) >= 3)
        }
    }

    @Test func unhighlightedOnCheckContrastsWithFaintCircle() {
        for (label, background) in [(LoginRowStyle.RGB(0, 0, 0), LoginRowStyle.RGB(246, 246, 246)),
                                    (.white, .init(38, 38, 38))] {
            let fill = LoginRowStyle.composite(label, alpha: 0.14, over: background)
            #expect(LoginRowStyle.contrast(label, fill) >= 3)
        }
    }

    @Test func offRingPreservesFaintAlphaOrFallsBackToFullLabelInk() {
        let background = LoginRowStyle.RGB(240, 240, 240)
        #expect(LoginRowStyle.offRingAlpha(label: .init(0, 0, 0), background: background) == 0.45)
        #expect(LoginRowStyle.offRingAlpha(label: .white, background: .init(38, 38, 38)) == 0.45)
        for label in [LoginRowStyle.RGB(60, 60, 60), .init(180, 180, 180)] {
            let alpha = LoginRowStyle.offRingAlpha(label: label, background: background)
            #expect(alpha == 1)
            let target = min(3, LoginRowStyle.contrast(label, background))
            #expect(LoginRowStyle.contrast(LoginRowStyle.composite(label, alpha: alpha, over: background), background) >= target)
            let off = LoginRowStyle.badge(state: .disabled, highlighted: false, enabled: true, offRingAlpha: alpha)
            #expect(!off.fill)
            #expect(off.ring == .label)
            #expect(off.ringAlpha == alpha)
        }
        // A native label below 3:1 sets the target; do not demand stronger ink.
        #expect(LoginRowStyle.offRingAlpha(label: .init(0, 0, 0), labelAlpha: 0.3, background: background) == 0.45)
    }

    @Test func contrastMatchesWCAG() {
        #expect(abs(LoginRowStyle.contrast(.white, .init(0, 0, 0)) - 21) < 0.01)
        #expect(abs(LoginRowStyle.contrast(.white, .white) - 1) < 0.0001)
    }
}
