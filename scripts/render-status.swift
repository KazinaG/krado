#!/usr/bin/env swift
import Foundation

// Compile only the pure state model, shared image styling, and bitmap renderer.
// Neither the app executable nor NSApplication is started.
let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let build = repository.appendingPathComponent(".build", isDirectory: true)
let binary = build.appendingPathComponent("render-status-preview")

func run(_ executable: URL, arguments: [String]) throws {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = repository
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 { exit(process.terminationStatus) }
}

do {
    guard CommandLine.arguments.count <= 2 else {
        FileHandle.standardError.write(Data("Usage: swift scripts/render-status.swift [output-directory]\n".utf8))
        exit(2)
    }
    let output = CommandLine.arguments.dropFirst().first.map {
        URL(fileURLWithPath: $0, isDirectory: true).path
    }
    try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
    try run(URL(fileURLWithPath: "/usr/bin/xcrun"), arguments: [
        "swiftc", "-module-cache-path", build.appendingPathComponent("status-module-cache").path,
        "-D", "STATUS_RENDERER", "-parse-as-library",
        "Sources/KradoCore/StatusAppearance.swift", "Sources/Krado/StatusPresentation.swift",
        "scripts/StatusRenderer.swift", "-o", binary.path,
    ])
    try run(binary, arguments: output.map { [$0] } ?? [])
} catch {
    FileHandle.standardError.write(Data("Status renderer failed: \(error)\n".utf8))
    exit(1)
}
