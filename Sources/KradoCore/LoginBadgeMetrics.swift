import Foundation

/// Geometry of the Launch at Login badge, based on native badge measurements.
public enum LoginBadgeMetrics {
    public static let fontSize: Double = 10
    public static let isBold = false
    public static let horizontalPadding: Double = 8
    public static let height: Double = 16

    public static let checkmarkWidth: Double = 9
    public static let checkmarkGap: Double = 3

    public static func contentWidth(textWidth: Double, showsCheckmark: Bool) -> Double {
        textWidth + (showsCheckmark ? checkmarkWidth + checkmarkGap : 0)
    }

    public static func capsuleWidth(textWidth: Double, showsCheckmark: Bool = false) -> Double {
        max(ceil(contentWidth(textWidth: textWidth, showsCheckmark: showsCheckmark)) + 2 * horizontalPadding, height * 2)
    }

    public static func textX(capsuleMinX: Double, capsuleWidth: Double, textWidth: Double) -> Double {
        capsuleMinX + (capsuleWidth - textWidth) / 2
    }
}
