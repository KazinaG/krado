import AppKit
import ApplicationServices
#if KRADO_CI_HOOKS
import ServiceManagement
#endif
import KradoCore
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let screens = ScreenManager()
    private let loginItem = LoginItemManager()
    private var updaterController: SPUStandardUpdaterController?
    /// Sparkle is created stopped; scheduled checks begin only after onboarding.
    private var updaterStarted = false
    private let updaterDelegate = UpdaterDelegate()
    private let updateItem = NSMenuItem(title: "", action: #selector(checkForUpdates), keyEquivalent: "")
    private var monitor: DragMonitor!
    private var hotKeys: HotKeys!
    private var statusItem: NSStatusItem!
    private let permissionItem = NSMenuItem(title: "", action: #selector(showPermissionGuide), keyEquivalent: "")
    private let monitorItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let errorItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let requestItem = NSMenuItem(title: "", action: #selector(showPermissionGuide), keyEquivalent: "")
    private let loginToggle = NSMenuItem(title: "", action: #selector(toggleLoginItem), keyEquivalent: "")
    private let loginHint = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginError = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    #if KRADO_LOGIN_SWITCH_PROBE
    private let loginSwitch = LoginSwitchProbe()
    #endif
    private var displayItems: [NSMenuItem] = []
    private var permissionTimer: Timer?
    private lazy var permissionGuide = PermissionGuide(
        permissionChanged: { [weak self] in self?.refreshPermission() },
        loginOffer: { [weak self] in self?.loginItem.onboardingOffer ?? .alreadyOn },
        enableLogin: { [weak self] in
            self?.loginItem.enableFromOnboarding()
            self?.refreshLoginState()
        },
        closed: { [weak self] in self?.startUpdaterIfOnboarded(guideOpen: false) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["KRADO_LAB_LOG"] == "1" {
            FileHandle.standardOutput.write(Data("KRADO_LAB AXIsProcessTrusted=\(AXIsProcessTrusted())\n".utf8))
        }
        NSApp.setActivationPolicy(.accessory)
        monitor = DragMonitor(screens: screens, report: { [weak self] error in
            self?.errorItem.title = error ?? ""
            self?.errorItem.isHidden = error == nil
        }, stateDidChange: { [weak self] in
            self?.refreshStatus()
        }, didMoveWindow: { [weak self] in
            self?.hotKeys?.resetResizeAnchor()
        })
        hotKeys = HotKeys(screens: screens, report: { [weak self] error in
            self?.errorItem.title = error ?? ""
            self?.errorItem.isHidden = error == nil
        })
        if UpdaterPolicy.isConfigured(
            publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            feedURL: Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        ) {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: false, updaterDelegate: updaterDelegate, userDriverDelegate: nil
            )
        }
        #if KRADO_CI_HOOKS
        do {
            switch ProcessInfo.processInfo.environment["KRADO_CI_LOGIN"] {
            case "on": try SMAppService.mainApp.register()
            case "off": try SMAppService.mainApp.unregister()
            default: break
            }
        } catch { print("KRADO_CI login error: \(error)") }
        printLoginEvidence()
        // A runner signal requests readback after keyboard activation without changing state.
        let evidenceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let path = ProcessInfo.processInfo.environment["KRADO_CI_LOGIN_READBACK"],
                      FileManager.default.fileExists(atPath: path) else { return }
                try? FileManager.default.removeItem(atPath: path)
                self?.printLoginEvidence()
            }
        }
        RunLoop.main.add(evidenceTimer, forMode: .common)
        #endif
        buildMenu()
        reloadScreens()
        refreshLoginState()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reloadScreens),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        refreshPermission()
        #if !KRADO_CI_HOOKS
        if !AXIsProcessTrusted() { permissionGuide.show() }
        #endif
        #if KRADO_CI_HOOKS
        let evidence = "Accessibility trusted: \(AXIsProcessTrusted())\n"
        FileHandle.standardOutput.write(Data(evidence.utf8))
        if ProcessInfo.processInfo.environment["KRADO_CI_OPEN_MENU"] == "1" {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.statusItem.button?.performClick(nil)
            }
        }
        #endif
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermission() }
        }
        if let permissionTimer { RunLoop.main.add(permissionTimer, forMode: .common) }
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        let statusHeader = NSMenuItem.sectionHeader(title: L10n.text("Status"))
        menu.addItem(statusHeader)
        for item in [permissionItem, monitorItem, errorItem] { menu.addItem(item) }
        permissionItem.target = self
        // Enabled, actionless rows preserve palette colors instead of AppKit's disabled tint.
        monitorItem.isEnabled = true
        errorItem.isEnabled = false
        errorItem.isHidden = true
        requestItem.title = L10n.text("Accessibility Setup…")
        requestItem.image = symbol("questionmark.circle")
        requestItem.target = self
        menu.addItem(requestItem)
        menu.addItem(.separator())
        let startupHeader = NSMenuItem.sectionHeader(title: L10n.text("Startup"))
        menu.addItem(startupHeader)
        loginToggle.title = L10n.text("Launch at Login")
        loginToggle.target = self
        if LoginRowPresentation.keepsMenuOpenOnToggle {
            loginToggle.view = LoginRowView { [weak self] in self?.toggleLoginItem() }
        }
        #if KRADO_LOGIN_SWITCH_PROBE
        // Probe only: deliberately uses a view to measure AppKit menu limitations.
        let probeView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
        let label = NSTextField(labelWithString: L10n.text("Launch at Login"))
        label.frame = NSRect(x: 16, y: 7, width: 210, height: 20)
        loginSwitch.frame = NSRect(x: 242, y: 4, width: 48, height: 24)
        loginSwitch.target = self
        loginSwitch.action = #selector(toggleLoginItem)
        probeView.addSubview(label)
        probeView.addSubview(loginSwitch)
        loginToggle.view = probeView
        #endif
        loginHint.isEnabled = false
        loginError.isEnabled = false
        for item in [loginToggle, loginHint, loginError] { menu.addItem(item) }
        menu.addItem(.separator())
        let appHeader = NSMenuItem.sectionHeader(title: L10n.text("krado"))
        menu.addItem(appHeader)
        let reloadItem = NSMenuItem(title: L10n.text("Reload Displays"), action: #selector(reloadScreens), keyEquivalent: "")
        reloadItem.image = symbol("arrow.clockwise")
        reloadItem.target = self
        menu.addItem(reloadItem)
        updateItem.title = L10n.text("Check for Updates…")
        updateItem.image = symbol("arrow.down")
        updateItem.target = self
        refreshUpdateItem()
        menu.addItem(updateItem)
        addAction(L10n.text("About krado"), "info", #selector(showAbout), to: menu)
        addAction(L10n.text("krado on GitHub…"), "chevron.left.forwardslash.chevron.right", #selector(openGitHub), to: menu)
        addAction(L10n.text("Uninstall krado…"), "trash", #selector(uninstall), to: menu)
        menu.addItem(.separator())
        addAction(L10n.text("Quit krado"), "xmark.rectangle", #selector(quit), to: menu)
        Self.keepImagesVisible(in: menu)
        statusItem.menu = menu
    }

    /// macOS 27 hides SF Symbol menu-item images by default for apps linked on the
    /// macOS 26 SDK or later (AppKit release notes; NSMenuItem.preferredImageVisibility,
    /// NSMenuItemImageVisibilityVisible = 1). krado's menu relies on its icons, so ask
    /// for them to stay visible. Set by key so the code also builds with older SDKs;
    /// macOS 14–26 do not have the property and are unaffected.
    static func keepImagesVisible(in menu: NSMenu) {
        let selector = NSSelectorFromString("setPreferredImageVisibility:")
        for item in menu.items {
            if item.image != nil, item.responds(to: selector) {
                item.setValue(1, forKey: "preferredImageVisibility")
            }
            if let submenu = item.submenu { keepImagesVisible(in: submenu) }
        }
    }

    private func symbol(_ name: String) -> NSImage? {
        MenuActionSymbol.image(named: name)
    }

    private func addAction(_ title: String, _ symbolName: String, _ action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = symbol(symbolName)
        if action == #selector(quit) { item.keyEquivalent = "q" }
        menu.addItem(item)
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        loginToggle.view?.needsDisplay = true
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshPermission()
        refreshUpdateItem()
        refreshLoginState()
        Self.keepImagesVisible(in: menu)
    }

    private func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        requestItem.isHidden = displayedPermissionGranted
        if trusted {
            _ = monitor.start()
            hotKeys.start()
        } else {
            monitor.stop()
            hotKeys.stop()
        }
        refreshStatus()
        startUpdaterIfOnboarded(guideOpen: permissionGuide.isOpen)
    }

    /// Starts Sparkle's scheduled checks once Accessibility is allowed and the welcome
    /// guide is closed, so the update alert never interrupts onboarding.
    private func startUpdaterIfOnboarded(guideOpen: Bool) {
        #if !KRADO_CI_HOOKS
        guard let updaterController, UpdaterStartPolicy.shouldStartScheduledChecks(
            configured: true, alreadyStarted: updaterStarted,
            accessibilityGranted: AXIsProcessTrusted(), onboardingOpen: guideOpen
        ) else { return }
        updaterStarted = true
        updaterController.startUpdater()
        refreshUpdateItem()
        #endif
    }

    private func refreshUpdateItem() {
        switch UpdaterStartPolicy.manualCheck(configured: updaterController != nil, alreadyStarted: updaterStarted) {
        case .unavailable: updateItem.isEnabled = false
        case .startThenCheck: updateItem.isEnabled = true
        case .check: updateItem.isEnabled = updaterController?.updater.canCheckForUpdates ?? false
        }
    }

    private var displayedPermissionGranted: Bool {
        #if KRADO_CI_HOOKS
        if ProcessInfo.processInfo.environment["KRADO_CI_STATE"] == "permissionNeeded" { return false }
        #endif
        return AXIsProcessTrusted()
    }

    private func refreshStatus() {
        let state = statusState(permissionGranted: displayedPermissionGranted, tapActive: monitor.isRunning)
        let appearance = statusAppearance(for: state)
        permissionItem.action = state == .permissionNeeded ? #selector(showPermissionGuide) : nil
        permissionItem.isEnabled = true
        configureStatusRow(permissionItem, symbol: appearance.permission,
            title: "Accessibility",
            detail: state == .permissionNeeded ? "Not allowed — click to set up" : "Allowed",
            description: StatusPresentation.permissionDescription(for: state))
        configureStatusRow(monitorItem, symbol: appearance.monitor,
            title: "Window drags",
            detail: state == .watching ? "Ready to snap" : (state == .tapError ? "Unavailable — retrying" : "Paused"),
            description: StatusPresentation.monitorDescription(for: state))
        let description = L10n.text(StatusPresentation.menuBarDescription(for: state))
        statusItem.button?.image = StatusPresentation.menuBarImage(for: state, description: description)
        statusItem.button?.title = ""
        statusItem.button?.toolTip = description
        statusItem.button?.setAccessibilityLabel(description)
    }

    private func configureStatusRow(_ item: NSMenuItem, symbol: StatusSymbol, title: String, detail: String, description: String) {
        let title = L10n.text(title)
        let description = L10n.text(description)
        item.title = title
        item.attributedTitle = StatusPresentation.statusTitle(title, detail: L10n.text(detail))
        if item.action != nil {
            let image = NSImage(systemSymbolName: symbol.name, accessibilityDescription: description)
            image?.isTemplate = true
            item.image = image
        } else {
            // macOS 26 shrinks symbol images in menus (≈11pt); a redrawn image keeps its size (≈13pt on 15 and 26).
            if let base = StatusPresentation.image(for: symbol, description: description) {
                let side = StatusIconCanvas.side(baseWidth: base.size.width, baseHeight: base.size.height, factor: 0.91)
                let size = NSSize(width: side, height: side)
                let target = StatusIconCanvas.drawRect(side: side, baseWidth: base.size.width, baseHeight: base.size.height)
                let image = NSImage(size: size, flipped: false) { _ in
                    base.draw(in: target)
                    return true
                }
                image.isTemplate = false
                image.accessibilityDescription = description
                item.image = image
                #if KRADO_CI_HOOKS
                let ratioBase = String(format: "%.4f", base.size.width / base.size.height)
                let ratioScaled = String(format: "%.4f", size.width / size.height)
                print("KRADO_CI status image symbol=\(symbol.name) base=\(base.size.width)x\(base.size.height) scaled=\(size.width)x\(size.height) ratioBase=\(ratioBase) ratioScaled=\(ratioScaled)")
                #endif
            } else {
                item.image = nil
            }
        }
        item.toolTip = description
        item.setAccessibilityLabel(description)
    }

    private func refreshLoginState() {
        let state = loginItem.state
        let installed = loginItem.isInstalled
        let row = LoginRowPresentation(state: state, installed: installed)
        let title = L10n.text(row.title)
        let value = L10n.text(row.stateText)
        loginToggle.title = title
        loginToggle.state = .off
        loginToggle.isEnabled = row.enabled
        #if !KRADO_LOGIN_SWITCH_PROBE
        loginToggle.image = symbol("power")
        #endif
        loginToggle.badge = row.badge.map { NSMenuItemBadge(string: L10n.text($0)) }
        loginToggle.setAccessibilityLabel(title + "、" + value)
        loginToggle.setAccessibilityValue(value)
        (loginToggle.view as? LoginRowView)?.update(title: title, badge: row.badge.map { L10n.text($0) }, enabled: row.enabled)
        #if KRADO_LOGIN_SWITCH_PROBE
        loginToggle.badge = nil
        loginToggle.state = .off
        loginSwitch.state = state == .enabled ? .on : .off
        loginSwitch.isEnabled = row.enabled
        loginSwitch.setAccessibilityLabel(title + "、" + value)
        loginSwitch.setAccessibilityValue(value)
        #endif
        #if KRADO_CI_HOOKS
        #if KRADO_LOGIN_SWITCH_PROBE
        print("KRADO_CI login probe value=\(value) badge=none detail=none")
        #else
        print("KRADO_CI login badge=\(row.badge.map { L10n.text($0) } ?? "none") state=\(loginToggle.state == .off ? "off" : "on") axLabel=\(loginToggle.accessibilityLabel() ?? "") axValue=\(loginToggle.accessibilityValue() ?? "")")
        #endif
        #endif
        switch LoginItemPolicy.hint(state: state, installedInApplications: installed) {
        case .allowInSettings:
            loginHint.title = L10n.text("Allow krado in System Settings → Login Items")
            loginHint.isHidden = false
        case .moveToApplications:
            loginHint.title = L10n.text("Move krado to Applications to launch at login")
            loginHint.isHidden = false
        case nil:
            loginHint.isHidden = true
        }
        loginError.title = loginItem.errorMessage.map { L10n.format("⚠︎ Launch at Login: %@", $0) } ?? ""
        loginError.isHidden = loginItem.errorMessage == nil
    }

    @objc private func checkForUpdates() {
        #if !KRADO_CI_HOOKS
        guard let updaterController else { return }
        switch UpdaterStartPolicy.manualCheck(configured: true, alreadyStarted: updaterStarted) {
        case .unavailable: return
        case .startThenCheck:
            // An explicit request always works, even during onboarding.
            updaterStarted = true
            updaterController.startUpdater()
        case .check: break
        }
        updaterController.checkForUpdates(nil)
        #endif
    }

    @objc private func showPermissionGuide() { permissionGuide.show() }
    @objc private func uninstall() {
        // Stop watching first so nothing reacts while permission and settings go away.
        permissionTimer?.invalidate()
        monitor.stop()
        hotKeys.stop()
        Uninstaller.confirmAndRun()
        if permissionTimer?.isValid != true {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshPermission() }
            }
            if let permissionTimer { RunLoop.main.add(permissionTimer, forMode: .common) }
        }
        refreshPermission()
    }

    #if KRADO_CI_HOOKS
    private func printLoginEvidence() {
        print("KRADO_CI login status raw=\(loginItem.status.rawValue) state=\(loginItem.state)")
    }
    #endif

    @objc private func toggleLoginItem() {
        loginItem.toggle()
        refreshLoginState()
        #if KRADO_CI_HOOKS
        printLoginEvidence()
        #endif
    }

    @objc private func reloadScreens() {
        monitor.cancelDrag()
        hotKeys?.resetResizeAnchor()
        screens.reload()
        guard let menu = statusItem.menu else { return }
        displayItems.forEach { menu.removeItem($0) }
        displayItems = DisplayRowsPolicy.showsRows(for: screens.screens) ? screens.screens.map { screen in
            let layout = screen.geometry.layout
            let title = layout.columns == 1 && layout.rows == 1
                ? L10n.format("%@: 1 × 1 (no split)", screen.name)
                : L10n.format("%@: %d × %d (%d zones)", screen.name, layout.columns, layout.rows, layout.columns * layout.rows)
            let item = NSMenuItem(
                title: title,
                action: nil, keyEquivalent: ""
            )
            item.image = self.symbol(DisplayRowsPolicy.symbolName)
            item.isEnabled = false
            return item
        } : []
        let index = menu.index(of: requestItem)
        for (offset, item) in displayItems.enumerated() { menu.insertItem(item, at: index + offset) }
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "krado",
            .applicationVersion: version,
            .version: "",
            .credits: NSAttributedString(string: L10n.text("Drag a window. Drop it on the grid.\nFree & open source. MIT License.")),
        ])
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/KazinaG/krado") { NSWorkspace.shared.open(url) }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        permissionGuide.stop()
        monitor.stop()
        hotKeys.stop()
        screens.hideAll()
        NotificationCenter.default.removeObserver(self)
    }
}

@main
struct KradoApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

/// Sparkle's documented feed hook. Normally returns nil (Info.plist's public feed); an
/// opt-in test feed is honoured only for this repository's release assets.
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        UpdaterPolicy.testFeedURL(UserDefaults.standard.string(forKey: UpdaterPolicy.testFeedDefaultsKey))
    }
}

#if KRADO_LOGIN_SWITCH_PROBE
/// Evidence probe only; never part of a distributed build.
@MainActor
private final class LoginSwitchProbe: NSSwitch {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
#endif
