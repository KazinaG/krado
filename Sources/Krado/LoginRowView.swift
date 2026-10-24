import AppKit
import KradoCore

@MainActor
final class LoginRowView: NSView {
    private let activate: () -> Void
    private let icon = NSImageView()
    private var title = ""
    private var stateText = ""
    private var enabled = true
    private var state: LoginItemState = .disabled
    private var highlight = LoginRowStyle.Highlight()
    private var pointerTracking: NSTrackingArea?

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

    init(activate: @escaping () -> Void) {
        self.activate = activate
        // The menu sizes itself from this initial width; 260/259 match the native row (CI menu-shots).
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

    /// `allStateTexts` are the localized words for every state; the row is sized for the widest.
    func update(title: String, stateText: String, allStateTexts: [String], state: LoginItemState, enabled: Bool) {
        self.title = title
        self.stateText = stateText
        self.enabled = enabled
        self.state = state
        // Size once, before menu tracking. Never reset the frame while toggling:
        // AppKit owns the stretched width of its view item.
        if window == nil {
            let font = NSFont.menuFont(ofSize: 0)
            func width(_ text: String) -> Double { Double((text as NSString).size(withAttributes: [.font: font]).width) }
            let rowWidth = LoginRowLayout.width(titleX: Double(Self.titleX), titleWidth: width(title),
                                                stateWidths: (allStateTexts + [stateText]).map(width),
                                                minimum: Double(Self.nativeWidth))
            let size = NSSize(width: rowWidth, height: Self.rowHeight)
            if frame.size != size { setFrameSize(size) }
        }
        needsLayout = true
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsDisplay = true
        if window == nil {
            highlight.menuDidClose()
            removeKeyMonitor()
        } else { installKeyMonitor() }
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
        highlight.clickedInside()
        activate()
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTracking { removeTrackingArea(pointerTracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        pointerTracking = area
    }

    override func mouseExited(with event: NSEvent) {
        highlight.mouseExited()
        needsDisplay = true
    }

    func menuWillHighlight(thisRow: Bool?) {
        highlight.menuWillHighlight(thisRow: thisRow)
        needsDisplay = true
    }

    func menuDidClose() {
        highlight.menuDidClose()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let size = Self.iconSize
        icon.frame = NSRect(x: Self.iconX, y: (bounds.height - size) / 2, width: size, height: size)
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = highlight.isHighlighted(menuItemHighlighted: enclosingMenuItem?.isHighlighted == true, enabled: enabled)
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 4, yRadius: 4).fill()
        }
        let foreground = Self.color(LoginRowStyle.ink(highlighted: highlighted, enabled: enabled))
        icon.contentTintColor = foreground

        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: Self.titleX, y: (bounds.height - titleSize.height) / 2), withAttributes: attributes)

        // The state word uses the title's font and ink, right-aligned like a native menu value.
        let stateSize = (stateText as NSString).size(withAttributes: attributes)
        let stateRect = NSRect(x: LoginRowLayout.stateX(rowMaxX: Double(bounds.maxX), stateWidth: Double(stateSize.width)),
                               y: Double((bounds.height - stateSize.height) / 2),
                               width: Double(stateSize.width), height: Double(stateSize.height))
        (stateText as NSString).draw(at: stateRect.origin, withAttributes: attributes)
        #if KRADO_CI_HOOKS
        writeCIEvidence(highlighted: highlighted, stateRect: stateRect, foreground: foreground)
        print("KRADO_CI draw login label=\(stateText) highlighted=\(highlighted) frame=\(frame) dirty=\(dirtyRect)")
        #endif
    }

    private static func color(_ ink: LoginRowStyle.Ink) -> NSColor {
        switch ink {
        case .label: return .labelColor
        case .disabled: return .disabledControlTextColor
        case .selectedText: return .selectedMenuItemTextColor
        }
    }

    #if KRADO_CI_HOOKS
    private func writeCIEvidence(highlighted: Bool, stateRect: NSRect, foreground: NSColor) {
        guard let path = ProcessInfo.processInfo.environment["KRADO_CI_LOGIN_GEOMETRY"], let window else { return }
        let screenTop = NSScreen.screens[0].frame.maxY
        func screenRect(_ local: NSRect) -> [String: Double] {
            let rect = window.convertToScreen(convert(local, to: nil))
            return ["x": rect.minX, "y": screenTop - rect.maxY, "width": rect.width, "height": rect.height]
        }
        func rgba(_ color: NSColor) -> [Double] {
            let c = color.usingColorSpace(.sRGB) ?? color
            return [Double(c.redComponent) * 255, Double(c.greenComponent) * 255, Double(c.blueComponent) * 255, Double(c.alphaComponent)]
        }
        var evidence: [String: Any] = screenRect(bounds)
        evidence["stateRect"] = screenRect(stateRect)
        let titleWidth = (title as NSString).size(withAttributes: [.font: NSFont.menuFont(ofSize: 0)]).width
        evidence["titleRect"] = screenRect(NSRect(x: Self.titleX, y: stateRect.minY, width: titleWidth, height: stateRect.height))
        evidence["label"] = stateText
        evidence["state"] = state == .enabled ? "on" : state == .needsApproval ? "approval" : "off"
        evidence["drawsStateText"] = !stateText.isEmpty
        evidence["drawsStateMark"] = false
        evidence["inks"] = ["text": rgba(foreground), "label": rgba(.labelColor)]
        evidence["menuItemHighlighted"] = enclosingMenuItem?.isHighlighted == true
        evidence["pointerInsideSinceClick"] = highlight.pointerInsideSinceClick
        evidence["nativeBadge"] = enclosingMenuItem?.badge != nil
        evidence["highlighted"] = highlighted
        if let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
    #endif
}
