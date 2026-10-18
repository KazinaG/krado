import Testing
@testable import KradoCore

@Suite("Visual status")
struct StatusAppearanceTests {
    @Test("Each state has an unambiguous menu bar shape and color", arguments: [
        StatusAppearanceCase(state: .watching, symbol: "square.grid.2x2.fill", color: .adaptive),
        StatusAppearanceCase(state: .permissionNeeded, symbol: "exclamationmark.triangle.fill", color: .warning),
        StatusAppearanceCase(state: .paused, symbol: "pause.circle.fill", color: .secondary),
        StatusAppearanceCase(state: .stopped, symbol: "stop.circle", color: .secondary),
        StatusAppearanceCase(state: .tapError, symbol: "exclamationmark.circle", color: .secondary),
    ])
    func menuBar(test: StatusAppearanceCase) {
        #expect(statusAppearance(for: test.state).menuBar == StatusSymbol(name: test.symbol, color: test.color))
    }

    @Test("Permission and monitor rows preserve independent signals", arguments: StatusState.allCases)
    func menuRows(state: StatusState) {
        let appearance = statusAppearance(for: state)
        #expect(appearance.permission == (state == .permissionNeeded
            ? StatusSymbol(name: "exclamationmark.triangle.fill", color: .warning)
            : StatusSymbol(name: "checkmark.circle.fill", color: .success)))
        switch state {
        case .watching:
            #expect(appearance.monitor == StatusSymbol(name: "record.circle.fill", color: .success))
        case .tapError:
            #expect(appearance.monitor == StatusSymbol(name: "exclamationmark.circle", color: .secondary))
        case .permissionNeeded, .paused, .stopped:
            #expect(appearance.monitor == StatusSymbol(name: "pause.circle.fill", color: .secondary))
        }
    }

    @Test("Permission takes precedence over the event tap", arguments: [
        StatusResolutionCase(permission: false, tap: false, expected: .permissionNeeded),
        StatusResolutionCase(permission: false, tap: true, expected: .permissionNeeded),
        StatusResolutionCase(permission: true, tap: false, expected: .tapError),
        StatusResolutionCase(permission: true, tap: true, expected: .watching),
    ])
    func resolution(test: StatusResolutionCase) {
        #expect(statusState(permissionGranted: test.permission, tapActive: test.tap) == test.expected)
    }
}

struct StatusAppearanceCase: Sendable {
    let state: StatusState
    let symbol: String
    let color: StatusColorRole
}

struct StatusResolutionCase: Sendable {
    let permission: Bool
    let tap: Bool
    let expected: StatusState
}
