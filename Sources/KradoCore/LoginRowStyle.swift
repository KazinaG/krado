import Foundation

/// How the Launch at Login row looks. Pure so tests can pin the rules.
public enum LoginRowStyle {
    /// The row is highlighted exactly when AppKit highlights its menu item. Mouse and
    /// keyboard share that one highlight, as in every native menu; the row keeps no
    /// hover state of its own (a missed mouse-exit used to leave a second highlight).
    public static func isHighlighted(menuItemHighlighted: Bool, enabled: Bool) -> Bool {
        enabled && menuItemHighlighted
    }

    public enum Ink: Equatable, Sendable {
        case label, disabled, selectedText, white, badgeInk
    }

    public struct Badge: Equatable, Sendable {
        public let pill: Ink
        public let pillAlpha: Double
        public let text: Ink
    }

    /// Unhighlighted: a faint pill with label text, like the native badge. Highlighted:
    /// a solid white pill with dark text, so On/Off reads the same on every accent colour
    /// and in Light and Dark (white text on a faint pill nearly vanished on blue).
    public static func badge(highlighted: Bool, enabled: Bool) -> Badge {
        if !enabled { return Badge(pill: .label, pillAlpha: 0.1, text: .disabled) }
        if highlighted { return Badge(pill: .white, pillAlpha: 1, text: .badgeInk) }
        return Badge(pill: .label, pillAlpha: 0.1, text: .label)
    }

    /// sRGB of `.badgeInk` (#1C1C1E, Apple's dark label grey).
    public static let badgeInk: RGB = RGB(0x1C, 0x1C, 0x1E)

    public struct RGB: Equatable, Sendable {
        public let r: Double, g: Double, b: Double
        public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
        public static let white = RGB(255, 255, 255)
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
