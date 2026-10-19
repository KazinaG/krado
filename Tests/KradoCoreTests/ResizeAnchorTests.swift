import Foundation
import Testing
@testable import KradoCore

@Suite("Keyboard grow and shrink with an anchor zone")
struct ResizeAnchorTests {
    let grid = GridGeometry(workArea: CGRect(x: 0, y: 0, width: 1200, height: 800), layout: GridLayout(columns: 4, rows: 2))
    var screens: [NavigationScreen] { [NavigationScreen(geometry: grid)] }

    private func span(_ columns: Range<Int>, _ rows: Range<Int> = 0..<1) -> GridSpan {
        GridSpan(columns: columns, rows: rows)
    }

    private func press(_ current: GridSpan, _ direction: Direction, anchor: ResizeAnchor?) -> ResizeStep? {
        ZoneNavigator.resize(windowFrame: grid.frame(for: current), screens: screens, direction: direction, anchor: anchor)
    }

    @Test("The first grow remembers the starting zone as the anchor")
    func firstGrowSetsAnchor() {
        let step = press(span(1..<2), .right, anchor: nil)
        #expect(step?.target == NavigationTarget(screenIndex: 0, span: span(1..<3)))
        #expect(step?.anchor == ResizeAnchor(screenIndex: 0, span: span(1..<2)))
    }

    @Test("Further grows keep the original anchor")
    func growKeepsAnchor() {
        let anchor = ResizeAnchor(screenIndex: 0, span: span(1..<2))
        let step = press(span(1..<3), .right, anchor: anchor)
        #expect(step?.target.span == span(1..<4))
        #expect(step?.anchor == anchor)
    }

    @Test("The opposite arrow shrinks back one zone per press, never past the anchor")
    func shrinkBackToAnchor() {
        let anchor = ResizeAnchor(screenIndex: 0, span: span(1..<2))
        let first = press(span(1..<4), .left, anchor: anchor)
        #expect(first?.target.span == span(1..<3))
        #expect(first?.anchor == anchor)
        let second = press(span(1..<3), .left, anchor: anchor)
        #expect(second?.target.span == span(1..<2))
        // Back at the anchor: the arrow grows on its own side again instead of shrinking further.
        let third = press(span(1..<2), .left, anchor: anchor)
        #expect(third?.target.span == span(0..<2))
        #expect(third?.anchor == anchor)
    }

    @Test("Shrinking works in every direction", arguments: Direction.allCases)
    func shrinkEachDirection(direction: Direction) {
        let (anchorSpan, grown): (GridSpan, GridSpan) = switch direction {
        case .left: (span(1..<2, 0..<2), span(1..<3, 0..<2))
        case .right: (span(2..<3, 0..<2), span(1..<3, 0..<2))
        case .up: (span(0..<4, 0..<1), span(0..<4, 0..<2))
        case .down: (span(0..<4, 1..<2), span(0..<4, 0..<2))
        }
        let anchor = ResizeAnchor(screenIndex: 0, span: anchorSpan)
        let step = press(grown, direction, anchor: anchor)
        #expect(step?.target.span == anchorSpan)
        #expect(step?.anchor == anchor)
    }

    @Test("Growing on both sides shrinks only the side the arrow points away from")
    func shrinkAfterGrowingBothWays() {
        let anchor = ResizeAnchor(screenIndex: 0, span: span(1..<2))
        // Grown right to 3, then left to 0; Right now pulls in the left edge first.
        #expect(press(span(0..<3), .right, anchor: anchor)?.target.span == span(1..<3))
        #expect(press(span(0..<3), .left, anchor: anchor)?.target.span == span(0..<2))
    }

    @Test("Without an anchor the arrow grows, matching the previous behaviour")
    func noAnchorGrows() {
        #expect(press(span(1..<3), .left, anchor: nil)?.target.span == span(0..<3))
        #expect(press(span(1..<3), .left, anchor: nil)?.target.span
            == ZoneNavigator.target(windowFrame: grid.frame(for: span(1..<3)), screens: screens, direction: .left, extend: true)?.span)
    }

    @Test("A stale anchor outside the window's span is replaced")
    func staleAnchorReplaced() {
        let stale = ResizeAnchor(screenIndex: 0, span: span(3..<4))
        let step = press(span(0..<2), .left, anchor: stale)
        #expect(step == nil) // at the left edge with no valid anchor: nothing to do
        let grow = press(span(0..<2), .right, anchor: stale)
        #expect(grow?.target.span == span(0..<3))
        #expect(grow?.anchor == ResizeAnchor(screenIndex: 0, span: span(0..<2)))
    }

    @Test("An anchor from another screen is ignored")
    func otherScreenAnchorIgnored() {
        let other = ResizeAnchor(screenIndex: 1, span: span(1..<2))
        let step = press(span(1..<3), .left, anchor: other)
        #expect(step?.target.span == span(0..<3))
        #expect(step?.anchor == ResizeAnchor(screenIndex: 0, span: span(1..<3)))
    }

    @Test("Growing at the screen edge without an anchor does nothing")
    func edgeWithoutAnchor() {
        #expect(press(span(3..<4), .right, anchor: nil) == nil)
    }

    @Test("An unaligned window grows from its centre zone, which becomes the anchor")
    func unalignedWindowGrowsFromCentreCell() {
        let frame = CGRect(x: 320, y: 40, width: 200, height: 200) // centre in column 1, row 0
        let step = ZoneNavigator.resize(windowFrame: frame, screens: screens, direction: .right,
                                        anchor: ResizeAnchor(screenIndex: 0, span: span(0..<1)))
        #expect(step?.target.span == span(1..<3))
        #expect(step?.anchor == ResizeAnchor(screenIndex: 0, span: span(1..<2)))
    }

    @Test("An unaligned window at the edge is only aligned and remembers nothing")
    func unalignedAtEdgeOnlyAligns() {
        let frame = CGRect(x: 1000, y: 40, width: 150, height: 200) // centre in column 3
        let step = ZoneNavigator.resize(windowFrame: frame, screens: screens, direction: .right, anchor: nil)
        #expect(step?.target.span == span(3..<4))
        #expect(step?.anchor == nil)
    }

    @Test("Frames match within the tolerance only")
    func framesMatch() {
        let frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        #expect(ZoneNavigator.framesMatch(frame, frame.offsetBy(dx: 1.5, dy: -1)))
        #expect(!ZoneNavigator.framesMatch(frame, frame.offsetBy(dx: 3, dy: 0)))
        #expect(!ZoneNavigator.framesMatch(frame, CGRect(x: 100, y: 100, width: 300, height: 197)))
    }
}
