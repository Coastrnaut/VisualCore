// swift-tools-version: 6.0
// ParticleUniverseCore — the app's GPU-free domain (feature 033 A04-P01): the versioned particle scene, the emitter
// families, scene commands and the seeded fixed-step scene simulation. Host-testable with `swift test`. The generic
// particle pool, emitter shapes and fixed-step runner live in VisualCoreSimulation (constitution Principle II, A04 reuse
// rule); this package holds only Particle Universe rules and presets.
import PackageDescription

let package = Package(
    name: "ParticleUniverseCore",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "ParticleUniverseCore", targets: ["ParticleUniverseCore"])],
    dependencies: [.package(name: "VisualCore", path: "../../../Packages/VisualCore")],
    targets: [
        .target(name: "ParticleUniverseCore", dependencies: [.product(name: "VisualCoreSimulation", package: "VisualCore"),
                                                             .product(name: "VisualCoreMath", package: "VisualCore"),
                                                             .product(name: "VisualCoreDiagnostics", package: "VisualCore")]),
        .testTarget(name: "ParticleUniverseCoreTests", dependencies: ["ParticleUniverseCore",
                                                                      .product(name: "VisualCoreSimulation", package: "VisualCore"),
                                                                      .product(name: "VisualCoreMath", package: "VisualCore"),
                                                                      .product(name: "VisualCoreDiagnostics", package: "VisualCore")],
                    resources: [.copy("Fixtures")]),
    ],
    swiftLanguageModes: [.v6]
)
