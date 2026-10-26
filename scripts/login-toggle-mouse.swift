// CI only. Post actual pointer events; never invoke the row action directly.
import CoreGraphics
import Foundation

let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let row = try JSONSerialization.jsonObject(with: data) as! [String: Any]
let switchRect = row["switchRect"] as! [String: Any]
let point = CGPoint(x: (switchRect["x"] as! Double) + (switchRect["width"] as! Double) / 2,
                    y: (switchRect["y"] as! Double) + (switchRect["height"] as! Double) / 2)
let source = CGEventSource(stateID: .hidSystemState)
func post(_ type: CGEventType, _ location: CGPoint) {
    CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location,
            mouseButton: .left)!.post(tap: .cghidEventTap)
}
post(.mouseMoved, point)
Thread.sleep(forTimeInterval: 0.2)
if CommandLine.arguments.contains("click") {
    post(.leftMouseDown, point)
    Thread.sleep(forTimeInterval: 0.1)
    post(.leftMouseUp, point)
    Thread.sleep(forTimeInterval: 0.2)
}
// Compare both images without hover highlighting or a pointer over the switch.
post(.mouseMoved, CGPoint(x: 5, y: 500))
