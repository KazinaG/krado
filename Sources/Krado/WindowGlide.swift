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
    private var refreshRate = 60
    private var began: CFTimeInterval = 0
    private var duration: TimeInterval = MotionSpec.duration
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
        duration = MotionSpec.duration(from: start, to: frame)
        self.completion = completion
        let display = NSScreen.screens.first { screen in
            let height = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == CGMainDisplayID() }?.frame.height ?? screen.frame.height
            return flipY(screen.frame, mainScreenHeight: height).contains(frame.origin)
        } ?? screen
        refreshRate = max(1, display.maximumFramesPerSecond)
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
        let progress = (CACurrentMediaTime() - began) / duration
        if MotionPreference.reduceMotion { finish(); return }
        guard progress < 1 else { finish(); return }
        let requested = MotionSpec.frame(from: start, to: destination, progress: progress)
        #if KRADO_LAB_HOOKS
        if ProcessInfo.processInfo.environment["KRADO_LAB_LOG"] == "1" {
            FileHandle.standardOutput.write(Data("KRADO_LAB glide t=\(String(format: "%.3f", progress)) frame=\(requested)\n".utf8))
        }
        #endif
        guard let actual = Accessibility.snapshot(of: window) else { finish(); return }
        guard CACurrentMediaTime() - began < duration else { finish(); return }
        var current = CGRect(origin: actual.position, size: actual.size)
        var sizeWriteMilliseconds = 0.0
        for step in MotionSpec.steps(from: current, to: requested) {
            guard CACurrentMediaTime() - began < duration else { finish(); return }
            guard step.isNeeded(in: current) else { continue }
            let result: (success: Bool, milliseconds: Double)
            switch step {
            case .size(let size):
                result = Accessibility.writeSize(size, of: window)
                sizeWriteMilliseconds += result.milliseconds
                guard let readback = Accessibility.snapshot(of: window) else { finish(); return }
                current = CGRect(origin: readback.position, size: readback.size)
            case .position(let point):
                result = Accessibility.writePosition(point, of: window)
                current.origin = point
            }
            let action = MotionSpec.action(after: step, success: result.success,
                                           writeMilliseconds: result.milliseconds,
                                           totalSizeWriteMilliseconds: sizeWriteMilliseconds,
                                           actualSize: current.size, refreshRate: refreshRate)
            guard action == .continueGlide else { finish(); return }
        }
        if CACurrentMediaTime() - began >= duration { finish() }
    }
}
