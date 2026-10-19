import AppKit
#if !STATUS_RENDERER
import KradoCore
#endif

/// Shared by the menu and the offscreen renderer; no application or window is created here.
@MainActor
enum StatusPresentation {
    static func image(for symbol: StatusSymbol, pointSize: CGFloat = 15, description: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: symbol.name, accessibilityDescription: description) else { return nil }
        let color: NSColor
        switch symbol.color {
        case .adaptive: color = .labelColor
        case .success: color = .systemGreen
        case .warning: color = .systemOrange
        case .secondary: color = .secondaryLabelColor
        }
        // Filled symbols have a separate foreground layer. A one-color palette also
        // fills the checkmark/exclamation/pause glyph, making the whole shape solid.
        let palette: [NSColor]
        switch symbol.name {
        case "exclamationmark.triangle.fill": palette = [.black, color]
        case "checkmark.circle.fill", "record.circle.fill": palette = [.white, color]
        case "pause.circle.fill": palette = [.labelColor, color]
        default: palette = [color]
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: palette))
        guard let configured = image.withSymbolConfiguration(configuration) else { return nil }
        configured.isTemplate = false
        return configured
    }

    static func menuBarImage(for state: StatusState, description: String) -> NSImage? {
        let symbol = statusAppearance(for: state).menuBar
        guard let image = image(for: symbol, pointSize: 16, description: description) else { return nil }
        // Only the active grid follows the menu bar's own light/dark/highlight tint.
        image.isTemplate = symbol.color == .adaptive
        return image
    }

    static func rowTitle(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    /// Standard attributed menu text preserves the system menu material.
    static func statusTitle(_ title: String, detail: String) -> NSAttributedString {
        let text = NSMutableAttributedString(string: title, attributes: [
            .font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.labelColor,
        ])
        text.append(NSAttributedString(string: "\n" + detail, attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return text
    }

    static func permissionTitle(for state: StatusState) -> String {
        state == .permissionNeeded ? "Permission needed" : "Accessibility allowed"
    }

    static func monitorTitle(for state: StatusState) -> String {
        switch state {
        case .watching: "Watching"
        case .permissionNeeded, .paused: "Paused"
        case .stopped: "Stopped"
        case .tapError: "Monitoring unavailable"
        }
    }

    static func permissionDescription(for state: StatusState) -> String {
        state == .permissionNeeded
            ? "Accessibility permission is required. Click to open setup."
            : "Accessibility permission is granted."
    }

    static func monitorDescription(for state: StatusState) -> String {
        switch state {
        case .watching: "krado is watching window drags."
        case .permissionNeeded: "Monitoring is paused until Accessibility permission is granted."
        case .paused: "Window drag monitoring is paused."
        case .stopped: "Window drag monitoring is stopped."
        case .tapError: "Window drag monitoring is unavailable. krado will retry automatically."
        }
    }

    static func menuBarDescription(for state: StatusState) -> String {
        switch state {
        case .watching: "krado — Watching window drags"
        case .permissionNeeded: "krado — Accessibility permission needed"
        case .paused: "krado — Monitoring paused"
        case .stopped: "krado — Monitoring stopped"
        case .tapError: "krado — Event monitoring error"
        }
    }
}
