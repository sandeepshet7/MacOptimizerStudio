// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOptimizerStudio",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MacOptimizerStudioCore",
            targets: ["MacOptimizerStudioCore"]
        ),
        .executable(
            name: "MacOptimizerStudio",
            targets: ["MacOptimizerStudio"]
        )
    ],
    targets: [
        .target(
            name: "MacOptimizerStudioCore",
            path: "Sources/MacOptimizerStudioCore"
        ),
        .executableTarget(
            name: "MacOptimizerStudio",
            dependencies: ["MacOptimizerStudioCore"],
            path: "Sources/MacOptimizerStudio"
        ),
        .executableTarget(
            name: "MacOptimizerStudioCoreSelfCheck",
            dependencies: ["MacOptimizerStudioCore"],
            path: "Sources/MacOptimizerStudioCoreSelfCheck"
        ),
        .testTarget(
            name: "MacOptimizerStudioCoreTests",
            dependencies: ["MacOptimizerStudioCore"],
            path: "Tests/MacOptimizerStudioCoreTests"
        )
    ]
)
