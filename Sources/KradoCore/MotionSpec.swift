import Foundation
import CoreGraphics

public enum MotionSpec {
    /// Longest glide; also the default for callers that do not pass a duration.
    /// 0.1.5 (Kazina, 2026-10-20 19:13): snapping felt a little fast and growing a
    /// window too fast, so moves take 0.26 s and enlargements 0.34 s (were 0.20 s).
    public static let moveDuration: TimeInterval = 0.28
    public static let growDuration: TimeInterval = 0.38
    public static let duration: TimeInterval = growDuration

    /// Enlargements (either side gets bigger) use the slower growDuration.
    public static func duration(from: CGRect, to: CGRect) -> TimeInterval {
        (to.width > from.width + 0.5 || to.height > from.height + 0.5) ? growDuration : moveDuration
    }
    public static let abortWriteMilliseconds: Double = 80

    public enum Mode: Equatable, Sendable {
        case full, positionOnly, abort
    }
    public static func easeOut(_ progress: Double) -> Double {
        let t = min(1, max(0, progress))
        return 1 - pow(1 - t, 3)
    }
    /// The glide curve. 0.1.6 test B (Kazina 2026-10-20 19:53: 0.1.5's ease-out cubic
    /// felt flat): ease-out quint (quick start, long soft settle; no overshoot so the window never leaves its zone).
    public static func ease(_ progress: Double) -> Double {
        let t = min(1, max(0, progress))
        return 1 - pow(1 - t, 5)
    }
    public static func frame(from: CGRect, to: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(ease(progress))
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { (a + (b - a) * t).rounded() }
        return CGRect(x: mix(from.minX, to.minX), y: mix(from.minY, to.minY),
                      width: mix(from.width, to.width), height: mix(from.height, to.height))
    }
    public static func frameCount(refreshRate: Int, duration: TimeInterval = MotionSpec.duration) -> Int {
        max(1, Int(ceil(Double(max(1, refreshRate)) * max(0, duration))))
    }
    public static func frameInterval(refreshRate: Int) -> TimeInterval { 1 / Double(max(1, refreshRate)) }
    /// Called after a size write. Position writes only use the abort threshold.
    public static func nextMode(current: Mode, writeMilliseconds: Double,
                                requested: CGSize, actual: CGSize, refreshRate: Int) -> Mode {
        if current == .abort || writeMilliseconds > abortWriteMilliseconds { return .abort }
        if current == .positionOnly { return .positionOnly }
        if writeMilliseconds > frameInterval(refreshRate: refreshRate) * 1000 ||
            abs(requested.width - actual.width) > 2 || abs(requested.height - actual.height) > 2 {
            return .positionOnly
        }
        return .full
    }

    /// Outer zones use their display edge; interior or full-display zones use their centre.
    public static func anchor(for target: CGRect, in workArea: CGRect) -> CGPoint {
        func component(_ low: CGFloat, _ high: CGFloat, _ areaLow: CGFloat, _ areaHigh: CGFloat) -> CGFloat {
            let atLow = abs(low - areaLow) <= 2
            let atHigh = abs(high - areaHigh) <= 2
            if atLow == atHigh { return 0.5 }
            return atLow ? 0 : 1
        }
        return CGPoint(x: component(target.minX, target.maxX, workArea.minX, workArea.maxX),
                       y: component(target.minY, target.maxY, workArea.minY, workArea.maxY))
    }

    public static func anchoredPosition(for requested: CGRect, actualSize: CGSize, anchor: CGPoint) -> CGPoint {
        CGPoint(x: (requested.minX + (requested.width - actualSize.width) * anchor.x).rounded(),
                y: (requested.minY + (requested.height - actualSize.height) * anchor.y).rounded())
    }
    /// Preserve the selected edge when an app clamps its size, but keep a fitting
    /// window inside the destination display's visible frame.
    public static func anchoredPosition(for requested: CGRect, actualSize: CGSize,
                                        anchor: CGPoint, in workArea: CGRect) -> CGPoint {
        let point = anchoredPosition(for: requested, actualSize: actualSize, anchor: anchor)
        guard workArea.contains(requested) else { return point }
        return CGPoint(x: min(max(point.x, workArea.minX), max(workArea.minX, workArea.maxX - actualSize.width)),
                       y: min(max(point.y, workArea.minY), max(workArea.minY, workArea.maxY - actualSize.height)))
    }

    /// AX size and position are separate writes. Shrink each axis before moving,
    /// then grow at the new origin, so neither intermediate rectangle adds overflow.
    /// The bridge also handles one axis growing while the other shrinks.
    public static func bridgeSize(from actual: CGRect, to requested: CGRect) -> CGSize {
        CGSize(width: min(actual.width, requested.width),
               height: min(actual.height, requested.height))
    }

    public static func positionFirst(from actual: CGRect, to requested: CGRect) -> Bool {
        bridgeSize(from: actual, to: requested) == actual.size
    }

    public static func writes(from actual: CGRect, to requested: CGRect) -> (position: Bool, size: Bool) {
        (actual.origin != requested.origin, actual.size != requested.size)
    }
}
