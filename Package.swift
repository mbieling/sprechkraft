// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceScribe",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-modern", from: "1.0.0"),
        .package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0"),
    ],
    targets: []  // Xcode-Projekt definiert die Targets; dies dient nur zur Resolver-Kompatibilität
)
