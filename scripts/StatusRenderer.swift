// Compiled by render-status.swift. This never starts NSApplication.
import AppKit

@main
@MainActor
struct RenderStatus {
    static let scale: CGFloat = 2

    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let destination = CommandLine.arguments.dropFirst().first.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? root.appendingPathComponent("docs/assets/status", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        for state in StatusState.allCases {
            for dark in [false, true] {
                let theme = dark ? "dark" : "light"
                guard let appearance = NSAppearance(named: dark ? .darkAqua : .aqua) else {
                    throw RenderError.unavailableAppearance(theme)
                }
                var failure: Error?
                appearance.performAsCurrentDrawingAppearance {
                    do {
                        let image = try required(StatusPresentation.menuBarImage(for: state, description: state.rawValue))
                        try render(size: NSSize(width: 40, height: 24), to: destination.appendingPathComponent("\(state.rawValue)-menubar-\(theme)@2x.png")) {
                            (dark ? NSColor(calibratedWhite: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.96, alpha: 1)).setFill()
                            NSRect(x: 0, y: 0, width: 40, height: 24).fill()
                            try draw(image, in: NSRect(x: 11, y: 3, width: 18, height: 18), templateTint: image.isTemplate ? .labelColor : nil)
                        }

                        for language in ["en", "ja"] {
                            let strings = try localization(language, root: root)
                            let permission = try localized(StatusPresentation.permissionTitle(for: state), in: strings)
                            let monitor = try localized(StatusPresentation.monitorTitle(for: state), in: strings)
                            let symbols = statusAppearance(for: state)
                            let permissionImage = try required(StatusPresentation.image(for: symbols.permission, description: permission))
                            let monitorImage = try required(StatusPresentation.image(for: symbols.monitor, description: monitor))
                            try render(size: NSSize(width: 280, height: 76), to: destination.appendingPathComponent("\(state.rawValue)-menu-\(language)-\(theme)@2x.png")) {
                                NSColor.windowBackgroundColor.setFill()
                                NSRect(x: 0, y: 0, width: 280, height: 76).fill()
                                let section = NSRect(x: 6, y: 6, width: 268, height: 64)
                                NSColor.controlBackgroundColor.setFill()
                                NSBezierPath(roundedRect: section, xRadius: 7, yRadius: 7).fill()
                                try row(permission, image: permissionImage, y: 44)
                                try row(monitor, image: monitorImage, y: 16)
                            }
                        }
                    } catch { failure = error }
                }
                if let failure { throw failure }
            }
        }
        print("Rendered 30 offscreen PNGs to \(destination.path)")
    }

    static func row(_ text: String, image: NSImage, y: CGFloat) throws {
        try draw(image, in: NSRect(x: 17, y: y, width: 17, height: 17))
        let title = StatusPresentation.rowTitle(text)
        title.draw(at: NSPoint(x: 44, y: y + (17 - title.size().height) / 2))
    }

    /// Template tinting happens in a transparent scratch bitmap, preserving the background.
    static func draw(_ image: NSImage, in rect: NSRect, templateTint: NSColor? = nil) throws {
        guard let templateTint else {
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return
        }
        let rep = try bitmap(size: rect.size)
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { throw RenderError.bitmap }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let bounds = NSRect(origin: .zero, size: rect.size)
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        templateTint.setFill()
        bounds.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()
        let tinted = NSImage(size: rect.size)
        tinted.addRepresentation(rep)
        tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    static func render(size: NSSize, to url: URL, drawing: () throws -> Void) throws {
        let rep = try bitmap(size: size)
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { throw RenderError.bitmap }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        try drawing()
        guard let png = rep.representation(using: .png, properties: [:]) else { throw RenderError.bitmap }
        try png.write(to: url)
    }

    static func bitmap(size: NSSize) throws -> NSBitmapImageRep {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { throw RenderError.bitmap }
        rep.size = size
        return rep
    }

    static func required(_ image: NSImage?) throws -> NSImage {
        guard let image else { throw RenderError.missingSymbol }
        return image
    }

    static func localization(_ language: String, root: URL) throws -> [String: String] {
        let path = root.appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
        let data = try Data(contentsOf: path)
        guard let strings = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            throw RenderError.localization(language)
        }
        return strings
    }

    static func localized(_ key: String, in strings: [String: String]) throws -> String {
        guard let value = strings[key] else { throw RenderError.localization(key) }
        return value
    }

    enum RenderError: Error {
        case unavailableAppearance(String)
        case bitmap
        case missingSymbol
        case localization(String)
    }
}
