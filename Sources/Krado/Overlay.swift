import AppKit
import KradoCore

@MainActor
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class GridView: NSView {
    let geometry: GridGeometry
    var target: GridSpan? { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    init(geometry: GridGeometry) {
        self.geometry = geometry
        super.init(frame: CGRect(origin: .zero, size: geometry.workArea.size))
        // Zones use the macOS accent color; redraw at once when the user changes it.
        NotificationCenter.default.addObserver(
            self, selector: #selector(systemColorsChanged),
            name: NSColor.systemColorsDidChangeNotification, object: nil
        )
    }

    @objc private func systemColorsChanged() { needsDisplay = true }

    required init?(coder: NSCoder) { nil }

    private func localFrame(_ span: GridSpan) -> CGRect {
        geometry.frame(for: span).offsetBy(dx: -geometry.workArea.minX, dy: -geometry.workArea.minY)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Rounded, slightly inset tiles read like macOS's own window tiling previews.
        // The inset is visual only; placed windows still fill their zones exactly.
        for span in geometry.zones {
            let path = Self.roundedPath(localFrame(span).insetBy(dx: 4, dy: 4))
            NSColor.controlAccentColor.withAlphaComponent(0.10).setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        if let target {
            let path = Self.roundedPath(localFrame(target).insetBy(dx: 5.5, dy: 5.5))
            NSColor.controlAccentColor.withAlphaComponent(0.30).setFill()
            path.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
            path.lineWidth = 3
            path.stroke()
        }
    }

    private static func roundedPath(_ rect: CGRect) -> NSBezierPath {
        let radius = min(10, rect.width / 4, rect.height / 4)
        return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }
}

@MainActor
final class ScreenGrid {
    let displayID: CGDirectDisplayID
    let name: String
    let geometry: GridGeometry
    let screenFrameAX: CGRect
    private let panel: OverlayPanel
    private let gridView: GridView
    /// True between show() and hide(); a fade-out finishes only if no show() came in between.
    private var wantsVisible = false
    private static let fadeDuration: TimeInterval = 0.12

    init(screen: NSScreen, displayID: CGDirectDisplayID, mainScreenHeight: CGFloat) {
        self.displayID = displayID
        name = screen.localizedName
        let descriptor = ScreenDescriptor(
            isBuiltin: CGDisplayIsBuiltin(displayID) != 0,
            // The grid rule reads the whole screen size so the menu bar and Dock never change it.
            visibleSize: screen.frame.size, name: screen.localizedName
        )
        geometry = GridGeometry(
            workArea: flipY(screen.visibleFrame, mainScreenHeight: mainScreenHeight),
            layout: GridPolicy.layout(for: descriptor), scale: screen.backingScaleFactor
        )
        screenFrameAX = flipY(screen.frame, mainScreenHeight: mainScreenHeight)
        gridView = GridView(geometry: geometry)
        panel = OverlayPanel(
            contentRect: screen.visibleFrame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.contentView = gridView
        panel.setFrame(screen.visibleFrame, display: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setAccessibilityElement(false)
        panel.setAccessibilityHidden(true)
    }

    func show(target: GridSpan?) {
        if gridView.target != target { gridView.target = target }
        guard !wantsVisible else { return }
        wantsVisible = true
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        fade(to: 1, completion: nil)
    }

    func hide() {
        guard wantsVisible else { return }
        wantsVisible = false
        fade(to: 0) { [weak self] in
            guard let self, !self.wantsVisible else { return }
            self.panel.orderOut(nil)
            if self.gridView.target != nil { self.gridView.target = nil }
        }
    }

    func close() {
        wantsVisible = false
        panel.close()
    }

    /// A short ease-out fade; instant when the user has Reduce Motion on.
    private func fade(to alpha: CGFloat, completion: (@MainActor @Sendable () -> Void)?) {
        let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : Self.fadeDuration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = alpha
        }, completionHandler: {
            MainActor.assumeIsolated { completion?() }
        })
    }
}

@MainActor
final class ScreenManager {
    private(set) var screens: [ScreenGrid] = []

    func reload() {
        screens.forEach { $0.close() }
        let available = NSScreen.screens
        let mainID = CGMainDisplayID()
        // NSScreen.main follows keyboard focus; it is not the coordinate-system anchor.
        guard let mainScreen = available.first(where: { Self.displayID(of: $0) == mainID }) else {
            screens = []
            return
        }
        let height = mainScreen.frame.height
        screens = available.compactMap { screen in
            guard let id = Self.displayID(of: screen), screen.visibleFrame.width > 0,
                  screen.visibleFrame.height > 0 else { return nil }
            return ScreenGrid(screen: screen, displayID: id, mainScreenHeight: height)
        }
    }

    func screen(at point: CGPoint) -> ScreenGrid? {
        screens.first { $0.screenFrameAX.contains(point) }
    }

    func hideAll() { screens.forEach { $0.hide() } }

    func show(_ screen: ScreenGrid, target: GridSpan?) {
        for other in screens where other !== screen { other.hide() }
        screen.show(target: target)
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
