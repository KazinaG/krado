import Foundation
import Testing
@testable import KradoCore

@Suite("Keyboard zone navigation")
struct ZoneNavigatorTests {
    let grid = GridGeometry(workArea: CGRect(x: 0, y: 0, width: 1200, height: 800), layout: GridLayout(columns: 4, rows: 2))

    @Test(arguments: [UInt32(123), 124, 125, 126, 0, 127])
    func keyCodes(code: UInt32) {
        let expected: [UInt32: Direction] = [123: .left, 124: .right, 125: .down, 126: .up]
        #expect(Direction(keyCode: code) == expected[code])
    }

    @Test(arguments: Direction.allCases)
    func moveAndExtend(direction: Direction) {
        let span: GridSpan
        let moved: GridSpan
        let grown: GridSpan
        switch direction {
        case .left:
            span = GridSpan(columns: 1..<3, rows: 0..<2)
            moved = GridSpan(columns: 0..<2, rows: 0..<2)
            grown = GridSpan(columns: 0..<3, rows: 0..<2)
        case .right:
            span = GridSpan(columns: 1..<3, rows: 0..<2)
            moved = GridSpan(columns: 2..<4, rows: 0..<2)
            grown = GridSpan(columns: 1..<4, rows: 0..<2)
        case .up:
            span = GridSpan(columns: 0..<4, rows: 1..<2)
            moved = GridSpan(columns: 0..<4, rows: 0..<1)
            grown = GridSpan(columns: 0..<4, rows: 0..<2)
        case .down:
            span = GridSpan(columns: 0..<4, rows: 0..<1)
            moved = GridSpan(columns: 0..<4, rows: 1..<2)
            grown = GridSpan(columns: 0..<4, rows: 0..<2)
        }
        let screens = [NavigationScreen(geometry: grid)]
        #expect(ZoneNavigator.target(windowFrame: grid.frame(for: span), screens: screens, direction: direction)?.span == moved)
        #expect(ZoneNavigator.target(windowFrame: grid.frame(for: span), screens: screens, direction: direction, extend: true)?.span == grown)
    }

    @Test(arguments: Direction.allCases)
    func edgesNoOp(direction: Direction) {
        let screens = [NavigationScreen(geometry: grid)]
        #expect(ZoneNavigator.target(windowFrame: grid.workArea, screens: screens, direction: direction) == nil)
        #expect(ZoneNavigator.target(windowFrame: grid.workArea, screens: screens, direction: direction, extend: true) == nil)
    }

    @Test func unalignedAndExactBoundary() {
        let screens = [NavigationScreen(geometry: grid)]
        // Centre is exactly on an internal boundary: keyboard still picks ONE cell.
        let frame = CGRect(x: 250, y: 100, width: 100, height: 100)
        #expect(ZoneNavigator.target(windowFrame: frame, screens: screens, direction: .left)?.span == GridSpan(columns: 1..<2, rows: 0..<1))
        #expect(ZoneNavigator.target(windowFrame: frame, screens: screens, direction: .left, extend: true)?.span == GridSpan(columns: 0..<2, rows: 0..<1))
        let edge = CGRect(x: 1100, y: 100, width: 100, height: 100)
        #expect(ZoneNavigator.target(windowFrame: edge, screens: screens, direction: .right, extend: true)?.span == GridSpan(columns: 3..<4, rows: 0..<1))
    }

    @Test func edgeTolerance() {
        let span = GridSpan(columns: 1..<3, rows: 0..<1)
        let frame = grid.frame(for: span)
        let screens = [NavigationScreen(geometry: grid)]
        #expect(ZoneNavigator.target(windowFrame: frame.insetBy(dx: 2, dy: 2), screens: screens, direction: .right)?.span == GridSpan(columns: 2..<4, rows: 0..<1))
        #expect(ZoneNavigator.target(windowFrame: frame.insetBy(dx: 2.1, dy: 2.1), screens: screens, direction: .right)?.span == GridSpan(columns: 2..<3, rows: 0..<1))
    }

    @Test(arguments: [Direction.left, .right, .up, .down])
    func adjacentScreens(direction: Direction) {
        let area: CGRect
        let source: GridSpan
        let expected: GridSpan
        switch direction {
        case .left:
            area = CGRect(x: -1000, y: 100, width: 900, height: 800)
            source = GridSpan(columns: 0..<2, rows: 1..<2)
            expected = GridSpan(columns: 2..<3, rows: 1..<2)
        case .right:
            area = CGRect(x: 1250, y: 100, width: 900, height: 800)
            source = GridSpan(columns: 2..<4, rows: 1..<2)
            expected = GridSpan(columns: 0..<1, rows: 1..<2)
        case .up:
            area = CGRect(x: 0, y: -900, width: 900, height: 800)
            source = GridSpan(columns: 2..<4, rows: 0..<1)
            expected = GridSpan(columns: 2..<3, rows: 1..<2)
        case .down:
            area = CGRect(x: 0, y: 900, width: 900, height: 800)
            source = GridSpan(columns: 0..<2, rows: 1..<2)
            expected = GridSpan(columns: 1..<2, rows: 0..<1)
        }
        let destination = GridGeometry(workArea: area, layout: GridLayout(columns: 3, rows: 2))
        let screens = [NavigationScreen(geometry: grid), NavigationScreen(geometry: destination)]
        let result = ZoneNavigator.target(windowFrame: grid.frame(for: source), screens: screens, direction: direction)
        #expect(result?.screenIndex == 1)
        #expect(result?.span == expected)
        #expect(ZoneNavigator.target(windowFrame: grid.frame(for: source), screens: screens, direction: direction, extend: true) == nil)
    }

    @Test func adjacencyRequiresOverlapAndChoosesNearest() {
        let distant = GridGeometry(workArea: CGRect(x: 2400, y: 0, width: 1200, height: 800), layout: grid.layout)
        let diagonal = GridGeometry(workArea: CGRect(x: 1200, y: 800, width: 1200, height: 800), layout: grid.layout)
        let near = GridGeometry(workArea: CGRect(x: 1300, y: 0, width: 1000, height: 800), layout: grid.layout)
        let edge = grid.frame(for: GridSpan(columns: 3..<4, rows: 0..<1))
        let screens = [grid, distant, diagonal, near].map { NavigationScreen(geometry: $0) }
        #expect(ZoneNavigator.target(windowFrame: edge, screens: screens, direction: .right)?.screenIndex == 3)
        #expect(ZoneNavigator.target(windowFrame: edge, screens: [screens[0], screens[2]], direction: .right) == nil)
        // An unaligned window at the edge must align before crossing screens.
        #expect(ZoneNavigator.target(windowFrame: edge.insetBy(dx: 20, dy: 20), screens: screens, direction: .right)?.screenIndex == 0)
    }

    @Test func missingScreenAndWorkAreaClamping() {
        #expect(ZoneNavigator.target(windowFrame: grid.workArea, screens: [], direction: .right) == nil)
        let screen = NavigationScreen(geometry: grid, frame: CGRect(x: 0, y: -30, width: 1200, height: 830))
        #expect(ZoneNavigator.target(windowFrame: CGRect(x: 10, y: -25, width: 100, height: 10), screens: [screen], direction: .up)?.span == GridSpan(columns: 0..<1, rows: 0..<1))
    }
}
