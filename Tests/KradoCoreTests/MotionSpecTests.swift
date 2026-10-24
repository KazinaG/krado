import Foundation
import Testing
@testable import KradoCore

@Suite("Motion specification")
struct MotionSpecTests {
    @Test("Easing and rounded interpolation")
    func easingAndRoundedInterpolation() {
        #expect(MotionSpec.easeOut(-1) == 0)
        #expect(MotionSpec.easeOut(2) == 1)
        #expect(MotionSpec.easeOut(0.5) == 0.875)
        let a = CGRect(x: -100, y: 0, width: 300, height: 200)
        let b = CGRect(x: 100, y: 80, width: 600, height: 400)
        #expect(MotionSpec.frame(from: a, to: b, progress: 0) == a)
        #expect(MotionSpec.frame(from: a, to: b, progress: 1) == b)
        #expect(MotionSpec.frame(from: a, to: b, progress: 0.5).origin.x == 75)
    }

    @Test("Display budget")
    func displayBudget() {
        #expect(MotionSpec.frameCount(refreshRate: 60, duration: 0.20) == 12)
        #expect(MotionSpec.frameCount(refreshRate: 120, duration: 0.20) == 24)
        #expect(MotionSpec.frameCount(refreshRate: 0) == 1)
        #expect(MotionSpec.frameInterval(refreshRate: 60) == 1 / 60.0)
    }

    @Test("Per-write fallback boundaries")
    func fallbackBoundaries() {
        let size = CGSize(width: 500, height: 400)
        func action(_ milliseconds: Double, _ actual: CGSize? = CGSize(width: 500, height: 400),
                    rate: Int = 60, total: Double? = nil, success: Bool = true) -> MotionSpec.StepAction {
            MotionSpec.action(after: .size(size), success: success, writeMilliseconds: milliseconds,
                              totalSizeWriteMilliseconds: total ?? milliseconds, actualSize: actual, refreshRate: rate)
        }
        #expect(MotionSpec.abortWriteMilliseconds == 80)
        #expect(action(1000 / 60.0) == .continueGlide)
        #expect(action(1000 / 60.0 + 0.01) == .snapToDestination)
        #expect(action(10, rate: 60) == .continueGlide)
        #expect(action(10, rate: 120) == .snapToDestination)
        #expect(action(8, total: 17) == .snapToDestination)
        #expect(action(0, CGSize(width: 502, height: 398)) == .continueGlide)
        #expect(action(0, CGSize(width: 502.01, height: 400)) == .snapToDestination)
        #expect(action(0, CGSize(width: 500, height: 397.99)) == .snapToDestination)
        #expect(action(0, nil) == .snapToDestination)
        #expect(action(0, success: false) == .snapToDestination)
        #expect(action(1, rate: 0) == .continueGlide)
        for (milliseconds, expected) in [(80.0, MotionSpec.StepAction.continueGlide), (80.01, .snapToDestination)] {
            #expect(MotionSpec.action(after: .position(.zero), success: true, writeMilliseconds: milliseconds,
                                      totalSizeWriteMilliseconds: 0, actualSize: nil, refreshRate: 60) == expected)
        }
    }

    @Test("Growing is slower than moving")
    func growIsSlowerThanMove() {
        let cell = CGRect(x: 0, y: 0, width: 640, height: 720)
        #expect(MotionSpec.duration(from: cell, to: cell.offsetBy(dx: 640, dy: 0)) == MotionSpec.moveDuration)
        #expect(MotionSpec.duration(from: cell, to: CGRect(x: 0, y: 0, width: 1280, height: 1440)) == MotionSpec.growDuration)
        #expect(MotionSpec.duration(from: CGRect(x: 0, y: 0, width: 1280, height: 1440), to: cell) == MotionSpec.moveDuration)
        #expect(MotionSpec.moveDuration > 0.20)
        #expect(MotionSpec.growDuration > MotionSpec.moveDuration)
    }
}
