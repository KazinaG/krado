import Foundation

/// How the Launch at Login row looks. Pure so tests can pin the rules.
public enum LoginRowStyle {
    /// AppKit may clear its custom-view highlight on mouse-up without another
    /// mouse move. Retain it only for the pointer that clicked this row. Moving
    /// the menu selection elsewhere always wins, including keyboard navigation.
    public struct Highlight: Equatable, Sendable {
        public private(set) var pointerInsideSinceClick = false
        private var anotherItemHighlighted = false

        public init() {}
        public mutating func clickedInside() { pointerInsideSinceClick = !anotherItemHighlighted }
        public mutating func mouseExited() { pointerInsideSinceClick = false }
        public mutating func menuWillHighlight(thisRow: Bool?) {
            anotherItemHighlighted = thisRow == false
            if anotherItemHighlighted { pointerInsideSinceClick = false }
        }
        public mutating func menuDidClose() {
            pointerInsideSinceClick = false
            anotherItemHighlighted = true
        }
        public func isHighlighted(menuItemHighlighted: Bool, enabled: Bool) -> Bool {
            enabled && !anotherItemHighlighted && (menuItemHighlighted || pointerInsideSinceClick)
        }
    }

    public enum Ink: Equatable, Sendable {
        case label, disabled, selectedText
    }

    /// One ink for the title, like a native menu row.
    public static func ink(highlighted: Bool, enabled: Bool) -> Ink {
        !enabled ? .disabled : highlighted ? .selectedText : .label
    }

    public enum SwitchSize: String, Sendable { case mini }
    public static let switchSize: SwitchSize = .mini
    public static func switchIsOn(for state: LoginItemState) -> Bool {
        state == .enabled || state == .needsApproval
    }

    /// The custom row's selection, measured against native rows (Quit) in CI
    /// login-hover at 1x: 5 pt in from each side, full row height, corner radius
    /// 7 pt on macOS 26 (best fit of the antialiased corner, 1x) and 4 pt before. AppKit does not publish these.
    public static let selectionHorizontalInset: Double = 5
    public static func selectionCornerRadius(macOS26OrLater: Bool) -> Double {
        macOS26OrLater ? 7 : 4
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
