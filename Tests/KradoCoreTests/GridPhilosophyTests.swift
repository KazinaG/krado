import CoreGraphics
import Testing
@testable import KradoCore

/// Grid constraints, checked against one rule with no special cases:
/// MacBook Air built-in is never split top/bottom; a 3:2 display at 3008 × 2005 is 4 × 2;
/// typical-width 4K tops out at 4 columns; zones are never tiny or absurdly tall and thin.
/// The rule reads the whole screen size, so the menu bar and Dock cannot flip the grid.
struct GridPhilosophyTests {
    struct Display: Sendable, CustomStringConvertible {
        let name: String
        let width: CGFloat
        let height: CGFloat
        let columns: Int
        let rows: Int
        var description: String { name }
    }

    static let displays: [Display] = [
        Display(name: "MacBook Air 13", width: 1470, height: 956, columns: 2, rows: 1),
        Display(name: "MacBook Air 13 larger text", width: 1280, height: 832, columns: 2, rows: 1),
        Display(name: "MacBook Air 15", width: 1710, height: 1112, columns: 2, rows: 1),
        Display(name: "4K default 1920", width: 1920, height: 1080, columns: 2, rows: 1),
        Display(name: "2560 × 1440", width: 2560, height: 1440, columns: 4, rows: 2),
        Display(name: "4K native", width: 3840, height: 2160, columns: 4, rows: 2),
        Display(name: "5K native", width: 5120, height: 2880, columns: 8, rows: 4),
        Display(name: "6K default", width: 3008, height: 1692, columns: 4, rows: 2),
        Display(name: "6K native", width: 6016, height: 3384, columns: 8, rows: 4),
        Display(name: "3:2 2256", width: 2256, height: 1504, columns: 2, rows: 2),
        Display(name: "3:2 2560", width: 2560, height: 1707, columns: 4, rows: 2),
        Display(name: "3:2 3008", width: 3008, height: 2005, columns: 4, rows: 2),
        Display(name: "3:2 3840", width: 3840, height: 2560, columns: 4, rows: 2),
        Display(name: "Portrait 4K", width: 1080, height: 1920, columns: 1, rows: 2),
        Display(name: "Portrait 4K native", width: 2160, height: 3840, columns: 2, rows: 4),
        Display(name: "Ultrawide 3440", width: 3440, height: 1440, columns: 4, rows: 2),
        Display(name: "Ultrawide 5120", width: 5120, height: 2160, columns: 8, rows: 2),
        Display(name: "8K", width: 7680, height: 4320, columns: 8, rows: 4),
    ]

    private func layout(_ w: CGFloat, _ h: CGFloat) -> GridLayout {
        GridPolicy.layout(for: ScreenDescriptor(isBuiltin: false, visibleSize: CGSize(width: w, height: h), name: ""))
    }

    @Test("Display table", arguments: displays)
    func table(display: Display) {
        #expect(layout(display.width, display.height) == GridLayout(columns: display.columns, rows: display.rows))
        // Built-in or external makes no difference: one rule for every screen.
        #expect(GridPolicy.layout(for: ScreenDescriptor(isBuiltin: true, visibleSize: CGSize(width: display.width, height: display.height), name: "x"))
            == GridLayout(columns: display.columns, rows: display.rows))
    }

    @Test func hardConstraints() {
        #expect(layout(1470, 956).rows == 1)
        #expect(layout(1280, 832).rows == 1)
        #expect(layout(1710, 1112).rows == 1)
        #expect(layout(1920, 1080).columns <= 4)
        #expect(layout(2560, 1440).columns <= 4)
        #expect(layout(3840, 2160).columns <= 4)
        #expect(layout(3008, 2005) == GridLayout(columns: 4, rows: 2))
    }

    @Test func zonesAreNeverTinyOrNeedleThin() {
        for w in stride(from: CGFloat(800), through: 8000, by: 40) {
            for h in stride(from: CGFloat(800), through: 8000, by: 40) {
                let l = layout(w, h)
                let cw = w / CGFloat(l.columns), ch = h / CGFloat(l.rows)
                #expect(l.columns <= 8 && l.rows <= 4)
                #expect(cw >= GridPolicy.minimumCellWidth || l.columns == 1)
                #expect(ch >= GridPolicy.minimumCellHeight || l.rows == 1)
            }
        }
    }
}
