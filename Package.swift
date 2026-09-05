// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OnsenCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "OnsenCore", targets: ["OnsenCore"])],
    targets: [
        .target(name: "OnsenCore", path: "Core"),
        .testTarget(name: "OnsenCoreTests", dependencies: ["OnsenCore"], path: "Tests/OnsenCoreTests")
    ]
)
