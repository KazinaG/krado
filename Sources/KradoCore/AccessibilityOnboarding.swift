import Foundation

/// The system calls the onboarding needs, injected so tests never touch TCC.
public struct AccessibilitySystem {
    /// Non-prompting trust check (`AXIsProcessTrusted()`).
    public var isTrusted: () -> Bool
    /// The prompting check (`AXIsProcessTrustedWithOptions(prompt: true)`). macOS's alert
    /// has its own "Open System Settings" button, which opens the pane and dismisses it.
    public var requestPrompt: () -> Void
    /// Opens Privacy & Security → Accessibility through the public settings URL.
    public var openSettings: () -> Void

    public init(isTrusted: @escaping () -> Bool, requestPrompt: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.isTrusted = isTrusted
        self.requestPrompt = requestPrompt
        self.openSettings = openSettings
    }
}

/// Remembers that the system prompt was already raised, across launches (UserDefaults
/// in the app, so a relaunch or an update never raises a second one).
public protocol PromptRecord: AnyObject {
    var promptShown: Bool { get set }
}

public final class DefaultsPromptRecord: PromptRecord {
    public static let key = "KradoAccessibilityPromptShown"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var promptShown: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}

/// The welcome guide's permission flow.
///
/// - The prompting call happens only from the guide's button, and at most once ever
///   (persisted). It is not combined with opening Settings, so macOS's own alert is the
///   only thing on screen and closes through its own button. Raising the alert and
///   opening Settings together left the alert behind after krado was turned on.
/// - Every later click opens Settings through the public URL only.
/// - Polling uses only the non-prompting check and stops once trust is seen.
public final class AccessibilityOnboarding {
    public enum Phase: Equatable, Sendable { case waiting, granted }
    public enum ButtonAction: Equatable, Sendable { case alreadyTrusted, systemPrompt, openSettings }

    public private(set) var phase: Phase = .waiting
    private let system: AccessibilitySystem
    private let record: PromptRecord

    public init(system: AccessibilitySystem, record: PromptRecord) {
        self.system = system
        self.record = record
    }

    /// Showing the guide never prompts.
    public func begin() {
        phase = system.isTrusted() ? .granted : .waiting
    }

    /// "Open System Settings" in the guide: one user action, at most one system call.
    @discardableResult
    public func openSettingsTapped() -> ButtonAction {
        if system.isTrusted() {
            phase = .granted
            return .alreadyTrusted
        }
        if !record.promptShown {
            record.promptShown = true
            system.requestPrompt()
            return .systemPrompt
        }
        system.openSettings()
        return .openSettings
    }

    /// One poll tick. Returns true exactly once, on the tick that sees the grant; the
    /// caller then advances the guide and stops its timer.
    public func poll() -> Bool {
        guard phase == .waiting else { return false }
        guard system.isTrusted() else { return false }
        phase = .granted
        return true
    }

    public var shouldKeepPolling: Bool { phase == .waiting }
}
