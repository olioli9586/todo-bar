// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TodoBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TodoBar",
            path: "Sources/TodoBar"
        )
    ]
)
