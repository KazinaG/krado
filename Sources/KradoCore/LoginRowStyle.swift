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
        /// Text on the solid On capsule: the menu's own background ink (white in
        /// light mode, near-black in dark mode), so it reads like a cut-out.
        case onFillText
        /// #1C1C1E, Apple's dark label grey: text on the white On capsule while highlighted.
        case badgeInk
    }

    /// One ink for the title, like a native menu row.
    public static func ink(highlighted: Bool, enabled: Bool) -> Ink {
        !enabled ? .disabled : highlighted ? .selectedText : .label
    }

    /// How Off (and Needs approval) is drawn. On is always the solid capsule.
    /// A = outline only, B = faint fill, C = outline and faint fill.
    public enum OffStyle: String, CaseIterable, Equatable, Sendable {
        case outline = "A", faintFill = "B", outlineAndFaintFill = "C"
    }

    /// What ships. A is closest to 0.1.9's outlined Off (Kazina 10/26 01:53: fill only when On).
    public static let shippedOffStyle: OffStyle = .outline

    /// The state capsule at the trailing edge: the state word inside a capsule,
    /// solid only when On.
    public struct Capsule: Equatable, Sendable {
        public let fill: Ink?
        public let fillAlpha: Double
        public let ring: Ink?
        /// Opacity of the ring. nil = the ink as the system gives it (Off's outline).
        public let ringAlpha: Double?
        public let text: Ink
        public init(fill: Ink?, fillAlpha: Double, ring: Ink?, ringAlpha: Double? = nil, text: Ink) {
            self.fill = fill; self.fillAlpha = fillAlpha; self.ring = ring; self.ringAlpha = ringAlpha; self.text = text
        }
        /// The solid fill that means On. Faint fills (style B/C) are not "filled".
        public var isSolid: Bool { fill != nil && fillAlpha >= LoginRowStyle.restOpacity }
        /// On draws its fill and ring as one shape at one opacity, so the edge is
        /// never darker than the fill (Kazina 10/26 03:22).
        public var fillAndRingShareOpacity: Bool {
            fill != nil && ring == fill && ringAlpha == fillAlpha
        }
    }

    /// On's fill and ring, and Off's outline, share one opacity of the title's ink, so they
    /// are equally strong (Kazina 10/26 03:22, and 21:55 "オンの塗りとオフの枠を同じ濃さに").
    /// At rest 85 %, the opacity of Apple's labelColor (Kazina 03:28; 216/255 in CI).
    /// While highlighted 100 %, the opacity of the selected-menu-item text itself: 85 % made
    /// the yellow accent's On fainter than the title (2.14:1 against 2.42:1).
    public static let restOpacity = 0.85
    public static func onOpacity(highlighted: Bool) -> Double { highlighted ? 1 : restOpacity }

    /// Faint fill of style B/C: under the highlight it is lighter so the word stays legible.
    public static let faintFillAlpha = 0.12
    public static let faintFillAlphaHighlighted = 0.2

    public static func capsule(state: LoginItemState, highlighted: Bool, enabled: Bool,
                               offStyle: OffStyle = shippedOffStyle) -> Capsule {
        if state == .enabled && enabled {
            let ink = ink(highlighted: highlighted, enabled: enabled)
            let alpha = onOpacity(highlighted: highlighted)
            return Capsule(fill: ink, fillAlpha: alpha, ring: ink, ringAlpha: alpha,
                           text: highlighted ? .badgeInk : .onFillText)
        }
        // Off, Needs approval and any disabled row: never solid.
        let ink = ink(highlighted: highlighted, enabled: enabled)
        let faint = highlighted ? faintFillAlphaHighlighted : faintFillAlpha
        switch offStyle {
        case .outline:
            // The outline at On's opacity (Kazina 10/26 21:55), only while the row is enabled.
            return Capsule(fill: nil, fillAlpha: 0, ring: ink,
                           ringAlpha: enabled ? onOpacity(highlighted: highlighted) : nil, text: ink)
        case .faintFill:
            return Capsule(fill: ink, fillAlpha: faint, ring: nil, text: ink)
        case .outlineAndFaintFill:
            return Capsule(fill: ink, fillAlpha: faint, ring: ink, text: ink)
        }
    }

    /// Cross-fade of the capsule when the state changes while the menu is open
    /// (Kazina 10/26 03:14: 150 ms). Opacity only, nothing moves or scales, so it also
    /// runs with Reduce Motion: Apple's HIG lists replacing motion with fades as a way
    /// to reduce motion (developer.apple.com/design/human-interface-guidelines/accessibility).
    public struct Fade: Equatable, Sendable {
        public static let duration: Double = 0.15
        /// Reduce Motion keeps the same cross-fade (see above).
        public static func duration(reduceMotion: Bool) -> Double { duration }

        public private(set) var startedAt: Double?
        public init() {}
        public mutating func start(at time: Double) { startedAt = time }
        public mutating func finish() { startedAt = nil }

        /// 0 at the start, 1 when done; Core Animation's default curve, like krado's other motion.
        public func progress(at time: Double) -> Double {
            guard let startedAt else { return 1 }
            return MotionSpec.defaultTiming((time - startedAt) / Self.duration)
        }
        public func isRunning(at time: Double) -> Bool {
            guard let startedAt else { return false }
            return time - startedAt < Self.duration
        }
        /// Opacity of the previous and the new capsule.
        public func opacities(at time: Double) -> (outgoing: Double, incoming: Double) {
            let p = progress(at: time)
            return (1 - p, p)
        }
    }

    /// The custom row's selection, measured against native rows (Quit) in CI
    /// login-hover at 1x: 5 pt in from each side, full row height, corner radius
    /// 7 pt on macOS 26 (best fit of the antialiased corner, 1x) and 4 pt before. AppKit does not publish these.
    public static let selectionHorizontalInset: Double = 5
    public static func selectionCornerRadius(macOS26OrLater: Bool) -> Double {
        macOS26OrLater ? 7 : 4
    }

    /// sRGB of `.badgeInk`.
    public static let badgeInk = RGB(0x1C, 0x1C, 0x1E)

    public struct RGB: Equatable, Sendable {
        public let r: Double, g: Double, b: Double
        public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
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

/// Size of the state capsule, in points (015c2c8's capsule: 10 pt medium, 16 pt high,
/// 8 pt padding, matched to the native NSMenuItemBadge in CI menu-shots).
public enum LoginBadgeMetrics {
    public static let fontSize: Double = 10
    public static let height: Double = 16
    public static let horizontalPadding: Double = 8
    public static let strokeWidth: Double = 1

    /// On and Off share one width, so toggling never changes the capsule's size.
    /// Needs approval gets the width of its own (longer) word.
    public static func capsuleWidth(textWidth: Double, onOffTextWidths: [Double]) -> Double {
        let onOff = onOffTextWidths.max() ?? 0
        let text = textWidth <= onOff + 0.5 ? onOff : textWidth
        return max((text + 2 * horizontalPadding).rounded(.up), height * 2)
    }

    public static func textX(capsuleMinX: Double, capsuleWidth: Double, textWidth: Double) -> Double {
        capsuleMinX + (capsuleWidth - textWidth) / 2
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
