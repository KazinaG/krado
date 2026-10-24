import Foundation

/// Fixed geometry across On, Off and approval; state text is accessibility-only.
public enum LoginBadgeMetrics {
    public static let diameter: Double = 16
    public static let symbolSize: Double = 9
    public static let strokeWidth: Double = 1

    public static func symbolInset(diameter: Double = LoginBadgeMetrics.diameter) -> Double {
        (diameter - symbolSize) / 2
    }
}
