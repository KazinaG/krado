import Foundation
import Testing
@testable import KradoCore

@Suite("Glide step fallback")
struct GlideStepTests {
    private enum Behavior: Equatable {
        case follows, slow, lagging, clamped, resizeMovesOrigin
    }

    private enum Event: Equatable {
        case write(MotionSpec.Step)
        case snap(CGRect)
    }

    private struct FakeWindow {
        var frame: CGRect
        var events: [Event] = []
        var completedFrames: [CGRect] = []

        mutating func glide(from start: CGRect, to destination: CGRect, behavior: Behavior) {
            for tick in 1...20 {
                let requested = MotionSpec.frame(from: start, to: destination, progress: Double(tick) / 20)
                var sizeMilliseconds = 0.0
                for step in MotionSpec.steps(from: frame, to: requested) {
                    guard step.isNeeded(in: frame) else { continue }
                    events.append(.write(step))
                    var milliseconds = 1.0
                    switch step {
                    case .position(let point): frame.origin = point
                    case .size(let size):
                        // Fail only after several successful frames, to catch a fallback
                        // that quietly continues the rest of an already-started glide.
                        let fault = tick >= 4
                        if fault && behavior == .slow { milliseconds = 20 }
                        if !fault || (behavior != .lagging && behavior != .clamped) { frame.size = size }
                        if behavior == .resizeMovesOrigin { frame.origin.x += 7; frame.origin.y += 5 }
                        sizeMilliseconds += milliseconds
                    }
                    let action = MotionSpec.action(after: step, success: true, writeMilliseconds: milliseconds,
                                                   totalSizeWriteMilliseconds: sizeMilliseconds,
                                                   actualSize: frame.size, refreshRate: 60)
                    if action == .snapToDestination {
                        // A single destination placement request, with no further glide
                        // position write. A clamping app may still refuse the final size.
                        events.append(.snap(destination))
                        frame.origin = destination.origin
                        if behavior != .clamped { frame.size = destination.size }
                        return
                    }
                }
                // AX size and position are separate writes. Record each completed
                // display step; the shrink/move/grow bridge is tested separately.
                completedFrames.append(frame)
            }
        }
    }

    @Test("Small-window growth snaps immediately on slow, lagging or clamped size writes")
    func failedGrowthNeverSlidesAStaleSize() {
        // Geometry fixtures independent of GridPolicy: 2×2 cells, each 640×360.
        // The first target spans the full display height; the second is interior.
        // Both formerly used a centre anchor on at least one axis.
        let fullHeightGrid = GridGeometry(workArea: CGRect(x: 0, y: 0, width: 2560, height: 720),
                                          layout: GridLayout(columns: 4, rows: 2))
        let interiorGrid = GridGeometry(workArea: CGRect(x: 0, y: 0, width: 2560, height: 1440),
                                        layout: GridLayout(columns: 4, rows: 4))
        let cases = [
            (CGRect(x: 1920, y: 360, width: 640, height: 360),
             fullHeightGrid.frame(for: GridSpan(columns: 0..<2, rows: 0..<2))),
            (CGRect(x: 1920, y: 1080, width: 640, height: 360),
             interiorGrid.frame(for: GridSpan(columns: 1..<3, rows: 1..<3)))
        ]
        for (start, target) in cases {
            #expect(target.width == start.width * 2)
            #expect(target.height == start.height * 2)
            for behavior in [Behavior.slow, .lagging, .clamped] {
                var fake = FakeWindow(frame: start)
                fake.glide(from: start, to: target, behavior: behavior)
                #expect(fake.completedFrames.count == 3)
                for (index, frame) in fake.completedFrames.enumerated() {
                    #expect(frame == MotionSpec.frame(from: start, to: target, progress: Double(index + 1) / 20))
                }
                #expect(fake.events.last == .snap(target))
                #expect(fake.events.filter { if case .snap = $0 { true } else { false } }.count == 1)
                // The rejected resize is followed immediately by the destination.
                if fake.events.count >= 2 {
                    let beforeSnap = fake.events[fake.events.count - 2]
                    if case .write(.size) = beforeSnap {} else { Issue.record("Moved after a rejected size write") }
                }
                #expect(fake.frame.origin == target.origin)
                if behavior != .clamped { #expect(fake.frame == target) }
            }
        }
    }

    @Test("Healthy growth, horizontal and vertical stretches keep every interpolated frame")
    func healthyWindowsKeepGliding() {
        let start = CGRect(x: 1920, y: 1080, width: 640, height: 360)
        for target in [CGRect(x: 640, y: 360, width: 1280, height: 720),
                       CGRect(x: 1280, y: 1080, width: 1280, height: 360),
                       CGRect(x: 1920, y: 720, width: 640, height: 720),
                       start.offsetBy(dx: -640, dy: -360)] {
            for behavior in [Behavior.follows, .resizeMovesOrigin] {
                var fake = FakeWindow(frame: start)
                fake.glide(from: start, to: target, behavior: behavior)
                #expect(fake.completedFrames.count == 20)
                #expect(!fake.events.contains(.snap(target)))
                for (index, frame) in fake.completedFrames.enumerated() {
                    #expect(frame == MotionSpec.frame(from: start, to: target, progress: Double(index + 1) / 20))
                }
                #expect(fake.frame == target)
            }
        }
    }

    @Test("A refused shrink bridge snaps before moving")
    func refusedBridgeDoesNotMove() {
        let actual = CGRect(x: 600, y: 600, width: 500, height: 500)
        let requested = CGRect(x: 0, y: 0, width: 800, height: 200)
        let steps = MotionSpec.steps(from: actual, to: requested)
        #expect(steps.first == .size(CGSize(width: 500, height: 200)))
        let action = MotionSpec.action(after: steps[0], success: true, writeMilliseconds: 1,
                                       totalSizeWriteMilliseconds: 1, actualSize: actual.size, refreshRate: 60)
        #expect(action == .snapToDestination)
    }
}
