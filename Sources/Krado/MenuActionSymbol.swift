import AppKit

/// Native template symbols; the three bare actions retain their circled symbols’ visible size.
@MainActor
enum MenuActionSymbol {
    static func image(named name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        let circledName: String
        switch name {
        case "info": circledName = "info.circle"
        case "power": circledName = "power.circle"
        case "arrow.down": circledName = "arrow.down.circle"
        default: return image
        }
        guard let resized = image?.copy() as? NSImage,
              let baseline = NSImage(systemSymbolName: circledName, accessibilityDescription: nil) else { return image }
        baseline.isTemplate = true
        guard let currentEdge = visibleLongestEdge(of: baseline),
              let bareEdge = visibleLongestEdge(of: resized) else { return image }
        let scale = currentEdge / bareEdge
        resized.size = NSSize(width: resized.size.width * scale, height: resized.size.height * scale)
        resized.isTemplate = true
        return resized
    }

    /// Match visible alpha bounds, without equating canvas size and ink.
    private static func visibleLongestEdge(of image: NSImage) -> CGFloat? {
        let pixelsPerPoint: CGFloat = 8
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int((image.size.width * pixelsPerPoint).rounded(.up)),
            pixelsHigh: Int((image.size.height * pixelsPerPoint).rounded(.up)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let bytes = bitmap.bitmapData,
              bitmap.samplesPerPixel == 4, !bitmap.bitmapFormat.contains(.alphaFirst) else { return nil }
        bytes.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        bitmap.size = image.size
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1)
        var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = -1, maxY = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where bytes[y * bitmap.bytesPerRow + x * 4 + 3] >= 8 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGFloat(max(maxX - minX + 1, maxY - minY + 1)) / pixelsPerPoint
    }
}
