/// One toggle per physical key press for the login row's listen-only key tap.
/// The tap can deliver the same key down twice (same timestamp), and auto-repeat
/// sends more key downs while the key is held, so a key down may act only when the
/// gate is armed, it is not a repeat and its timestamp is new. A key down that was
/// handled disarms the gate until the next key up. Timestamps are `CGEventTimestamp`.
///
/// Two steps (`admit`, then `handled`) rather than a callback, so the caller does not
/// hold the gate while it toggles the row.
public struct KeyPressGate: Equatable, Sendable {
    public private(set) var armed = true
    public private(set) var lastKeyDownTime: UInt64 = 0

    public init() {}

    /// The tap was (re)installed: the next press may act.
    public mutating func rearm() { armed = true }

    public mutating func keyUp() { armed = true }

    /// Whether this key down may act. An admitted key down's timestamp is remembered,
    /// whether or not the caller then handles it.
    public mutating func admit(isRepeat: Bool, time: UInt64) -> Bool {
        guard armed, !isRepeat, time != lastKeyDownTime else { return false }
        lastKeyDownTime = time
        return true
    }

    /// The admitted key down toggled the row: ignore key downs until a key up.
    public mutating func handled() { armed = false }
}
