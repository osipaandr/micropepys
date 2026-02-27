// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MicropepysCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MicropepysCore", targets: ["MicropepysCore"])
    ],
    targets: [
        .target(name: "MicropepysCore"),
        .testTarget(name: "MicropepysCoreTests", dependencies: ["MicropepysCore"])
    ]
)
