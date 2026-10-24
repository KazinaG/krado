import Testing
@testable import KradoCore

@Suite struct LoginRowStyleTests {
    @Test func highlightFollowsTheMenuItemOnly() {
        // One highlight in the menu: the row never lights up on its own.
        #expect(LoginRowStyle.isHighlighted(menuItemHighlighted: true, enabled: true))
        #expect(!LoginRowStyle.isHighlighted(menuItemHighlighted: false, enabled: true))
        #expect(!LoginRowStyle.isHighlighted(menuItemHighlighted: true, enabled: false))
        #expect(!LoginRowStyle.isHighlighted(menuItemHighlighted: false, enabled: false))
    }

    @Test(arguments: [false, true])
    func onAndOffDifferInShape(highlighted: Bool) {
        let on = LoginRowStyle.badge(state: .enabled, highlighted: highlighted, enabled: true)
        let off = LoginRowStyle.badge(state: .disabled, highlighted: highlighted, enabled: true)
        #expect(on.fill)
        #expect(on.showsCheckmark)
        #expect(!off.fill)
        #expect(!off.showsCheckmark)
        #expect(LoginRowStyle.badge(state: .unavailable, highlighted: highlighted, enabled: true) == off)
        #expect(off.pill == (highlighted ? .selectedText : .label))
        #expect(off.pillAlpha == (highlighted ? 1 : 0.45))
        #expect(off.text == (highlighted ? .selectedText : .secondaryLabel))
        if highlighted {
            #expect(on.pill == .white)
            #expect(on.pillAlpha == 1)
            #expect(on.text == .badgeInk)
            #expect(LoginRowStyle.contrast(LoginRowStyle.badgeInk, .white) >= 4.5)
            // Off uses the native selected text/background pairing; no computed contrast rule.
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
        #expect(approval.pillAlpha == 0.1)
        #expect(approval.text == (highlighted ? .selectedText : .label))
        for state in [LoginItemState.enabled, .disabled, .unavailable, .needsApproval] {
            let disabled = LoginRowStyle.badge(state: state, highlighted: highlighted, enabled: false)
            #expect(disabled.text == .disabled)
            #expect(disabled.fill == (state == .enabled || state == .needsApproval))
            #expect(disabled.showsCheckmark == (state == .enabled))
        }
    }

    @Test func contrastMatchesWCAG() {
        #expect(abs(LoginRowStyle.contrast(.white, .init(0, 0, 0)) - 21) < 0.01)
        #expect(abs(LoginRowStyle.contrast(.white, .white) - 1) < 0.0001)
    }
}
