import XCTest
@testable import KradoCore

/// Kazina's macOS 27 screenshot: the green status circles render 27×25px (2x) although the
/// image is square; its 16.38pt size (18 × 0.91) is not pixel-aligned. The canvas must be
/// a whole-point square so the menu cannot snap width and height differently.
final class StatusIconCanvasTests: XCTestCase {
    func testCanvasIsWholePointSquare() {
        for (w, h) in [(18.0, 18.0), (15.0, 15.0), (17.0, 16.0)] {
            let side = StatusIconCanvas.side(baseWidth: w, baseHeight: h, factor: 0.91)
            XCTAssertEqual(side, side.rounded())
        }
        XCTAssertEqual(StatusIconCanvas.side(baseWidth: 18, baseHeight: 18, factor: 0.91), 16)
    }

    func testDrawRectKeepsAspectAndCenters() {
        let r = StatusIconCanvas.drawRect(side: 16, baseWidth: 17, baseHeight: 16)
        XCTAssertEqual(r.width / r.height, 17.0 / 16.0, accuracy: 0.001)
        XCTAssertEqual(r.minX + r.width / 2, 8, accuracy: 0.001)
        XCTAssertEqual(r.minY + r.height / 2, 8, accuracy: 0.001)
    }
}
