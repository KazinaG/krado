import AppKit
import KradoCore

/// The Launch at Login row: a custom menu view, so a click toggles without closing
/// the menu. AppKit draws no highlight under custom views, so the row shows the
/// system selection material (NSVisualEffectView .selection, emphasized) in the
/// native row's shape, and draws its content in a view above it.
@MainActor
final class LoginRowView: NSView {
    private let activate: () -> Void
    private let selection = NSVisualEffectView()
    private let content = LoginRowContentView()
    private let icon = NSImageView()
    private var title = ""
    private var stateText = ""
    private var enabled = true
    private var state: LoginItemState = .disabled
    private var highlight = LoginRowStyle.Highlight()
    private var pointerTracking: NSTrackingArea?
    private(set) var isDrawnHighlighted = false
    private let loginSwitch = NSSwitch()

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

    private static var selectionRadius: CGFloat {
        if #available(macOS 26, *) { return CGFloat(LoginRowStyle.selectionCornerRadius(macOS26OrLater: true)) }
        return CGFloat(LoginRowStyle.selectionCornerRadius(macOS26OrLater: false))
    }

    init(activate: @escaping () -> Void) {
        self.activate = activate
        // The menu sizes itself from this initial width; 260/259 match the native row (CI menu-shots).
        super.init(frame: NSRect(x: 0, y: 0, width: Self.nativeWidth, height: Self.rowHeight))
        autoresizingMask = [.width]
        // The same material and emphasis AppKit uses for a selected menu row; only the
        // shape (inset and corner radius) is ours, matched to native rows in CI.
        selection.material = .selection
        selection.state = .active
        selection.blendingMode = .behindWindow
        selection.isEmphasized = true
        selection.maskImage = Self.selectionMask(radius: Self.selectionRadius)
        selection.isHidden = true
        selection.autoresizingMask = [.width, .height]
        selection.setAccessibilityElement(false)
        addSubview(selection)
        content.row = self
        content.autoresizingMask = [.width, .height]
        content.setAccessibilityElement(false)
        addSubview(content)
        icon.image = MenuActionSymbol.image(named: "power")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        content.addSubview(icon)
        // The row owns every click; the switch only displays refreshed login state.
        switch LoginRowStyle.switchSize {
        case .mini: loginSwitch.controlSize = .mini
        }
        loginSwitch.setAccessibilityElement(false)
        content.addSubview(loginSwitch)
        // The enclosing menu item supplies the action and accessibility metadata.
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    /// A resizable rounded-rect mask, the documented way to round an NSVisualEffectView.
    private static func selectionMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    func update(title: String, stateText: String, state: LoginItemState, enabled: Bool) {
        self.title = title
        self.stateText = stateText
        self.enabled = enabled
        self.state = state
        loginSwitch.state = LoginRowStyle.switchIsOn(for: state) ? .on : .off
        loginSwitch.isEnabled = enabled
        // Size once, before menu tracking. Never reset the frame while toggling:
        // AppKit owns the stretched width of its view item.
        if window == nil {
            let font = NSFont.menuFont(ofSize: 0)
            let titleWidth = Double((title as NSString).size(withAttributes: [.font: font]).width)
            let rowWidth = LoginRowLayout.width(titleX: Double(Self.titleX), titleWidth: titleWidth,
                                                switchWidth: Double(loginSwitch.fittingSize.width),
                                                minimum: Double(Self.nativeWidth))
            let size = NSSize(width: rowWidth, height: Self.rowHeight)
            if frame.size != size { setFrameSize(size) }
        }
        needsLayout = true
        needsDisplay = true
        content.needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsDisplay = true
        content.needsDisplay = true
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

    // Clicks belong to the row, not to the selection or content subviews.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        return bounds.contains(local) ? self : nil
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
        let inset = CGFloat(LoginRowStyle.selectionHorizontalInset)
        selection.frame = bounds.insetBy(dx: inset, dy: 0)
        content.frame = bounds
        let size = Self.iconSize
        icon.frame = NSRect(x: Self.iconX, y: (bounds.height - size) / 2, width: size, height: size)
        let fitting = loginSwitch.fittingSize
        loginSwitch.frame = NSRect(x: CGFloat(LoginRowLayout.switchX(rowMaxX: Double(bounds.maxX), switchWidth: Double(fitting.width))),
                                  y: (bounds.height - fitting.height) / 2, width: fitting.width, height: fitting.height)
    }

    // AppKit redraws this view when the item's highlight changes; the selection's
    // visibility and the content follow from here.
    override func draw(_ dirtyRect: NSRect) {
        let highlighted = highlight.isHighlighted(menuItemHighlighted: enclosingMenuItem?.isHighlighted == true, enabled: enabled)
        if isDrawnHighlighted != highlighted || selection.isHidden == highlighted {
            isDrawnHighlighted = highlighted
            selection.isHidden = !highlighted
        }
        content.needsDisplay = true
    }

    fileprivate func drawContent() {
        let highlighted = isDrawnHighlighted
        let bounds = content.bounds
        let foreground = Self.color(LoginRowStyle.ink(highlighted: highlighted, enabled: enabled))
        icon.contentTintColor = foreground

        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: Self.titleX, y: (bounds.height - titleSize.height) / 2), withAttributes: attributes)

        #if KRADO_CI_HOOKS
        writeCIEvidence(highlighted: highlighted, foreground: foreground)
        print("KRADO_CI draw login label=\(stateText) highlighted=\(highlighted) frame=\(frame)")
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
    private func writeCIEvidence(highlighted: Bool, foreground: NSColor) {
        guard let path = ProcessInfo.processInfo.environment["KRADO_CI_LOGIN_GEOMETRY"], let window else { return }
        let screenTop = NSScreen.screens[0].frame.maxY
        func screenRect(_ local: NSRect) -> [String: Double] {
            let rect = window.convertToScreen(content.convert(local, to: nil))
            return ["x": rect.minX, "y": screenTop - rect.maxY, "width": rect.width, "height": rect.height]
        }
        func rgba(_ color: NSColor) -> [Double] {
            let c = color.usingColorSpace(.sRGB) ?? color
            return [Double(c.redComponent) * 255, Double(c.greenComponent) * 255, Double(c.blueComponent) * 255, Double(c.alphaComponent)]
        }
        var evidence: [String: Any] = screenRect(content.bounds)
        func sizeName(_ size: NSControl.ControlSize) -> String {
            switch size {
            case .mini: return "mini"
            case .small: return "small"
            case .regular: return "regular"
            case .large: return "large"
            @unknown default: return "unknown"
            }
        }
        let fitting = loginSwitch.fittingSize
        let switchState = loginSwitch.state == .on ? "on" : "off"
        evidence["switchClass"] = String(describing: type(of: loginSwitch))
        evidence["switchControlSize"] = sizeName(loginSwitch.controlSize)
        evidence["switchState"] = switchState
        evidence["switchEnabled"] = loginSwitch.isEnabled
        evidence["switchRect"] = screenRect(loginSwitch.frame)
        evidence["switchFittingSize"] = [fitting.width, fitting.height]
        var sizes: [String: [CGFloat]] = [:]
        for size: NSControl.ControlSize in [.mini, .small, .regular] {
            let sample = NSSwitch()
            sample.controlSize = size
            sizes[sizeName(size)] = [sample.fittingSize.width, sample.fittingSize.height]
        }
        evidence["nsSwitchFittingSizes"] = sizes
        print("KRADO_CI login switch controlSize=\(sizeName(loginSwitch.controlSize)) state=\(switchState) fitting=\(fitting.width)x\(fitting.height)")
        let titleSize = (title as NSString).size(withAttributes: [.font: NSFont.menuFont(ofSize: 0)])
        evidence["titleRect"] = screenRect(NSRect(x: Self.titleX, y: (content.bounds.height - titleSize.height) / 2,
                                                 width: titleSize.width, height: titleSize.height))
        evidence["selectionRect"] = screenRect(selection.frame)
        evidence["selectionRadius"] = Double(Self.selectionRadius)
        evidence["selectionVisible"] = !selection.isHidden
        evidence["selectionMaterial"] = selection.material == .selection && selection.isEmphasized && selection.state == .active
        evidence["selfPaintedHighlight"] = false
        evidence["label"] = stateText
        evidence["state"] = state == .enabled ? "on" : state == .needsApproval ? "approval" : "off"
        evidence["inks"] = ["title": rgba(foreground), "label": rgba(.labelColor)]
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

/// Draws the row's content above the selection material.
@MainActor
private final class LoginRowContentView: NSView {
    weak var row: LoginRowView?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) { row?.drawContent() }
}
