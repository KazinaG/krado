import Foundation
import CoreGraphics

public enum MotionSpec {
    public static let duration: TimeInterval = 0.20
    public static let abortWriteMilliseconds: Double = 80

    public enum Mode: Equatable, Sendable {
        case full, positionOnly, abort
    }
    public static func easeOut(_ progress: Double) -> Double {
        let t = min(1, max(0, progress))
        return 1 - pow(1 - t, 3)
    }
    public static func frame(from: CGRect, to: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(easeOut(progress))
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
    public static func writes(from actual: CGRect, to requested: CGRect) -> (position: Bool, size: Bool) {
        (actual.origin != requested.origin, actual.size != requested.size)
    }
}
