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
        case label, secondaryLabel, disabled, selectedText, white, black, badgeInk
    }

    public struct Badge: Equatable, Sendable {
        public let pill: Ink
        public let pillAlpha: Double
        public let text: Ink
        public let fill: Bool
        public let showsCheckmark: Bool
        public var symbolName: String? {
            showsCheckmark ? "checkmark" : showsApproval ? "exclamationmark" : nil
        }
        public var showsApproval: Bool = false
        /// A separate boundary is needed around the recessed highlighted Off fill.
        public var ring: Ink? = nil
        public var ringAlpha: Double = 1
    }

    /// On is filled and checked; Off is outlined until highlighted, then recessed.
    /// Approval and disabled states keep their existing faint fill or outline.
    public static func badge(state: LoginItemState, highlighted: Bool, enabled: Bool,
                             offRingAlpha: Double = 0.45) -> Badge {
        let on = state == .enabled
        let off = state == .disabled || state == .unavailable
        if !enabled {
            return Badge(pill: .label, pillAlpha: 0.1, text: .disabled,
                         fill: !off, showsCheckmark: on, showsApproval: state == .needsApproval,
                         ring: off ? .label : nil, ringAlpha: 0.1)
        }
        if off {
            return Badge(pill: highlighted ? .black : .label,
                         pillAlpha: highlighted ? 0.4 : offRingAlpha,
                         text: highlighted ? .white : .secondaryLabel,
                         fill: highlighted, showsCheckmark: false,
                         ring: highlighted ? .white : .label,
                         ringAlpha: highlighted ? 1 : offRingAlpha)
        }
        if on && highlighted {
            return Badge(pill: .white, pillAlpha: 1, text: .badgeInk,
                         fill: true, showsCheckmark: true)
        }
        return Badge(pill: highlighted ? .selectedText : .label,
                     pillAlpha: on ? 0.14 : 0.1,
                     text: highlighted ? .selectedText : .label,
                     fill: true, showsCheckmark: on, showsApproval: state == .needsApproval)
    }

    /// sRGB of `.badgeInk` (#1C1C1E, Apple's dark label grey).
    public static let badgeInk: RGB = RGB(0x1C, 0x1C, 0x1E)

    public struct RGB: Equatable, Sendable {
        public let r: Double, g: Double, b: Double
        public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        public static let white = RGB(255, 255, 255)
    }

    public static func composite(_ ink: RGB, alpha: Double, over background: RGB) -> RGB {
        RGB(ink.r * alpha + background.r * (1 - alpha),
            ink.g * alpha + background.g * (1 - alpha),
            ink.b * alpha + background.b * (1 - alpha))
    }

    /// Preserve the faint Off ring when it passes. Its target never exceeds
    /// native label ink on the same background, even when that is below 3:1.
    public static func offRingAlpha(label: RGB, labelAlpha: Double = 1, background: RGB) -> Double {
        let target = min(3, contrast(composite(label, alpha: labelAlpha, over: background), background))
        return contrast(composite(label, alpha: 0.45, over: background), background) >= target ? 0.45 : 1
    }

    /// WCAG 2 contrast ratio of two sRGB colours (0–255 per channel).
    public static func contrast(_ a: RGB, _ b: RGB) -> Double {
        func channel(_ v: Double) -> Double {
            let c = v / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func luminance(_ c: RGB) -> Double { 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b) }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
