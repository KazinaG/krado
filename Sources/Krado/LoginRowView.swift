import AppKit
import KradoCore

@MainActor
final class LoginRowView: NSView {
    private let activate: () -> Void
    private let icon = NSImageView()
    private var title = ""
    private var badge: String?
    private var enabled = true
    private var hovered = false

    private static var rowHeight: CGFloat {
        if #available(macOS 26, *) { return 24 }
        return 22
    }

    private static var iconSize: CGFloat {
        if #available(macOS 26, *) { return 14 }
        return 16
    }

    // Measured against native rows in CI menu-shots (1x): glyph and title x match.
    private static var nativeWidth: CGFloat {
        if #available(macOS 26, *) { return 260 }
        return 259
    }

    private static var iconX: CGFloat { 18 }

    private static var titleX: CGFloat {
        if #available(macOS 26, *) { return 39 }
        return 42
    }

    private var badgeFont: NSFont {
        NSFont.systemFont(ofSize: LoginBadgeMetrics.fontSize, weight: LoginBadgeMetrics.isBold ? .bold : .medium)
    }

    init(activate: @escaping () -> Void) {
        self.activate = activate
        // The menu sizes itself from this initial width; 260/259 match the native row with a badge (CI menu-shots).
        super.init(frame: NSRect(x: 0, y: 0, width: Self.nativeWidth, height: Self.rowHeight))
        autoresizingMask = [.width]
        icon.image = MenuActionSymbol.image(named: "power")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        addSubview(icon)
        // The enclosing menu item supplies the action and accessibility metadata.
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    func update(title: String, badge: String?, enabled: Bool) {
        self.title = title
        self.badge = badge
        self.enabled = enabled
        let font = NSFont.menuFont(ofSize: 0)
        let titleWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let badgeWidth = badge.map {
            LoginBadgeMetrics.capsuleWidth(textWidth: ($0 as NSString).size(withAttributes: [.font: badgeFont]).width)
        } ?? 0
        // Start the title at the native image-column boundary. Let the menu
        // stretch this content-sized row to accommodate its other items.
        let width = Self.titleX + titleWidth + (badge == nil ? 0 : 16 + badgeWidth) + 49
        setFrameSize(NSSize(width: max(Self.nativeWidth, ceil(width)), height: Self.rowHeight))
        needsLayout = true
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hovered = false
        needsDisplay = true
        if window == nil { removeKeyMonitor() } else { installKeyMonitor() }
    }

    // Custom menu views lose AppKit's keyboard activation. While the menu is open,
    // Return, Enter or Space toggles the row when the keyboard has highlighted it.
    private var keyMonitor: Any?

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.handlesActivationKey(event) else { return event }
            self.activate()
            self.needsDisplay = true
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handlesActivationKey(_ event: NSEvent) -> Bool {
        guard enabled, window != nil, enclosingMenuItem?.isHighlighted == true else { return false }
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard mods.isEmpty else { return false }
        // 36 Return, 76 keypad Enter, 49 Space
        return [36, 76, 49].contains(event.keyCode)
    }

    override func keyDown(with event: NSEvent) {
        if handlesActivationKey(event) { activate(); needsDisplay = true } else { super.keyDown(with: event) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        guard enabled, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        activate()
    }

    override func layout() {
        super.layout()
        let size = Self.iconSize
        icon.frame = NSRect(x: Self.iconX, y: (bounds.height - size) / 2, width: size, height: size)
    }

    override func draw(_ dirtyRect: NSRect) {
        #if KRADO_CI_HOOKS
        if let path = ProcessInfo.processInfo.environment["KRADO_CI_LOGIN_GEOMETRY"], let window {
            let rect = window.convertToScreen(convert(bounds, to: nil))
            let screenTop = NSScreen.screens[0].frame.maxY
            let evidence: [String: Any] = [
                "x": rect.minX, "y": screenTop - rect.maxY,
                "width": rect.width, "height": rect.height,
                "label": badge ?? "", "nativeBadge": enclosingMenuItem?.badge != nil
            ]
            if let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]) {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
            print("KRADO_CI draw login label=\(badge ?? "none") frame=\(frame) dirty=\(dirtyRect)")
        }
        #endif
        let highlighted = enabled && (enclosingMenuItem?.isHighlighted == true || hovered)
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 4, yRadius: 4).fill()
        }
        let foreground: NSColor = !enabled ? .disabledControlTextColor : highlighted ? .selectedMenuItemTextColor : .labelColor
        icon.contentTintColor = foreground

        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: Self.titleX, y: (bounds.height - titleSize.height) / 2), withAttributes: attributes)

        if let badge {
            let badgeColor: NSColor = !enabled ? .disabledControlTextColor : highlighted ? .selectedMenuItemTextColor : .labelColor
            let attributes: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: badgeColor]
            let size = (badge as NSString).size(withAttributes: attributes)
            let width = LoginBadgeMetrics.capsuleWidth(textWidth: size.width)
            let height = LoginBadgeMetrics.height
            let capsule = NSRect(x: (bounds.maxX - 17 - width).rounded(),
                y: ((bounds.height - height) / 2).rounded(), width: width, height: height)
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: capsule, xRadius: height / 2, yRadius: height / 2).fill()
            let x = LoginBadgeMetrics.textX(capsuleMinX: capsule.minX, capsuleWidth: width, textWidth: size.width)
            (badge as NSString).draw(at: NSPoint(x: x, y: capsule.minY + (height - size.height) / 2), withAttributes: attributes)
        }
    }
}
