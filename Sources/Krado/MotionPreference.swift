import AppKit

/// The user's Reduce Motion setting. CI lab builds (-DKRADO_LAB_HOOKS) can ignore it with
/// KRADO_LAB_IGNORE_REDUCE_MOTION=1, because hosted macOS runners ship with Reduce Motion on.
@MainActor
enum MotionPreference {
    static var reduceMotion: Bool {
        #if KRADO_LAB_HOOKS
        if ProcessInfo.processInfo.environment["KRADO_LAB_IGNORE_REDUCE_MOTION"] == "1" { return false }
        #endif
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
