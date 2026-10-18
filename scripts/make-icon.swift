#!/usr/bin/env swift
// Deterministic, offscreen artwork. No NSApplication, windows, or network access.
// Run from the repository root: swift scripts/make-icon.swift
// Regenerate only the layout diagram: swift scripts/make-icon.swift --layouts-only
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("docs/assets", isDirectory: true)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = assets.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let layoutsOnly = CommandLine.arguments.contains("--layouts-only")
let fileManager = FileManager.default
for directory in layoutsOnly ? [assets] : [assets, resources, iconset] {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}
let white = color(1, 1, 1)
let accent = color(0.34, 0.95, 0.80)
let muted = color(0.67, 0.75, 0.85)

func rounded(_ context: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor) {
    context.setFillColor(fill)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

func gradient(_ context: CGContext, rect: CGRect, radius: CGFloat, colors: [CGColor]) {
    context.saveGState()
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    context.restoreGState()
}

func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: CGColor = white) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(cgColor: fill)!,
    ]
    (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
}

func centeredText(_ value: String, centerX: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, fill: CGColor = white) {
    let width = (value as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width
    text(value, x: centerX - width / 2, y: y, size: size, weight: weight, fill: fill)
}

func grid(_ context: CGContext, rect: CGRect, columns: Int, rows: Int, gap: CGFloat, radius: CGFloat, highlighted: Bool = true) {
    let cellWidth = (rect.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
    let cellHeight = (rect.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
    for row in 0..<rows {
        for column in 0..<columns {
            let cell = CGRect(x: rect.minX + CGFloat(column) * (cellWidth + gap), y: rect.maxY - CGFloat(row + 1) * cellHeight - CGFloat(row) * gap, width: cellWidth, height: cellHeight)
            rounded(context, cell, radius: radius, fill: color(1, 1, 1, 0.91))
        }
    }
    if highlighted {
        let span = CGRect(x: rect.minX, y: rect.maxY - cellHeight, width: columns > 1 ? 2 * cellWidth + gap : cellWidth, height: cellHeight)
        rounded(context, span, radius: radius, fill: accent)
        if span.width > 100 {
            rounded(context, CGRect(x: span.minX + 15, y: span.maxY - 22, width: min(56, span.width - 30), height: 5), radius: 2.5, fill: color(0.03, 0.26, 0.26, 0.45))
        }
    }
}

func icon(_ context: CGContext, rect: CGRect) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: rect.width / 1024, y: rect.height / 1024)
    let background = CGRect(x: 64, y: 64, width: 896, height: 896)
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 27, color: color(0.01, 0.03, 0.10, 0.26))
    rounded(context, background, radius: 210, fill: color(0.14, 0.22, 0.45))
    context.setShadow(offset: .zero, blur: 0, color: nil)
    gradient(context, rect: background, radius: 210, colors: [color(0.24, 0.22, 0.59), color(0.06, 0.39, 0.44)])
    context.setStrokeColor(color(1, 1, 1, 0.15))
    context.setLineWidth(3)
    context.addPath(CGPath(roundedRect: background.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 210, cornerHeight: 210, transform: nil))
    context.strokePath()
    grid(context, rect: CGRect(x: 196, y: 286, width: 632, height: 452), columns: 4, rows: 2, gap: 20, radius: 22)
    context.restoreGState()
}

func render(width: Int, height: Int, to destination: URL, draw: (CGContext) -> Void) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    draw(context)
    NSGraphicsContext.restoreGraphicsState()
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "krado.artwork", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    try png.write(to: destination)
}

if !layoutsOnly {
    try render(width: 1024, height: 1024, to: assets.appendingPathComponent("icon.png")) { context in
        icon(context, rect: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    }

    try render(width: 1280, height: 640, to: assets.appendingPathComponent("cover.png")) { context in
        gradient(context, rect: CGRect(x: 0, y: 0, width: 1280, height: 640), radius: 0, colors: [color(0.055, 0.075, 0.17), color(0.055, 0.18, 0.24)])
        icon(context, rect: CGRect(x: 58, y: 368, width: 150, height: 150))
        text("krado", x: 230, y: 396, size: 76, weight: .bold)
        text("Drag a window.", x: 76, y: 300, size: 42, weight: .semibold)
        text("Drop it on the grid.", x: 76, y: 246, size: 42, weight: .semibold)
        text("Window tiling for macOS — free & open source", x: 78, y: 194, size: 22, fill: muted)
        text("macOS 14+   ·   English & 日本語", x: 78, y: 79, size: 17, weight: .medium, fill: muted)
        let display = CGRect(x: 765, y: 204, width: 443, height: 298)
        context.setShadow(offset: CGSize(width: 0, height: -16), blur: 35, color: color(0, 0, 0, 0.25))
        rounded(context, display, radius: 19, fill: color(0.26, 0.33, 0.44))
        context.setShadow(offset: .zero, blur: 0, color: nil)
        rounded(context, display.insetBy(dx: 9, dy: 9), radius: 12, fill: color(0.08, 0.13, 0.23))
        grid(context, rect: display.insetBy(dx: 25, dy: 25), columns: 4, rows: 2, gap: 10, radius: 8)
        rounded(context, CGRect(x: 966, y: 147, width: 42, height: 57), radius: 5, fill: color(0.25, 0.33, 0.43))
        rounded(context, CGRect(x: 909, y: 138, width: 156, height: 13), radius: 6.5, fill: color(0.36, 0.44, 0.55))
        centeredText("Room for your next idea.", centerX: 987, y: 88, size: 17, fill: muted)
    }
}

try render(width: 1280, height: 640, to: assets.appendingPathComponent("layouts.png")) { context in
    gradient(context, rect: CGRect(x: 0, y: 0, width: 1280, height: 640), radius: 0, colors: [color(0.055, 0.075, 0.17), color(0.055, 0.18, 0.24)])
    text("A grid that fits your display", x: 64, y: 550, size: 36, weight: .bold)
    text("Visible work area in points · same rule for built-in and external displays", x: 66, y: 514, size: 19, fill: muted)
    text("1. Portrait: H > W → 1 × 2 if H ≥ 1200; otherwise 1 × 1", x: 65, y: 466, size: 20, weight: .medium)
    text("2. Ultrawide: W/H ≥ 2.1 and W ≥ 2400 → 4 × 2 if H ≥ 1300; otherwise 4 × 1", x: 65, y: 431, size: 20, weight: .medium)
    text("3. Otherwise, choose the width band below:", x: 65, y: 386, size: 19, weight: .medium, fill: muted)
    let items: [(String, String, String, Int, Int, CGRect)] = [
        ("Large", "4 × 2", "W ≥ 2800", 4, 2, CGRect(x: 65, y: 198, width: 255, height: 150)),
        ("Mid-size", "2 × 2", "1800 ≤ W < 2800", 2, 2, CGRect(x: 352, y: 198, width: 255, height: 150)),
        ("Small", "2 × 1", "1200 ≤ W < 1800", 2, 1, CGRect(x: 639, y: 198, width: 255, height: 150)),
        ("Tiny", "1 × 1", "W < 1200", 1, 1, CGRect(x: 926, y: 198, width: 255, height: 150)),
    ]
    for (label, layout, condition, columns, rows, frame) in items {
        rounded(context, frame, radius: 12, fill: color(0.25, 0.33, 0.44))
        grid(context, rect: frame.insetBy(dx: 10, dy: 10), columns: columns, rows: rows, gap: 7, radius: 5, highlighted: false)
        centeredText(label, centerX: frame.midX, y: 157, size: 21, weight: .semibold)
        centeredText(layout, centerX: frame.midX, y: 115, size: 29, weight: .bold, fill: accent)
        centeredText(condition, centerX: frame.midX, y: 83, size: 16, fill: muted)
    }
    text("Priority: portrait → ultrawide → width bands. W = visible width; H = visible height.", x: 65, y: 32, size: 17, fill: muted)
}

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let message = String(data: data, encoding: .utf8) ?? "Artwork command failed"
        throw NSError(domain: "krado.artwork", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
    }
}

if !layoutsOnly {
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = size * scale
            let suffix = scale == 2 ? "@2x" : ""
            let output = iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
            try run("/usr/bin/sips", ["-z", "\(pixels)", "\(pixels)", assets.appendingPathComponent("icon.png").path, "--out", output.path])
        }
    }
    try run("/usr/bin/iconutil", ["--convert", "icns", "--output", resources.appendingPathComponent("AppIcon.icns").path, iconset.path])
    print("Generated docs/assets/{icon,cover,layouts}.png, AppIcon.iconset, and Resources/AppIcon.icns (offscreen).")
} else {
    print("Generated docs/assets/layouts.png only (offscreen).")
}
