import AppKit
@preconcurrency import ApplicationServices

@MainActor
final class PermissionGuide: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var pollTimer: Timer?
    private var closeTimer: Timer?
    private var didRequestPrompt = false
    private let permissionChanged: () -> Void
    private var statusLabel: NSTextField?
    private var settingsButton: NSButton?

    init(permissionChanged: @escaping () -> Void) {
        self.permissionChanged = permissionChanged
    }

    func show() {
        guard !AXIsProcessTrusted() else { permissionChanged(); return }
        closeTimer?.invalidate()
        if window == nil { buildWindow() }
        statusLabel?.stringValue = L10n.text("Waiting for Accessibility permission…")
        settingsButton?.isEnabled = true
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startPolling()
    }

    private func buildWindow() {
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        panel.title = L10n.text("Welcome to krado")
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        func label(_ key: String, bold: Bool = false) -> NSTextField {
            let label = NSTextField(wrappingLabelWithString: L10n.text(key))
            label.font = bold ? .boldSystemFont(ofSize: 19) : .systemFont(ofSize: 13)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 464).isActive = true
            return label
        }
        stack.addArrangedSubview(label("Give your windows a place.", bold: true))
        stack.addArrangedSubview(label("krado needs Accessibility permission to read and move other apps’ windows. It never reads keystrokes or screen contents and sends nothing over the network."))
        stack.addArrangedSubview(label("1. Click Open System Settings below.\n2. Enable krado in Privacy & Security → Accessibility.\n3. If krado is missing, click + and add krado.app from Applications."))
        let button = NSButton(title: L10n.text("Open System Settings"), target: self, action: #selector(openSettings))
        button.bezelStyle = .rounded
        stack.addArrangedSubview(button)
        settingsButton = button
        stack.addArrangedSubview(label("After a rebuild or update, you may need to remove the old krado entry with −, then add it again with +."))
        let status = label("Waiting for Accessibility permission…")
        status.textColor = .secondaryLabelColor
        stack.addArrangedSubview(status)
        statusLabel = status
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -28),
        ])
        panel.contentView = content
        let size = content.fittingSize
        panel.setContentSize(NSSize(width: 520, height: max(420, size.height)))
        window = panel
    }

    @objc private func openSettings() {
        // The only prompting path. Opening the guide and all polling are non-prompting.
        if !didRequestPrompt {
            didRequestPrompt = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AXIsProcessTrusted() else { return }
                self.permissionChanged()
                self.statusLabel?.stringValue = L10n.text("✓ All set! Accessibility is allowed.")
                self.settingsButton?.isEnabled = false
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                self.closeTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated { self?.window?.close() }
                }
            }
        }
        if let pollTimer { RunLoop.main.add(pollTimer, forMode: .common) }
    }

    func windowWillClose(_ notification: Notification) { stop() }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        closeTimer?.invalidate()
        closeTimer = nil
    }
}
