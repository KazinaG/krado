import Testing
@testable import KradoCore

struct DisplayRowsPolicyTests {
    @Test func noScreens() {
        #expect(!DisplayRowsPolicy.showsRows(for: [String]()))
    }

    @Test func oneScreen() {
        #expect(!DisplayRowsPolicy.showsRows(for: ["Display 1"]))
    }

    @Test func twoScreens() {
        #expect(DisplayRowsPolicy.showsRows(for: ["Display 1", "Display 2"]))
    }

    @Test func threeScreens() {
        #expect(DisplayRowsPolicy.showsRows(for: ["Display 1", "Display 2", "Display 3"]))
    }

    @Test func displayRowSymbol() {
        #expect(DisplayRowsPolicy.symbolName == "display")
    }
}
