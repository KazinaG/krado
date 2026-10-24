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

    /// One ink for the title and the state word, like a native menu row:
    /// the state is read from the word, not from colour or a mark.
    public static func ink(highlighted: Bool, enabled: Bool) -> Ink {
        !enabled ? .disabled : highlighted ? .selectedText : .label
    }
}

/// Horizontal layout of the Launch at Login row, in points.
public enum LoginRowLayout {
    /// Trailing edge of the state word, inset from the row's right edge.
    public static let trailingInset: Double = 17
    /// Minimum space between the title and the state word.
    public static let gap: Double = 16
    /// Room AppKit keeps after the trailing inset (matches native rows in CI menu-shots).
    public static let extra: Double = 32

    /// Width that fits the title and the widest state word, so the frame never
    /// has to change while toggling.
    public static func width(titleX: Double, titleWidth: Double, stateWidths: [Double], minimum: Double) -> Double {
        let state = stateWidths.max() ?? 0
        return max(minimum, (titleX + titleWidth + gap + state + trailingInset + extra).rounded(.up))
    }

    /// Left edge of a right-aligned state word.
    public static func stateX(rowMaxX: Double, stateWidth: Double) -> Double {
        (rowMaxX - trailingInset - stateWidth).rounded()
    }
}
