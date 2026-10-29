// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "HaloSearch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HaloSearch", targets: ["HaloSearch"]),
        .library(name: "HaloSearchCore", targets: ["HaloSearchCore"]),
    ],
    targets: [
        // Platform-independent logic: Google request building, gesture recognition, text selection.
        .target(name: "HaloSearchCore"),
        // The menu bar app: capture, overlay, results panel.
        .executableTarget(name: "HaloSearch", dependencies: ["HaloSearchCore"]),
        .testTarget(name: "HaloSearchCoreTests", dependencies: ["HaloSearchCore"]),
    ]
)
