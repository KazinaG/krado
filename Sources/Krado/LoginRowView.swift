import AppKit

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
        return 17
    }

    // Measured against native rows in CI menu-shots (1x): glyph and title x match.
    private static var iconX: CGFloat { 18 }

    private static var titleX: CGFloat {
        if #available(macOS 26, *) { return 39 }
        return 42
    }

    private var badgeFont: NSFont {
        NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
    }

    init(activate: @escaping () -> Void) {
        self.activate = activate
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: Self.rowHeight))
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
            ($0 as NSString).size(withAttributes: [.font: badgeFont]).width + 14
        } ?? 0
        // Start the title at the native image-column boundary. Let the menu
        // stretch this content-sized row to accommodate its other items.
        let width = Self.titleX + titleWidth + (badge == nil ? 0 : 16 + badgeWidth) + 49
        setFrameSize(NSSize(width: ceil(width), height: Self.rowHeight))
        needsLayout = true
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hovered = false
        needsDisplay = true
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
            let badgeColor: NSColor = !enabled ? .disabledControlTextColor : highlighted ? .selectedMenuItemTextColor : .secondaryLabelColor
            let attributes: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: badgeColor]
            let size = (badge as NSString).size(withAttributes: attributes)
            let capsule = NSRect(x: bounds.maxX - 17 - size.width - 14,
                y: (bounds.height - 16) / 2, width: size.width + 14, height: 16)
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(roundedRect: capsule, xRadius: 8, yRadius: 8).fill()
            (badge as NSString).draw(at: NSPoint(x: capsule.minX + 7, y: (bounds.height - size.height) / 2), withAttributes: attributes)
        }
    }
}
