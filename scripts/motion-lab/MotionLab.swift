import AppKit
import ApplicationServices
import CoreGraphics

// Standalone runner tool: swiftc -swift-version 6 MotionLab.swift -o MotionLab
struct LabError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

@MainActor
func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}

@MainActor
func findWindow(_ bundle: String) throws -> AXUIElement {
    guard AXIsProcessTrusted() else { throw LabError("AXIsProcessTrusted=false") }
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
        throw LabError("App not running: \(bundle)")
    }
    app.activate(options: [])
    pump(0.3)
    let application = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 0.2)
    guard let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] else {
        throw LabError("No AX windows: \(bundle)")
    }
    // AXWindows is front-to-back. Prefer the focused standard window if it is in the list.
    let focused = attribute(application, kAXFocusedWindowAttribute)
    let standard = windows.filter {
        (attribute($0, kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole &&
        (attribute($0, kAXMinimizedAttribute) as? Bool) != true
    }
    guard let result = standard.first(where: { candidate in focused.map { CFEqual(candidate, $0) } == true }) else {
        guard let first = standard.first else { throw LabError("No standard window: \(bundle)") }
        AXUIElementSetMessagingTimeout(first, 0.2)
        return first
    }
    AXUIElementSetMessagingTimeout(result, 0.2)
    return result
}

@MainActor
func frame(_ window: AXUIElement) throws -> CGRect {
    guard let p = attribute(window, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
          let s = attribute(window, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else {
        throw LabError("Cannot read window frame")
    }
    var point = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(unsafeDowncast(p, to: AXValue.self), .cgPoint, &point),
          AXValueGetValue(unsafeDowncast(s, to: AXValue.self), .cgSize, &size) else {
        throw LabError("Invalid AX frame")
    }
    return CGRect(origin: point, size: size)
}

@MainActor
func pump(_ seconds: Double) {
    guard seconds > 0 else { return }
    RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
}

struct Write: Codable {
    let attribute: String
    let milliseconds: Double
    let error: Int32
}
struct Sample: Codable {
    let requested: [Double]
    let actual: [Double]?
    let deviationPixels: [Double]?
    let lagged: Bool
    let writes: [Write]
}
struct Trial: Codable {
    let strategy: String
    let repetition: Int
    let plannedSeconds: Double
    let elapsedSeconds: Double
    let framesWritten: Int
    let medianMilliseconds: Double
    let p95Milliseconds: Double
    let maxMilliseconds: Double
    let samples: [Sample]
}
struct Measurement: Codable {
    let bundleID: String
    let trusted: Bool
    let screen: [Double]
    let scale: Double
    let trials: [Trial]
    let error: String?
}
func numbers(_ rect: CGRect) -> [Double] { [rect.minX, rect.minY, rect.width, rect.height].map(Double.init) }

@MainActor
func write(_ window: AXUIElement, _ key: String, _ requested: CGRect) -> Write {
    var position = requested.origin
    var size = requested.size
    let value = key == kAXSizeAttribute ? AXValueCreate(.cgSize, &size) : AXValueCreate(.cgPoint, &position)
    let start = ProcessInfo.processInfo.systemUptime
    let error = value.map { AXUIElementSetAttributeValue(window, key as CFString, $0) } ?? .illegalArgument
    return Write(attribute: key, milliseconds: (ProcessInfo.processInfo.systemUptime - start) * 1000, error: error.rawValue)
}

@MainActor
func place(_ window: AXUIElement, _ rect: CGRect) {
    _ = write(window, kAXPositionAttribute, rect)
    _ = write(window, kAXSizeAttribute, rect)
    _ = write(window, kAXPositionAttribute, rect)
}

@MainActor
func mainScreen() throws -> NSScreen {
    guard let screen = NSScreen.screens.first(where: {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == CGMainDisplayID()
    }) else { throw LabError("No main screen") }
    return screen
}

@MainActor
func workArea(_ screen: NSScreen) -> CGRect {
    let v = screen.visibleFrame
    return CGRect(x: v.minX, y: screen.frame.height - v.maxY, width: v.width, height: v.height)
}

@MainActor
func measure(_ bundle: String, _ output: String) throws {
    var trials: [Trial] = []
    var failure: String?
    var screenRect = CGRect.zero
    var scale = 1.0
    do {
        let screen = try mainScreen()
        screenRect = screen.frame
        scale = screen.backingScaleFactor
        let window = try findWindow(bundle)
        let original = try frame(window)
        defer { place(window, original) }
        let area = workArea(screen)
        let a = CGRect(x: area.minX, y: area.minY, width: area.width / 2, height: area.height)
        let b = CGRect(x: area.minX + area.width * 0.35, y: area.minY + area.height * 0.2,
                       width: area.width * 0.6, height: area.height * 0.65)
        for strategy in 0...3 {
            for repetition in 0..<3 {
                let source = repetition % 2 == 0 ? a : b
                let destination = repetition % 2 == 0 ? b : a
                place(window, source)
                pump(0.25)
                let actualStart = try frame(window)
                let start = ProcessInfo.processInfo.systemUptime
                var samples: [Sample] = []
                // S3 pays its one resize at time zero, before position stepping.
                let initialWrites = strategy == 3 ? [write(window, kAXSizeAttribute, destination)] : []
                let count = strategy == 0 ? 1 : 12
                for index in 1...count {
                    if strategy != 0 { pump(start + Double(index) / 60 - ProcessInfo.processInfo.systemUptime) }
                    let t = strategy == 0 ? 1 : Double(index) / 12
                    let eased = 1 - pow(1 - t, 3)
                    func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { (x + (y - x) * eased).rounded() }
                    var requested = CGRect(x: mix(actualStart.minX, destination.minX), y: mix(actualStart.minY, destination.minY),
                                           width: mix(actualStart.width, destination.width), height: mix(actualStart.height, destination.height))
                    var writes: [Write] = index == 1 ? initialWrites : []
                    switch strategy {
                    case 0:
                        writes = [write(window, kAXPositionAttribute, requested), write(window, kAXSizeAttribute, requested), write(window, kAXPositionAttribute, requested)]
                    case 1:
                        writes = [write(window, kAXPositionAttribute, requested), write(window, kAXSizeAttribute, requested)]
                    case 2:
                        requested.size = index == count ? destination.size : actualStart.size
                        writes.append(write(window, kAXPositionAttribute, requested))
                        if index == count { writes.append(write(window, kAXSizeAttribute, requested)) }
                    default:
                        requested.size = destination.size
                        writes.append(write(window, kAXPositionAttribute, requested))
                    }
                    let actual = try? frame(window)
                    let deviation = actual.map { value in zip(numbers(value), numbers(requested)).map { abs($0 - $1) * scale } }
                    samples.append(Sample(requested: numbers(requested), actual: actual.map(numbers), deviationPixels: deviation,
                                          lagged: deviation?.contains(where: { $0 > 0.5 }) ?? true, writes: writes))
                }
                let times = samples.flatMap(\.writes).map(\.milliseconds).sorted()
                func percentile(_ p: Double) -> Double { times.isEmpty ? 0 : times[min(times.count - 1, max(0, Int(ceil(Double(times.count) * p)) - 1))] }
                trials.append(Trial(strategy: "S\(strategy)", repetition: repetition + 1, plannedSeconds: strategy == 0 ? 0 : 0.2,
                                    elapsedSeconds: ProcessInfo.processInfo.systemUptime - start,
                                    framesWritten: samples.count, medianMilliseconds: percentile(0.5), p95Milliseconds: percentile(0.95),
                                    maxMilliseconds: times.last ?? 0, samples: samples))
            }
        }
    } catch { failure = String(describing: error) }
    let report = Measurement(bundleID: bundle, trusted: AXIsProcessTrusted(), screen: numbers(screenRect), scale: scale, trials: trials, error: failure)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(report).write(to: URL(fileURLWithPath: output))
    if let failure { print("\(bundle): \(failure)") }
}

@MainActor
func drag(_ args: [String]) throws {
    guard args.count >= 5, let x = Double(args[0]), let y = Double(args[1]), let endX = Double(args[2]),
          let endY = Double(args[3]), let duration = Double(args[4]), duration > 0 else { throw LabError("drag x y x y duration [--via x,y ...] [--hold seconds]") }
    var points = [CGPoint(x: x, y: y)]
    var hold = 0.0
    var index = 5
    while index < args.count {
        if args[index] == "--via" { index += 1; continue }
        if args[index] == "--hold" {
            index += 1
            guard index < args.count, let seconds = Double(args[index]) else { throw LabError("Invalid hold") }
            hold = max(0, seconds)
        } else {
            let values = args[index].split(separator: ",").compactMap { Double($0) }
            guard values.count == 2 else { throw LabError("Invalid waypoint") }
            points.append(CGPoint(x: values[0], y: values[1]))
        }
        index += 1
    }
    points.append(CGPoint(x: endX, y: endY))
    func post(_ type: CGEventType, _ point: CGPoint) throws {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { throw LabError("Cannot create mouse event") }
        event.post(tap: .cghidEventTap)
    }
    try post(.mouseMoved, points[0]); pump(0.1)
    try post(.leftMouseDown, points[0])
    let start = ProcessInfo.processInfo.systemUptime
    let frames = max(1, Int(ceil(duration * 60)))
    for index in 1...frames {
        pump(start + duration * Double(index) / Double(frames) - ProcessInfo.processInfo.systemUptime)
        let progress = Double(index) / Double(frames) * Double(points.count - 1)
        let segment = min(points.count - 2, Int(progress))
        let t = progress - Double(segment)
        let a = points[segment], b = points[segment + 1]
        try post(.leftMouseDragged, CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
    }
    pump(hold)
    try post(.leftMouseUp, points.last!)
}

@MainActor
func run() throws {
    _ = NSApplication.shared
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else { throw LabError("measure | place | drag | windows | screen") }
    switch command {
    case "measure":
        guard args.count == 3 else { throw LabError("measure bundle-id output.json") }
        try measure(args[1], args[2])
    case "place":
        guard args.count == 6 else { throw LabError("place bundle-id x y w h") }
        let values = args.dropFirst(2).compactMap(Double.init)
        guard values.count == 4 else { throw LabError("Invalid frame") }
        place(try findWindow(args[1]), CGRect(x: values[0], y: values[1], width: values[2], height: values[3]))
        print(numbers(try frame(try findWindow(args[1]))))
    case "drag": try drag(Array(args.dropFirst()))
    case "windows":
        guard args.count == 2 else { throw LabError("windows owner-name") }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for window in windows where (window[kCGWindowOwnerName as String] as? String) == args[1] {
            print(window[kCGWindowBounds as String] ?? "unknown bounds")
        }
    case "screen":
        let screen = try mainScreen()
        let area = workArea(screen)
        var columns = 1, rows = 1
        while columns < 8 && screen.frame.width / CGFloat(columns * 2) >= 640 { columns *= 2 }
        while rows < 4 && screen.frame.height / CGFloat(rows * 2) >= 720 { rows *= 2 }
        print("screen=\(numbers(screen.frame)) workArea=\(numbers(area)) expectedLayout=\(columns)x\(rows) maxFPS=\(screen.maximumFramesPerSecond)")
        // Shell-readable coordinates for the capture driver, in AX/CGEvent points.
        print("\(Int(area.minX)) \(Int(area.minY)) \(Int(area.width)) \(Int(area.height))")
    default: throw LabError("Unknown subcommand \(command)")
    }
}

do { try MainActor.assumeIsolated { try run() } }
catch { print("MotionLab: \(error)"); exit(1) }
