import Foundation
import CoreGraphics

public enum MotionSpec {
    /// Moves and shrinks take 0.26 s; enlargements take 0.34 s.
    /// Both use ease-out cubic timing, 1 − (1 − t)³, with rounded whole-point frames.
    /// `duration` is the longest glide and the default for callers without a duration.
    public static let moveDuration: TimeInterval = 0.26
    public static let growDuration: TimeInterval = 0.34
    public static let duration: TimeInterval = growDuration

    /// Enlargements (either side gets bigger) use the slower growDuration.
    public static func duration(from: CGRect, to: CGRect) -> TimeInterval {
        (to.width > from.width + 0.5 || to.height > from.height + 0.5) ? growDuration : moveDuration
    }
    public static let abortWriteMilliseconds: Double = 80

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

    public enum Step: Equatable, Sendable {
        case size(CGSize)
        case position(CGPoint)

        public func isNeeded(in actual: CGRect) -> Bool {
            switch self {
            case .size(let size): actual.size != size
            case .position(let point): actual.origin != point
            }
        }
    }

    public enum StepAction: Equatable, Sendable {
        case continueGlide, snapToDestination
    }

    /// Plan separate AX writes without adding overflow: shrink, move, then grow.
    /// The last position restores the path if resizing itself moves the window.
    public static func steps(from actual: CGRect, to requested: CGRect) -> [Step] {
        let bridge = bridgeSize(from: actual, to: requested)
        var steps: [Step] = []
        if bridge != actual.size { steps.append(.size(bridge)) }
        steps.append(.position(requested.origin))
        if bridge != requested.size {
            steps.append(.size(requested.size))
            steps.append(.position(requested.origin))
        }
        return steps
    }

    /// Check each write before issuing another. A slow, lagging or clamped resize
    /// ends the glide immediately; never move a stale-size window toward an anchor.
    /// Size timings accumulate across the shrink/grow bridge within this frame.
    /// Position-only moves retain the 80 ms abort budget.
    public static func action(after step: Step, success: Bool, writeMilliseconds: Double,
                              totalSizeWriteMilliseconds: Double, actualSize: CGSize?,
                              refreshRate: Int) -> StepAction {
        guard success, writeMilliseconds <= abortWriteMilliseconds else { return .snapToDestination }
        if case .size(let requested) = step {
            guard let actualSize,
                  totalSizeWriteMilliseconds <= frameInterval(refreshRate: refreshRate) * 1000,
                  abs(requested.width - actualSize.width) <= 2,
                  abs(requested.height - actualSize.height) <= 2 else { return .snapToDestination }
        }
        return .continueGlide
    }

    /// AX size and position are separate writes. Shrink each axis before moving,
    /// then grow at the new origin, so neither intermediate rectangle adds overflow.
    /// The bridge also handles one axis growing while the other shrinks.
    public static func bridgeSize(from actual: CGRect, to requested: CGRect) -> CGSize {
        CGSize(width: min(actual.width, requested.width),
               height: min(actual.height, requested.height))
    }
}
