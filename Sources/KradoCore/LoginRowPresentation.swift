/// Text keys and semantic appearance only; ServiceManagement is read by the app.
public struct LoginRowPresentation: Equatable, Sendable {
    /// The row is a custom view so toggling does not dismiss the menu.
    public static let keepsMenuOpenOnToggle = true
    public let title = "Launch at Login"
    public let stateText: String
    public let badge: String?
    public let enabled: Bool

    public init(state: LoginItemState, installed: Bool) {
        let text: String
        switch state {
        case .enabled:
            text = "On"
        case .needsApproval:
            text = "Needs approval"
        case .disabled, .unavailable:
            text = "Off"
        }
        stateText = text
        badge = text
        enabled = LoginItemPolicy.toggleAction(state: state, installedInApplications: installed) != .moveToApplications
    }
}
