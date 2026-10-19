// Prints "id x y width height name" for each on-screen Finder window (CI runner only).
import CoreGraphics
import Foundation

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let list = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []
for w in list where (w[kCGWindowOwnerName as String] as? String) == "Finder"
    && (w[kCGWindowLayer as String] as? Int) == 0 {
    guard let id = w[kCGWindowNumber as String] as? Int,
          let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
    let name = (w[kCGWindowName as String] as? String) ?? ""
    print(id, Int(b["X"] ?? 0), Int(b["Y"] ?? 0), Int(b["Width"] ?? 0), Int(b["Height"] ?? 0), name)
}
