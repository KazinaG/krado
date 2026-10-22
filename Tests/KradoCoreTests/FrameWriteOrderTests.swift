import Testing
import CoreGraphics
@testable import KradoCore

@Suite("Frame write order")
struct FrameWriteOrderTests {
    @Test("Clamped size stays in the visible area")
    func clampedSizeStaysInVisibleArea() {
        let area = CGRect(x: -1000, y: 40, width: 1000, height: 800)
        let requested = CGRect(x: -1000, y: 40, width: 500, height: 400)
        let size = CGSize(width: 600, height: 500)
        let point = MotionSpec.anchoredPosition(for: requested, actualSize: size,
                                               anchor: CGPoint(x: 1, y: 1), in: area)
        #expect(area.contains(CGRect(origin: point, size: size)))
    }

    @Test("Write order and mixed resize bridge")
    func orderAndMixedResizeBridge() {
        let a = CGRect(x: 600, y: 600, width: 200, height: 200)
        #expect(MotionSpec.positionFirst(from: a, to: CGRect(x: 0, y: 0, width: 800, height: 800)))
        #expect(!MotionSpec.positionFirst(from: a, to: CGRect(x: 700, y: 700, width: 100, height: 100)))
        #expect(MotionSpec.bridgeSize(from: a, to: CGRect(x: 0, y: 0, width: 400, height: 100)) == CGSize(width: 200, height: 100))
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
                        let bridge = MotionSpec.bridgeSize(from: current, to: next)
                        let intermediates = [CGRect(origin: current.origin, size: bridge),
                                             CGRect(origin: next.origin, size: bridge), next]
                        for frame in intermediates {
                            #expect(frame.minX >= area.minX)
                            #expect(frame.minY >= area.minY)
                            #expect(frame.maxX <= area.maxX)
                            #expect(frame.maxY <= area.maxY)
                        }
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
