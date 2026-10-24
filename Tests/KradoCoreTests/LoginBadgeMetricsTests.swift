import XCTest
import Testing
@testable import KradoCore

/// Native NSMenuItemBadge, measured in CI menu-shots at 1x (macOS 15 and 26):
/// "オフ" ink ≈16–18pt wide inside a ≈34×16–17pt capsule, i.e. ≈8pt padding per side,
/// and a lighter, smaller face than 11pt bold.
final class LoginBadgeMetricsTests: XCTestCase {
    func testCapsuleFitsTextPlusNativePadding() {
        for textWidth in [16.0, 17.4, 18.0, 30.2] {
            let width = LoginBadgeMetrics.capsuleWidth(textWidth: textWidth)
            XCTAssertGreaterThanOrEqual(width, ceil(textWidth) + 2 * LoginBadgeMetrics.horizontalPadding)
        }
        XCTAssertGreaterThanOrEqual(LoginBadgeMetrics.horizontalPadding, 8)
        XCTAssertEqual(LoginBadgeMetrics.capsuleWidth(textWidth: 18), 34, accuracy: 1)
    }

    func testFontMatchesNativeBadgeNotBold11() {
        XCTAssertLessThanOrEqual(LoginBadgeMetrics.fontSize, 10)
        XCTAssertFalse(LoginBadgeMetrics.isBold)
    }

    func testTextIsCenteredInCapsule() {
        let x = LoginBadgeMetrics.textX(capsuleMinX: 100, capsuleWidth: 34, textWidth: 18)
        XCTAssertEqual(x, 108, accuracy: 0.01)
    }
}

final class LoginRowStayOpenTests: XCTestCase {
    /// Toggling Launch at Login must not dismiss the menu (custom view row, not a plain item).
    func testLaunchAtLoginKeepsMenuOpen() {
        XCTAssertTrue(LoginRowPresentation.keepsMenuOpenOnToggle)
    }
}

@Suite struct LoginBadgeCheckmarkTests {
    @Test(arguments: [12.0, 18, 30.2])
    func checkmarkFitsBesideCenteredText(textWidth: Double) {
        let content = LoginBadgeMetrics.contentWidth(textWidth: textWidth, showsCheckmark: true)
        #expect(content == textWidth + LoginBadgeMetrics.checkmarkWidth + LoginBadgeMetrics.checkmarkGap)
        let width = LoginBadgeMetrics.capsuleWidth(textWidth: textWidth, showsCheckmark: true)
        #expect(width >= ceil(content) + 2 * LoginBadgeMetrics.horizontalPadding)
        #expect(width > LoginBadgeMetrics.capsuleWidth(textWidth: textWidth))
        let x = LoginBadgeMetrics.textX(capsuleMinX: 100, capsuleWidth: width, textWidth: content)
        #expect(abs((x - 100) - (100 + width - x - content)) < 0.001)
    }
}
