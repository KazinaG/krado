import Testing
@testable import KradoCore

// Kazina 10/26 03:29 "ステータスのところはなぜホバーされるの？" and 03:33 "ステータス行は押せない行にする".
@Suite struct StatusRowPolicyTests {
    @Test(arguments: StatusState.allCases)
    func informationRowsCannotBeChosen(state: StatusState) {
        #expect(!StatusRowPolicy.monitorRowEnabled)
        // Accessibility is choosable only while choosing it does something (opens the guide).
        #expect(StatusRowPolicy.permissionRowEnabled(for: state) == (state == .permissionNeeded))
    }
}
