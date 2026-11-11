// swift-tools-version: 6.0
// VisualCore — pure, host-testable modules (no GPU, no UIKit). Package map and rules R1–R5:
// specs/002-architecture-contracts/contracts/package-map.md (ADR-0003). Version 0.1.0.
import PackageDescription

let pure = ["VisualCoreMath", "VisualCoreSimulation", "VisualCoreScenes", "VisualCoreShaderSource",
            "VisualCoreEffectsGraph", "VisualCoreDiagnostics", "VisualCoreAudioDSP", "VisualCorePersistence"]

let package = Package(
    name: "VisualCore",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: pure.map { .library(name: $0, targets: [$0]) }
        + [.library(name: "VisualCoreTestSupport", targets: ["VisualCoreTestSupport"])],
    targets: [
        .target(name: "VisualCoreMath"),
        .target(name: "VisualCoreSimulation", dependencies: ["VisualCoreMath"]),
        .target(name: "VisualCoreScenes", dependencies: ["VisualCoreMath"]),
        .target(name: "VisualCoreShaderSource"),
        .target(name: "VisualCoreEffectsGraph"),
        .target(name: "VisualCoreDiagnostics"),
        .target(name: "VisualCoreAudioDSP"),
        .target(name: "VisualCorePersistence"),
        // Test-only (rule R5): never a dependency of a product target.
        .target(name: "VisualCoreTestSupport", dependencies: ["VisualCoreMath", "VisualCoreSimulation"]),
        .testTarget(name: "VisualCoreDiagnosticsTests", dependencies: ["VisualCoreDiagnostics"]),
        .testTarget(name: "VisualCoreShaderSourceTests", dependencies: ["VisualCoreShaderSource"]),
        .testTarget(name: "VisualCoreScaffoldTests",
                    dependencies: ["VisualCoreMath", "VisualCoreSimulation", "VisualCoreScenes", "VisualCoreShaderSource",
                                   "VisualCoreEffectsGraph", "VisualCoreDiagnostics", "VisualCoreAudioDSP",
                                   "VisualCorePersistence", "VisualCoreTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
