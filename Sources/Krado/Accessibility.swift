import AppKit
import QuartzCore
import ApplicationServices
import KradoCore

/// AX calls are confined to the main run loop. No permission prompts are made here.
@MainActor
enum Accessibility {
    static func focusedWindow() -> AXUIElement? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.1)
        guard let window = elementAttribute(element, kAXFocusedWindowAttribute) else { return nil }
        return movableWindow(window)
    }

    static func window(at point: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success,
              var current = element else { return nil }

        for _ in 0..<16 {
            if stringAttribute(current, kAXRoleAttribute) == kAXWindowRole {
                return movableWindow(current)
            }
            if let window = elementAttribute(current, kAXWindowAttribute) {
                return movableWindow(window)
            }
            guard let parent = elementAttribute(current, kAXParentAttribute), !CFEqual(current, parent) else { break }
            current = parent
        }
        return nil
    }

    private static func movableWindow(_ window: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        AXUIElementSetMessagingTimeout(window, 0.1)
        var movable = DarwinBoolean(false)
        var resizable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &movable) == .success,
              AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &resizable) == .success,
              movable.boolValue, resizable.boolValue else { return nil }
        return window
    }

    static func snapshot(of window: AXUIElement) -> WindowSnapshot? {
        guard let positionValue = attribute(window, kAXPositionAttribute),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              let sizeValue = attribute(window, kAXSizeAttribute),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        let axPosition = unsafeDowncast(positionValue, to: AXValue.self)
        let axSize = unsafeDowncast(sizeValue, to: AXValue.self)
        guard AXValueGetType(axPosition) == .cgPoint, AXValueGetType(axSize) == .cgSize else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(axPosition, .cgPoint, &position), AXValueGetValue(axSize, .cgSize, &size),
              position.x.isFinite, position.y.isFinite,
              size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
        return WindowSnapshot(position: position, size: size)
    }

    /// Use the same shrink–move–grow order as the glide, including the final snap.
    static func setFrame(_ frame: CGRect, of window: AXUIElement) -> Bool {
        guard let actual = snapshot(of: window) else { return false }
        let current = CGRect(origin: actual.position, size: actual.size)
        let bridge = MotionSpec.bridgeSize(from: current, to: frame)
        if bridge != current.size && !writeSize(bridge, of: window).success { return false }
        if !writePosition(frame.origin, of: window).success { return false }
        if bridge != frame.size && !writeSize(frame.size, of: window).success { return false }
        // Some apps move their origin during a resize; avoid a redundant final write.
        guard let readback = snapshot(of: window) else { return false }
        return readback.position == frame.origin || writePosition(frame.origin, of: window).success
    }

    static func writeSize(_ size: CGSize, of window: AXUIElement) -> (success: Bool, milliseconds: Double) {
        var value = size
        guard let ax = AXValueCreate(.cgSize, &value) else { return (false, 0) }
        let began = CACurrentMediaTime()
        let result = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, ax)
        return (result == .success, (CACurrentMediaTime() - began) * 1000)
    }

    static func writePosition(_ point: CGPoint, of window: AXUIElement) -> (success: Bool, milliseconds: Double) {
        var value = point
        guard let ax = AXValueCreate(.cgPoint, &value) else { return (false, 0) }
        let began = CACurrentMediaTime()
        let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, ax)
        return (result == .success, (CACurrentMediaTime() - began) * 1000)
    }

    private static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }

    private static func stringAttribute(_ element: AXUIElement, _ key: String) -> String? {
        attribute(element, key) as? String
    }

    private static func elementAttribute(_ element: AXUIElement, _ key: String) -> AXUIElement? {
        guard let value = attribute(element, key), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}
