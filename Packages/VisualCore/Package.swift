// swift-tools-version: 6.0
// VisualCore — pure, host-testable modules (no GPU, no UIKit). Package map and rules R1–R5:
// specs/002-architecture-contracts/contracts/package-map.md (ADR-0003). Version 1.0.0-rc.1.
import PackageDescription

let pure = ["VisualCoreMath", "VisualCoreSimulation", "VisualCoreScenes", "VisualCoreShaderSource",
            "VisualCoreEffectsGraph", "VisualCoreDiagnostics", "VisualCoreAudioDSP", "VisualCorePersistence",
            "VisualCoreParameters", "VisualCoreExperience"]

let package = Package(
    name: "VisualCore",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: pure.map { .library(name: $0, targets: [$0]) }
        + [.library(name: "VisualCoreTestSupport", targets: ["VisualCoreTestSupport"])],
    targets: [
        .target(name: "VisualCoreMath"),
        .target(name: "VisualCoreSimulation", dependencies: ["VisualCoreMath"]),
        // Scenes → Simulation (feature 023 T-A02-501; research R1): SyntheticGestureScript uses SeededRandom. Pure and acyclic (R2, R3).
        .target(name: "VisualCoreScenes", dependencies: ["VisualCoreMath", "VisualCoreSimulation"]),
        .target(name: "VisualCoreShaderSource", dependencies: ["VisualCoreMath"]),
        .target(name: "VisualCoreEffectsGraph"),
        .target(name: "VisualCoreDiagnostics"),
        .target(name: "VisualCoreAudioDSP"),
        .target(name: "VisualCorePersistence"),
        // Parameter schemas, palettes, presets and stable hashes (feature 012 A01-P01; Foundation only, rule R2).
        .target(name: "VisualCoreParameters"),
        // Experience identity, the validated runtime catalog and the experience contract of the unified app (features
        // 187 to 192; Foundation only, rule R2). It builds on four pure modules; the diagnostics module was added by
        // UA-F06 so that an experience can declare its quality profile.
        .target(name: "VisualCoreExperience",
                dependencies: ["VisualCoreMath", "VisualCoreSimulation", "VisualCorePersistence", "VisualCoreDiagnostics"]),
        // Host performance baselines (feature 010 T-F909); an executable, never a library dependency.
        .executableTarget(name: "VisualCoreBaselines",
                          dependencies: ["VisualCoreMath", "VisualCoreSimulation", "VisualCoreScenes", "VisualCoreShaderSource", "VisualCoreEffectsGraph"]),
        // Test-only (rule R5): never a dependency of a product target.
        .target(name: "VisualCoreTestSupport",
                dependencies: ["VisualCoreMath", "VisualCoreSimulation", "VisualCoreExperience", "VisualCorePersistence",
                               "VisualCoreDiagnostics"]),
        .testTarget(name: "VisualCoreMathTests", dependencies: ["VisualCoreMath"]),
        .testTarget(name: "VisualCoreSimulationTests", dependencies: ["VisualCoreSimulation", "VisualCoreMath"]),
        .testTarget(name: "VisualCoreScenesTests", dependencies: ["VisualCoreScenes", "VisualCoreMath"]),
        .testTarget(name: "VisualCoreDiagnosticsTests", dependencies: ["VisualCoreDiagnostics"]),
        // Feature 047 (A06-P01) T-A06-102: ring buffer, demo signal and spectrum analyser.
        .testTarget(name: "VisualCoreAudioDSPTests", dependencies: ["VisualCoreAudioDSP"]),
        .testTarget(name: "VisualCoreParametersTests", dependencies: ["VisualCoreParameters"]),
        .testTarget(name: "VisualCoreTestSupportTests", dependencies: ["VisualCoreTestSupport"]),
        .testTarget(name: "VisualCorePersistenceTests", dependencies: ["VisualCorePersistence"]),
        .testTarget(name: "VisualCoreExperienceTests",
                    dependencies: ["VisualCoreExperience", "VisualCoreTestSupport", "VisualCorePersistence", "VisualCoreSimulation",
                                   "VisualCoreMath", "VisualCoreDiagnostics"],
                    resources: [.copy("Fixtures")]),
        .testTarget(name: "VisualCoreShaderSourceTests", dependencies: ["VisualCoreShaderSource"]),
        .testTarget(name: "VisualCoreEffectsGraphTests", dependencies: ["VisualCoreEffectsGraph"], resources: [.copy("Fixtures")]),
        .testTarget(name: "VisualCoreScaffoldTests",
                    dependencies: ["VisualCoreMath", "VisualCoreSimulation", "VisualCoreScenes", "VisualCoreShaderSource",
                                   "VisualCoreEffectsGraph", "VisualCoreDiagnostics", "VisualCoreAudioDSP",
                                   "VisualCorePersistence", "VisualCoreTestSupport", "VisualCoreExperience"]),
    ],
    swiftLanguageModes: [.v6]
)
