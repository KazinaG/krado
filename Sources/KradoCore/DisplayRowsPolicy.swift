public enum DisplayRowsPolicy {
    /// SF Symbol shown in front of each monitor row, same template style as other menu actions.
    public static let symbolName = "display"

    public static func showsRows<S: Collection>(for screens: S) -> Bool {
        screens.count >= 2
    }
}
