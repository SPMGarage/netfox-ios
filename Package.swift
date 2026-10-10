// swift-tools-version: 6.2

import PackageDescription

let upcomingFeatures: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances")
]

let package = Package(
    name: "netfox",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "netfox", targets: ["netfox"])
    ],
    targets: [
        // Interception, records, storage and export. No UI and no default isolation:
        // most of this code runs on CFNetwork and URLSession delegate queues.
        .target(
            name: "NetfoxCore",
            path: "Sources/NetfoxCore",
            swiftSettings: upcomingFeatures
        ),
        // Public NFX facade, the @Observable stores and the SwiftUI inspector.
        .target(
            name: "netfox",
            dependencies: ["NetfoxCore"],
            path: "Sources/netfox",
            // LegacyUI holds the 3.x SwiftUI views until they are ported to the new store.
            exclude: ["LegacyUI"],
            resources: [.process("PrivacyInfo.xcprivacy")],
            swiftSettings: upcomingFeatures + [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "NetfoxCoreTests",
            dependencies: ["NetfoxCore", "netfox"],
            path: "Tests/NetfoxCoreTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
