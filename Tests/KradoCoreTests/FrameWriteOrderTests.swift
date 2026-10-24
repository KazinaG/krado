import Testing
import CoreGraphics
@testable import KradoCore

@Suite("Frame write order")
struct FrameWriteOrderTests {
    @Test("Write order and mixed resize bridge")
    func orderAndMixedResizeBridge() {
        let a = CGRect(x: 600, y: 600, width: 200, height: 200)
        let grow = CGRect(x: 0, y: 0, width: 800, height: 800)
        #expect(MotionSpec.steps(from: a, to: grow) == [
            .position(grow.origin), .size(grow.size), .position(grow.origin)
        ])
        let shrink = CGRect(x: 700, y: 700, width: 100, height: 100)
        #expect(MotionSpec.steps(from: a, to: shrink) == [.size(shrink.size), .position(shrink.origin)])
        let mixed = CGRect(x: 0, y: 0, width: 400, height: 100)
        #expect(MotionSpec.steps(from: a, to: mixed) == [
            .size(CGSize(width: 200, height: 100)), .position(mixed.origin),
            .size(mixed.size), .position(mixed.origin)
        ])
        #expect(!MotionSpec.Step.size(a.size).isNeeded(in: a))
        #expect(!MotionSpec.Step.position(a.origin).isNeeded(in: a))
    }

    @Test("Eight-column growth and shrink stay inside with monotonic edges")
    func eightColumnGrowthAndShrinkStayInsideWithMonotonicEdges() {
        for rows in [2, 4] {
            let area = CGRect(x: -5120, y: 40, width: 5120, height: CGFloat(rows) * 720)
            let cell = CGSize(width: area.width / 8, height: area.height / CGFloat(rows))
            for span in [CGSize(width: 4, height: 1), CGSize(width: 1, height: CGFloat(min(4, rows))),
                         CGSize(width: 2, height: 2)] {
                let small = CGRect(x: area.maxX - cell.width, y: area.maxY - cell.height,
                                   width: cell.width, height: cell.height)
                let large = CGRect(x: area.maxX - cell.width * span.width,
                                   y: area.maxY - cell.height * span.height,
                                   width: cell.width * span.width, height: cell.height * span.height)
                for (start, end) in [(small, large), (large, small)] {
                    var current = start
                    for tick in 1...24 {
                        let next = MotionSpec.frame(from: start, to: end, progress: Double(tick) / 24)
                        var actual = current
                        for step in MotionSpec.steps(from: current, to: next) {
                            guard step.isNeeded(in: actual) else { continue }
                            switch step {
                            case .size(let size): actual.size = size
                            case .position(let point): actual.origin = point
                            }
                            #expect(actual.minX >= area.minX)
                            #expect(actual.minY >= area.minY)
                            #expect(actual.maxX <= area.maxX)
                            #expect(actual.maxY <= area.maxY)
                        }
                        #expect(actual == next)
                        // Displayed endpoints follow a monotonic path; final snap is identical.
                        for (old, new, first, last) in [(current.minX, next.minX, start.minX, end.minX),
                                                       (current.minY, next.minY, start.minY, end.minY),
                                                       (current.maxX, next.maxX, start.maxX, end.maxX),
                                                       (current.maxY, next.maxY, start.maxY, end.maxY)] {
                            if last >= first { #expect(new >= old) }
                            else { #expect(new <= old) }
                        }
                        current = next
                    }
                    #expect(current == end)
                }
            }
        }
    }
}
