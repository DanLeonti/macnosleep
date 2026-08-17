// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacNoSleep",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacNoSleep",
            path: "Sources/MacNoSleep",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
