import AppKit
import ApplicationServices
import KradoCore

// The source is installed exclusively on CFRunLoopGetMain(), so this callback runs on the main actor.
private let mouseTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let location = event.location
    MainActor.assumeIsolated { monitor.handle(type: type, location: location) }
    return Unmanaged.passUnretained(event)
}

@MainActor
final class DragMonitor {
    private struct Drag {
        let window: AXUIElement
        let initial: WindowSnapshot
        var hasDragged = false
        var hasMoved = false
    }

    private let glide = WindowGlide()
    private let screens: ScreenManager
    private let report: (String?) -> Void
    private let stateDidChange: () -> Void
    private let didMoveWindow: () -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var pollTimer: Timer?
    private var drag: Drag?
    private var cursor = CGPoint.zero
    private var target: (window: AXUIElement, frame: CGRect)?
    private var accumulator = SpanAccumulator<CGDirectDisplayID>()
    private var snapSession = DragSnapSession()
    /// Passive global key monitor, installed only while a drag is in progress so Esc can
    /// cancel snapping. Global key monitoring relies on the Accessibility permission krado has.
    private var keyMonitor: Any?
    var isRunning: Bool {
        guard let tap, CFMachPortIsValid(tap) else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    /// didMoveWindow runs after any drag, snapped or not, so keyboard grow anchors are forgotten.
    init(screens: ScreenManager, report: @escaping (String?) -> Void, stateDidChange: @escaping () -> Void,
         didMoveWindow: @escaping () -> Void = {}) {
        self.screens = screens
        self.report = report
        self.stateDidChange = stateDidChange
        self.didMoveWindow = didMoveWindow
    }

    func start() -> Bool {
        if isRunning { return true }
        // A retained but disabled/invalid tap is not an active monitor. Recreate it on retry.
        if tap != nil { stop() }
        // Do not create a tap until the non-prompting trust check succeeds.
        guard AXIsProcessTrusted() else { return false }
        let mask = [CGEventType.leftMouseDown, .leftMouseDragged, .leftMouseUp].reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << $1.rawValue)
        }
        // Session events suffice; the tap only observes events and never changes/consumes them.
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: mouseTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            return false
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        if isRunning { return true }
        stop()
        return false
    }

    func stop() {
        cancelDrag()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
    }

    func cancelDrag(keepingOverlay: Bool = false) {
        if !keepingOverlay {
            glide.finish()
        }
        pollTimer?.invalidate()
        pollTimer = nil
        drag = nil
        target = nil
        accumulator.reset()
        snapSession.end()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if !keepingOverlay { screens.hideAll() }
    }

    fileprivate func handle(type: CGEventType, location: CGPoint) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            cancelDrag()
            if let tap, CFMachPortIsValid(tap), AXIsProcessTrusted() {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            stateDidChange()
        case .leftMouseDown:
            cancelDrag()
            cursor = location
            guard let window = Accessibility.window(at: location),
                  let initial = Accessibility.snapshot(of: window) else { return }
            drag = Drag(window: window, initial: initial)
            snapSession.begin()
            keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let keyCode = event.keyCode
                MainActor.assumeIsolated { self?.handleKey(keyCode) }
            }
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            }
            if let pollTimer { RunLoop.main.add(pollTimer, forMode: .common) }
        case .leftMouseDragged:
            cursor = location
            drag?.hasDragged = true
        case .leftMouseUp:
            cursor = location
            // Invalidate a formerly valid target if the window resized or disappeared before release.
            sample()
            let finalTarget = target
            let dragged = drag?.hasDragged == true
            cancelDrag(keepingOverlay: finalTarget != nil)
            if dragged { didMoveWindow() }
            if let finalTarget {
                glide.run(window: finalTarget.window, to: finalTarget.frame) { [weak self] success in
                    self?.screens.hideAll()
                    self?.report(success ? nil : L10n.text("⚠︎ Window placement failed. The app may restrict its window size or position."))
                }
            }
        default:
            break
        }
    }

    private func handleKey(_ keyCode: UInt16) {
        guard snapSession.keyDown(keyCode) else { return }
        target = nil
        accumulator.reset()
        screens.hideAll()
    }

    private func sample() {
        target = nil
        guard let drag, drag.hasDragged else { return }
        guard snapSession.allowsSnap else {
            screens.hideAll()
            return
        }
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let shift = flags.contains(.maskShift)
        let option = flags.contains(.maskAlternate)
        if option {
            _ = accumulator.update(screenID: nil, hit: nil, shift: shift, option: true)
        }
        if !shift { accumulator.reset() }
        guard let current = Accessibility.snapshot(of: drag.window) else {
            cancelDrag()
            return
        }
        switch WindowMovement.classify(initial: drag.initial, current: current) {
        case .resized:
            // Once a resize is observed, never reclassify this gesture as a move.
            cancelDrag()
        case .stationary where !drag.hasMoved:
            return
        case .stationary, .moving:
            self.drag?.hasMoved = true
            guard !option else {
                screens.hideAll()
                return
            }
            let currentScreen = screens.screen(at: cursor)
            let retainedScreen = shift ? screens.screens.first { $0.displayID == accumulator.screenID } : nil
            guard let screen = currentScreen ?? retainedScreen else {
                screens.hideAll()
                return
            }
            let span = accumulator.update(
                screenID: screen.displayID, hit: screen.geometry.hitTest(cursor), shift: shift, option: false
            )
            screens.show(screen, target: span)
            if let span { target = (drag.window, screen.geometry.frame(for: span)) }
        }
    }
}
