import Foundation
import CoreGraphics

public enum MotionSpec {
    /// Moves and shrinks take 0.26 s; enlargements take 0.34 s.
    /// Both use the public Core Animation default curve with whole-point frames.
    /// `duration` is the longest glide and the default for callers without a duration.
    public static let moveDuration: TimeInterval = 0.26
    public static let growDuration: TimeInterval = 0.34
    public static let duration: TimeInterval = growDuration

    /// Enlargements (either side gets bigger) use the slower growDuration.
    public static func duration(from: CGRect, to: CGRect) -> TimeInterval {
        (to.width > from.width + 0.5 || to.height > from.height + 0.5) ? growDuration : moveDuration
    }
    public static let abortWriteMilliseconds: Double = 80

    /// Public Core Animation default timing: cubic Bézier (0.25, 0.1), (0.25, 1).
    /// That macOS Show Desktop uses this curve is an assumption.
    public static func defaultTiming(_ progress: Double) -> Double {
        let x = min(1, max(0, progress))
        guard x > 0, x < 1 else { return x }
        func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var t = x
        // Newton converges quickly for this curve; retain a bracket for bisection.
        var lower = 0.0, upper = 1.0
        for _ in 0..<8 {
            let error = bezier(t, 0.25, 0.25) - x
            if abs(error) < 1e-9 { return bezier(t, 0.1, 1) }
            if error < 0 { lower = t } else { upper = t }
            let derivative = 0.75 * (1 - t) * (1 - t) + 2.25 * t * t
            let next = t - error / derivative
            if next <= lower || next >= upper { break }
            t = next
        }
        for _ in 0..<32 {
            t = (lower + upper) / 2
            let value = bezier(t, 0.25, 0.25)
            if abs(value - x) < 1e-9 { break }
            if value < x { lower = t } else { upper = t }
        }
        return bezier(t, 0.1, 1)
    }
    public static func frame(from: CGRect, to: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(defaultTiming(progress))
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { (a + (b - a) * t).rounded() }
        // Interpolate and round the edges (not origin + size) so every edge moves
        // monotonically and never passes the target by a rounding point.
        let minX = mix(from.minX, to.minX), maxX = mix(from.maxX, to.maxX)
        let minY = mix(from.minY, to.minY), maxY = mix(from.maxY, to.maxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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

    /// Only a failed AX write or a single hung write ends the glide early.
    /// Slow callbacks skip frames on the same wall-clock curve. Read-back size
    /// differences (including lag, rounding and clamping) never change this decision.
    public static func action(success: Bool, writeMilliseconds: Double) -> StepAction {
        guard success, writeMilliseconds <= abortWriteMilliseconds else { return .snapToDestination }
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
