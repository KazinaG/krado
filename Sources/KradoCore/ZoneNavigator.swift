import Foundation

public enum Direction: CaseIterable, Sendable {
    case left, right, down, up

    /// Carbon virtual key codes, kept pure so no Carbon dependency is needed here.
    public init?(keyCode: UInt32) {
        switch keyCode {
        case 123: self = .left
        case 124: self = .right
        case 125: self = .down
        case 126: self = .up
        default: return nil
        }
    }

    private var delta: (column: Int, row: Int) {
        switch self {
        case .left: (-1, 0)
        case .right: (1, 0)
        case .down: (0, 1)
        case .up: (0, -1)
        }
    }

    fileprivate var step: (column: Int, row: Int) { delta }
}

public struct NavigationScreen: Sendable {
    public let frame: CGRect
    public let geometry: GridGeometry

    public init(geometry: GridGeometry, frame: CGRect? = nil) {
        self.geometry = geometry
        self.frame = frame ?? geometry.workArea
    }
}

public struct NavigationTarget: Equatable, Sendable {
    public let screenIndex: Int
    public let span: GridSpan
}

public enum ZoneNavigator {
    public static func target(
        windowFrame: CGRect, screens: [NavigationScreen], direction: Direction,
        extend: Bool = false, tolerance: CGFloat = 2
    ) -> NavigationTarget? {
        let centre = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        guard centre.x.isFinite, centre.y.isFinite,
              windowFrame.width > 0, windowFrame.height > 0,
              let index = screens.firstIndex(where: { $0.frame.contains(centre) }) else { return nil }
        let grid = screens[index].geometry
        let aligned = matchingSpan(windowFrame, grid: grid, tolerance: max(0, tolerance))
        let span = aligned ?? cell(at: centre, grid: grid)
        let step = direction.step
        if extend {
            let grown = GridSpan(
                columns: (span.columns.lowerBound + min(0, step.column))..<(span.columns.upperBound + max(0, step.column)),
                rows: (span.rows.lowerBound + min(0, step.row))..<(span.rows.upperBound + max(0, step.row))
            )
            if fits(grown, grid: grid) { return NavigationTarget(screenIndex: index, span: grown) }
            return aligned == nil ? NavigationTarget(screenIndex: index, span: span) : nil
        }
        // The first move of an unaligned window only aligns it, even at a screen edge.
        guard aligned != nil else { return NavigationTarget(screenIndex: index, span: span) }
        let moved = GridSpan(
            columns: (span.columns.lowerBound + step.column)..<(span.columns.upperBound + step.column),
            rows: (span.rows.lowerBound + step.row)..<(span.rows.upperBound + step.row)
        )
        if fits(moved, grid: grid) { return NavigationTarget(screenIndex: index, span: moved) }
        guard let next = adjacentScreen(to: index, screens: screens, direction: direction, centre: centre) else { return nil }
        let destination = screens[next].geometry
        var facing = cell(at: centre, grid: destination)
        switch direction {
        case .left: facing = GridSpan(columns: (destination.layout.columns - 1)..<destination.layout.columns, rows: facing.rows)
        case .right: facing = GridSpan(columns: 0..<1, rows: facing.rows)
        case .up: facing = GridSpan(columns: facing.columns, rows: (destination.layout.rows - 1)..<destination.layout.rows)
        case .down: facing = GridSpan(columns: facing.columns, rows: 0..<1)
        }
        return NavigationTarget(screenIndex: next, span: facing)
    }

    private static func fits(_ span: GridSpan, grid: GridGeometry) -> Bool {
        span.columns.lowerBound >= 0 && span.columns.upperBound <= grid.layout.columns
            && span.rows.lowerBound >= 0 && span.rows.upperBound <= grid.layout.rows
    }

    private static func cell(at point: CGPoint, grid: GridGeometry) -> GridSpan {
        // Clamp to the work area for window centres in a menu-bar/Dock region.
        let column = (0..<grid.layout.columns).first { point.x < grid.xEdges[$0 + 1] } ?? grid.layout.columns - 1
        let row = (0..<grid.layout.rows).first { point.y < grid.yEdges[$0 + 1] } ?? grid.layout.rows - 1
        return GridSpan(columns: column..<(column + 1), rows: row..<(row + 1))
    }

    private static func matchingSpan(_ frame: CGRect, grid: GridGeometry, tolerance: CGFloat) -> GridSpan? {
        for left in 0..<grid.layout.columns {
            for right in (left + 1)...grid.layout.columns {
                for top in 0..<grid.layout.rows {
                    for bottom in (top + 1)...grid.layout.rows {
                        let span = GridSpan(columns: left..<right, rows: top..<bottom)
                        let candidate = grid.frame(for: span)
                        if abs(frame.minX - candidate.minX) <= tolerance,
                           abs(frame.maxX - candidate.maxX) <= tolerance,
                           abs(frame.minY - candidate.minY) <= tolerance,
                           abs(frame.maxY - candidate.maxY) <= tolerance { return span }
                    }
                }
            }
        }
        return nil
    }

    private static func adjacentScreen(to index: Int, screens: [NavigationScreen], direction: Direction, centre: CGPoint) -> Int? {
        let area = screens[index].geometry.workArea
        let horizontal = direction == .left || direction == .right
        let candidates = screens.indices.compactMap { other -> (index: Int, distance: CGFloat, perpendicular: CGFloat)? in
            guard other != index else { return nil }
            let next = screens[other].geometry.workArea
            let overlap = horizontal
                ? min(area.maxY, next.maxY) - max(area.minY, next.minY)
                : min(area.maxX, next.maxX) - max(area.minX, next.minX)
            guard overlap > 0 else { return nil }
            let distance: CGFloat
            switch direction {
            case .left: distance = area.minX - next.maxX
            case .right: distance = next.minX - area.maxX
            case .up: distance = area.minY - next.maxY
            case .down: distance = next.minY - area.maxY
            }
            guard distance >= 0 else { return nil }
            let perpendicular = horizontal
                ? max(next.minY - centre.y, centre.y - next.maxY, 0)
                : max(next.minX - centre.x, centre.x - next.maxX, 0)
            return (other, distance, perpendicular)
        }
        return candidates.min {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.perpendicular != $1.perpendicular { return $0.perpendicular < $1.perpendicular }
            return $0.index < $1.index
        }?.index
    }
}
