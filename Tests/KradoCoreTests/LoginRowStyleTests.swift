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

    @Test func titleAndStateWordShareOneInk() {
        #expect(LoginRowStyle.ink(highlighted: false, enabled: true) == .label)
        #expect(LoginRowStyle.ink(highlighted: true, enabled: true) == .selectedText)
        #expect(LoginRowStyle.ink(highlighted: false, enabled: false) == .disabled)
        // A disabled row never shows the selection ink, even if AppKit highlights it.
        #expect(LoginRowStyle.ink(highlighted: true, enabled: false) == .disabled)
    }

    @Test func rowFitsTheWidestStateWordWithoutOverlap() {
        let titleX = 39.0, titleWidth = 96.0
        let words = [28.0, 30.0, 48.0] // e.g. オン, オフ, 承認待ち
        let width = LoginRowLayout.width(titleX: titleX, titleWidth: titleWidth, stateWidths: words, minimum: 260)
        for word in words {
            let x = LoginRowLayout.stateX(rowMaxX: width, stateWidth: word)
            #expect(x >= titleX + titleWidth + LoginRowLayout.gap - 0.5)
            #expect(x + word <= width - LoginRowLayout.trailingInset + 0.5)
        }
        // A long title grows the row instead of colliding with the state word.
        let long = LoginRowLayout.width(titleX: titleX, titleWidth: 300, stateWidths: words, minimum: 260)
        #expect(long > 260)
        #expect(LoginRowLayout.stateX(rowMaxX: long, stateWidth: 48) >= titleX + 300 + LoginRowLayout.gap - 0.5)
    }

    @Test func stateWordIsRightAligned() {
        // Words of different widths end at the same trailing edge.
        let a = LoginRowLayout.stateX(rowMaxX: 300, stateWidth: 20) + 20
        let b = LoginRowLayout.stateX(rowMaxX: 300, stateWidth: 40) + 40
        #expect(abs(a - b) <= 1)
        #expect(abs(a - (300 - LoginRowLayout.trailingInset)) <= 1)
    }
}
