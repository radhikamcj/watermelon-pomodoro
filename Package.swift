// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WatermelonPomodoro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "WatermelonPomodoro", path: "Sources/WatermelonPomodoro")
    ]
)
