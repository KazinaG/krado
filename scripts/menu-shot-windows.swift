// CI only: record krado's windows and select its floating menu, in screen points.
import AppKit
import CoreGraphics
import Foundation

let pid = Int32(CommandLine.arguments[1])!
let evidencePath = CommandLine.arguments[2]
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let owned = windows.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid }
let evidence = owned.map { window in
    "owner=\(window[kCGWindowOwnerName as String] ?? "?") pid=\(pid) layer=\(window[kCGWindowLayer as String] ?? "?") bounds=\(window[kCGWindowBounds as String] ?? "?") alpha=\(window[kCGWindowAlpha as String] ?? "?")"
}.joined(separator: "\n")
try evidence.write(toFile: evidencePath, atomically: true, encoding: .utf8)
let candidates: [CGRect] = owned.compactMap { window in
    guard let layer = window[kCGWindowLayer as String] as? NSNumber, layer.intValue > 0,
          let alpha = window[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue > 0,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
          let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double,
          width > 100, height > 100 else { return nil }
    return CGRect(x: x, y: y, width: width, height: height)
}
guard let menu = candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
    FileHandle.standardError.write(Data("No floating krado menu found; see window evidence\n".utf8))
    exit(1)
}
let screen = CGDisplayBounds(CGMainDisplayID())
let data = try JSONSerialization.data(withJSONObject: [
    "x": menu.minX, "y": menu.minY, "width": menu.width, "height": menu.height,
    "screenWidth": screen.width, "screenHeight": screen.height,
])
print(String(decoding: data, as: UTF8.self))
