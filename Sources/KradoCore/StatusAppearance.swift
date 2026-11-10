/// Semantic status shared by the menu and offscreen previews.
public enum StatusState: String, CaseIterable, Sendable {
    case watching
    case permissionNeeded
    case paused
    case stopped
    case tapError
}

/// Platform-independent color intent; AppKit resolves these to system colors.
public enum StatusColorRole: Sendable, Equatable {
    case adaptive
    case success
    case warning
    case secondary
}

public struct StatusSymbol: Sendable, Equatable {
    public let name: String
    public let color: StatusColorRole

    public init(name: String, color: StatusColorRole) {
        self.name = name
        self.color = color
    }
}

public struct StatusAppearance: Sendable, Equatable {
    public let menuBar: StatusSymbol
    public let permission: StatusSymbol
    public let monitor: StatusSymbol
}

/// Resolve permission first so an inactive event tap never hides missing access.
public func statusState(permissionGranted: Bool, tapActive: Bool) -> StatusState {
    guard permissionGranted else { return .permissionNeeded }
    return tapActive ? .watching : .tapError
}

/// A pure mapping that keeps status shapes and color intent consistent everywhere.
public func statusAppearance(for state: StatusState) -> StatusAppearance {
    let menuBar: StatusSymbol
    let monitor: StatusSymbol
    switch state {
    case .watching:
        menuBar = StatusSymbol(name: "square.grid.2x2.fill", color: .adaptive)
        monitor = StatusSymbol(name: "record.circle.fill", color: .success)
    case .permissionNeeded:
        menuBar = StatusSymbol(name: "exclamationmark.triangle.fill", color: .warning)
        monitor = StatusSymbol(name: "pause.circle.fill", color: .secondary)
    case .paused:
        menuBar = StatusSymbol(name: "pause.circle.fill", color: .secondary)
        monitor = StatusSymbol(name: "pause.circle.fill", color: .secondary)
    case .stopped:
        menuBar = StatusSymbol(name: "stop.circle", color: .secondary)
        monitor = StatusSymbol(name: "pause.circle.fill", color: .secondary)
    case .tapError:
        menuBar = StatusSymbol(name: "exclamationmark.circle", color: .secondary)
        monitor = StatusSymbol(name: "exclamationmark.circle", color: .secondary)
    }
    let permission = state == .permissionNeeded
        ? StatusSymbol(name: "exclamationmark.triangle.fill", color: .warning)
        : StatusSymbol(name: "checkmark.circle.fill", color: .success)
    return StatusAppearance(menuBar: menuBar, permission: permission, monitor: monitor)
}

/// Which Status rows can be chosen (Kazina 10/26 03:33: the status rows are rows you
/// cannot press, so they do not highlight on hover). Only a row that does something
/// when chosen is enabled: Accessibility while permission is needed (it opens the
/// setup guide). Apple HIG Menus: an unavailable item appears dimmed and does not
/// respond to interactions.
public enum StatusRowPolicy {
    public static func permissionRowEnabled(for state: StatusState) -> Bool { state == .permissionNeeded }
    public static let monitorRowEnabled = false
}
