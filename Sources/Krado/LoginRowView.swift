import AppKit
import KradoCore

@MainActor
final class LoginRowView: NSView {
    private let activate: () -> Void
    private let icon = NSImageView()
    private let badgeSymbol = NSImageView()
    private var title = ""
    private var badge: String?
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
        // The menu sizes itself from this initial width; 260/259 match the native row with a badge (CI menu-shots).
        super.init(frame: NSRect(x: 0, y: 0, width: Self.nativeWidth, height: Self.rowHeight))
        autoresizingMask = [.width]
        icon.image = MenuActionSymbol.image(named: "power")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        addSubview(icon)
        badgeSymbol.imageScaling = .scaleProportionallyUpOrDown
        badgeSymbol.setAccessibilityElement(false)
        badgeSymbol.isHidden = true
        addSubview(badgeSymbol)
        // The enclosing menu item supplies the action and accessibility metadata.
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    func update(title: String, badge: String?, state: LoginItemState, enabled: Bool) {
        self.title = title
        self.badge = badge
        self.enabled = enabled
        self.state = state
        // Size from the title once, before menu tracking. Never reset the frame
        // while toggling: AppKit owns the stretched width of its view item.
        if window == nil {
            let titleWidth = (title as NSString).size(withAttributes: [.font: NSFont.menuFont(ofSize: 0)]).width
            let width = Self.titleX + titleWidth + 16 + LoginBadgeMetrics.diameter + 49
            let size = NSSize(width: max(Self.nativeWidth, ceil(width)), height: Self.rowHeight)
            if frame.size != size { setFrameSize(size) }
        }
        badgeSymbol.image = LoginRowStyle.badge(state: state, highlighted: false, enabled: enabled).symbolName.flatMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: LoginBadgeMetrics.symbolSize, weight: .bold))
        }
        badgeSymbol.image?.isTemplate = true
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
        let foreground: NSColor = !enabled ? .disabledControlTextColor : highlighted ? .selectedMenuItemTextColor : .labelColor
        icon.contentTintColor = foreground

        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: Self.titleX, y: (bounds.height - titleSize.height) / 2), withAttributes: attributes)

        var capsule = NSRect.zero
        var pillColor = NSColor.clear, badgeColor = NSColor.clear, ringColor = NSColor.clear
        // Menu materials are translucent; use the appearance's window surface
        // to choose opacity, then let screenshot CI verify the actual menu surface.
        func rgb(_ color: NSColor) -> LoginRowStyle.RGB {
            .init(Double(color.redComponent) * 255, Double(color.greenComponent) * 255, Double(color.blueComponent) * 255)
        }
        var offRingAlpha = 1.0
        if let background = NSColor.windowBackgroundColor.usingColorSpace(.sRGB),
           let label = NSColor.labelColor.usingColorSpace(.sRGB) {
            offRingAlpha = LoginRowStyle.offRingAlpha(label: rgb(label), labelAlpha: Double(label.alphaComponent),
                                                     background: rgb(background))
        }
        let style = LoginRowStyle.badge(state: state, highlighted: highlighted, enabled: enabled,
                                       offRingAlpha: offRingAlpha)
        badgeSymbol.isHidden = badge == nil || style.symbolName == nil
        if badge != nil {
            badgeColor = Self.color(style.text)
            pillColor = Self.color(style.pill).withAlphaComponent(style.pillAlpha)
            let height = LoginBadgeMetrics.diameter
            capsule = NSRect(x: (bounds.maxX - 17 - height).rounded(),
                y: ((bounds.height - height) / 2).rounded(), width: height, height: height)
            if style.fill {
                pillColor.setFill()
                NSBezierPath(roundedRect: capsule, xRadius: height / 2, yRadius: height / 2).fill()
            }
            if let ring = style.ring {
                ringColor = Self.color(ring).withAlphaComponent(style.ringAlpha)
                ringColor.setStroke()
                let outline = NSBezierPath(roundedRect: capsule.insetBy(dx: LoginBadgeMetrics.strokeWidth / 2, dy: LoginBadgeMetrics.strokeWidth / 2),
                                           xRadius: (height - LoginBadgeMetrics.strokeWidth) / 2, yRadius: (height - LoginBadgeMetrics.strokeWidth) / 2)
                outline.lineWidth = LoginBadgeMetrics.strokeWidth
                outline.stroke()
            }
            badgeSymbol.isHidden = style.symbolName == nil
            let inset = LoginBadgeMetrics.symbolInset()
            badgeSymbol.frame = capsule.insetBy(dx: inset, dy: inset)
            badgeSymbol.contentTintColor = badgeColor
        }
        #if KRADO_CI_HOOKS
        writeCIEvidence(highlighted: highlighted, capsule: capsule, pill: pillColor, text: badgeColor,
                        ring: ringColor, style: style)
        print("KRADO_CI draw login label=\(badge ?? "none") highlighted=\(highlighted) frame=\(frame) dirty=\(dirtyRect)")
        #endif
    }

    private static func color(_ ink: LoginRowStyle.Ink) -> NSColor {
        switch ink {
        case .label: return .labelColor
        case .secondaryLabel: return .secondaryLabelColor
        case .disabled: return .disabledControlTextColor
        case .selectedText: return .selectedMenuItemTextColor
        case .white: return .white
        case .black: return .black
        case .badgeInk:
            let c = LoginRowStyle.badgeInk
            return NSColor(srgbRed: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1)
        }
    }

    #if KRADO_CI_HOOKS
    private func writeCIEvidence(highlighted: Bool, capsule: NSRect, pill: NSColor, text: NSColor,
                                 ring: NSColor, style: LoginRowStyle.Badge) {
        guard let path = ProcessInfo.processInfo.environment["KRADO_CI_LOGIN_GEOMETRY"], let window else { return }
        let screenTop = NSScreen.screens[0].frame.maxY
        func screenRect(_ local: NSRect) -> [String: Double] {
            let rect = window.convertToScreen(convert(local, to: nil))
            return ["x": rect.minX, "y": screenTop - rect.maxY, "width": rect.width, "height": rect.height]
        }
        var evidence: [String: Any] = screenRect(bounds)
        do {
            // Current-draw sRGB, including the recessed fill and separate ring.
            // Unhighlighted checks also composite raw inks over screenshot pixels
            // because the menu material can differ from the nominal surface.
            func rgba(_ color: NSColor) -> [Double] {
                let c = color.usingColorSpace(.sRGB) ?? color
                return [Double(c.redComponent) * 255, Double(c.greenComponent) * 255, Double(c.blueComponent) * 255, Double(c.alphaComponent)]
            }
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
            let background = highlighted ? NSColor.selectedContentBackgroundColor : NSColor.windowBackgroundColor
            let pillRGB = style.fill ? rgb(pill, over: background) : rgb(background)
            let pillColor = NSColor(srgbRed: CGFloat(pillRGB[0]) / 255, green: CGFloat(pillRGB[1]) / 255, blue: CGFloat(pillRGB[2]) / 255, alpha: 1)
            evidence["colors"] = ["background": rgb(background), "pill": pillRGB,
                                  "text": rgb(text, over: pillColor), "ring": rgb(ring, over: pillColor)]
            evidence["inks"] = ["pill": rgba(pill), "text": rgba(text), "ring": rgba(ring), "label": rgba(.labelColor)]
        }
        evidence["capsule"] = screenRect(capsule)
        evidence["label"] = badge ?? ""
        evidence["state"] = state == .enabled ? "on" : state == .needsApproval ? "approval" : "off"
        evidence["symbol"] = style.symbolName ?? ""
        evidence["drawsStateText"] = false
        evidence["menuItemHighlighted"] = enclosingMenuItem?.isHighlighted == true
        evidence["pointerInsideSinceClick"] = highlight.pointerInsideSinceClick
        evidence["nativeBadge"] = enclosingMenuItem?.badge != nil
        evidence["highlighted"] = highlighted
        evidence["highlightedFill"] = style.fill
        evidence["highlightedCheckmark"] = style.showsCheckmark
        evidence["drawsRing"] = style.ring != nil
        evidence["ringWidth"] = LoginBadgeMetrics.strokeWidth
        evidence["ringInset"] = LoginBadgeMetrics.strokeWidth / 2
        if let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
    #endif
}
