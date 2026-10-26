import AppKit
import KradoCore

/// The Launch at Login row: a custom menu view with a leading icon, the title and
/// Apple's NSSwitch. Only the switch can be pressed (maintainer 2026-10-26 17:17); the
/// rest of the row ignores clicks and never highlights. A click on the switch is
/// handled by NSSwitch itself, so it animates, and the menu stays open because a view
/// item does not close the menu. When the login state changes otherwise (keyboard,
/// failed registration), the switch moves through `animator()`, which Apple documents
/// as the way to animate NSSwitch.state.
@MainActor
final class LoginRowView: NSView {
    private let activate: () -> Void
    private let content = LoginRowContentView()
    private let icon = NSImageView()
    private var title = ""
    private var stateText = ""
    private var enabled = true
    private var state: LoginItemState = .disabled
    private var focus = LoginRowStyle.KeyboardFocus()
    private let loginSwitch = LoginSwitch()

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
        content.row = self
        content.autoresizingMask = [.width, .height]
        content.setAccessibilityElement(false)
        addSubview(content)
        icon.image = MenuActionSymbol.image(named: "power")
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        content.addSubview(icon)
        switch LoginRowStyle.switchSize {
        case .mini: loginSwitch.controlSize = .mini
        }
        loginSwitch.target = self
        loginSwitch.action = #selector(switchClicked)
        loginSwitch.focusRingType = .none // the row draws the ring for keyboard focus
        loginSwitch.setAccessibilityElement(false)
        // Above the content view so it receives its own clicks.
        addSubview(loginSwitch)
        // The enclosing menu item supplies the action and accessibility metadata.
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    func update(title: String, stateText: String, state: LoginItemState, enabled: Bool) {
        self.title = title
        self.stateText = stateText
        self.enabled = enabled
        self.state = state
        let target: NSControl.StateValue = LoginRowStyle.switchIsOn(for: state) ? .on : .off
        if loginSwitch.state != target {
            if window != nil {
                // Visible: slide to the new state (Apple: NSSwitch.state via animator()).
                loginSwitch.animator().state = target
            } else {
                loginSwitch.state = target
            }
        }
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
        content.needsDisplay = true
    }

    @objc private func switchClicked() {
        // NSSwitch has already moved itself; the refresh that follows confirms or
        // animates it back if registration did not take.
        activate()
        content.needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        content.needsDisplay = true
        // Measured in CI: on macOS 26 a switch outside a window reports a 54x24 fitting
        // size whatever its controlSize; inside the menu window, mini reports 36x16.
        // Lay out again once the row is in the menu window.
        needsLayout = true
        if window == nil {
            focus.menuDidClose()
            removeKeyMonitor()
        } else { installKeyMonitor() }
    }

    // Custom menu views lose AppKit's keyboard activation. While the menu is open,
    // Return, Enter or Space toggles when the keyboard has selected the row.
    private var keyMonitor: Any?

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.handlesActivationKey(event) else { return event }
            self.activate()
            self.content.needsDisplay = true
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
        if handlesActivationKey(event) { activate(); content.needsDisplay = true } else { super.keyDown(with: event) }
    }

    // Only the switch takes clicks. Elsewhere the row swallows them without acting,
    // so the menu neither toggles nor closes.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        guard bounds.contains(local) else { return nil }
        return loginSwitch.frame.contains(local) ? loginSwitch : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}

    func menuWillHighlight(thisRow: Bool?, byKeyboard: Bool) {
        focus.menuWillHighlight(thisRow: thisRow, byKeyboard: byKeyboard)
        content.needsDisplay = true
    }

    func menuDidClose() {
        focus.menuDidClose()
        content.needsDisplay = true
    }

    override func layout() {
        super.layout()
        content.frame = bounds
        let size = Self.iconSize
        icon.frame = NSRect(x: Self.iconX, y: (bounds.height - size) / 2, width: size, height: size)
        placeSwitch()
    }

    /// The switch at its own size, right-aligned and centred. Called from layout and
    /// again before drawing: AppKit gives this menu view no layout pass once it is in
    /// the menu window, and only there does the switch report its real size (CI).
    private func placeSwitch() {
        let fitting = loginSwitch.fittingSize
        let frame = NSRect(x: CGFloat(LoginRowLayout.switchX(rowMaxX: Double(bounds.maxX), switchWidth: Double(fitting.width))),
                           y: ((bounds.height - fitting.height) / 2).rounded(), width: fitting.width, height: fitting.height)
        if loginSwitch.frame != frame { loginSwitch.frame = frame }
    }

    fileprivate func drawContent() {
        placeSwitch()
        let look = LoginRowStyle.switchLook(state: state, enabled: enabled, pressed: loginSwitch.isPressed,
                                            keyboardFocused: focus.isFocused)
        let bounds = content.bounds
        let foreground = Self.color(look.titleInk)
        icon.contentTintColor = foreground

        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: foreground]
        let titleSize = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(at: NSPoint(x: Self.titleX, y: (bounds.height - titleSize.height) / 2), withAttributes: attributes)

        if look.focusRing {
            // The system keyboard focus ring around the switch, not a row highlight.
            NSGraphicsContext.saveGraphicsState()
            NSFocusRingPlacement.only.set()
            let r = loginSwitch.frame
            NSBezierPath(roundedRect: r, xRadius: r.height / 2, yRadius: r.height / 2).fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        #if KRADO_CI_HOOKS
        writeCIEvidence(look: look, foreground: foreground)
        print("KRADO_CI draw login label=\(stateText) focusRing=\(look.focusRing) frame=\(frame)")
        #endif
    }

    private static func color(_ ink: LoginRowStyle.Ink) -> NSColor {
        switch ink {
        case .label: return .labelColor
        case .disabled: return .disabledControlTextColor
        }
    }

    #if KRADO_CI_HOOKS
    private func writeCIEvidence(look: LoginRowStyle.SwitchLook, foreground: NSColor) {
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
        // LoginSwitch only observes the press; the control and its drawing are NSSwitch.
        evidence["switchClass"] = type(of: loginSwitch).superclass().map { NSStringFromClass($0) } ?? "?"
        evidence["macOSMajor"] = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        evidence["switchControlSize"] = sizeName(loginSwitch.controlSize)
        evidence["switchState"] = switchState
        evidence["switchEnabled"] = loginSwitch.isEnabled
        evidence["switchRect"] = screenRect(loginSwitch.frame)
        evidence["switchFittingSize"] = [fitting.width, fitting.height]
        print("KRADO_CI login switch controlSize=\(sizeName(loginSwitch.controlSize)) state=\(switchState) fitting=\(fitting.width)x\(fitting.height) appActive=\(NSApp.isActive)")
        let titleSize = (title as NSString).size(withAttributes: [.font: NSFont.menuFont(ofSize: 0)])
        evidence["titleRect"] = screenRect(NSRect(x: Self.titleX, y: (bounds.height - titleSize.height) / 2,
                                                 width: titleSize.width, height: titleSize.height))
        evidence["rowHighlight"] = look.rowHighlight
        evidence["focusRing"] = look.focusRing
        evidence["selfPaintedHighlight"] = false
        evidence["appIsActive"] = NSApp.isActive
        evidence["menuWindowIsKey"] = window.isKeyWindow
        evidence["accent"] = rgba(.controlAccentColor)
        evidence["label"] = stateText
        evidence["state"] = state == .enabled ? "on" : state == .needsApproval ? "approval" : "off"
        evidence["inks"] = ["title": rgba(foreground), "label": rgba(.labelColor)]
        evidence["menuItemHighlighted"] = enclosingMenuItem?.isHighlighted == true
        evidence["nativeBadge"] = enclosingMenuItem?.badge != nil
        evidence["highlighted"] = look.rowHighlight
        if let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
    #endif
}

/// NSSwitch that reports whether the pointer is holding it down, so the row's look
/// model knows the pressed state. Drawing stays Apple's.
@MainActor
private final class LoginSwitch: NSSwitch {
    private(set) var isPressed = false
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        (superview as? LoginRowView)?.setNeedsContentDisplay()
        super.mouseDown(with: event) // tracks until mouse-up
        isPressed = false
        (superview as? LoginRowView)?.setNeedsContentDisplay()
    }
}

extension LoginRowView {
    fileprivate func setNeedsContentDisplay() { content.needsDisplay = true }
}

/// Draws the row's content: icon, title and the keyboard focus ring.
@MainActor
private final class LoginRowContentView: NSView {
    weak var row: LoginRowView?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) { row?.drawContent() }
}
