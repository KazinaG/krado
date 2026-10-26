// Disposable macOS CI only (login-switch-probe.yml). Diagnoses why an NSSwitch in a
// status-item menu row draws gray when on, and whether it animates.
// Usage: login-switch-probe <out-dir>
// Phases: "inactive" (menu opened as krado does today) and "activate-on-open"
// (NSApp.activate in menuWillOpen, previous app restored on close).
import AppKit
import SwiftUI

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "probe"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

final class Model: ObservableObject { @Published var on = true }

struct ToggleView: View {
    @ObservedObject var model: Model
    let active: ControlActiveState?
    var body: some View {
        let t = Toggle("", isOn: $model.on).toggleStyle(.switch).labelsHidden().controlSize(.mini)
        if let active { t.environment(\.controlActiveState, active) } else { t }
    }
}

@MainActor
final class Probe: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    var rows: [(String, NSView)] = []
    let mini = NSSwitch()
    let clickMini = NSSwitch()
    let models = [Model(), Model(), Model()]
    var actions: [String] = []
    var phaseName = ""
    var previousApp: NSRunningApplication?
    var log: [String: Any] = [:]

    func row(_ name: String, _ control: NSView, width: CGFloat, height: CGFloat) {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 32))
        let label = NSTextField(labelWithString: name)
        label.frame = NSRect(x: 14, y: 7, width: 170, height: 18)
        view.addSubview(label)
        control.frame = NSRect(x: 260 - 14 - width, y: (32 - height) / 2, width: width, height: height)
        view.addSubview(control)
        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.view = view
        menu.addItem(item)
        rows.append((name, control))
    }

    @objc func switched(_ sender: NSSwitch) {
        actions.append("\(Date().timeIntervalSince1970) action state=\(sender.state.rawValue)")
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "PROBE"
        mini.controlSize = .mini; mini.state = .on
        clickMini.controlSize = .mini; clickMini.state = .off
        clickMini.target = self; clickMini.action = #selector(switched(_:))
        row("nsswitch-mini-on", mini, width: 28, height: 16)
        row("swiftui-mini-key-on", NSHostingView(rootView: ToggleView(model: models[0], active: .key)), width: 40, height: 22)
        row("swiftui-mini-active-on", NSHostingView(rootView: ToggleView(model: models[1], active: .active)), width: 40, height: 22)
        row("swiftui-mini-plain-on", NSHostingView(rootView: ToggleView(model: models[2], active: nil)), width: 40, height: 22)
        row("nsswitch-mini-click", clickMini, width: 28, height: 16)
        menu.delegate = self
        statusItem.menu = menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.phase("inactive") }
    }

    func menuWillOpen(_ menu: NSMenu) {
        log["\(phaseName).frontmostBeforeOpen"] = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        if phaseName == "activate-on-open" {
            previousApp = NSWorkspace.shared.frontmostApplication
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        log["\(phaseName).frontmostAtClose"] = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        if phaseName == "activate-on-open", let previousApp, previousApp != NSRunningApplication.current {
            NSApp.yieldActivation(to: previousApp)
            previousApp.activate()
        }
    }

    func later(_ s: Double, _ f: @escaping () -> Void) {
        let t = Timer(timeInterval: s, repeats: false) { _ in MainActor.assumeIsolated { f() } }
        RunLoop.main.add(t, forMode: .common)
    }

    func phase(_ name: String) {
        phaseName = name
        later(0.4) { self.record("\(name)-early") }
        later(1.5) { self.record(name) }
        later(2.5) { self.animationProbe(name) }
        later(6.5) { self.menu.cancelTracking() }
        statusItem.button?.performClick(nil)   // returns when the menu closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.log["\(name).frontmostAfterClose"] = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
            if name == "inactive" { self.phase("activate-on-open") } else { self.finish() }
        }
    }

    func finish() {
        log["actions"] = actions
        let data = try! JSONSerialization.data(withJSONObject: log, options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: URL(fileURLWithPath: "\(out)/log.json"))
        NSApp.terminate(nil)
    }

    func screenRect(_ v: NSView) -> [String: Double] {
        guard let w = v.window else { return [:] }
        let r = w.convertToScreen(v.convert(v.bounds, to: nil))
        let top = NSScreen.screens[0].frame.maxY
        return ["x": r.minX, "y": top - r.maxY, "width": r.width, "height": r.height]
    }

    func rgba(_ c: NSColor) -> [Double] {
        let s = c.usingColorSpace(.sRGB) ?? c
        return [s.redComponent, s.greenComponent, s.blueComponent, s.alphaComponent].map { Double($0) * 255 }
    }

    func run(_ path: String, _ args: [String], wait: Bool = true) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run(); if wait { p.waitUntilExit() }
    }

    func record(_ name: String) {
        let shot = "\(out)/\(name).png"
        run("/usr/sbin/screencapture", ["-x", "-m", shot])
        let window = rows.first?.1.window
        var json: [String: Any] = [
            "phase": name,
            "appIsActive": NSApp.isActive,
            "menuWindowIsKey": window?.isKeyWindow ?? false,
            "controlAccentColor": rgba(.controlAccentColor),
            "screenWidth": NSScreen.screens[0].frame.width,
            "screenshot": shot,
        ]
        var controls: [String: Any] = [:]
        for (n, v) in rows { controls[n] = ["rect": screenRect(v)] }
        json["controls"] = controls
        let data = try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: URL(fileURLWithPath: "\(out)/\(name).json"))
    }

    // Frame sampling around (1) mini.animator().state = .off and (2) a real mouse click
    // on clickMini. A Python helper captures the switch rect repeatedly with timestamps.
    func animationProbe(_ name: String) {
        let a = screenRect(mini), c = screenRect(clickMini)
        let spec: [String: Any] = ["animator": a, "click": c]
        let data = try! JSONSerialization.data(withJSONObject: spec)
        try! data.write(to: URL(fileURLWithPath: "\(out)/\(name)-frames-spec.json"))
        run("/usr/bin/env", ["python3", "scripts/login-switch-frames.py", out, name, "animator"], wait: false)
        later(0.6) {
            self.log["\(name).animatorAt"] = Date().timeIntervalSince1970
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.allowsImplicitAnimation = true
                self.mini.animator().state = .off
            }
        }
        later(2.0) {
            self.run("/usr/bin/env", ["python3", "scripts/login-switch-frames.py", out, name, "click"], wait: false)
        }
        later(2.6) {
            // Real click in the middle of the switch (CGEvent, global top-left coordinates).
            let p = CGPoint(x: c["x"]! + c["width"]! / 2, y: c["y"]! + c["height"]! / 2)
            self.log["\(name).clickAt"] = Date().timeIntervalSince1970
            for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
                CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
                usleep(30_000)
            }
        }
        later(3.8) { self.mini.state = .on; self.clickMini.state = .off }
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { Probe() }
app.delegate = delegate
app.run()
