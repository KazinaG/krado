import AppKit
import ApplicationServices
import QuartzCore
import KradoCore

/// Owned by DragMonitor; all AX and display callbacks run on the main run loop.
@MainActor
final class WindowGlide: NSObject {
    private var link: CADisplayLink?
    private var window: AXUIElement?
    private var start = CGRect.zero
    private var destination = CGRect.zero
    private var mode: MotionSpec.Mode = .full
    private var refreshRate = 60
    private var workArea = CGRect.zero
    private var anchor = CGPoint(x: 0.5, y: 0.5)
    private var began: CFTimeInterval = 0
    private var completion: ((Bool) -> Void)?

    func run(window: AXUIElement, to frame: CGRect, completion: @escaping (Bool) -> Void) {
        finish()
        guard !MotionPreference.reduceMotion,
              let snapshot = Accessibility.snapshot(of: window), let screen = NSScreen.screens.first else {
            completion(Accessibility.setFrame(frame, of: window))
            return
        }
        self.window = window
        start = CGRect(origin: snapshot.position, size: snapshot.size)
        destination = frame
        self.completion = completion
        mode = .full
        let display = NSScreen.screens.first { screen in
            let height = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == CGMainDisplayID() }?.frame.height ?? screen.frame.height
            return flipY(screen.frame, mainScreenHeight: height).contains(frame.origin)
        } ?? screen
        refreshRate = max(1, display.maximumFramesPerSecond)
        let mainHeight = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == CGMainDisplayID()
        }?.frame.height ?? display.frame.height
        workArea = flipY(display.visibleFrame, mainScreenHeight: mainHeight)
        anchor = MotionSpec.anchor(for: frame, in: workArea)
        began = CACurrentMediaTime()
        let link = display.displayLink(target: self, selector: #selector(step(_:)))
        self.link = link
        link.add(to: .main, forMode: .common)
    }

    /// Cancellation completes the previous placement before a new gesture can start.
    func finish() {
        link?.invalidate()
        link = nil
        guard let window else { return }
        self.window = nil
        let done = completion
        completion = nil
        done?(Accessibility.setFrame(destination, of: window))
    }

    @objc private func step(_ sender: CADisplayLink) {
        guard let window else { return }
        let progress = (CACurrentMediaTime() - began) / MotionSpec.duration
        if MotionPreference.reduceMotion { finish(); return }
        guard progress < 1 else { finish(); return }
        let requested = MotionSpec.frame(from: start, to: destination, progress: progress)
        #if KRADO_LAB_HOOKS
        if ProcessInfo.processInfo.environment["KRADO_LAB_LOG"] == "1" {
            FileHandle.standardOutput.write(Data("KRADO_LAB glide t=\(String(format: "%.3f", progress)) mode=\(mode) frame=\(requested)\n".utf8))
        }
        #endif
        guard let actual = Accessibility.snapshot(of: window) else { finish(); return }
        guard CACurrentMediaTime() - began < MotionSpec.duration else { finish(); return }
        var current = CGRect(origin: actual.position, size: actual.size)
        if mode == .full && MotionSpec.writes(from: current, to: requested).size {
            let bridge = MotionSpec.bridgeSize(from: current, to: requested)
            // Shrink first, move the smaller rectangle, then grow. In particular,
            // never enlarge a bottom/right anchored window at its old origin.
            let sizes = [bridge, requested.size]
            var writeMilliseconds = 0.0
            for (index, size) in sizes.enumerated() {
                guard CACurrentMediaTime() - began < MotionSpec.duration else { finish(); return }
                if index == 1 && current.origin != requested.origin {
                    let move = Accessibility.writePosition(requested.origin, of: window)
                    guard move.success, move.milliseconds <= MotionSpec.abortWriteMilliseconds else {
                        finish(); return
                    }
                }
                if size == current.size { continue }
                let result = Accessibility.writeSize(size, of: window)
                guard result.success, result.milliseconds <= MotionSpec.abortWriteMilliseconds,
                      let readback = Accessibility.snapshot(of: window) else {
                    finish(); return
                }
                writeMilliseconds += result.milliseconds
                current = CGRect(origin: readback.position, size: readback.size)
            }
            mode = MotionSpec.nextMode(current: mode, writeMilliseconds: writeMilliseconds,
                                       requested: requested.size, actual: current.size, refreshRate: refreshRate)
            guard mode != .abort else { finish(); return }
        }
        // AX calls consume the same wall-clock budget as display callbacks.
        guard CACurrentMediaTime() - began < MotionSpec.duration else { finish(); return }
        // Keep the zone's edge/centre on the interpolated path even if size is clamped.
        let position = MotionSpec.anchoredPosition(for: requested, actualSize: current.size, anchor: anchor, in: workArea)
        if current.origin != position {
            let result = Accessibility.writePosition(position, of: window)
            if !result.success || result.milliseconds > MotionSpec.abortWriteMilliseconds { finish(); return }
        }
        if CACurrentMediaTime() - began >= MotionSpec.duration { finish() }
    }
}
