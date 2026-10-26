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
    private var onOffTexts: [String] = []
    private var enabled = true
    private var state: LoginItemState = .disabled
    private var highlight = LoginRowStyle.Highlight()
    private var pointerTracking: NSTrackingArea?
    private(set) var isDrawnHighlighted = false
    private var offStyle = LoginRowStyle.shippedOffStyle
    // The capsule that is fading out after a toggle, and the 150 ms cross-fade.
    private var previous: (state: LoginItemState, text: String)?
    private var fade = LoginRowStyle.Fade()
    private var fadeTimer: Timer?

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

    private static var badgeFont: NSFont { .systemFont(ofSize: CGFloat(LoginBadgeMetrics.fontSize), weight: .medium) }

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
        #if KRADO_CI_HOOKS
        if let raw = ProcessInfo.processInfo.environment["KRADO_CI_LOGIN_OFF_STYLE"],
           let style = LoginRowStyle.OffStyle(rawValue: raw) { offStyle = style }
        #endif
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

    private func capsuleWidth(for text: String) -> CGFloat {
        func width(_ t: String) -> Double { Double((t as NSString).size(withAttributes: [.font: Self.badgeFont]).width) }
        return CGFloat(LoginBadgeMetrics.capsuleWidth(textWidth: width(text), onOffTextWidths: onOffTexts.map(width)))
    }

    /// `onOffTexts` are the localized On and Off words (one shared capsule width);
    /// `allStateTexts` are every state word; the row is sized for the widest capsule.
    func update(title: String, stateText: String, onOffTexts: [String], allStateTexts: [String],
                state: LoginItemState, enabled: Bool) {
        // A toggle while the menu is open cross-fades the capsule (Kazina 10/26 03:14).
        if window != nil, state != self.state || stateText != self.stateText {
            startFade(from: (self.state, self.stateText))
        }
        self.title = title
        self.stateText = stateText
        self.onOffTexts = onOffTexts
        self.enabled = enabled
        self.state = state
        // Size once, before menu tracking. Never reset the frame while toggling:
        // AppKit owns the stretched width of its view item.
        if window == nil {
            let font = NSFont.menuFont(ofSize: 0)
            let titleWidth = Double((title as NSString).size(withAttributes: [.font: font]).width)
            let rowWidth = LoginRowLayout.width(titleX: Double(Self.titleX), titleWidth: titleWidth,
                                                stateWidths: (allStateTexts + [stateText]).map { Double(capsuleWidth(for: $0)) },
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
            stopFade()
        } else { installKeyMonitor() }
    }

    private static var now: Double { ProcessInfo.processInfo.systemUptime }

    private func startFade(from old: (state: LoginItemState, text: String)) {
        previous = old
        fade.start(at: Self.now)
        guard fadeTimer == nil else { return }
        // Common modes: the menu's event-tracking run loop mode must keep the timer firing.
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.fadeTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        fadeTimer = timer
    }

    private func fadeTick() {
        content.needsDisplay = true
        if !fade.isRunning(at: Self.now) { stopFade() }
    }

    /// Ends the cross-fade. The start time is kept until the menu closes so CI can log
    /// the settled frame.
    private func stopFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        previous = nil
        content.needsDisplay = true
        if window == nil { fade.finish() }
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

        // The state word inside a capsule at the trailing edge; solid only when On.
        // While a toggle fades, the old capsule fades out as the new one fades in.
        let now = Self.now
        let fading = previous != nil && fade.isRunning(at: now)
        let opacities = fading ? fade.opacities(at: now) : (outgoing: 0, incoming: 1)
        if fading, let previous {
            drawCapsule(state: previous.state, text: previous.text, highlighted: highlighted, opacity: opacities.outgoing)
        }
        #if KRADO_CI_HOOKS
        let (style, capsule, wordRect) = drawCapsule(state: state, text: stateText, highlighted: highlighted,
                                                     opacity: opacities.incoming)
        writeCIEvidence(highlighted: highlighted, capsule: capsule, wordRect: wordRect, foreground: foreground, style: style)
        if let startedAt = fade.startedAt, now - startedAt < 1 {
            print(String(format: "KRADO_CI login fade t=%.4f p=%.4f outgoing=%.4f incoming=%.4f",
                         now - startedAt, fade.progress(at: now), opacities.outgoing, opacities.incoming))
        }
        print("KRADO_CI draw login label=\(stateText) highlighted=\(highlighted) frame=\(frame)")
        #else
        drawCapsule(state: state, text: stateText, highlighted: highlighted, opacity: opacities.incoming)
        #endif
    }

    /// One capsule and its word at `opacity` (1 when not fading). On's fill and ring
    /// are drawn as one shape in a transparency layer at 85 %, so the ring is exactly
    /// as dark as the fill.
    @discardableResult
    private func drawCapsule(state: LoginItemState, text: String, highlighted: Bool,
                             opacity: Double) -> (LoginRowStyle.Capsule, NSRect, NSRect) {
        let bounds = content.bounds
        let style = LoginRowStyle.capsule(state: state, highlighted: highlighted, enabled: enabled, offStyle: offStyle)
        let width = capsuleWidth(for: text)
        let height = CGFloat(LoginBadgeMetrics.height)
        let capsule = NSRect(x: CGFloat(LoginRowLayout.stateX(rowMaxX: Double(bounds.maxX), stateWidth: Double(width))),
                             y: ((bounds.height - height) / 2).rounded(), width: width, height: height)
        let stroke = CGFloat(LoginBadgeMetrics.strokeWidth)
        let outline = NSBezierPath(roundedRect: capsule.insetBy(dx: stroke / 2, dy: stroke / 2),
                                   xRadius: (height - stroke) / 2, yRadius: (height - stroke) / 2)
        outline.lineWidth = stroke
        let solid = NSBezierPath(roundedRect: capsule, xRadius: height / 2, yRadius: height / 2)
        let cg = NSGraphicsContext.current?.cgContext
        cg?.saveGState()
        if style.fillAndRingShareOpacity, let fill = style.fill {
            cg?.setAlpha(CGFloat(style.fillAlpha * opacity))
            cg?.beginTransparencyLayer(auxiliaryInfo: nil)
            let ink = Self.color(fill).withAlphaComponent(1)
            ink.setFill(); solid.fill()
            ink.setStroke(); outline.stroke()
            cg?.endTransparencyLayer()
        } else {
            cg?.setAlpha(CGFloat(opacity))
            if let fill = style.fill {
                Self.color(fill).withAlphaComponent(CGFloat(style.fillAlpha)).setFill()
                solid.fill()
            }
            if let ring = style.ring {
                let ink = Self.color(ring)
                (style.ringAlpha.map { ink.withAlphaComponent(CGFloat($0)) } ?? ink).setStroke()
                outline.stroke()
            }
        }
        cg?.restoreGState()
        cg?.saveGState()
        cg?.setAlpha(CGFloat(opacity))
        let textAttributes: [NSAttributedString.Key: Any] = [.font: Self.badgeFont, .foregroundColor: Self.color(style.text)]
        let textSize = (text as NSString).size(withAttributes: textAttributes)
        let wordRect = NSRect(x: CGFloat(LoginBadgeMetrics.textX(capsuleMinX: Double(capsule.minX), capsuleWidth: Double(width),
                                                                  textWidth: Double(textSize.width))),
                              y: capsule.minY + (height - textSize.height) / 2, width: textSize.width, height: textSize.height)
        (text as NSString).draw(at: wordRect.origin, withAttributes: textAttributes)
        cg?.restoreGState()
        return (style, capsule, wordRect)
    }

    private static func color(_ ink: LoginRowStyle.Ink) -> NSColor {
        switch ink {
        case .label: return .labelColor
        case .disabled: return .disabledControlTextColor
        case .selectedText: return .selectedMenuItemTextColor
        case .onFillText: return .windowBackgroundColor
        case .badgeInk:
            let c = LoginRowStyle.badgeInk
            return NSColor(srgbRed: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1)
        }
    }

    #if KRADO_CI_HOOKS
    private func writeCIEvidence(highlighted: Bool, capsule: NSRect, wordRect: NSRect, foreground: NSColor,
                                 style: LoginRowStyle.Capsule) {
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
        evidence["stateRect"] = screenRect(capsule)
        evidence["wordRect"] = screenRect(wordRect)
        let titleWidth = (title as NSString).size(withAttributes: [.font: NSFont.menuFont(ofSize: 0)]).width
        evidence["titleRect"] = screenRect(NSRect(x: Self.titleX, y: wordRect.minY, width: titleWidth, height: wordRect.height))
        evidence["selectionRect"] = screenRect(selection.frame)
        evidence["selectionRadius"] = Double(Self.selectionRadius)
        evidence["selectionVisible"] = !selection.isHidden
        evidence["selectionMaterial"] = selection.material == .selection && selection.isEmphasized && selection.state == .active
        evidence["selfPaintedHighlight"] = false
        evidence["label"] = stateText
        evidence["state"] = state == .enabled ? "on" : state == .needsApproval ? "approval" : "off"
        evidence["offStyle"] = offStyle.rawValue
        evidence["drawsStateText"] = !stateText.isEmpty
        evidence["drawsStateCapsule"] = true
        evidence["capsuleSolid"] = style.isSolid
        evidence["capsuleRing"] = style.ring != nil
        var inks: [String: Any] = ["title": rgba(foreground), "label": rgba(.labelColor), "text": rgba(Self.color(style.text))]
        if let fill = style.fill { inks["fill"] = rgba(Self.color(fill)); inks["fillAlpha"] = style.fillAlpha }
        if let ring = style.ring { inks["ring"] = rgba(Self.color(ring)) }
        if let ringAlpha = style.ringAlpha { inks["ringAlpha"] = ringAlpha }
        evidence["fillAndRingShareOpacity"] = style.fillAndRingShareOpacity
        evidence["fadeDuration"] = LoginRowStyle.Fade.duration
        evidence["reduceMotion"] = MotionPreference.reduceMotion
        evidence["inks"] = inks
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
