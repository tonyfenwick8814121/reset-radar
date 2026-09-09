// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ResetRadar",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ResetRadar", targets: ["ResetRadar"])
    ],
    targets: [
        .executableTarget(
            name: "ResetRadar",
            path: "ResetRadar",
            exclude: ["Resources/Info.plist"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ResetRadarTests",
            dependencies: ["ResetRadar"],
            path: "ResetRadarTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
