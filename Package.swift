// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftNetPulse",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "SwiftNetPulse", targets: ["SwiftNetPulse"]),
    ],
    targets: [
        .target(
            name: "SwiftNetPulse",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "SwiftNetPulseTests",
            dependencies: ["SwiftNetPulse"],
            exclude: ["Fixtures"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
