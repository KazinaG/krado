import Foundation

/// Geometry of the Launch at Login badge, matched to the native NSMenuItemBadge
/// as measured in CI menu-shots (1x) on macOS 15 and 26.
public enum LoginBadgeMetrics {
    public static let fontSize: Double = 10
    public static let isBold = false
    public static let horizontalPadding: Double = 8
    public static let height: Double = 16

    public static func capsuleWidth(textWidth: Double) -> Double {
        max(ceil(textWidth) + 2 * horizontalPadding, height * 2)
    }

    public static func textX(capsuleMinX: Double, capsuleWidth: Double, textWidth: Double) -> Double {
        capsuleMinX + (capsuleWidth - textWidth) / 2
    }
}
