// CI only. Move or click the real pointer at a screen point (points, top-left origin).
//   status-rows-mouse move|click <x> <y>
import CoreGraphics
import Foundation

let command = CommandLine.arguments[1]
let point = CGPoint(x: Double(CommandLine.arguments[2])!, y: Double(CommandLine.arguments[3])!)
let source = CGEventSource(stateID: .hidSystemState)
let types: [CGEventType] = command == "click" ? [.mouseMoved, .leftMouseDown, .leftMouseUp] : [.mouseMoved]
for type in types {
    CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)!
        .post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.1)
}
Thread.sleep(forTimeInterval: 0.4)
