import AppKit

@MainActor
final class LoginRowView: NSView {
    private let activate: () -> Void
    private let icon = NSImageView()
    private var title = ""
    private var badge: String?
    private var enabled = true
    private var hovered = false

    init(activate: @escaping () -> Void) {
        self.activate = activate
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        autoresizingMask = [.width]
        icon.image = MenuActionSymbol.image(named: "power")
        icon.imageScaling = .scaleNone
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
        let badgeWidth = ((badge ?? "") as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
        setFrameSize(NSSize(width: max(frame.width, 54 + titleWidth + 24 + badgeWidth + 24), height: frame.height))
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

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = enabled && (enclosingMenuItem?.isHighlighted == true || hovered)
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 4, yRadius: 4).fill()
        }
        let foreground: NSColor = !enabled ? .disabledControlTextColor : highlighted ? .selectedMenuItemTextColor : .labelColor
        icon.contentTintColor = foreground
        icon.frame = NSRect(x: 12, y: 0, width: 18, height: bounds.height)

        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: 36, y: (bounds.height - titleSize.height) / 2), withAttributes: attributes)

        if let badge {
            let badgeColor: NSColor = !enabled ? .disabledControlTextColor : highlighted ? .selectedMenuItemTextColor : .secondaryLabelColor
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: badgeColor]
            let size = (badge as NSString).size(withAttributes: attributes)
            let capsule = NSRect(x: bounds.maxX - 16 - size.width - 12,
                y: (bounds.height - 16) / 2, width: size.width + 12, height: 16)
            badgeColor.withAlphaComponent(enabled ? 0.12 : 0.06).setFill()
            NSBezierPath(roundedRect: capsule, xRadius: 8, yRadius: 8).fill()
            (badge as NSString).draw(at: NSPoint(x: capsule.minX + 6, y: (bounds.height - size.height) / 2), withAttributes: attributes)
        }
    }
}
