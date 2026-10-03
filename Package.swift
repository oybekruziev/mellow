// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MellowCore",
    platforms: [.macOS("26.0")],
    products: [.library(name: "MellowCore", targets: ["MellowCore"])],
    targets: [
        .target(name: "MellowCore"),
        .testTarget(name: "MellowCoreTests", dependencies: ["MellowCore"])
    ]
)
