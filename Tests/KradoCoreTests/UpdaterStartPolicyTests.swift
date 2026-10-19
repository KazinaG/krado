import Foundation
import Testing
@testable import KradoCore

@Suite("Updater start policy (no update alert during onboarding)")
struct UpdaterStartPolicyTests {
    @Test("Scheduled checks start once Accessibility is allowed and the guide is closed")
    func startsAfterOnboarding() {
        #expect(UpdaterStartPolicy.shouldStartScheduledChecks(
            configured: true, alreadyStarted: false, accessibilityGranted: true, onboardingOpen: false))
    }

    @Test("No scheduled check before Accessibility is allowed, even with the guide closed")
    func notBeforePermission() {
        #expect(!UpdaterStartPolicy.shouldStartScheduledChecks(
            configured: true, alreadyStarted: false, accessibilityGranted: false, onboardingOpen: false))
        #expect(!UpdaterStartPolicy.shouldStartScheduledChecks(
            configured: true, alreadyStarted: false, accessibilityGranted: false, onboardingOpen: true))
    }

    @Test("No scheduled check while the welcome guide is still open after permission")
    func notWhileGuideOpen() {
        #expect(!UpdaterStartPolicy.shouldStartScheduledChecks(
            configured: true, alreadyStarted: false, accessibilityGranted: true, onboardingOpen: true))
    }

    @Test("Never started twice, never started without a valid feed and key")
    func idempotentAndConfigured() {
        #expect(!UpdaterStartPolicy.shouldStartScheduledChecks(
            configured: true, alreadyStarted: true, accessibilityGranted: true, onboardingOpen: false))
        #expect(!UpdaterStartPolicy.shouldStartScheduledChecks(
            configured: false, alreadyStarted: false, accessibilityGranted: true, onboardingOpen: false))
    }

    @Test("Check for Updates… always works when updates are configured")
    func manualCheck() {
        #expect(UpdaterStartPolicy.manualCheck(configured: true, alreadyStarted: false) == .startThenCheck)
        #expect(UpdaterStartPolicy.manualCheck(configured: true, alreadyStarted: true) == .check)
        #expect(UpdaterStartPolicy.manualCheck(configured: false, alreadyStarted: false) == .unavailable)
    }

    private static let appSource: String = {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return (try? String(contentsOf: root.appendingPathComponent("Sources/Krado/App.swift"), encoding: .utf8)) ?? ""
    }()

    @Test("The app creates Sparkle's controller without starting it")
    func controllerNotStartedAtLaunch() {
        #expect(!Self.appSource.isEmpty)
        #expect(Self.appSource.contains("startingUpdater: false"))
        #expect(!Self.appSource.contains("startingUpdater: true"))
        #expect(Self.appSource.contains("UpdaterStartPolicy.shouldStartScheduledChecks"))
    }
}
