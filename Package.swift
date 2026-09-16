// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftNetPulse",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "SwiftNetPulse", targets: ["SwiftNetPulse"]),
    ],
    targets: [
        .target(name: "SwiftNetPulse"),
        .testTarget(
            name: "SwiftNetPulseTests",
            dependencies: ["SwiftNetPulse"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
