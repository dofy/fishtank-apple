// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FishtankCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "FishtankCore", targets: ["FishtankCore"])],
    targets: [
        .target(name: "FishtankCore", path: "Sources/Core"),
        .testTarget(name: "FishtankCoreTests", dependencies: ["FishtankCore"], path: "Tests", resources: [.copy("Fixtures")])
    ]
)
