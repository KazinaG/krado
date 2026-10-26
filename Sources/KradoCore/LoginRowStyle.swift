import Foundation

/// How the Launch at Login row looks. Pure so tests can pin the rules.
public enum LoginRowStyle {
    public enum Ink: Equatable, Sendable {
        case label, disabled
    }

    /// One ink for the title and icon, like a native menu row. The row itself never
    /// highlights (maintainer 2026-10-26 17:17: only the switch can be pressed, the row
    /// does not light up), so there is no selected-text ink.
    public static func ink(enabled: Bool) -> Ink {
        enabled ? .label : .disabled
    }

    public enum SwitchSize: String, Sendable { case mini }
    public static let switchSize: SwitchSize = .mini
    public static func switchIsOn(for state: LoginItemState) -> Bool {
        state == .enabled || state == .needsApproval
    }

    /// What the Launch at Login row shows for one state of its switch.
    /// `pressed` is drawn by Apple's NSSwitch itself while the pointer holds it down;
    /// everything else is set by krado.
    public struct SwitchLook: Hashable, Sendable {
        public let isOn: Bool
        public let isEnabled: Bool
        public let pressed: Bool
        public let focusRing: Bool
        public let rowHighlight: Bool
        public let titleInk: Ink
        public let approvalHint: Bool
    }

    /// - Parameters:
    ///   - pressed: the pointer is holding the switch down.
    ///   - keyboardFocused: the keyboard (not the pointer) selected the row.
    public static func switchLook(state: LoginItemState, enabled: Bool, pressed: Bool,
                                  keyboardFocused: Bool) -> SwitchLook {
        SwitchLook(isOn: switchIsOn(for: state), isEnabled: enabled,
                   pressed: enabled && pressed, focusRing: enabled && keyboardFocused,
                   rowHighlight: false, titleInk: ink(enabled: enabled),
                   approvalHint: state == .needsApproval)
    }

    /// The row shows the keyboard focus ring only when a key moved the menu selection
    /// onto it. Pointer hover, another row, or closing the menu clears it.
    public struct KeyboardFocus: Equatable, Sendable {
        public private(set) var isFocused = false
        public init() {}
        public mutating func menuWillHighlight(thisRow: Bool?, byKeyboard: Bool) {
            isFocused = thisRow == true && byKeyboard
        }
        public mutating func menuDidClose() { isFocused = false }
    }
}

/// Horizontal layout of the Launch at Login row, in points.
public enum LoginRowLayout {
    /// Trailing edge of the switch, inset from the row's right edge.
    public static let trailingInset: Double = 17
    /// Minimum space between the title and the switch.
    public static let gap: Double = 16
    /// Room AppKit keeps after the trailing inset (matches native rows in CI menu-shots).
    public static let extra: Double = 32

    /// Width that fits the title and the switch, so the frame never
    /// has to change while toggling.
    public static func width(titleX: Double, titleWidth: Double, switchWidth: Double, minimum: Double) -> Double {
        return max(minimum, (titleX + titleWidth + gap + switchWidth + trailingInset + extra).rounded(.up))
    }

    /// Left edge of a right-aligned switch.
    public static func switchX(rowMaxX: Double, switchWidth: Double) -> Double {
        rowMaxX - trailingInset - switchWidth
    }
}
