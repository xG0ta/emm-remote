// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EmmRemote",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "EmmRemote", path: "Sources/EmmRemote")
    ]
)
