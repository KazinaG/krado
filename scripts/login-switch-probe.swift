// Disposable macOS CI only (login-switch-probe.yml). Diagnoses why an NSSwitch in a
// status-item menu row draws gray when on, and whether it animates.
// Usage: login-switch-probe <out-dir>
// Opens a real status-item menu twice, once without and once after NSApp.activate,
// with several switch variants, writes <out>/<phase>.json and full-screen shots.
import AppKit
import SwiftUI

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "probe"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

final class Model: ObservableObject { @Published var on = true }

@MainActor
final class Probe: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    var rows: [(String, NSView)] = []
    let heli = NSSwitch()        // HeliPort-style: regular, real target/action
    let mini = NSSwitch()        // krado 0.1.13 size
    let miniOff = NSSwitch()
    let modelPlain = Model()
    let modelTint = Model()
    var actions: [String] = []

    func row(_ name: String, _ control: NSView, width: CGFloat = 60, height: CGFloat = 30) {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 32))
        let label = NSTextField(labelWithString: name)
        label.frame = NSRect(x: 14, y: 7, width: 150, height: 18)
        view.addSubview(label)
        control.frame = NSRect(x: 260 - 14 - width, y: (32 - height) / 2, width: width, height: height)
        view.addSubview(control)
        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.view = view
        menu.addItem(item)
        rows.append((name, control))
    }

    @objc func switched(_ sender: NSSwitch) { actions.append("action state=\(sender.state.rawValue)") }

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "PROBE"
        heli.state = .on; heli.target = self; heli.action = #selector(switched(_:))
        mini.controlSize = .mini; mini.state = .on; mini.target = self; mini.action = #selector(switched(_:))
        miniOff.controlSize = .mini; miniOff.state = .off
        row("nsswitch-regular-on", heli, width: 42, height: 25)
        row("nsswitch-mini-on", mini, width: 28, height: 16)
        row("nsswitch-mini-off", miniOff, width: 28, height: 16)
        let plain = NSHostingView(rootView: ToggleView(model: modelPlain, tint: false))
        let tint = NSHostingView(rootView: ToggleView(model: modelTint, tint: true))
        row("swiftui-mini-on", plain, width: 40, height: 22)
        row("swiftui-mini-tint-on", tint, width: 40, height: 22)
        statusItem.menu = menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.phase("inactive") }
    }

    func later(_ s: Double, _ f: @escaping () -> Void) {
        let t = Timer(timeInterval: s, repeats: false) { _ in MainActor.assumeIsolated { f() } }
        RunLoop.main.add(t, forMode: .common)
    }

    func phase(_ name: String) {
        later(1.5) { self.record(name) }
        later(3.0) { self.animationProbe(name) }
        later(4.5) { self.menu.cancelTracking() }
        statusItem.button?.performClick(nil)   // returns when the menu closes
        if name == "inactive" {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.phase("active") }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { NSApp.terminate(nil) }
        }
    }

    func screenRect(_ v: NSView) -> [String: Double] {
        guard let w = v.window else { return [:] }
        let r = w.convertToScreen(v.convert(v.bounds, to: nil))
        let top = NSScreen.screens[0].frame.maxY
        return ["x": r.minX, "y": top - r.maxY, "width": r.width, "height": r.height]
    }

    func widgetDefinitions(_ v: NSView) -> [String] {
        var found: [String] = []
        let sel = NSSelectorFromString("widgetDefinition")
        func walk(_ v: NSView) {
            if v.responds(to: sel), let d = v.value(forKey: "widgetDefinition") as? [String: Any] {
                let keys = ["widget", "kCUIPresentationStateKey", "state", "value", "size"]
                found.append(keys.map { "\($0)=\(d[$0].map { "\($0)" } ?? "-")" }.joined(separator: " "))
            }
            v.subviews.forEach(walk)
        }
        walk(v)
        return found
    }

    func rgba(_ c: NSColor) -> [Double] {
        let s = c.usingColorSpace(.sRGB) ?? c
        return [s.redComponent, s.greenComponent, s.blueComponent, s.alphaComponent].map { Double($0) * 255 }
    }

    func record(_ name: String) {
        let shot = "\(out)/\(name).png"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x", "-m", shot]
        try? p.run(); p.waitUntilExit()
        let window = rows.first?.1.window
        var json: [String: Any] = [
            "phase": name,
            "appIsActive": NSApp.isActive,
            "menuWindowClass": window.map { String(describing: type(of: $0)) } ?? "-",
            "menuWindowIsKey": window?.isKeyWindow ?? false,
            "menuWindowIsMain": window?.isMainWindow ?? false,
            "keyWindow": NSApp.keyWindow.map { String(describing: type(of: $0)) } ?? "nil",
            "controlAccentColor": rgba(.controlAccentColor),
            "screenWidth": NSScreen.screens[0].frame.width,
            "screenshot": shot,
        ]
        var controls: [String: Any] = [:]
        for (n, v) in rows {
            var c: [String: Any] = ["rect": screenRect(v)]
            if let s = v as? NSSwitch {
                c["state"] = s.state == .on ? "on" : "off"
                c["isEnabled"] = s.isEnabled
                c["controlSize"] = s.controlSize.rawValue
                c["widgets"] = widgetDefinitions(s)
            }
            controls[n] = c
        }
        json["controls"] = controls
        let data = try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: URL(fileURLWithPath: "\(out)/\(name).json"))
        print("PROBE recorded \(name) active=\(NSApp.isActive)")
    }

    func animationKeys(_ v: NSView) -> [String] {
        var keys: [String] = []
        func walk(_ l: CALayer) {
            keys += (l.animationKeys() ?? []).map { "\(type(of: l)):\($0)" }
            l.sublayers?.forEach(walk)
        }
        if let l = v.layer { walk(l) }
        return keys
    }

    // While the menu is tracking: set state directly vs through animator(), then read
    // the Core Animation animations attached under each switch 30 ms later.
    func animationProbe(_ name: String) {
        miniOff.state = .on                       // direct
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.allowsImplicitAnimation = true
            mini.animator().state = .off          // animator()
        }
        withAnimation { modelTint.on = false }    // SwiftUI
        later(0.03) {
            let r: [String: Any] = [
                "direct(nsswitch-mini-off->on)": self.animationKeys(self.miniOff),
                "animator(nsswitch-mini-on->off)": self.animationKeys(self.mini),
                "withAnimation(swiftui-mini-tint-on->off)": self.animationKeys(self.rows[4].1),
                "actions": self.actions,
            ]
            let data = try! JSONSerialization.data(withJSONObject: r, options: [.prettyPrinted, .sortedKeys])
            try! data.write(to: URL(fileURLWithPath: "\(out)/\(name)-animation.json"))
            // Put states back for the next phase.
            self.miniOff.state = .off; self.mini.state = .on; self.modelTint.on = true
        }
    }
}

struct ToggleView: View {
    @ObservedObject var model: Model
    let tint: Bool
    var body: some View {
        let t = Toggle("", isOn: $model.on).toggleStyle(.switch).labelsHidden().controlSize(.mini)
        if tint { t.tint(Color(nsColor: .controlAccentColor)) } else { t }
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { Probe() }
app.delegate = delegate
app.run()
