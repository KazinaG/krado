import XCTest
@testable import KradoCore

final class MotionSpecTests: XCTestCase {
    func testEasingAndRoundedInterpolation() {
        XCTAssertEqual(MotionSpec.easeOut(-1), 0)
        XCTAssertEqual(MotionSpec.easeOut(2), 1)
        XCTAssertEqual(MotionSpec.easeOut(0.5), 0.875)
        let a = CGRect(x: -100, y: 0, width: 300, height: 200)
        let b = CGRect(x: 100, y: 80, width: 600, height: 400)
        XCTAssertEqual(MotionSpec.frame(from: a, to: b, progress: 0), a)
        XCTAssertEqual(MotionSpec.frame(from: a, to: b, progress: 1), b)
        XCTAssertEqual(MotionSpec.frame(from: a, to: b, progress: 0.5).origin.x, CGFloat((-100 + 200 * MotionSpec.ease(0.5)).rounded()))
    }
    func testDisplayBudget() {
        XCTAssertEqual(MotionSpec.frameCount(refreshRate: 60, duration: 0.20), 12)
        XCTAssertEqual(MotionSpec.frameCount(refreshRate: 120, duration: 0.20), 24)
        XCTAssertEqual(MotionSpec.frameCount(refreshRate: 0), 1)
        XCTAssertEqual(MotionSpec.frameInterval(refreshRate: 60), 1 / 60.0)
    }
    func testWriteModeBoundaries() {
        let size = CGSize(width: 500, height: 400)
        func mode(_ milliseconds: Double, _ actual: CGSize? = nil, rate: Int = 60,
                  current: MotionSpec.Mode = .full) -> MotionSpec.Mode {
            MotionSpec.nextMode(current: current, writeMilliseconds: milliseconds,
                                requested: size, actual: actual ?? size, refreshRate: rate)
        }
        XCTAssertEqual(MotionSpec.abortWriteMilliseconds, 80)
        XCTAssertEqual(mode(1000 / 60.0), .full)
        XCTAssertEqual(mode(1000 / 60.0 + 0.01), .positionOnly)
        XCTAssertEqual(mode(10, rate: 60), .full)
        XCTAssertEqual(mode(10, rate: 120), .positionOnly)
        XCTAssertEqual(mode(80), .positionOnly)
        XCTAssertEqual(mode(80.01), .abort)
        XCTAssertEqual(mode(0, CGSize(width: 502, height: 398)), .full)
        XCTAssertEqual(mode(0, CGSize(width: 502.01, height: 400)), .positionOnly)
        XCTAssertEqual(mode(0, CGSize(width: 500, height: 397.99)), .positionOnly)
        for milliseconds in [20.0, 26, 50, 51] {
            XCTAssertEqual(mode(milliseconds), .positionOnly)
        }
        for deviation in [3.0, 7.0] {
            XCTAssertEqual(mode(1, CGSize(width: 500 + deviation, height: 400)), .positionOnly)
        }
        XCTAssertEqual(mode(0, current: .positionOnly), .positionOnly)
        XCTAssertEqual(mode(80, current: .positionOnly), .positionOnly)
        XCTAssertEqual(mode(80.01, current: .positionOnly), .abort)
        XCTAssertEqual(mode(0, current: .abort), .abort)
        XCTAssertEqual(mode(1, rate: 0), .full)
    }
    func testActualSizeAnchoring() {
        let work = CGRect(x: -1000, y: 40, width: 1000, height: 800)
        let left = CGRect(x: -1000, y: 40, width: 500, height: 800)
        let right = CGRect(x: -500, y: 40, width: 500, height: 800)
        let lower = CGRect(x: -1000, y: 440, width: 1000, height: 400)
        XCTAssertEqual(MotionSpec.anchor(for: left, in: work), CGPoint(x: 0, y: 0.5))
        XCTAssertEqual(MotionSpec.anchor(for: right, in: work), CGPoint(x: 1, y: 0.5))
        XCTAssertEqual(MotionSpec.anchor(for: lower, in: work), CGPoint(x: 0.5, y: 1))
        XCTAssertEqual(MotionSpec.anchor(for: work, in: work), CGPoint(x: 0.5, y: 0.5))
        let interior = CGRect(x: -750, y: 240, width: 500, height: 400)
        XCTAssertEqual(MotionSpec.anchor(for: interior, in: work), CGPoint(x: 0.5, y: 0.5))
        let actual = CGSize(width: 493, height: 797)
        XCTAssertEqual(MotionSpec.anchoredPosition(for: left, actualSize: actual, anchor: CGPoint(x: 0, y: 0.5)),
                       CGPoint(x: -1000, y: 42))
        XCTAssertEqual(MotionSpec.anchoredPosition(for: right, actualSize: actual, anchor: CGPoint(x: 1, y: 0.5)),
                       CGPoint(x: -493, y: 42))
        let position = MotionSpec.anchoredPosition(for: interior, actualSize: CGSize(width: 600, height: 500),
                                                 anchor: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(position, CGPoint(x: -800, y: 190))
        XCTAssertEqual(MotionSpec.anchoredPosition(for: right, actualSize: right.size, anchor: CGPoint(x: 1, y: 0.5)),
                       right.origin)
    }
    func testRedundantWrites() {
        let a = CGRect(x: 1, y: 2, width: 3, height: 4)
        XCTAssertFalse(MotionSpec.writes(from: a, to: a).position)
        XCTAssertFalse(MotionSpec.writes(from: a, to: a).size)
        XCTAssertTrue(MotionSpec.writes(from: a, to: a.offsetBy(dx: 1, dy: 0)).position)
        XCTAssertFalse(MotionSpec.writes(from: a, to: a.offsetBy(dx: 1, dy: 0)).size)
    }

    func testGrowIsSlowerThanMove() {
        let cell = CGRect(x: 0, y: 0, width: 640, height: 720)
        XCTAssertEqual(MotionSpec.duration(from: cell, to: cell.offsetBy(dx: 640, dy: 0)), MotionSpec.moveDuration)
        XCTAssertEqual(MotionSpec.duration(from: cell, to: CGRect(x: 0, y: 0, width: 1280, height: 1440)), MotionSpec.growDuration)
        XCTAssertEqual(MotionSpec.duration(from: CGRect(x: 0, y: 0, width: 1280, height: 1440), to: cell), MotionSpec.moveDuration)
        XCTAssertGreaterThan(MotionSpec.moveDuration, 0.20)
        XCTAssertGreaterThan(MotionSpec.growDuration, MotionSpec.moveDuration)
    }

    func testEaseIsMonotonicAndEndsAtOne() {
        XCTAssertEqual(MotionSpec.ease(0), 0, accuracy: 1e-9)
        XCTAssertEqual(MotionSpec.ease(1), 1, accuracy: 1e-9)
        var last = 0.0
        for i in 1...100 { let v = MotionSpec.ease(Double(i) / 100); XCTAssertGreaterThanOrEqual(v, last); XCTAssertLessThanOrEqual(v, 1); last = v }
    }
}
