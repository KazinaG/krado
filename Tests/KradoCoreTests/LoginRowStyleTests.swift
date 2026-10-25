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

    @Test func titleAndIconShareOneInk() {
        #expect(LoginRowStyle.ink(highlighted: false, enabled: true) == .label)
        #expect(LoginRowStyle.ink(highlighted: true, enabled: true) == .selectedText)
        #expect(LoginRowStyle.ink(highlighted: false, enabled: false) == .disabled)
        // A disabled row never shows the selection ink, even if AppKit highlights it.
        #expect(LoginRowStyle.ink(highlighted: true, enabled: false) == .disabled)
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

    // Native selection shape, measured on Quit in CI login-hover (1x).
    @Test func selectionMatchesNativeRowShape() {
        #expect(LoginRowStyle.selectionHorizontalInset == 5)
        #expect(LoginRowStyle.selectionCornerRadius(macOS26OrLater: true) == 7)
        #expect(LoginRowStyle.selectionCornerRadius(macOS26OrLater: false) == 4)
    }

    @Test func switchUsesMiniAndReflectsRequestedLoginState() {
        #expect(LoginRowStyle.switchSize == .mini)
        #expect(LoginRowStyle.switchIsOn(for: .enabled))
        #expect(LoginRowStyle.switchIsOn(for: .needsApproval))
        #expect(!LoginRowStyle.switchIsOn(for: .disabled))
        #expect(!LoginRowStyle.switchIsOn(for: .unavailable))
    }
}
