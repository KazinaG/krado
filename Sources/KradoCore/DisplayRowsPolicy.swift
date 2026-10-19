public enum DisplayRowsPolicy {
    public static func showsRows<S: Collection>(for screens: S) -> Bool {
        screens.count >= 2
    }
}
