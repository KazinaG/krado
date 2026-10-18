import AppKit
import ApplicationServices
import KradoCore
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let screens = ScreenManager()
    private let loginItem = LoginItemManager()
    private var updaterController: SPUStandardUpdaterController?
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
    private let loginSettings = NSMenuItem(title: "", action: #selector(openLoginSettings), keyEquivalent: "")
    private let displaySeparator = NSMenuItem.separator()
    private var displayItems: [NSMenuItem] = []
    private var permissionTimer: Timer?
    private lazy var permissionGuide = PermissionGuide { [weak self] in self?.refreshPermission() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        monitor = DragMonitor(screens: screens, report: { [weak self] error in
            self?.errorItem.title = error ?? ""
            self?.errorItem.isHidden = error == nil
        }, stateDidChange: { [weak self] in
            self?.refreshStatus()
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
                startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
            )
        }
        buildMenu()
        reloadScreens()
        loginItem.applyFirstRunDefault()
        refreshLoginState()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reloadScreens),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        refreshPermission()
        if !AXIsProcessTrusted() { permissionGuide.show() }
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
        for item in [permissionItem, monitorItem, errorItem] { menu.addItem(item) }
        permissionItem.target = self
        // Enabled, actionless rows preserve palette colors instead of AppKit's disabled tint.
        monitorItem.isEnabled = true
        errorItem.isEnabled = false
        errorItem.isHidden = true
        menu.addItem(displaySeparator)
        requestItem.title = L10n.text("Accessibility Setup…")
        requestItem.target = self
        menu.addItem(requestItem)
        menu.addItem(.separator())
        loginToggle.title = L10n.text("Open at Login")
        loginToggle.target = self
        loginHint.isEnabled = false
        loginError.isEnabled = false
        loginSettings.title = L10n.text("Open Login Items Settings…")
        loginSettings.target = self
        for item in [loginToggle, loginHint, loginSettings, loginError] { menu.addItem(item) }
        menu.addItem(.separator())
        addAction(L10n.text("Reload Displays"), #selector(reloadScreens), to: menu)
        updateItem.title = L10n.text("Check for Updates…")
        updateItem.target = self
        updateItem.isEnabled = updaterController?.updater.canCheckForUpdates ?? false
        menu.addItem(updateItem)
        addAction(L10n.text("About krado"), #selector(showAbout), to: menu)
        addAction(L10n.text("krado on GitHub…"), #selector(openGitHub), to: menu)
        menu.addItem(.separator())
        addAction(L10n.text("Quit krado"), #selector(quit), to: menu)
        statusItem.menu = menu
    }

    private func addAction(_ title: String, _ action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateItem.isEnabled = updaterController?.updater.canCheckForUpdates ?? false
        refreshPermission()
        refreshLoginState()
    }

    private func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        requestItem.isHidden = trusted
        if trusted {
            _ = monitor.start()
            hotKeys.start()
        } else {
            monitor.stop()
            hotKeys.stop()
        }
        refreshStatus()
    }

    private func refreshStatus() {
        let state = statusState(permissionGranted: AXIsProcessTrusted(), tapActive: monitor.isRunning)
        let appearance = statusAppearance(for: state)
        permissionItem.action = state == .permissionNeeded ? #selector(showPermissionGuide) : nil
        permissionItem.isEnabled = true
        configureStatusRow(permissionItem, symbol: appearance.permission,
            title: StatusPresentation.permissionTitle(for: state),
            description: StatusPresentation.permissionDescription(for: state))
        configureStatusRow(monitorItem, symbol: appearance.monitor,
            title: StatusPresentation.monitorTitle(for: state),
            description: StatusPresentation.monitorDescription(for: state))
        let description = L10n.text(StatusPresentation.menuBarDescription(for: state))
        statusItem.button?.image = StatusPresentation.menuBarImage(for: state, description: description)
        statusItem.button?.title = ""
        statusItem.button?.toolTip = description
        statusItem.button?.setAccessibilityLabel(description)
    }

    private func configureStatusRow(_ item: NSMenuItem, symbol: StatusSymbol, title: String, description: String) {
        let title = L10n.text(title)
        let description = L10n.text(description)
        item.title = title
        item.attributedTitle = StatusPresentation.rowTitle(title)
        item.image = StatusPresentation.image(for: symbol, description: description)
        item.toolTip = description
        item.setAccessibilityLabel(description)
    }

    private func refreshLoginState() {
        let status = loginItem.status
        loginToggle.state = status == .enabled ? .on : (status == .requiresApproval ? .mixed : .off)
        loginToggle.isEnabled = loginItem.isInstalled || status == .enabled || status == .requiresApproval
        loginHint.isHidden = false
        if !loginItem.isInstalled {
            loginHint.title = L10n.text("Move krado to the Applications folder to open at login")
        } else {
            switch status {
            case .enabled: loginHint.isHidden = true
            case .requiresApproval:
                loginHint.title = L10n.text("⚠︎ Allow krado in System Settings → Login Items")
            case .notFound:
                loginHint.title = L10n.text("⚠︎ Login item unavailable. Try reinstalling krado in Applications.")
            case .notRegistered: loginHint.isHidden = true
            @unknown default:
                loginHint.title = L10n.text("⚠︎ Login item status is unavailable")
            }
        }
        loginSettings.isHidden = status != .requiresApproval
        loginError.title = loginItem.errorMessage.map { L10n.format("⚠︎ Open at Login: %@", $0) } ?? ""
        loginError.isHidden = loginItem.errorMessage == nil
    }

    @objc private func checkForUpdates() { updaterController?.checkForUpdates(nil) }

    @objc private func showPermissionGuide() { permissionGuide.show() }
    @objc private func toggleLoginItem() { loginItem.toggle(); refreshLoginState() }
    @objc private func openLoginSettings() { loginItem.openSettings() }

    @objc private func reloadScreens() {
        monitor.cancelDrag()
        screens.reload()
        guard let menu = statusItem.menu else { return }
        displayItems.forEach { menu.removeItem($0) }
        displayItems = screens.screens.map { screen in
            let layout = screen.geometry.layout
            let title = layout.columns == 1 && layout.rows == 1
                ? L10n.format("%@: 1 × 1 (no split)", screen.name)
                : L10n.format("%@: %d × %d (%d zones)", screen.name, layout.columns, layout.rows, layout.columns * layout.rows)
            let item = NSMenuItem(
                title: title,
                action: nil, keyEquivalent: ""
            )
            item.isEnabled = false
            return item
        }
        let index = menu.index(of: displaySeparator)
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
