// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Focus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Focus", path: "Sources/Focus")
    ]
)
