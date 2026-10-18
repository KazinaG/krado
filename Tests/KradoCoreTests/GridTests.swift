import Foundation
import CoreGraphics
import Testing
@testable import KradoCore

@Suite("Grid geometry and hit testing")
struct GridTests {
    private let area = CGRect(x: -1000, y: -200, width: 1200, height: 800)

    @Test("Zone frames", arguments: [2, 4])
    func zones(columns: Int) {
        let grid = GridGeometry(workArea: area, layout: GridLayout(columns: columns, rows: 2))
        #expect(grid.zones.count == columns * 2)
        for (index, span) in grid.zones.enumerated() {
            let column = index % columns
            let row = index / columns
            #expect(grid.frame(for: span) == CGRect(
                x: area.minX + CGFloat(column) * area.width / CGFloat(columns),
                y: area.minY + CGFloat(row) * 400,
                width: area.width / CGFloat(columns), height: 400
            ))
        }
        #expect(grid.frame(for: GridSpan(columns: 0..<columns, rows: 0..<2)) == area)
    }

    @Test("Rounded edges tile exactly", arguments: [CGFloat(1), CGFloat(2)])
    func rounding(scale: CGFloat) {
        let frame = CGRect(x: -1000.5, y: -200.5, width: 1001.5, height: 803.5)
        let grid = GridGeometry(workArea: frame, layout: GridLayout(columns: 4, rows: 2), scale: scale)
        #expect(grid.xEdges.first == frame.minX)
        #expect(grid.xEdges.last == frame.maxX)
        #expect(grid.yEdges.first == frame.minY)
        #expect(grid.yEdges.last == frame.maxY)
        for edge in grid.xEdges.dropFirst().dropLast() + grid.yEdges.dropFirst().dropLast() {
            #expect(edge * scale == (edge * scale).rounded())
        }
        let widths = (0..<4).map { grid.frame(for: GridSpan(columns: $0..<($0 + 1), rows: 0..<1)).width }
        let heights = (0..<2).map { grid.frame(for: GridSpan(columns: 0..<1, rows: $0..<($0 + 1))).height }
        #expect(widths.reduce(0, +) == frame.width)
        #expect(heights.reduce(0, +) == frame.height)
        for column in 0..<3 {
            #expect(grid.frame(for: GridSpan(columns: column..<(column + 1), rows: 0..<1)).maxX
                == grid.frame(for: GridSpan(columns: (column + 1)..<(column + 2), rows: 0..<1)).minX)
        }
        #expect(widths.max()! - widths.min()! <= 1 / scale)
        #expect(heights.max()! - heights.min()! <= 1 / scale)
    }

    @Test("Cells, edges, corners, and inclusive band limits", arguments: [
        HitCase(x: 150, y: 200, columns: 0..<1, rows: 0..<1),
        HitCase(x: 1050, y: 600, columns: 3..<4, rows: 1..<2),
        HitCase(x: 300, y: 200, columns: 0..<2, rows: 0..<1),
        HitCase(x: 600, y: 200, columns: 1..<3, rows: 0..<1),
        HitCase(x: 900, y: 600, columns: 2..<4, rows: 1..<2),
        HitCase(x: 150, y: 400, columns: 0..<1, rows: 0..<2),
        HitCase(x: 600, y: 400, columns: 1..<3, rows: 0..<2),
        HitCase(x: 288, y: 200, columns: 0..<2, rows: 0..<1),
        HitCase(x: 312, y: 200, columns: 0..<2, rows: 0..<1),
        HitCase(x: 287.99, y: 200, columns: 0..<1, rows: 0..<1),
        HitCase(x: 312.01, y: 200, columns: 1..<2, rows: 0..<1),
        HitCase(x: 150, y: 388, columns: 0..<1, rows: 0..<2),
        HitCase(x: 150, y: 412, columns: 0..<1, rows: 0..<2),
        HitCase(x: 150, y: 387.99, columns: 0..<1, rows: 0..<1),
        HitCase(x: 150, y: 412.01, columns: 0..<1, rows: 1..<2),
        HitCase(x: 288, y: 388, columns: 0..<2, rows: 0..<2),
        HitCase(x: 0, y: 0, columns: 0..<1, rows: 0..<1),
        HitCase(x: 5, y: 5, columns: 0..<1, rows: 0..<1),
        HitCase(x: 1195, y: 795, columns: 3..<4, rows: 1..<2),
        HitCase(x: 1200, y: 800, columns: 3..<4, rows: 1..<2),
        HitCase(x: 0, y: 400, columns: 0..<1, rows: 0..<2),
        HitCase(x: 1200, y: 400, columns: 3..<4, rows: 0..<2),
    ])
    func hitTest(test: HitCase) {
        let grid = GridGeometry(workArea: area, layout: GridLayout(columns: 4, rows: 2))
        #expect(grid.hitTest(CGPoint(x: area.minX + test.x, y: area.minY + test.y))
            == GridSpan(columns: test.columns, rows: test.rows))
    }

    @Test("Outside work area", arguments: [
        CGPoint(x: -0.01, y: 100), CGPoint(x: 1200.01, y: 100),
        CGPoint(x: 100, y: -0.01), CGPoint(x: 100, y: 800.01),
        CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 0, y: CGFloat.infinity),
    ])
    func outside(point: CGPoint) {
        let grid = GridGeometry(workArea: area, layout: GridLayout(columns: 4, rows: 2))
        #expect(grid.hitTest(CGPoint(x: point.x + area.minX, y: point.y + area.minY)) == nil)
    }

    @Test("2 by 2 center selects the entire grid")
    func twoByTwoIntersection() {
        let grid = GridGeometry(workArea: area, layout: GridLayout(columns: 2, rows: 2))
        #expect(grid.hitTest(CGPoint(x: -400, y: 200)) == GridSpan(columns: 0..<2, rows: 0..<2))
    }

    @Test("Single-row layouts have full-height cells and no horizontal internal edge", arguments: [2, 4])
    func singleRow(columns: Int) {
        let grid = GridGeometry(workArea: area, layout: GridLayout(columns: columns, rows: 1))
        #expect(grid.yEdges == [area.minY, area.maxY])
        #expect(grid.zones.count == columns)
        for span in grid.zones {
            let frame = grid.frame(for: span)
            #expect(frame.minY == area.minY && frame.height == area.height)
            for y in [area.minY, area.midY - 12, area.midY, area.midY + 12, area.maxY] {
                #expect(grid.hitTest(CGPoint(x: frame.midX, y: y)) == span)
            }
        }
        for edge in grid.xEdges.indices.dropFirst().dropLast() {
            let selected = GridSpan(columns: (edge - 1)..<(edge + 1), rows: 0..<1)
            #expect(grid.hitTest(CGPoint(x: grid.xEdges[edge], y: area.midY)) == selected)
            #expect(grid.frame(for: selected).height == area.height)
            #expect(grid.hitTest(CGPoint(x: grid.xEdges[edge] - 12, y: area.maxY)) == selected)
            #expect(grid.hitTest(CGPoint(x: grid.xEdges[edge] + 12, y: area.minY)) == selected)
        }
    }

    @Test("Unsplit screens have one zone and snap to the entire visible frame", arguments: [
        CGSize(width: 1024, height: 740), CGSize(width: 800, height: 1100),
    ])
    func unsplit(size: CGSize) {
        let visibleFrame = CGRect(x: -1200.5, y: 25.5, width: size.width, height: size.height)
        let layout = GridPolicy.layout(for: ScreenDescriptor(isBuiltin: true, visibleSize: size, name: "Tiny"))
        let grid = GridGeometry(workArea: visibleFrame, layout: layout, scale: 2)
        let cell = GridSpan(columns: 0..<1, rows: 0..<1)
        #expect(layout == GridLayout(columns: 1, rows: 1))
        #expect(grid.zones == [cell])
        #expect(grid.xEdges == [visibleFrame.minX, visibleFrame.maxX])
        #expect(grid.yEdges == [visibleFrame.minY, visibleFrame.maxY])
        for x in [visibleFrame.minX, visibleFrame.minX + 12, visibleFrame.midX, visibleFrame.maxX - 12, visibleFrame.maxX] {
            for y in [visibleFrame.minY, visibleFrame.minY + 12, visibleFrame.midY, visibleFrame.maxY - 12, visibleFrame.maxY] {
                let selected = grid.hitTest(CGPoint(x: x, y: y))
                #expect(selected == cell)
                #expect(grid.frame(for: selected!) == visibleFrame)
            }
        }
        #expect(grid.hitTest(CGPoint(x: visibleFrame.maxX + 0.01, y: visibleFrame.midY)) == nil)
    }

    @Test("Portrait has full-width stacked halves and no vertical internal edge")
    func portrait() {
        let grid = GridGeometry(workArea: area, layout: GridLayout(columns: 1, rows: 2))
        #expect(grid.xEdges == [area.minX, area.maxX])
        #expect(grid.zones.count == 2)
        #expect(grid.hitTest(CGPoint(x: area.midX, y: area.minY + 100)) == GridSpan(columns: 0..<1, rows: 0..<1))
        #expect(grid.hitTest(CGPoint(x: area.midX, y: area.maxY - 100)) == GridSpan(columns: 0..<1, rows: 1..<2))
        let both = grid.hitTest(CGPoint(x: area.midX, y: area.midY))
        #expect(both == GridSpan(columns: 0..<1, rows: 0..<2))
        #expect(grid.frame(for: both!) == area)
    }

    @Test("Hit testing follows rounded edges")
    func roundedHit() {
        let grid = GridGeometry(workArea: CGRect(x: 0, y: 0, width: 1001, height: 801), layout: GridLayout(columns: 4, rows: 2))
        #expect(grid.xEdges == [0, 250, 501, 751, 1001])
        #expect(grid.hitTest(CGPoint(x: 513, y: 100))?.columns == 1..<3)
        #expect(grid.hitTest(CGPoint(x: 513.01, y: 100))?.columns == 2..<3)
    }

    @Test("Custom band and gap")
    func customConstants() {
        let grid = GridGeometry(workArea: area, layout: GridLayout(columns: 4, rows: 2))
        #expect(grid.hitTest(CGPoint(x: -690, y: 0), bandWidth: 10)?.columns == 1..<2)
        #expect(grid.frame(for: GridSpan(columns: 0..<2, rows: 0..<1), gap: 8)
            == CGRect(x: -996, y: -196, width: 592, height: 392))
        #expect(KradoDefaults.gap == 0)
        #expect(KradoDefaults.boundaryBandWidth == 24)
    }
}

struct HitCase: Sendable {
    let x: CGFloat
    let y: CGFloat
    let columns: Range<Int>
    let rows: Range<Int>
}
