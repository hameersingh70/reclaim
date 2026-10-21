// swift-tools-version: 6.0
// Reclaim — Developer Storage Intelligence for macOS
// Phase 1: Project skeleton, domain models, analyzer protocol, DI container.
//
// Note: Tests run as an executable target (no XCTest/Testing framework required)
// since this machine has Swift Command Line Tools only (no Xcode.app).
// When Xcode is installed, migrate Tests/ReclaimTests to a proper .testTarget.

import PackageDescription

let package = Package(
    name: "Reclaim",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Reclaim",
            targets: ["Reclaim"]
        ),
        .executable(
            name: "reclaim",
            targets: ["ReclaimCLI"]
        ),
        .executable(
            name: "ReclaimTests",
            targets: ["ReclaimTests"]
        ),
        .executable(
            name: "ReclaimUI",
            targets: ["ReclaimUI"]
        )
    ],
    targets: [
        .target(
            name: "Reclaim",
            path: "Sources/Reclaim"
        ),
        .executableTarget(
            name: "ReclaimCLI",
            dependencies: ["Reclaim"],
            path: "Sources/ReclaimCLI"
        ),
        .executableTarget(
            name: "ReclaimTests",
            dependencies: ["Reclaim"],
            path: "Tests/ReclaimTests"
        ),
        .executableTarget(
            name: "ReclaimUI",
            dependencies: ["Reclaim"],
            path: "Sources/ReclaimUI",
            resources: [.copy("Resources")]
        )
    ]
)
