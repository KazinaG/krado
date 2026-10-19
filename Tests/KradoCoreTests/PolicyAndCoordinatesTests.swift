import Foundation
import CoreGraphics
import Testing
@testable import KradoCore

@Suite("Display policy and coordinates")
struct PolicyAndCoordinatesTests {
    @Test("Example display sizes and zone counts", arguments: [
        PolicyCase(width: 3440, height: 1410, columns: 4, rows: 2),
        PolicyCase(width: 2560, height: 1050, columns: 4, rows: 1),
        PolicyCase(width: 3008, height: 1975, columns: 4, rows: 2),
        PolicyCase(width: 3840, height: 2135, columns: 4, rows: 2),
        PolicyCase(width: 1920, height: 1055, columns: 2, rows: 2),
        PolicyCase(width: 2560, height: 1415, columns: 2, rows: 2),
        PolicyCase(width: 2056, height: 1305, columns: 2, rows: 2),
        PolicyCase(width: 1800, height: 1137, columns: 2, rows: 2),
        PolicyCase(width: 1470, height: 924, columns: 2, rows: 1),
        PolicyCase(width: 1280, height: 800, columns: 2, rows: 1),
        PolicyCase(width: 1710, height: 1074, columns: 2, rows: 1),
        PolicyCase(width: 1512, height: 950, columns: 2, rows: 1),
        PolicyCase(width: 1728, height: 1085, columns: 2, rows: 1),
        PolicyCase(width: 1024, height: 740, columns: 1, rows: 1),
    ])
    func examples(test: PolicyCase) { checkPolicy(test) }

    @Test("Ordered policy threshold boundaries", arguments: [
        // Portrait height threshold and orientation precedence (squares are not portrait).
        PolicyCase(width: 800, height: 1199.99, columns: 1, rows: 1),
        PolicyCase(width: 800, height: 1200, columns: 1, rows: 2),
        PolicyCase(width: 800, height: 1200.01, columns: 1, rows: 2),
        PolicyCase(width: 1800, height: 1800, columns: 2, rows: 2),
        PolicyCase(width: 1800, height: 1800.01, columns: 1, rows: 2),
        PolicyCase(width: 2800, height: 2800, columns: 4, rows: 2),
        PolicyCase(width: 2800, height: 2800.01, columns: 1, rows: 2),
        PolicyCase(width: 3000, height: 4000, columns: 1, rows: 2),
        // An ultrawide aspect ratio alone is insufficient below 2400pt wide.
        PolicyCase(width: 2399.99, height: 1000, columns: 2, rows: 2),
        PolicyCase(width: 2400, height: 1000, columns: 4, rows: 1),
        PolicyCase(width: 2400.01, height: 1000, columns: 4, rows: 1),
        PolicyCase(width: 1000, height: 400, columns: 1, rows: 1),
        // Isolate the aspect-ratio boundary while satisfying the width threshold.
        PolicyCase(width: 2519.99, height: 1200, columns: 2, rows: 2),
        PolicyCase(width: 2520, height: 1200, columns: 4, rows: 1),
        PolicyCase(width: 2520.01, height: 1200, columns: 4, rows: 1),
        // Ultrawide height controls rows, even above the general large-screen width.
        PolicyCase(width: 3000, height: 1299.99, columns: 4, rows: 1),
        PolicyCase(width: 3000, height: 1300, columns: 4, rows: 2),
        PolicyCase(width: 3000, height: 1300.01, columns: 4, rows: 2),
        PolicyCase(width: 2800, height: 1000, columns: 4, rows: 1),
        // General width boundaries, with non-ultrawide sizes.
        PolicyCase(width: 2799.99, height: 1600, columns: 2, rows: 2),
        PolicyCase(width: 2800, height: 1600, columns: 4, rows: 2),
        PolicyCase(width: 2800.01, height: 1600, columns: 4, rows: 2),
        PolicyCase(width: 1799.99, height: 1000, columns: 2, rows: 1),
        PolicyCase(width: 1800, height: 1000, columns: 2, rows: 2),
        PolicyCase(width: 1800.01, height: 1000, columns: 2, rows: 2),
        PolicyCase(width: 1199.99, height: 800, columns: 1, rows: 1),
        PolicyCase(width: 1200, height: 800, columns: 2, rows: 1),
        PolicyCase(width: 1200.01, height: 800, columns: 2, rows: 1),
    ])
    func boundaries(test: PolicyCase) { checkPolicy(test) }

    private func checkPolicy(_ test: PolicyCase) {
        let screen = ScreenDescriptor(isBuiltin: false, visibleSize: CGSize(width: test.width, height: test.height), name: "Any display")
        let layout = GridPolicy.layout(for: screen)
        #expect(layout == GridLayout(columns: test.columns, rows: test.rows))
        let grid = GridGeometry(workArea: CGRect(origin: .zero, size: screen.visibleSize), layout: layout)
        #expect(grid.zones.count == test.columns * test.rows)
        // Both screen name and built-in status are informational.
        let renamed = ScreenDescriptor(isBuiltin: true, visibleSize: screen.visibleSize, name: "Different")
        #expect(layout == GridPolicy.layout(for: renamed))
    }

    @Test("Rect reflection and round trip across monitor arrangements", arguments: [
        CoordinateCase(appKit: CGRect(x: 0, y: 0, width: 1440, height: 900), ax: CGRect(x: 0, y: 0, width: 1440, height: 900)),
        CoordinateCase(appKit: CGRect(x: 0, y: 900, width: 1600, height: 1000), ax: CGRect(x: 0, y: -1000, width: 1600, height: 1000)),
        CoordinateCase(appKit: CGRect(x: -1600, y: 0, width: 1600, height: 1000), ax: CGRect(x: -1600, y: -100, width: 1600, height: 1000)),
        CoordinateCase(appKit: CGRect(x: 0, y: -1000, width: 1600, height: 1000), ax: CGRect(x: 0, y: 900, width: 1600, height: 1000)),
        CoordinateCase(appKit: CGRect(x: 1440, y: -100, width: 1600, height: 1000), ax: CGRect(x: 1440, y: 0, width: 1600, height: 1000)),
        CoordinateCase(appKit: CGRect(x: -1500, y: 925, width: 1400, height: 875), ax: CGRect(x: -1500, y: -900, width: 1400, height: 875)),
        CoordinateCase(appKit: CGRect(x: 0, y: 48, width: 1440, height: 827), ax: CGRect(x: 0, y: 25, width: 1440, height: 827)),
    ])
    func rectCoordinates(test: CoordinateCase) {
        #expect(flipY(test.appKit, mainScreenHeight: 900) == test.ax)
        #expect(flipY(test.ax, mainScreenHeight: 900) == test.appKit)
    }

    @Test("Point reflection", arguments: [
        CGPoint(x: 0, y: 900), CGPoint(x: -1600, y: 1900),
        CGPoint(x: 0, y: -1000), CGPoint(x: 1600.5, y: 24.5),
    ])
    func pointCoordinates(point: CGPoint) {
        let reflected = flipY(point, mainScreenHeight: 900)
        #expect(reflected == CGPoint(x: point.x, y: 900 - point.y))
        #expect(flipY(reflected, mainScreenHeight: 900) == point)
    }

    @Test("Top row of a screen above main remains above main in AX")
    func aboveScreenGrid() {
        let area = flipY(CGRect(x: -400, y: 900, width: 1600, height: 1000), mainScreenHeight: 900)
        let grid = GridGeometry(workArea: area, layout: GridLayout(columns: 2, rows: 2))
        let span = grid.hitTest(CGPoint(x: -200, y: -800))
        #expect(span == GridSpan(columns: 0..<1, rows: 0..<1))
        #expect(grid.frame(for: span!) == CGRect(x: -400, y: -1000, width: 800, height: 500))
        #expect(flipY(grid.frame(for: span!), mainScreenHeight: 900) == CGRect(x: -400, y: 1400, width: 800, height: 500))
    }
}

struct PolicyCase: Sendable {
    let width: CGFloat
    let height: CGFloat
    let columns: Int
    let rows: Int
}

struct CoordinateCase: Sendable {
    let appKit: CGRect
    let ax: CGRect
}
