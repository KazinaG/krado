// swift-tools-version: 6.0
import PackageDescription
import Foundation

// Swift 6.4's swiftbuild backend in CLT can omit the bundled Testing macro path.
// Workaround for https://github.com/swiftlang/swift-build/issues/1870; remove once fixed.
// Discover the selected compiler instead of depending on an Xcode/CLT install path.
// This affects only test compilation and uses the toolchain's own macro, not a package dependency.
func testingMacroSettings() -> [SwiftSetting] {
    let compiler: String
    if let override = ProcessInfo.processInfo.environment["SWIFT_EXEC"] {
        compiler = override
    } else {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["--find", "swiftc"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let path = String(data: data, encoding: .utf8) else { return [] }
        compiler = path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let directory = URL(fileURLWithPath: compiler).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("lib/swift/host/plugins/testing")
    guard FileManager.default.fileExists(atPath: directory.appendingPathComponent("libTestingMacros.dylib").path) else { return [] }
    return [.unsafeFlags(["-plugin-path", directory.path])]
}

let package = Package(
    name: "krado",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KradoCore", targets: ["KradoCore"]),
        .executable(name: "krado", targets: ["Krado"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .target(name: "KradoCore"),
        .executableTarget(
            name: "Krado",
            dependencies: ["KradoCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "KradoCoreTests", dependencies: ["KradoCore"], swiftSettings: testingMacroSettings()),
    ]
)
