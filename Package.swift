// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Refocus",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Refocus", targets: ["RefocusApp"]),
        .executable(name: "RefocusHelper", targets: ["RefocusHelper"]),
        .executable(name: "RefocusChecks", targets: ["RefocusChecks"])
    ],
    targets: [
        .target(name: "RefocusCore"),
        .executableTarget(name: "RefocusApp", dependencies: ["RefocusCore"]),
        .executableTarget(name: "RefocusHelper", dependencies: ["RefocusCore"]),
        .executableTarget(name: "RefocusChecks", dependencies: ["RefocusCore"], path: "Tests/RefocusChecks")
    ]
)
