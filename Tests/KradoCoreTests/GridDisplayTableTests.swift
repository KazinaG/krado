import CoreGraphics
import Testing
@testable import KradoCore

/// Real displays at their "looks like" sizes, with the menu bar (25pt external, 37pt notched built-in)
/// and with or without a visible bottom Dock (about 70pt). The grid must not change when the Dock shows.
struct GridDisplayTableTests {
    struct Display: Sendable, CustomStringConvertible {
        let name: String
        let width: CGFloat
        let height: CGFloat
        let menuBar: CGFloat
        let columns: Int
        let rows: Int
        var description: String { name }
    }

    static let displays: [Display] = [
        Display(name: "MacBook Air 13 default", width: 1470, height: 956, menuBar: 37, columns: 2, rows: 1),
        Display(name: "MacBook Air 13 larger text", width: 1280, height: 832, menuBar: 37, columns: 2, rows: 1),
        Display(name: "4K looks like 1920x1080", width: 1920, height: 1080, menuBar: 25, columns: 2, rows: 2),
        Display(name: "4K looks like 2560x1440", width: 2560, height: 1440, menuBar: 25, columns: 2, rows: 2),
        Display(name: "4K native", width: 3840, height: 2160, menuBar: 25, columns: 4, rows: 2),
        Display(name: "5K default", width: 2560, height: 1440, menuBar: 25, columns: 2, rows: 2),
        Display(name: "5K native", width: 5120, height: 2880, menuBar: 25, columns: 6, rows: 2),
        Display(name: "Pro Display XDR default", width: 3008, height: 1692, menuBar: 25, columns: 4, rows: 2),
        Display(name: "BenQ RD280U default", width: 3008, height: 2005, menuBar: 25, columns: 4, rows: 2),
        Display(name: "BenQ RD280U larger", width: 2256, height: 1504, menuBar: 25, columns: 2, rows: 2),
        Display(name: "BenQ RD280U 2560", width: 2560, height: 1707, menuBar: 25, columns: 2, rows: 2),
        Display(name: "Portrait 4K native", width: 2160, height: 3840, menuBar: 25, columns: 2, rows: 3),
        Display(name: "Portrait 4K default", width: 1080, height: 1920, menuBar: 25, columns: 1, rows: 2),
        Display(name: "Ultrawide 3440x1440", width: 3440, height: 1440, menuBar: 25, columns: 4, rows: 2),
        Display(name: "Ultrawide 5120x2160", width: 5120, height: 2160, menuBar: 25, columns: 6, rows: 2),
        Display(name: "8K native", width: 7680, height: 4320, menuBar: 25, columns: 8, rows: 4),
    ]

    private func layout(_ w: CGFloat, _ h: CGFloat) -> GridLayout {
        GridPolicy.layout(for: ScreenDescriptor(isBuiltin: false, visibleSize: CGSize(width: w, height: h), name: ""))
    }

    @Test("Display table, Dock hidden, shown at the bottom, or shown at the side", arguments: displays)
    func table(display: Display) {
        let expected = GridLayout(columns: display.columns, rows: display.rows)
        let h = display.height - display.menuBar
        #expect(layout(display.width, h) == expected)            // Dock hidden (autohide)
        #expect(layout(display.width, h - 70) == expected)       // Dock at the bottom
        #expect(layout(display.width - 70, h) == expected)       // Dock on the side
        // No menu bar at all (auto-hidden) keeps the same grid too.
        #expect(layout(display.width, display.height) == expected)
    }

    /// v0.1.0 regression: the BenQ RD280U visible frame (3008 × 2005 minus a 25pt menu bar) gave
    /// floor(3008 / 900) = 3 lopsided columns × 2 rows. It is 4 × 2 again, as before the even-grid change.
    @Test func benQRD280UIsFourByTwo() {
        #expect(layout(3008, 1980) == GridLayout(columns: 4, rows: 2))
        #expect(layout(3008, 1968) == GridLayout(columns: 4, rows: 2))  // 37pt menu bar
    }

    @Test func columnsAreEvenCounts() {
        for w in stride(from: CGFloat(400), through: 8000, by: 10) {
            for h in [CGFloat(800), 1000, 1500, 2100, 3000, 4300] {
                #expect([1, 2, 4, 6, 8].contains(layout(w, h).columns))
            }
        }
    }

    @Test func columnBoundariesSitAwayFromCommonWidths() {
        #expect(layout(2779.99, 1600).columns == 2)
        #expect(layout(2780, 1600).columns == 4)
        #expect(layout(4219.99, 2200).columns == 4)
        #expect(layout(4220, 2200).columns == 6)
        #expect(layout(5659.99, 3000).columns == 6)
        #expect(layout(5660, 3000).columns == 8)
    }

    @Test func rowBoundariesIncludeChromeAllowance() {
        #expect(layout(5000, 2899.99).rows == 2)
        #expect(layout(5000, 2900).rows == 3)
        #expect(layout(7680, 3899.99).rows == 3)
        #expect(layout(7680, 3900).rows == 4)
    }

    @Test func zonesStayAtLeast640Wide() {
        for w in stride(from: CGFloat(1200), through: 8000, by: 10) {
            let l = layout(w, 1500)
            #expect(w / CGFloat(l.columns) >= 600)
        }
    }
}
