// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PixiepocketCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PixiepocketCore", targets: ["PixiepocketCore"]),
    ],
    targets: [
        .target(
            name: "PixiepocketCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "PixiepocketCoreTests",
            dependencies: ["PixiepocketCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
    ]
)
