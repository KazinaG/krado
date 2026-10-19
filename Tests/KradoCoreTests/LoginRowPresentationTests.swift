import XCTest
@testable import KradoCore

final class LoginRowPresentationTests: XCTestCase {
    func testAllStatesAndInstallationPaths() {
        let cases: [(LoginItemState, String)] = [
            (.enabled, "On"),
            (.disabled, "Off"),
            (.needsApproval, "Needs approval"),
            (.unavailable, "Off"),
        ]
        for (state, text) in cases {
            for installed in [true, false] {
                let row = LoginRowPresentation(state: state, installed: installed)
                XCTAssertEqual(row.title, "Launch at Login")
                XCTAssertEqual(row.stateText, text)
                XCTAssertEqual(row.badge, row.stateText)
                XCTAssertEqual(row.enabled, installed || state == .enabled || state == .needsApproval)
            }
        }
    }
}
