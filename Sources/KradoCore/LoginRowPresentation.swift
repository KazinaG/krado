/// Text keys and semantic appearance only; ServiceManagement is read by the app.
public struct LoginRowPresentation: Equatable, Sendable {
    /// The row is a custom view so toggling does not dismiss the menu.
    public static let keepsMenuOpenOnToggle = true
    /// Every state word the row can show. The row is sized for the widest one,
    /// so toggling never moves or clips the text.
    public static let allStateTexts = ["On", "Off", "Needs approval"]
    /// On and Off share one capsule width, so toggling never resizes the capsule.
    public static let onOffTexts = ["On", "Off"]
    public let title = "Launch at Login"
    /// The visible state word, drawn inside the state capsule at the trailing edge
    /// of the row and also used as the VoiceOver value.
    public let stateText: String
    public let enabled: Bool

    public init(state: LoginItemState, installed: Bool) {
        switch state {
        case .enabled:
            stateText = "On"
        case .needsApproval:
            stateText = "Needs approval"
        case .disabled, .unavailable:
            stateText = "Off"
        }
        enabled = LoginItemPolicy.toggleAction(state: state, installedInApplications: installed) != .moveToApplications
    }
}
