// CI only. Post real pointer and key events over krado's open menu.
//   login-hover-mouse <login-geometry.json> <menu.json> away|login|click-row|click-switch|slow-to-quit|jump-to-quit|down|keys-to-login [app.log]
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
let sw = row["switchRect"] as! [String: Any]
let switchCentre = CGPoint(x: d(sw, "x") + d(sw, "width") / 2, y: d(sw, "y") + d(sw, "height") / 2)
// Quit is the last row: bottom padding plus half a row above the menu's bottom edge.
let quit = CGPoint(x: login.x, y: d(menu, "y") + d(menu, "height") - 6 - d(row, "height") / 2)
let source = CGEventSource(stateID: .hidSystemState)
func move(_ p: CGPoint) {
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!
        .post(tap: .cghidEventTap)
}
func click(_ p: CGPoint) {
    move(p)
    Thread.sleep(forTimeInterval: 0.1)
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!
            .post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.1)
    }
}
func key(_ code: CGKeyCode) {
    for down in [true, false] {
        CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)!.post(tap: .cghidEventTap)
    }
    Thread.sleep(forTimeInterval: 0.15)
}
switch command {
case "away": move(CGPoint(x: 5, y: 500))
case "login": move(login)
case "click-row": click(login)          // on the title: must do nothing
case "click-switch": click(switchCentre) // on the switch: toggles, menu stays open
case "slow-to-quit":
    // A person moving down the menu: about 0.4 s, every row in between is crossed.
    for i in 1...24 {
        let t = Double(i) / 24
        move(CGPoint(x: login.x, y: login.y + (quit.y - login.y) * t))
        Thread.sleep(forTimeInterval: 0.016)
    }
case "jump-to-quit": move(quit)
case "down": key(125)
case "keys-to-login":
    // Pointer outside the menu, then Up from the bottom until the app logs that the
    // keyboard selected Launch at Login (at most 15 presses).
    move(CGPoint(x: 5, y: 500))
    Thread.sleep(forTimeInterval: 0.3)
    let log = CommandLine.arguments[4]
    for _ in 0..<15 {
        key(126)
        Thread.sleep(forTimeInterval: 0.25)
        let lines = (try? String(contentsOfFile: log, encoding: .utf8))?
            .split(separator: "\n").filter { $0.contains("KRADO_CI menu willHighlight item=") } ?? []
        if lines.last?.hasSuffix("item=login") == true { break }
    }
default: fatalError("unknown command \(command)")
}
// Long enough for the switch animation to settle.
Thread.sleep(forTimeInterval: 0.6)
print(String(format: "login=%.0f,%.0f switch=%.0f,%.0f quit=%.0f,%.0f", login.x, login.y, switchCentre.x, switchCentre.y, quit.x, quit.y))
