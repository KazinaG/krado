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

    @Test func highlightedBadgeIsSolidWhiteWithDarkText() {
        let badge = LoginRowStyle.badge(highlighted: true, enabled: true)
        #expect(badge == .init(pill: .white, pillAlpha: 1, text: .badgeInk))
        // Independent of the accent colour and of Light/Dark: text sits on the opaque pill.
        #expect(LoginRowStyle.contrast(LoginRowStyle.badgeInk, .white) >= 4.5)
    }

    @Test func unhighlightedBadgeKeepsTheNativeLook() {
        #expect(LoginRowStyle.badge(highlighted: false, enabled: true) == .init(pill: .label, pillAlpha: 0.1, text: .label))
        #expect(LoginRowStyle.badge(highlighted: true, enabled: false).text == .disabled)
    }

    @Test func contrastMatchesWCAG() {
        #expect(abs(LoginRowStyle.contrast(.white, .init(0, 0, 0)) - 21) < 0.01)
        #expect(abs(LoginRowStyle.contrast(.white, .white) - 1) < 0.0001)
        // macOS's blue highlight (#0064E1) with white text, the system's own pairing.
        #expect(LoginRowStyle.contrast(.white, .init(0x00, 0x64, 0xE1)) > 4.5)
    }
}
