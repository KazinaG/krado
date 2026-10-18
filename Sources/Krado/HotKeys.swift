import AppKit
import ApplicationServices
import Carbon
import KradoCore

private let hotKeySignature: OSType = 0x4B524144 // KRAD

// Installed on the application target and dispatched by the main event loop.
private let hotKeyCallback: EventHandlerUPP = { _, event, context in
    guard let event, let context else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
    guard status == noErr, identifier.signature == hotKeySignature else { return OSStatus(eventNotHandledErr) }
    let hotKeys = Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { hotKeys.handle(identifier.id) }
    return noErr
}

@MainActor
final class HotKeys {
    private let screens: ScreenManager
    private let report: (String?) -> Void
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []

    init(screens: ScreenManager, report: @escaping (String?) -> Void) {
        self.screens = screens
        self.report = report
    }

    func start() {
        guard AXIsProcessTrusted(), handler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            NSLog("krado: InstallEventHandler failed (%d)", status)
            return
        }
        for keyCode in UInt32(123)...126 {
            for extend in [false, true] {
                let id = keyCode + (extend ? 256 : 0)
                let modifiers = UInt32(controlKey | cmdKey) | (extend ? UInt32(shiftKey) : 0)
                var reference: EventHotKeyRef?
                let result = RegisterEventHotKey(keyCode, modifiers,
                    EventHotKeyID(signature: hotKeySignature, id: id), GetApplicationEventTarget(), 0, &reference)
                if result == noErr, let reference {
                    registrations.append(reference)
                } else {
                    NSLog("krado: hot key %u (extend=%d) registration failed (%d)", keyCode, extend ? 1 : 0, result)
                }
            }
        }
    }

    func stop() {
        for reference in registrations { UnregisterEventHotKey(reference) }
        registrations.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    fileprivate func handle(_ id: UInt32) {
        guard AXIsProcessTrusted(), let direction = Direction(keyCode: id % 256),
              let window = Accessibility.focusedWindow(),
              let snapshot = Accessibility.snapshot(of: window) else { return }
        let available = screens.screens.map { NavigationScreen(geometry: $0.geometry, frame: $0.screenFrameAX) }
        let frame = CGRect(origin: snapshot.position, size: snapshot.size)
        guard let target = ZoneNavigator.target(windowFrame: frame, screens: available, direction: direction, extend: id >= 256) else { return }
        let placed = Accessibility.setFrame(available[target.screenIndex].geometry.frame(for: target.span), of: window)
        report(placed ? nil : L10n.text("⚠︎ Window placement failed. The app may restrict its window size or position."))
    }
}
