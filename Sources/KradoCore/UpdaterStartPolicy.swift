import Foundation

/// When Sparkle's scheduled update checks may begin. Pure logic; never touches Sparkle.
///
/// The updater is created without starting, so no "new version available" alert can
/// interrupt first-run onboarding. Scheduled checks start only once Accessibility is
/// allowed and the welcome guide is closed. "Check for Updates…" always works.
public enum UpdaterStartPolicy {
    public static func shouldStartScheduledChecks(
        configured: Bool,
        alreadyStarted: Bool,
        accessibilityGranted: Bool,
        onboardingOpen: Bool
    ) -> Bool {
        configured && !alreadyStarted && accessibilityGranted && !onboardingOpen
    }

    public enum ManualCheck: Equatable, Sendable {
        /// No valid feed/key: the menu item stays disabled.
        case unavailable
        /// The user asked explicitly, so start the updater first, then check.
        case startThenCheck
        case check
    }

    public static func manualCheck(configured: Bool, alreadyStarted: Bool) -> ManualCheck {
        guard configured else { return .unavailable }
        return alreadyStarted ? .check : .startThenCheck
    }
}
