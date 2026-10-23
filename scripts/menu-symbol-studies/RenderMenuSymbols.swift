// Standalone bitmap study. Compile with StatusAppearance and StatusPresentation;
// never creates NSApplication, windows, menus, status items, event taps or prompts.
import AppKit

@main
@MainActor
struct RenderMenuSymbols {
    enum Study: String, CaseIterable { case current, a, b }
    struct Spec {
        let name: String
        let pointSize: CGFloat?
        let weight: NSFont.Weight
        let success: Bool
    }
    static var scale: CGFloat = 2
    static var metrics: [[String: Any]] = []

    static let canvasHeight: CGFloat = 900
    static let roles = ["about", "login", "update", "accessibility"]
    static let enlargedVisibleMax: CGFloat = 18

    // Keep font configuration/weight unchanged; vary only shape and uniform scale.
    static func spec(_ role: String, _ study: Study) -> Spec {
        let current = ["about": "info.circle", "login": "power.circle", "update": "arrow.down.circle", "accessibility": "checkmark.circle.fill"]
        let bare = ["about": "info", "login": "power", "update": "arrow.down", "accessibility": "checkmark"]
        return Spec(name: (study == .b ? bare : current)[role]!,
                    pointSize: role == "accessibility" ? 15 : nil,
                    weight: .regular, success: role == "accessibility")
    }

    static func sourceImage(_ spec: Spec) throws -> NSImage {
        guard var image = NSImage(systemSymbolName: spec.name, accessibilityDescription: nil) else {
            throw Failure.symbol(spec.name)
        }
        if let pointSize = spec.pointSize {
            var config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: spec.weight)
            if spec.success {
                let colors: [NSColor] = spec.name == "checkmark.circle.fill" ? [.white, .systemGreen] : [.systemGreen]
                config = config.applying(NSImage.SymbolConfiguration(paletteColors: colors))
            }
            guard let configured = image.withSymbolConfiguration(config) else { throw Failure.symbol(spec.name) }
            image = configured
        }
        image.isTemplate = !spec.success
        return image
    }

    struct Ink {
        let width: CGFloat
        let height: CGFloat
        var longest: CGFloat { max(width, height) }
        var array: [CGFloat] { [width, height] }
    }

    // Measure alpha bounds at 8 pixels/point, rather than equating image canvas
    // dimensions or font point size with visible symbol size. Nothing is saved.
    static func ink(_ image: NSImage) throws -> Ink {
        let pixelScale: CGFloat = 8
        let rep = try bitmap(size: image.size, pixelScale: pixelScale)
        guard let context = NSGraphicsContext(bitmapImageRep: rep), let bytes = rep.bitmapData else { throw Failure.bitmap }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard rep.samplesPerPixel == 4, !rep.bitmapFormat.contains(.alphaFirst) else { throw Failure.bitmap }
        var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = -1, maxY = -1
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where bytes[y*rep.bytesPerRow+x*4+3] >= 8 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { throw Failure.bitmap }
        return Ink(width: CGFloat(maxX-minX+1)/pixelScale, height: CGFloat(maxY-minY+1)/pixelScale)
    }

    static func symbol(_ spec: Spec, theme: String, study: Study, role: String) throws -> NSImage {
        let image = try sourceImage(spec)
        let baseline = try sourceImage(self.spec(role, .current))
        let baselineInk = try ink(baseline)
        let rawSize = image.size
        let rawInk = try ink(image)
        let target = study == .a ? enlargedVisibleMax : baselineInk.longest
        let factor = study == .current ? 1 : target/rawInk.longest
        image.size = NSSize(width: rawSize.width*factor, height: rawSize.height*factor)
        let finalInk = try ink(image)
        guard abs(finalInk.longest-target) <= 0.5 else { throw Failure.size }
        if study == .a { guard finalInk.longest > baselineInk.longest+0.5 else { throw Failure.size } }
        metrics.append(["theme": theme, "study": study.rawValue, "role": role, "symbol": spec.name,
                        "point_size": spec.pointSize.map { $0 as Any } ?? "system default",
                        "weight": spec.pointSize == nil ? "system default" : "regular",
                        "scale": scale, "source_native_size_pt": [rawSize.width, rawSize.height],
                        "source_visible_size_pt": rawInk.array, "baseline_native_size_pt": [baseline.size.width, baseline.size.height],
                        "baseline_visible_size_pt": baselineInk.array, "baseline_visible_max_pt": baselineInk.longest,
                        "target_visible_max_pt": target, "uniform_scale_factor": factor,
                        "native_size_pt": [image.size.width, image.size.height], "rendered_visible_size_pt": finalInk.array,
                        "rendered_visible_max_pt": finalInk.longest,
                        "size_policy": study == .a ? "current circled shape, common 18pt visible longest edge" : (study == .b ? "bare shape, same visible longest edge as this role in current production" : "unaltered production reference")])
        return image
    }

    static func main() throws {
        let reviseDraft = CommandLine.arguments.count == 3 && CommandLine.arguments[2] == "--revise-unattached-draft"
        guard CommandLine.arguments.count == 2 || reviseDraft else { throw Failure.usage }
        let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        if FileManager.default.fileExists(atPath: out.path) {
            guard reviseDraft else { throw Failure.existingOutput }
            let allowed = Set(["krado-menu-symbols-AB-current-size@2x.png", "symbol-metrics.json"])
            guard Set(try FileManager.default.contentsOfDirectory(atPath: out.path)) == allowed else { throw Failure.existingOutput }
        }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        scale = 2
        do {
            try render(size: NSSize(width: 880, height: canvasHeight), to: out.appendingPathComponent("krado-menu-symbols-AB-current-size@2x.png")) {
                NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
                NSRect(x: 0, y: 0, width: 880, height: canvasHeight).fill()
                text("メニュー記号の比較", x: 32, top: 24, size: 24, weight: .bold, color: .black)
                text("未採用の静止案  ·  文字・状態・配置は共通", x: 32, top: 61, size: 13, color: NSColor(calibratedWhite: 0.35, alpha: 1))
                text("A  今の丸付きのまま大きく", x: 32, top: 103, size: 18, weight: .semibold, color: .black)
                text("B  丸を外して現行サイズ", x: 456, top: 103, size: 18, weight: .semibold, color: .black)
                text("4種の可視最長辺を18 ptへ。形・ウェイト設定を維持", x: 32, top: 133, size: 11, color: .darkGray)
                text("役割ごとの現行の可視最長辺を維持。ウェイト設定は共通", x: 456, top: 133, size: 11, color: .darkGray)
                for (dark, top) in [(false, CGFloat(162)), (true, CGFloat(454))] {
                    let theme = dark ? "dark" : "light"
                    guard let appearance = NSAppearance(named: dark ? .darkAqua : .aqua) else { throw Failure.appearance }
                    var failure: Error?
                    appearance.performAsCurrentDrawingAppearance {
                        do {
                            try panel(.a, x: 32, top: top, dark: dark, theme: theme)
                            try panel(.b, x: 456, top: top, dark: dark, theme: theme)
                        } catch { failure = error }
                    }
                    if let failure { throw failure }
                }
                text("基準：現在の記号", x: 32, top: 758, size: 11, weight: .medium, color: .darkGray)
                guard let light = NSAppearance(named: .aqua) else { throw Failure.appearance }
                var failure: Error?
                light.performAsCurrentDrawingAppearance {
                    do {
                        for (role, x, label) in [("about", CGFloat(183), "About"), ("login", CGFloat(330), "ログイン"), ("update", CGFloat(492), "更新"), ("accessibility", CGFloat(640), "許可済み")] {
                            let image = try symbol(spec(role, .current), theme: "light", study: .current, role: role)
                            try draw(image, center: NSPoint(x: x, y: canvasHeight-768))
                            text(label, x: x+18, top: 761, size: 11, color: .darkGray)
                        }
                    } catch { failure = error }
                }
                if let failure { throw failure }
                text("現行基準：About・ログイン・更新＝システム既定設定。許可済み＝15 pt regular。", x: 32, top: 800, size: 11, color: .darkGray)
                let actionMax = metrics.last { $0["study"] as? String == "current" && $0["role"] as? String == "about" }!["baseline_visible_max_pt"] as! CGFloat
                let permissionMax = metrics.last { $0["study"] as? String == "current" && $0["role"] as? String == "accessibility" }!["baseline_visible_max_pt"] as! CGFloat
                text(String(format: "Bは現行の可視最長辺を維持（通常3種 %.1f pt／許可済み %.1f pt）。Aは4種18 pt。縦横比は維持。", Double(actionMax), Double(permissionMax)), x: 32, top: 822, size: 11, color: .darkGray)
                text("許可済みの緑・ログインのオン・監視記号・文字・行間は共通。A/Bの違いは対象4記号の形と大きさのみ。", x: 32, top: 844, size: 11, color: .darkGray)
                text("未採用の静止比較。実際のSF Symbolsを使用。実メニューの素材・選択状態・VoiceOverは未検証。", x: 32, top: 876, size: 11, color: .darkGray)
            }
        }
        let data = try JSONSerialization.data(withJSONObject: ["rendering": "offscreen bitmap only", "menu": "static layout mock, not native menu screenshot", "canvas_size_pt": [880, 900], "image_scale": 2, "alpha_measurement": "8 pixels per point; alpha >= 8/255", "definitions": ["a": "retain current circled shapes; common visible longest edge 18pt; no weight change", "b": "remove circles; retain each role's current visible longest edge; no weight change"], "metrics": metrics], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: out.appendingPathComponent("symbol-metrics.json"))
        print("Rendered one revised A/B comparison at 2x; no application or UI created: \(out.path)")
    }

    static func panel(_ study: Study, x: CGFloat, top: CGFloat, dark: Bool, theme: String) throws {
        let bg = dark ? NSColor(calibratedWhite: 0.15, alpha: 1) : NSColor(calibratedWhite: 0.995, alpha: 1)
        bg.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: canvasHeight-top-276, width: 392, height: 276), xRadius: 10, yRadius: 10).fill()
        let label = NSColor.labelColor
        let secondary = NSColor.secondaryLabelColor
        text(dark ? "暗い表示" : "明るい表示", x: x+14, top: top+12, size: 10, color: secondary)
        text("ステータス", x: x+14, top: top+31, size: 11, weight: .semibold, color: secondary)
        try draw(symbol(spec("accessibility", study), theme: theme, study: study, role: "accessibility"), center: NSPoint(x: x+25, y: canvasHeight-top-66))
        text("アクセシビリティ", x: x+46, top: top+51, size: 13, color: label)
        text("許可済み", x: x+46, top: top+70, size: 11, color: secondary)
        let monitor = StatusSymbol(name: "record.circle.fill", color: .success)
        guard let monitorImage = StatusPresentation.image(for: monitor, description: "Ready to snap") else { throw Failure.symbol(monitor.name) }
        try draw(monitorImage, center: NSPoint(x: x+25, y: canvasHeight-top-104))
        text("ウインドウのドラッグ", x: x+46, top: top+89, size: 13, color: label)
        text("スナップできます", x: x+46, top: top+108, size: 11, color: secondary)
        separator(x: x+12, top: top+131, width: 368, dark: dark)
        text("起動", x: x+14, top: top+139, size: 11, weight: .semibold, color: secondary)
        try draw(symbol(spec("login", study), theme: theme, study: study, role: "login"), center: NSPoint(x: x+25, y: canvasHeight-top-171))
        text("ログイン時に起動", x: x+46, top: top+162, size: 13, color: label)
        // The production badge is NSMenuItemBadge. Here only the same state word is mocked.
        text("オン", x: x+343, top: top+164, size: 11, color: secondary)
        separator(x: x+12, top: top+191, width: 368, dark: dark)
        text("krado", x: x+14, top: top+199, size: 11, weight: .semibold, color: secondary)
        try draw(symbol(spec("update", study), theme: theme, study: study, role: "update"), center: NSPoint(x: x+25, y: canvasHeight-top-231))
        text("アップデートを確認…", x: x+46, top: top+222, size: 13, color: label)
        try draw(symbol(spec("about", study), theme: theme, study: study, role: "about"), center: NSPoint(x: x+25, y: canvasHeight-top-257))
        text("kradoについて", x: x+46, top: top+248, size: 13, color: label)
    }

    static func separator(x: CGFloat, top: CGFloat, width: CGFloat, dark: Bool) {
        NSColor(calibratedWhite: dark ? 0.28 : 0.88, alpha: 1).setFill()
        NSRect(x: x, y: canvasHeight-top, width: width, height: 0.5).fill()
    }

    static func text(_ value: String, x: CGFloat, top: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor) {
        let attributed = NSAttributedString(string: value, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
        attributed.draw(at: NSPoint(x: x, y: canvasHeight-top-attributed.size().height))
    }

    static func draw(_ image: NSImage, center: NSPoint) throws {
        // Preserve the configured native image size: fitting all symbols to one box
        // would erase the very size difference this comparison is meant to show.
        let size = image.size
        guard size.width <= 28, size.height <= 28 else { throw Failure.size }
        let rect = NSRect(x: center.x-size.width/2, y: center.y-size.height/2, width: size.width, height: size.height)
        if !image.isTemplate {
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return
        }
        let rep = try bitmap(size: size)
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { throw Failure.bitmap }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let bounds = NSRect(origin: .zero, size: size)
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.labelColor.setFill()
        bounds.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()
        let tinted = NSImage(size: size)
        tinted.addRepresentation(rep)
        tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    static func render(size: NSSize, to url: URL, drawing: () throws -> Void) throws {
        let rep = try bitmap(size: size)
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { throw Failure.bitmap }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        try drawing()
        guard let png = rep.representation(using: .png, properties: [:]) else { throw Failure.bitmap }
        try png.write(to: url, options: .atomic)
    }

    static func bitmap(size: NSSize, pixelScale: CGFloat? = nil) throws -> NSBitmapImageRep {
        let pixels = pixelScale ?? scale
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int((size.width*pixels).rounded(.up)), pixelsHigh: Int((size.height*pixels).rounded(.up)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { throw Failure.bitmap }
        rep.bitmapData?.initialize(repeating: 0, count: rep.bytesPerRow*rep.pixelsHigh)
        rep.size = size
        return rep
    }

    enum Failure: Error { case usage, existingOutput, symbol(String), appearance, bitmap, size }
}
