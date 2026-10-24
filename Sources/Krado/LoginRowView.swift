import AppKit
import KradoCore

@MainActor
final class LoginRowView: NSView {
    private let activate: () -> Void
    private let icon = NSImageView()
    private var title = ""
    private var badge: String?
    private var enabled = true

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
        // Only AppKit's highlight (shared by mouse and keyboard); no hover state of our own.
        let highlighted = LoginRowStyle.isHighlighted(menuItemHighlighted: enclosingMenuItem?.isHighlighted == true, enabled: enabled)
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

        var capsule = NSRect.zero
        var pillColor = NSColor.clear, badgeColor = NSColor.clear
        if let badge {
            let style = LoginRowStyle.badge(highlighted: highlighted, enabled: enabled)
            badgeColor = Self.color(style.text)
            pillColor = Self.color(style.pill).withAlphaComponent(style.pillAlpha)
            let attributes: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: badgeColor]
            let size = (badge as NSString).size(withAttributes: attributes)
            let width = LoginBadgeMetrics.capsuleWidth(textWidth: size.width)
            let height = LoginBadgeMetrics.height
            capsule = NSRect(x: (bounds.maxX - 17 - width).rounded(),
                y: ((bounds.height - height) / 2).rounded(), width: width, height: height)
            pillColor.setFill()
            NSBezierPath(roundedRect: capsule, xRadius: height / 2, yRadius: height / 2).fill()
            let x = LoginBadgeMetrics.textX(capsuleMinX: capsule.minX, capsuleWidth: width, textWidth: size.width)
            (badge as NSString).draw(at: NSPoint(x: x, y: capsule.minY + (height - size.height) / 2), withAttributes: attributes)
        }
        #if KRADO_CI_HOOKS
        writeCIEvidence(highlighted: highlighted, capsule: capsule, pill: pillColor, text: badgeColor)
        print("KRADO_CI draw login label=\(badge ?? "none") highlighted=\(highlighted) frame=\(frame) dirty=\(dirtyRect)")
        #endif
    }

    private static func color(_ ink: LoginRowStyle.Ink) -> NSColor {
        switch ink {
        case .label: return .labelColor
        case .disabled: return .disabledControlTextColor
        case .selectedText: return .selectedMenuItemTextColor
        case .white: return .white
        case .badgeInk:
            let c = LoginRowStyle.badgeInk
            return NSColor(srgbRed: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1)
        }
    }

    #if KRADO_CI_HOOKS
    private static var lastHighlightedColors: [String: [Int]]?

    private func writeCIEvidence(highlighted: Bool, capsule: NSRect, pill: NSColor, text: NSColor) {
        guard let path = ProcessInfo.processInfo.environment["KRADO_CI_LOGIN_GEOMETRY"], let window else { return }
        let screenTop = NSScreen.screens[0].frame.maxY
        func screenRect(_ local: NSRect) -> [String: Double] {
            let rect = window.convertToScreen(convert(local, to: nil))
            return ["x": rect.minX, "y": screenTop - rect.maxY, "width": rect.width, "height": rect.height]
        }
        if highlighted {
            // sRGB 0–255, the pill composited over the highlight as drawn.
            func rgb(_ color: NSColor, over base: NSColor? = nil) -> [Int] {
                let c = color.usingColorSpace(.sRGB) ?? color
                let a = Double(c.alphaComponent)
                let top = [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent)]
                var under = [0.0, 0.0, 0.0]
                if let b = base?.usingColorSpace(.sRGB) {
                    under = [Double(b.redComponent), Double(b.greenComponent), Double(b.blueComponent)]
                }
                return (0..<3).map { i in
                    let mixed: Double = top[i] * a + under[i] * (1 - a)
                    return Int((mixed * 255).rounded())
                }
            }
            let highlight = NSColor.selectedContentBackgroundColor
            let pillRGB = rgb(pill, over: highlight)
            let pillColor = NSColor(srgbRed: CGFloat(pillRGB[0]) / 255, green: CGFloat(pillRGB[1]) / 255, blue: CGFloat(pillRGB[2]) / 255, alpha: 1)
            Self.lastHighlightedColors = ["highlight": rgb(highlight), "pill": pillRGB, "text": rgb(text, over: pillColor)]
        }
        var evidence: [String: Any] = screenRect(bounds)
        evidence["capsule"] = screenRect(capsule)
        evidence["label"] = badge ?? ""
        evidence["nativeBadge"] = enclosingMenuItem?.badge != nil
        evidence["highlighted"] = highlighted
        if let colors = Self.lastHighlightedColors { evidence["colors"] = colors }
        if let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
    #endif
}
