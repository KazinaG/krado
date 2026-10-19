import Foundation
import CoreGraphics

public enum KradoDefaults {
    /// Full width: 12 points on either side of an internal boundary.
    public static let boundaryBandWidth: CGFloat = 24
    public static let gap: CGFloat = 0
    public static let movementThreshold: CGFloat = 3
    public static let sizeTolerance: CGFloat = 2
}

public struct GridLayout: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public init(columns: Int, rows: Int) {
        precondition(columns > 0 && rows > 0)
        self.columns = columns
        self.rows = rows
    }
}

public struct ScreenDescriptor: Equatable, Sendable {
    public let isBuiltin: Bool
    public let visibleSize: CGSize
    public let name: String

    public init(isBuiltin: Bool, visibleSize: CGSize, name: String) {
        self.isBuiltin = isBuiltin
        self.visibleSize = visibleSize
        self.name = name
    }
}

/// Rule B — one law for every screen: keep halving the screen, across and down,
/// while each zone stays at least 640 pt wide and 720 pt tall.
/// columns = the largest of 1, 2, 4, 8 with W / columns ≥ 640; rows = the largest of 1, 2, 4 with H / rows ≥ 720.
/// W × H is the whole screen (menu bar and Dock included), so showing or hiding them never changes the grid.
public enum GridPolicy {
    public static let minimumCellWidth: CGFloat = 640
    public static let minimumCellHeight: CGFloat = 720
    public static let maximumColumns = 8
    public static let maximumRows = 4

    /// `screen.visibleSize` carries the whole screen size here (see Overlay), not the visible frame.
    public static func layout(for screen: ScreenDescriptor) -> GridLayout {
        let width = screen.visibleSize.width
        let height = screen.visibleSize.height
        guard width > 0, height > 0 else { return GridLayout(columns: 1, rows: 1) }
        var columns = 1
        while columns < maximumColumns && width / CGFloat(columns * 2) >= minimumCellWidth { columns *= 2 }
        var rows = 1
        while rows < maximumRows && height / CGFloat(rows * 2) >= minimumCellHeight { rows *= 2 }
        return GridLayout(columns: columns, rows: rows)
    }
}

/// Half-open column/row ranges. Rows increase downwards in AX coordinates.
public struct GridSpan: Equatable, Sendable {
    public let columns: Range<Int>
    public let rows: Range<Int>

    public init(columns: Range<Int>, rows: Range<Int>) {
        precondition(!columns.isEmpty && !rows.isEmpty)
        self.columns = columns
        self.rows = rows
    }

    public func union(_ other: GridSpan) -> GridSpan {
        GridSpan(
            columns: min(columns.lowerBound, other.columns.lowerBound)..<max(columns.upperBound, other.columns.upperBound),
            rows: min(rows.lowerBound, other.rows.lowerBound)..<max(rows.upperBound, other.rows.upperBound)
        )
    }
}

/// All frames/points use a global top-left origin (AX/CGEvent coordinates).
public struct GridGeometry: Sendable {
    public let workArea: CGRect
    public let layout: GridLayout
    public let scale: CGFloat
    public let xEdges: [CGFloat]
    public let yEdges: [CGFloat]

    public init(workArea: CGRect, layout: GridLayout, scale: CGFloat = 1) {
        precondition(workArea.width > 0 && workArea.height > 0 && scale > 0)
        self.workArea = workArea
        self.layout = layout
        self.scale = scale
        xEdges = Self.edges(origin: workArea.minX, length: workArea.width, count: layout.columns, scale: scale)
        yEdges = Self.edges(origin: workArea.minY, length: workArea.height, count: layout.rows, scale: scale)
    }

    /// Round absolute internal edges, preserving the exact outer work-area edges.
    private static func edges(origin: CGFloat, length: CGFloat, count: Int, scale: CGFloat) -> [CGFloat] {
        (0...count).map { index in
            if index == 0 { return origin }
            if index == count { return origin + length }
            return ((origin + length * CGFloat(index) / CGFloat(count)) * scale).rounded() / scale
        }
    }

    public func frame(for span: GridSpan, gap: CGFloat = KradoDefaults.gap) -> CGRect {
        precondition(span.columns.lowerBound >= 0 && span.columns.upperBound <= layout.columns)
        precondition(span.rows.lowerBound >= 0 && span.rows.upperBound <= layout.rows)
        let rect = CGRect(
            x: xEdges[span.columns.lowerBound], y: yEdges[span.rows.lowerBound],
            width: xEdges[span.columns.upperBound] - xEdges[span.columns.lowerBound],
            height: yEdges[span.rows.upperBound] - yEdges[span.rows.lowerBound]
        )
        let inset = max(0, min(gap / 2, min(rect.width, rect.height) / 2))
        return rect.insetBy(dx: inset, dy: inset)
    }

    public var zones: [GridSpan] {
        (0..<layout.rows).flatMap { row in
            (0..<layout.columns).map { GridSpan(columns: $0..<($0 + 1), rows: row..<(row + 1)) }
        }
    }

    /// Includes exact outer edges; only internal edges can select adjacent cells.
    /// The band's endpoints are inclusive. In overlapping bands, the nearest edge wins.
    public func hitTest(_ point: CGPoint, bandWidth: CGFloat = KradoDefaults.boundaryBandWidth) -> GridSpan? {
        guard point.x.isFinite, point.y.isFinite,
              point.x >= workArea.minX, point.x <= workArea.maxX,
              point.y >= workArea.minY, point.y <= workArea.maxY else { return nil }
        return GridSpan(
            columns: Self.hitRange(point.x, edges: xEdges, halfBand: max(0, bandWidth / 2)),
            rows: Self.hitRange(point.y, edges: yEdges, halfBand: max(0, bandWidth / 2))
        )
    }

    private static func hitRange(_ value: CGFloat, edges: [CGFloat], halfBand: CGFloat) -> Range<Int> {
        let count = edges.count - 1
        if let boundary = (1..<count).min(by: { abs(value - edges[$0]) < abs(value - edges[$1]) }),
           abs(value - edges[boundary]) <= halfBand {
            return (boundary - 1)..<(boundary + 1)
        }
        let cell = (0..<count).first(where: { value < edges[$0 + 1] }) ?? count - 1
        return cell..<(cell + 1)
    }
}
