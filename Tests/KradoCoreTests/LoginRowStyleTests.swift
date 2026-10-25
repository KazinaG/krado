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

    // Kazina 10/26 01:53: the state word sits in a capsule, filled only when On.
    @Test func onlyOnIsSolid() {
        for style in LoginRowStyle.OffStyle.allCases {
            for highlighted in [false, true] {
                #expect(LoginRowStyle.capsule(state: .enabled, highlighted: highlighted, enabled: true, offStyle: style).isSolid)
                for state in [LoginItemState.disabled, .unavailable, .needsApproval] {
                    for enabled in [true, false] {
                        let capsule = LoginRowStyle.capsule(state: state, highlighted: highlighted, enabled: enabled, offStyle: style)
                        #expect(!capsule.isSolid, "\(style) \(state) highlighted=\(highlighted) enabled=\(enabled)")
                        // Something must still draw the capsule.
                        #expect(capsule.ring != nil || capsule.fill != nil)
                    }
                }
            }
        }
    }

    @Test func shippedOffIsOutlineOnly() {
        #expect(LoginRowStyle.shippedOffStyle == .outline)
        for highlighted in [false, true] {
            let off = LoginRowStyle.capsule(state: .disabled, highlighted: highlighted, enabled: true)
            #expect(off.fill == nil)
            #expect(off.ring == LoginRowStyle.ink(highlighted: highlighted, enabled: true))
            #expect(off.text == LoginRowStyle.ink(highlighted: highlighted, enabled: true))
        }
    }

    @Test func onCapsuleTextStaysLegibleWhileHighlighted() {
        let on = LoginRowStyle.capsule(state: .enabled, highlighted: true, enabled: true)
        #expect(on.fill == .selectedText)
        #expect(on.text == .badgeInk)
        #expect(LoginRowStyle.contrast(LoginRowStyle.badgeInk, LoginRowStyle.RGB(255, 255, 255)) >= 4.5)
        let resting = LoginRowStyle.capsule(state: .enabled, highlighted: false, enabled: true)
        #expect(resting.fill == .label)
        #expect(resting.text == .onFillText)
    }

    @Test func faintFillsStayFaint() {
        #expect(LoginRowStyle.faintFillAlpha < 0.5)
        #expect(LoginRowStyle.faintFillAlphaHighlighted < 0.5)
    }

    // Native selection shape, measured on Quit in CI login-hover (1x).
    @Test func selectionMatchesNativeRowShape() {
        #expect(LoginRowStyle.selectionHorizontalInset == 5)
        #expect(LoginRowStyle.selectionCornerRadius(macOS26OrLater: true) == 7)
        #expect(LoginRowStyle.selectionCornerRadius(macOS26OrLater: false) == 4)
    }

    @Test func onAndOffShareOneCapsuleWidth() {
        let onOff = [20.0, 21.5]
        let on = LoginBadgeMetrics.capsuleWidth(textWidth: 20, onOffTextWidths: onOff)
        let off = LoginBadgeMetrics.capsuleWidth(textWidth: 21.5, onOffTextWidths: onOff)
        #expect(on == off)
        #expect(on >= 21.5 + 2 * LoginBadgeMetrics.horizontalPadding)
        let approval = LoginBadgeMetrics.capsuleWidth(textWidth: 40, onOffTextWidths: onOff)
        #expect(approval >= 40 + 2 * LoginBadgeMetrics.horizontalPadding)
        #expect(LoginBadgeMetrics.capsuleWidth(textWidth: 4, onOffTextWidths: [4]) >= LoginBadgeMetrics.height * 2)
        #expect(abs(LoginBadgeMetrics.textX(capsuleMinX: 100, capsuleWidth: 40, textWidth: 20) - 110) < 0.01)
        #expect(LoginRowPresentation.onOffTexts.allSatisfy { LoginRowPresentation.allStateTexts.contains($0) })
    }
}

