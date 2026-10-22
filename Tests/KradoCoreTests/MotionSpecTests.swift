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

    @Test("Write mode boundaries")
    func writeModeBoundaries() {
        let size = CGSize(width: 500, height: 400)
        func mode(_ milliseconds: Double, _ actual: CGSize? = nil, rate: Int = 60,
                  current: MotionSpec.Mode = .full) -> MotionSpec.Mode {
            MotionSpec.nextMode(current: current, writeMilliseconds: milliseconds,
                                requested: size, actual: actual ?? size, refreshRate: rate)
        }
        #expect(MotionSpec.abortWriteMilliseconds == 80)
        #expect(mode(1000 / 60.0) == .full)
        #expect(mode(1000 / 60.0 + 0.01) == .positionOnly)
        #expect(mode(10, rate: 60) == .full)
        #expect(mode(10, rate: 120) == .positionOnly)
        #expect(mode(80) == .positionOnly)
        #expect(mode(80.01) == .abort)
        #expect(mode(0, CGSize(width: 502, height: 398)) == .full)
        #expect(mode(0, CGSize(width: 502.01, height: 400)) == .positionOnly)
        #expect(mode(0, CGSize(width: 500, height: 397.99)) == .positionOnly)
        for milliseconds in [20.0, 26, 50, 51] {
            #expect(mode(milliseconds) == .positionOnly)
        }
        for deviation in [3.0, 7.0] {
            #expect(mode(1, CGSize(width: 500 + deviation, height: 400)) == .positionOnly)
        }
        #expect(mode(0, current: .positionOnly) == .positionOnly)
        #expect(mode(80, current: .positionOnly) == .positionOnly)
        #expect(mode(80.01, current: .positionOnly) == .abort)
        #expect(mode(0, current: .abort) == .abort)
        #expect(mode(1, rate: 0) == .full)
    }

    @Test("Actual size anchoring")
    func actualSizeAnchoring() {
        let work = CGRect(x: -1000, y: 40, width: 1000, height: 800)
        let left = CGRect(x: -1000, y: 40, width: 500, height: 800)
        let right = CGRect(x: -500, y: 40, width: 500, height: 800)
        let lower = CGRect(x: -1000, y: 440, width: 1000, height: 400)
        #expect(MotionSpec.anchor(for: left, in: work) == CGPoint(x: 0, y: 0.5))
        #expect(MotionSpec.anchor(for: right, in: work) == CGPoint(x: 1, y: 0.5))
        #expect(MotionSpec.anchor(for: lower, in: work) == CGPoint(x: 0.5, y: 1))
        #expect(MotionSpec.anchor(for: work, in: work) == CGPoint(x: 0.5, y: 0.5))
        let interior = CGRect(x: -750, y: 240, width: 500, height: 400)
        #expect(MotionSpec.anchor(for: interior, in: work) == CGPoint(x: 0.5, y: 0.5))
        let actual = CGSize(width: 493, height: 797)
        #expect(MotionSpec.anchoredPosition(for: left, actualSize: actual, anchor: CGPoint(x: 0, y: 0.5)) == CGPoint(x: -1000, y: 42))
        #expect(MotionSpec.anchoredPosition(for: right, actualSize: actual, anchor: CGPoint(x: 1, y: 0.5)) == CGPoint(x: -493, y: 42))
        let position = MotionSpec.anchoredPosition(for: interior, actualSize: CGSize(width: 600, height: 500),
                                                 anchor: CGPoint(x: 0.5, y: 0.5))
        #expect(position == CGPoint(x: -800, y: 190))
        #expect(MotionSpec.anchoredPosition(for: right, actualSize: right.size, anchor: CGPoint(x: 1, y: 0.5)) == right.origin)
    }

    @Test("Redundant writes")
    func redundantWrites() {
        let a = CGRect(x: 1, y: 2, width: 3, height: 4)
        #expect(!MotionSpec.writes(from: a, to: a).position)
        #expect(!MotionSpec.writes(from: a, to: a).size)
        #expect(MotionSpec.writes(from: a, to: a.offsetBy(dx: 1, dy: 0)).position)
        #expect(!MotionSpec.writes(from: a, to: a.offsetBy(dx: 1, dy: 0)).size)
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
