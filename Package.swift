// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "SayRight",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "SayRight", path: "Sources/SayRight"),
        .testTarget(name: "SayRightTests", dependencies: ["SayRight"], path: "Tests/SayRightTests"),
    ]
)
