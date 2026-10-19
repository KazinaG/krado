import CoreGraphics
import Testing
@testable import KradoCore

/// README promise: zones are never too small; a typical 4K display tops out at 4 columns;
/// a MacBook Air's built-in screen is never split top/bottom (at its default size).
struct GridPhilosophyTests {
    private func layout(_ w: CGFloat, _ h: CGFloat) -> GridLayout {
        GridPolicy.layout(for: ScreenDescriptor(isBuiltin: false, visibleSize: CGSize(width: w, height: h), name: ""))
    }

    @Test func macBookAirIsNotSplitTopAndBottom() {
        #expect(layout(1470, 919).rows == 1)   // 13" default, menu bar subtracted
        #expect(layout(1710, 1079).rows == 1)  // 15" default / 13" "More Space"
    }

    @Test func fourKTopsOutAtFourColumnsTwoRows() {
        #expect(layout(1920, 1050) == GridLayout(columns: 2, rows: 2))  // 4K default (looks like 1920×1080)
        #expect(layout(2560, 1410) == GridLayout(columns: 2, rows: 2))
        #expect(layout(3840, 2130) == GridLayout(columns: 4, rows: 2))  // 4K at native size
    }

    @Test func largerScreensGetMoreEvenZones() {
        #expect(layout(3008, 1667) == GridLayout(columns: 4, rows: 2))  // Pro Display XDR default
        #expect(layout(5120, 2855) == GridLayout(columns: 6, rows: 2))  // 5K native
        #expect(layout(6016, 3359) == GridLayout(columns: 8, rows: 3))  // 6K native
        #expect(layout(7680, 4295) == GridLayout(columns: 8, rows: 4))  // 8K native
        #expect(layout(1080, 1890) == GridLayout(columns: 1, rows: 2))  // portrait 4K default
        #expect(layout(2160, 3810) == GridLayout(columns: 2, rows: 3))  // portrait 4K native
        #expect(layout(3440, 1410) == GridLayout(columns: 4, rows: 2))  // ultrawide
        #expect(layout(5120, 1410) == GridLayout(columns: 6, rows: 2))  // super ultrawide
    }

    @Test func zonesAreNeverTooSmall() {
        for w in stride(from: CGFloat(400), through: 8000, by: 200) {
            for h in stride(from: CGFloat(400), through: 8000, by: 200) {
                let l = layout(w, h)
                #expect(l.columns <= 8 && l.rows <= 4)
                // Never too small: every zone stays at least 450 × 450 points.
                #expect(w / CGFloat(l.columns) >= 450 || l.columns == 1)
                #expect(h / CGFloat(l.rows) >= 450 || l.rows == 1)
            }
        }
    }
}
