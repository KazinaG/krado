/// Text keys and semantic appearance only; ServiceManagement is read by the app.
public struct LoginRowPresentation: Equatable, Sendable {
    /// The row is a custom view so toggling does not dismiss the menu.
    public static let keepsMenuOpenOnToggle = true
    /// State words retained for accessibility and CI evidence.
    public static let allStateTexts = ["On", "Off", "Needs approval"]
    public let title = "Launch at Login"
    /// The state word used as the VoiceOver value.
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
