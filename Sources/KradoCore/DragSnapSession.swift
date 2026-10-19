/// Whether the current drag may still snap. Esc cancels snapping for the rest of the gesture;
/// the window then stays wherever it is dropped, as with Option+drag.
public struct DragSnapSession: Equatable, Sendable {
    /// Carbon virtual key code for Escape.
    public static let escapeKeyCode: UInt16 = 53

    public private(set) var isActive = false
    public private(set) var isCancelled = false

    public init() {}

    /// A new mouse-down on a window starts a fresh gesture.
    public mutating func begin() {
        isActive = true
        isCancelled = false
    }

    public mutating func end() {
        isActive = false
        isCancelled = false
    }

    /// Returns true when this key press cancelled snapping just now.
    public mutating func keyDown(_ keyCode: UInt16) -> Bool {
        guard isActive, !isCancelled, keyCode == Self.escapeKeyCode else { return false }
        isCancelled = true
        return true
    }

    public var allowsSnap: Bool { isActive && !isCancelled }
}
