import AppKit
import ApplicationServices
import KradoCore

/// AX calls are confined to the main run loop. No permission prompts are made here.
@MainActor
enum Accessibility {
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

    /// Reapply position after size because some apps move the origin while resizing.
    static func setFrame(_ frame: CGRect, of window: AXUIElement) -> Bool {
        var origin = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return false }
        let first = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let second = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let third = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        return first == .success && second == .success && third == .success
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
