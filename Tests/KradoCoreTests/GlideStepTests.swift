import Foundation
import Testing
@testable import KradoCore

@Suite("Time-based glide with fake AX windows and clock")
struct GlideStepTests {
    private enum Behavior: Equatable {
        case fast, slow, lagging, rounding, clamped, resizeMovesOrigin, failed, hung

        func size(_ requested: CGSize) -> CGSize {
            switch self {
            case .rounding:
                CGSize(width: (requested.width / 7).rounded() * 7,
                       height: (requested.height / 15).rounded() * 15)
            case .clamped:
                CGSize(width: min(1000, requested.width), height: min(600, requested.height))
            default: requested
            }
        }
    }

    private struct Clock {
        var now = 0.0
        let interval = 1 / 60.0
        mutating func nextCallback() {
            now = (floor((now + 1e-9) / interval) + 1) * interval
        }
    }

    private struct Placement {
        let time: Double
        let requested: CGRect
        let actual: CGRect
    }

    private struct FakeWindow {
        var frame: CGRect
        var placements: [Placement] = []
        var destinationRequests: [CGRect] = []
        var clock = Clock()
        var lastWriteDuration = 0.0
        var writes = 0

        mutating func glide(to target: CGRect, behavior: Behavior) {
            let start = frame
            let duration = MotionSpec.duration(from: start, to: target)
            func finish(_ window: inout FakeWindow) {
                // Exactly one final placement request, even when the app refuses
                // the target's size. AX success cannot override an app's max size.
                window.destinationRequests.append(target)
                window.frame = CGRect(origin: target.origin, size: behavior.size(target.size))
            }
            clock.nextCallback()
            while clock.now < duration {
                let sampledTime = clock.now
                let requested = MotionSpec.frame(from: start, to: target, progress: sampledTime / duration)
                // Lagging read-back reports the original size throughout the glide.
                var current = behavior == .lagging ? CGRect(origin: frame.origin, size: start.size) : frame
                var needsOriginCorrection = false
                for step in MotionSpec.steps(from: current, to: requested) {
                    if clock.now >= duration { finish(&self); return }
                    let forcePosition: Bool
                    if case .position = step { forcePosition = needsOriginCorrection } else { forcePosition = false }
                    guard forcePosition || step.isNeeded(in: current) else { continue }
                    writes += 1
                    let milliseconds: Double = behavior == .hung ? 81 : behavior == .slow ? Double(20 + (writes % 3) * 10) : 1
                    lastWriteDuration = milliseconds / 1000
                    clock.now += lastWriteDuration
                    switch step {
                    case .size(let size):
                        frame.size = behavior.size(size)
                        if behavior == .resizeMovesOrigin { frame.origin.x += 7; frame.origin.y += 5 }
                        current.size = size
                        needsOriginCorrection = true
                    case .position(let point):
                        frame.origin = point
                        current.origin = point
                        needsOriginCorrection = false
                    }
                    if MotionSpec.action(success: behavior != .failed, writeMilliseconds: milliseconds) == .snapToDestination {
                        finish(&self)
                        return
                    }
                }
                placements.append(Placement(time: sampledTime, requested: requested, actual: frame))
                if clock.now >= duration { finish(&self); return }
                clock.nextCallback()
            }
            finish(&self)
        }
    }

    @Test("Every responsive app glides through 4x growth, including full-height targets")
    func growthKeepsItsTimeAndRequestedOrigin() {
        let cases = [
            (CGRect(x: 1920, y: 360, width: 640, height: 360), CGRect(x: 0, y: 0, width: 1280, height: 720)),
            (CGRect(x: 1920, y: 1080, width: 640, height: 360), CGRect(x: 640, y: 360, width: 1280, height: 720))
        ]
        for (start, target) in cases {
            for behavior in [Behavior.fast, .slow, .lagging, .rounding, .clamped, .resizeMovesOrigin] {
                check(start: start, target: target, behavior: behavior)
            }
        }
    }

    @Test("Horizontal, vertical, mixed-axis shrink/grow and move paths")
    func otherPaths() {
        let start = CGRect(x: 1920, y: 1080, width: 640, height: 360)
        for target in [CGRect(x: 1280, y: 1080, width: 1280, height: 360),
                       CGRect(x: 1920, y: 720, width: 640, height: 720),
                       CGRect(x: 640, y: 360, width: 800, height: 200),
                       CGRect(x: 640, y: 360, width: 320, height: 180),
                       start.offsetBy(dx: -640, dy: -360)] {
            for behavior in [Behavior.fast, .slow, .resizeMovesOrigin] {
                check(start: start, target: target, behavior: behavior)
            }
        }
    }

    private func check(start: CGRect, target: CGRect, behavior: Behavior) {
        var fake = FakeWindow(frame: start)
        fake.glide(to: target, behavior: behavior)
        #expect(fake.placements.count >= 2)
        for placement in fake.placements {
            let curve = MotionSpec.frame(from: start, to: target,
                                         progress: placement.time / MotionSpec.duration(from: start, to: target))
            #expect(placement.requested == curve)
            #expect(abs(placement.actual.minX - curve.minX) <= 1)
            #expect(abs(placement.actual.minY - curve.minY) <= 1)
            #expect(placement.actual.size == behavior.size(curve.size))
        }
        #expect(fake.destinationRequests == [target])
        #expect(fake.frame.origin == target.origin)
        #expect(fake.frame.size == behavior.size(target.size))
        // Display quantisation, or one in-flight write, can cross the deadline.
        let duration = MotionSpec.duration(from: start, to: target)
        #expect(fake.clock.now >= duration)
        #expect(fake.clock.now <= duration + max(fake.clock.interval, fake.lastWriteDuration) + 1e-9)
    }

    @Test("An AX error or a single write over 80 ms immediately attempts the destination once")
    func abortsOnlyForErrorOrHungWrite() {
        let start = CGRect(x: 1920, y: 360, width: 640, height: 360)
        let target = CGRect(x: 0, y: 0, width: 1280, height: 720)
        for behavior in [Behavior.failed, .hung] {
            var fake = FakeWindow(frame: start)
            fake.glide(to: target, behavior: behavior)
            #expect(fake.writes == 1)
            #expect(fake.placements.isEmpty)
            #expect(fake.destinationRequests == [target])
            #expect(fake.frame == target)
            #expect(fake.clock.now < MotionSpec.growDuration)
        }
    }
}
