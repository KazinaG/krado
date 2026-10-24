import Foundation
import Testing
@testable import KradoCore

@Suite("Motion specification")
struct MotionSpecTests {
    @Test("Easing and rounded interpolation")
    func easingAndRoundedInterpolation() {
        #expect(MotionSpec.defaultTiming(0) == 0)
        #expect(MotionSpec.defaultTiming(1) == 1)
        #expect(MotionSpec.defaultTiming(-1) == 0)
        #expect(MotionSpec.defaultTiming(2) == 1)
        #expect(abs(MotionSpec.defaultTiming(0.5) - 0.8024) < 0.002)
        let samples = (0...1000).map { MotionSpec.defaultTiming(Double($0) / 1000) }
        for (a, b) in zip(samples, samples.dropFirst()) { #expect(b >= a) }
        let a = CGRect(x: -100, y: 0, width: 300, height: 200)
        let b = CGRect(x: 100, y: 80, width: 600, height: 400)
        #expect(MotionSpec.frame(from: a, to: b, progress: 0) == a)
        #expect(MotionSpec.frame(from: a, to: b, progress: 1) == b)
        #expect(MotionSpec.frame(from: a, to: b, progress: 0.5).origin.x == 60)
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
        #expect(MotionSpec.abortWriteMilliseconds == 80)
        for milliseconds in [0.0, 10, 20, 40, 80] {
            #expect(MotionSpec.action(success: true, writeMilliseconds: milliseconds) == .continueGlide)
        }
        #expect(MotionSpec.action(success: true, writeMilliseconds: 80.01) == .snapToDestination)
        #expect(MotionSpec.action(success: false, writeMilliseconds: 1) == .snapToDestination)
    }

    @Test("Growing is slower than moving")
    func growIsSlowerThanMove() {
        let cell = CGRect(x: 0, y: 0, width: 640, height: 720)
        #expect(MotionSpec.duration(from: cell, to: cell.offsetBy(dx: 640, dy: 0)) == MotionSpec.moveDuration)
        #expect(MotionSpec.duration(from: cell, to: CGRect(x: 0, y: 0, width: 1280, height: 1440)) == MotionSpec.growDuration)
        #expect(MotionSpec.duration(from: CGRect(x: 0, y: 0, width: 1280, height: 1440), to: cell) == MotionSpec.moveDuration)
        #expect(MotionSpec.moveDuration == 0.26)
        #expect(MotionSpec.growDuration == 0.34)
    }
}
