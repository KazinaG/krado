import AppKit
import QuartzCore
import KradoCore

@MainActor
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class GridView: NSView {
    let geometry: GridGeometry
    private let tiles = CALayer()
    private let highlight = CAShapeLayer()
    var target: GridSpan? {
        didSet {
            guard target != oldValue else { return }
            if let target { moveHighlight(to: localFrame(target).insetBy(dx: 5.5, dy: 5.5), duration: 0.12) }
            else { highlight.removeAllAnimations(); highlight.opacity = 0 }
        }
    }
    override var isFlipped: Bool { true }

    init(geometry: GridGeometry) {
        self.geometry = geometry
        super.init(frame: CGRect(origin: .zero, size: geometry.workArea.size))
        wantsLayer = true
        layer?.addSublayer(tiles)
        layer?.addSublayer(highlight)
        highlight.actions = ["opacity": NSNull(), "position": NSNull(), "bounds": NSNull(), "path": NSNull()]
        highlight.opacity = 0
        highlight.lineWidth = 3
        rebuildTiles()
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildTiles),
            name: NSColor.systemColorsDidChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { nil }

    @objc private func rebuildTiles() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tiles.sublayers?.forEach { $0.removeFromSuperlayer() }
        for span in geometry.zones {
            let tile = CAShapeLayer()
            tile.path = Self.path(localFrame(span).insetBy(dx: 4, dy: 4))
            tile.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.10).cgColor
            tile.strokeColor = NSColor.white.withAlphaComponent(0.5).cgColor
            tile.lineWidth = 1
            tiles.addSublayer(tile)
        }
        highlight.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.30).cgColor
        highlight.strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.95).cgColor
        CATransaction.commit()
    }
    private func localFrame(_ span: GridSpan) -> CGRect {
        geometry.frame(for: span).offsetBy(dx: -geometry.workArea.minX, dy: -geometry.workArea.minY)
    }
    private static func path(_ rect: CGRect) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: min(10, rect.width / 4),
               cornerHeight: min(10, rect.height / 4), transform: nil)
    }
    private func moveHighlight(to rect: CGRect, duration: TimeInterval) {
        let reduced = MotionPreference.reduceMotion
        let visible = highlight.opacity > 0
        let presentation = highlight.presentation()
        let oldPosition = presentation?.position ?? highlight.position
        let oldBounds = presentation?.bounds ?? highlight.bounds
        let oldPath = presentation?.path ?? highlight.path
        let oldScale = presentation?.transform.m11 ?? 1
        let oldOpacity: Float = visible ? (presentation?.opacity ?? highlight.opacity) : 0
        highlight.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.bounds = CGRect(origin: .zero, size: rect.size)
        highlight.position = CGPoint(x: rect.midX, y: rect.midY)
        highlight.path = Self.path(highlight.bounds)
        highlight.opacity = 1
        CATransaction.commit()
        guard !reduced, duration > 0 else { return }
        func animate(_ key: String, _ from: Any?, _ to: Any?) {
            let animation = CABasicAnimation(keyPath: key)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .default)
            highlight.add(animation, forKey: key)
        }
        animate("position", visible ? oldPosition : highlight.position, highlight.position)
        animate("bounds", visible ? oldBounds : highlight.bounds, highlight.bounds)
        animate("path", visible ? oldPath : highlight.path, highlight.path)
        animate("opacity", oldOpacity, Float(1))
        if !visible || oldScale != 1 { animate("transform.scale", visible ? oldScale : 0.96, CGFloat(1)) }
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
            layout: Self.layout(for: descriptor), scale: screen.backingScaleFactor
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

    /// CI lab builds only (-DKRADO_LAB_HOOKS): KRADO_LAB_GRID=CxR forces a layout, because hosted
    /// runners have a 1024 × 768 screen where the real rule gives 1 × 1 and no cells to cross.
    private static func layout(for descriptor: ScreenDescriptor) -> GridLayout {
        #if KRADO_LAB_HOOKS
        if let value = ProcessInfo.processInfo.environment["KRADO_LAB_GRID"] {
            let parts = value.split(separator: "x").compactMap { Int($0) }
            if parts.count == 2, parts[0] > 0, parts[1] > 0 { return GridLayout(columns: parts[0], rows: parts[1]) }
        }
        #endif
        return GridPolicy.layout(for: descriptor)
    }

    func close() {
        wantsVisible = false
        panel.close()
    }

    /// A short ease-out fade; instant when the user has Reduce Motion on.
    private func fade(to alpha: CGFloat, completion: (@MainActor @Sendable () -> Void)?) {
        let duration = MotionPreference.reduceMotion ? 0 : Self.fadeDuration
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
    private weak var active: ScreenGrid?

    func reload() {
        active = nil
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

    func hideAll() { screens.forEach { $0.hide() }; active = nil }

    func show(_ screen: ScreenGrid, target: GridSpan?) {
        if active !== screen { active?.hide(); active = screen }
        screen.show(target: target)
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
