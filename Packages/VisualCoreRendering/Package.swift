// swift-tools-version: 6.0
// VisualCoreRendering — iOS-only modules over the owner's prebuilt ANGLE (Metal backend) frameworks,
// reused in place from the read-only reference (ADR-0002; built by its scripts/build_angle_xcframework.py
// at pin 29d1823). Package map and rules R1–R5: specs/002-architecture-contracts/contracts/package-map.md.
// Version 0.1.0. Tests run on iOS simulators.
import PackageDescription

let package = Package(
    name: "VisualCoreRendering",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "VisualCoreRendering", targets: ["VisualCoreRendering"]),
        .library(name: "VisualCoreEffects", targets: ["VisualCoreEffects"]),
        .library(name: "VisualCoreUI", targets: ["VisualCoreUI"]),
        .library(name: "VisualCoreAudio", targets: ["VisualCoreAudio"]),
        .library(name: "VisualCoreAutomation", targets: ["VisualCoreAutomation"]),
    ],
    dependencies: [.package(path: "../VisualCore")],
    targets: [
        .binaryTarget(name: "libEGL", path: "../../External/projectm-ios/Build/ANGLEFrameworks/libEGL.xcframework"),
        // libEGL loads libGLESv2 at run time; depending on it embeds it next to libEGL (as in the reference).
        .binaryTarget(name: "libGLESv2", path: "../../External/projectm-ios/Build/ANGLEFrameworks/libGLESv2.xcframework"),
        .target(name: "CVisualCoreEGL", dependencies: ["libEGL", "libGLESv2"]),
        .target(name: "CVisualCoreGL", dependencies: ["CVisualCoreEGL"]),
        .target(name: "VisualCoreRendering",
                dependencies: ["CVisualCoreEGL", "CVisualCoreGL",
                               .product(name: "VisualCoreDiagnostics", package: "VisualCore"),
                               .product(name: "VisualCoreShaderSource", package: "VisualCore"),
                               .product(name: "VisualCoreMath", package: "VisualCore"),
                               .product(name: "VisualCoreSimulation", package: "VisualCore"),
                               .product(name: "VisualCoreScenes", package: "VisualCore")],
                linkerSettings: [.linkedFramework("QuartzCore"), .linkedFramework("UIKit")]),
        .target(name: "VisualCoreEffects",
                dependencies: ["VisualCoreRendering", .product(name: "VisualCoreEffectsGraph", package: "VisualCore")]),
        .target(name: "VisualCoreUI",
                dependencies: ["VisualCoreRendering", .product(name: "VisualCoreDiagnostics", package: "VisualCore")]),
        .target(name: "VisualCoreAudio", dependencies: [.product(name: "VisualCoreAudioDSP", package: "VisualCore")],
                linkerSettings: [.linkedFramework("AVFAudio")]),
        .target(name: "VisualCoreAutomation", dependencies: ["VisualCoreRendering", .product(name: "VisualCoreDiagnostics", package: "VisualCore")]),
        .testTarget(name: "VisualCoreAutomationTests", dependencies: ["VisualCoreAutomation", "VisualCoreRendering"]),
        .testTarget(name: "VisualCoreEffectsTests",
                    dependencies: ["VisualCoreEffects", "VisualCoreRendering", "CVisualCoreGL",
                                   .product(name: "VisualCoreEffectsGraph", package: "VisualCore")]),
        .testTarget(name: "VisualCoreRenderingTests",
                    dependencies: ["VisualCoreRendering", "CVisualCoreGL",
                                   .product(name: "VisualCoreDiagnostics", package: "VisualCore"),
                                   .product(name: "VisualCoreMath", package: "VisualCore"),
                                   .product(name: "VisualCoreSimulation", package: "VisualCore"),
                                   .product(name: "VisualCoreScenes", package: "VisualCore")]),
    ],
    swiftLanguageModes: [.v6]
)
