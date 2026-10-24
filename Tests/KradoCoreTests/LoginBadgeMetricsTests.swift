import Testing
@testable import KradoCore

@Suite struct LoginBadgeMetricsTests {
    @Test func indicatorHasFixedCircularGeometry() {
        #expect(LoginBadgeMetrics.diameter == 16)
        #expect(LoginBadgeMetrics.strokeWidth == 1)
        #expect(LoginBadgeMetrics.symbolSize == 9)
        #expect(LoginBadgeMetrics.symbolInset() * 2 + LoginBadgeMetrics.symbolSize == LoginBadgeMetrics.diameter)
        // Every state uses the same circle, regardless of its localized AX text.
        for state in [LoginItemState.enabled, .disabled, .needsApproval, .unavailable] {
            let row = LoginRowPresentation(state: state, installed: true)
            #expect(!row.stateText.isEmpty)
            #expect(row.badge != nil)
        }
    }

    @Test func launchAtLoginKeepsMenuOpen() {
        #expect(LoginRowPresentation.keepsMenuOpenOnToggle)
    }
}
