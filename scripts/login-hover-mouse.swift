// CI only. Post real pointer and key events over krado's open menu.
//   login-hover-mouse <login-geometry.json> <menu.json> away|login|click-stay|slow-to-quit|jump-to-quit|down
import CoreGraphics
import Foundation

func json(_ path: String) -> [String: Any] {
    try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
}
let row = json(CommandLine.arguments[1])
let menu = json(CommandLine.arguments[2])
let command = CommandLine.arguments[3]
let d = { (dict: [String: Any], key: String) in dict[key] as! Double }
let login = CGPoint(x: d(row, "x") + 80, y: d(row, "y") + d(row, "height") / 2)
// Quit is the last row: bottom padding plus half a row above the menu's bottom edge.
let quit = CGPoint(x: login.x, y: d(menu, "y") + d(menu, "height") - 6 - d(row, "height") / 2)
let source = CGEventSource(stateID: .hidSystemState)
func move(_ p: CGPoint) {
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!
        .post(tap: .cghidEventTap)
}
switch command {
case "away": move(CGPoint(x: 5, y: 500))
case "login": move(login)
case "click-stay":
    // Keep the pointer exactly where it was; no move can repair a lost highlight.
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: login, mouseButton: .left)!
            .post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.1)
    }
case "slow-to-quit":
    // A person moving down the menu: about 0.4 s, every row in between is crossed.
    for i in 1...24 {
        let t = Double(i) / 24
        move(CGPoint(x: login.x, y: login.y + (quit.y - login.y) * t))
        Thread.sleep(forTimeInterval: 0.016)
    }
case "jump-to-quit": move(quit)
case "down":
    for down in [true, false] {
        CGEvent(keyboardEventSource: source, virtualKey: 125, keyDown: down)!.post(tap: .cghidEventTap)
    }
default: fatalError("unknown command \(command)")
}
Thread.sleep(forTimeInterval: command == "click-stay" ? 0.5 : 0.4)
print(String(format: "login=%.0f,%.0f quit=%.0f,%.0f", login.x, login.y, quit.x, quit.y))
