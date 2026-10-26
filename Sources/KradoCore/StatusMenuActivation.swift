/// How krado opens its status menu.
///
/// On macOS 26 a menu of an app that is not active draws an on `NSSwitch` in the
/// inactive gray, not the accent colour; macOS 15 draws it in the accent colour either
/// way. Measured in CI (`login-switch-probe`, runs 40292151161 and 40293171016): the
/// same switch reads (191, 192, 191) with krado inactive and (0, 118, 248) once krado
/// is active. A SwiftUI `Toggle`, with `.tint` or a `controlActiveState` environment,
/// stays gray too, and activating from `menuWillOpen` closes the menu. So on macOS 26
/// a click on the status item activates krado first, then opens the menu, and gives
/// focus back to the previous app after the menu closes.
public enum StatusMenuActivation {
    public static func activatesBeforeOpening(macOS26OrLater: Bool) -> Bool { macOS26OrLater }

    /// Give focus back after the menu closes, unless krado was already in front, the
    /// previous app has quit, a krado window (guide, About, uninstall) is now showing,
    /// or krado is no longer active (the user switched apps, or an item opened another
    /// app such as System Settings): never undo a later activation.
    public static func returnsFocus(previousWasKrado: Bool, previousStillRunning: Bool,
                                    kradoWindowShowing: Bool, kradoStillActive: Bool) -> Bool {
        !previousWasKrado && previousStillRunning && !kradoWindowShowing && kradoStillActive
    }
}
