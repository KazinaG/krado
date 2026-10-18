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
    }

    required init?(coder: NSCoder) { nil }

    private func localFrame(_ span: GridSpan) -> CGRect {
        geometry.frame(for: span).offsetBy(dx: -geometry.workArea.minX, dy: -geometry.workArea.minY)
    }

    override func draw(_ dirtyRect: NSRect) {
        for span in geometry.zones {
            let rect = localFrame(span)
            NSColor.controlAccentColor.withAlphaComponent(0.10).setFill()
            NSBezierPath(rect: rect).fill()
            NSColor.white.withAlphaComponent(0.5).setStroke()
            let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 1
            path.stroke()
        }
        if let target {
            let rect = localFrame(target).insetBy(dx: 2, dy: 2)
            NSColor.controlAccentColor.withAlphaComponent(0.30).setFill()
            NSBezierPath(rect: rect).fill()
            NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 3
            path.stroke()
        }
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

    init(screen: NSScreen, displayID: CGDirectDisplayID, mainScreenHeight: CGFloat) {
        self.displayID = displayID
        name = screen.localizedName
        let descriptor = ScreenDescriptor(
            isBuiltin: CGDisplayIsBuiltin(displayID) != 0,
            visibleSize: screen.visibleFrame.size, name: screen.localizedName
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
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide() {
        if panel.isVisible { panel.orderOut(nil) }
        if gridView.target != nil { gridView.target = nil }
    }

    func close() { panel.close() }
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
