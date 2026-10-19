import Foundation
import Testing
@testable import KradoCore

private final class FakeSystem {
    var trusted = false
    var trustChecks = 0
    var prompts = 0
    var settingsOpens = 0
    var system: AccessibilitySystem {
        AccessibilitySystem(
            isTrusted: { [unowned self] in self.trustChecks += 1; return self.trusted },
            requestPrompt: { [unowned self] in self.prompts += 1 },
            openSettings: { [unowned self] in self.settingsOpens += 1 }
        )
    }
}

private final class MemoryRecord: PromptRecord { var promptShown = false }

@Suite("Accessibility onboarding (system prompt at most once)")
struct AccessibilityOnboardingTests {
    @Test("Showing the guide and polling never prompt")
    func showingAndPollingNeverPrompt() {
        let fake = FakeSystem()
        let flow = AccessibilityOnboarding(system: fake.system, record: MemoryRecord())
        flow.begin()
        for _ in 0..<30 { _ = flow.poll() }
        #expect(fake.prompts == 0)
        #expect(fake.settingsOpens == 0)
        #expect(fake.trustChecks == 31)
        #expect(flow.phase == .waiting)
    }

    @Test("The first click raises only the system prompt, not Settings on top of it")
    func firstClickPromptsOnly() {
        let fake = FakeSystem()
        let flow = AccessibilityOnboarding(system: fake.system, record: MemoryRecord())
        flow.begin()
        #expect(flow.openSettingsTapped() == .systemPrompt)
        #expect(fake.prompts == 1)
        #expect(fake.settingsOpens == 0)
    }

    @Test("Later clicks open Settings through the URL and never prompt again")
    func laterClicksOpenSettings() {
        let fake = FakeSystem()
        let flow = AccessibilityOnboarding(system: fake.system, record: MemoryRecord())
        flow.begin()
        for _ in 0..<5 { flow.openSettingsTapped() }
        #expect(fake.prompts == 1)
        #expect(fake.settingsOpens == 4)
    }

    @Test("A relaunch (or update) with the same record never prompts a second time")
    func promptOncePerInstall() {
        let fake = FakeSystem()
        let record = MemoryRecord()
        let first = AccessibilityOnboarding(system: fake.system, record: record)
        first.begin()
        first.openSettingsTapped()
        let relaunched = AccessibilityOnboarding(system: fake.system, record: record)
        relaunched.begin()
        #expect(relaunched.openSettingsTapped() == .openSettings)
        #expect(fake.prompts == 1)
    }

    @Test("The guide advances once on grant and polling stops")
    func advancesOnGrant() {
        let fake = FakeSystem()
        let flow = AccessibilityOnboarding(system: fake.system, record: MemoryRecord())
        flow.begin()
        flow.openSettingsTapped()
        #expect(!flow.poll())
        #expect(flow.shouldKeepPolling)
        fake.trusted = true
        #expect(flow.poll())
        #expect(flow.phase == .granted)
        #expect(!flow.shouldKeepPolling)
        let checks = fake.trustChecks
        #expect(!flow.poll())
        #expect(fake.trustChecks == checks)
        #expect(fake.prompts == 1)
    }

    @Test("Clicking after permission is already on does nothing system-side")
    func alreadyTrusted() {
        let fake = FakeSystem()
        fake.trusted = true
        let flow = AccessibilityOnboarding(system: fake.system, record: MemoryRecord())
        flow.begin()
        #expect(flow.phase == .granted)
        #expect(flow.openSettingsTapped() == .alreadyTrusted)
        #expect(fake.prompts == 0)
        #expect(fake.settingsOpens == 0)
    }

    @Test("The record persists in UserDefaults under krado's key")
    func defaultsRecord() throws {
        let suite = "krado.tests.prompt.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let record = DefaultsPromptRecord(defaults: defaults)
        #expect(!record.promptShown)
        record.promptShown = true
        #expect(DefaultsPromptRecord(defaults: defaults).promptShown)
        #expect(defaults.bool(forKey: "KradoAccessibilityPromptShown"))
    }

    private static func source(_ path: String) -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return (try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)) ?? ""
    }

    @Test("The prompting API appears in exactly one place in the app")
    func singlePromptCallSite() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Krado")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".swift") }
        #expect(!files.isEmpty)
        let count = files.reduce(0) { total, file in
            let text = Self.source("Sources/Krado/\(file)")
            return total + text.components(separatedBy: "AXIsProcessTrustedWithOptions(").count - 1
        }
        #expect(count == 1)
        #expect(Self.source("Sources/Krado/PermissionGuide.swift").contains("onboarding.openSettingsTapped()"))
    }
}
