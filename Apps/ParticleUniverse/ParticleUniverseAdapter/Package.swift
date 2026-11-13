// swift-tools-version: 6.0
// ParticleUniverseAdapter — feature 193 (UA-F07) T-U07-027 (research R1, R5; data-model section 2). The pure core that
// adapts Particle Universe to the experience contract, with its manifest: host-testable with `swift test`. The
// presenter and controls in `Experience/` need UIKit and the GPU; the framework target `ParticleUniverseExperience` of
// project.yml compiles them with the app's sources.
import PackageDescription

let package = Package(
    name: "ParticleUniverseAdapter",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "ParticleUniverseAdapterCore", targets: ["ParticleUniverseAdapterCore"])],
    dependencies: [
        .package(name: "VisualCore", path: "../../../Packages/VisualCore"),
        .package(name: "ParticleUniverseCore", path: "../ParticleUniverseCore"),
    ],
    targets: [
        .target(name: "ParticleUniverseAdapterCore",
                dependencies: [.product(name: "ParticleUniverseCore", package: "ParticleUniverseCore"),
                               .product(name: "VisualCoreExperience", package: "VisualCore"),
                               .product(name: "VisualCoreSimulation", package: "VisualCore"),
                               .product(name: "VisualCoreMath", package: "VisualCore"),
                               .product(name: "VisualCoreDiagnostics", package: "VisualCore"),
                               .product(name: "VisualCoreParameters", package: "VisualCore"),
                               .product(name: "VisualCorePersistence", package: "VisualCore")],
                path: "Core"),
        .testTarget(name: "ParticleUniverseAdapterCoreTests",
                    dependencies: ["ParticleUniverseAdapterCore",
                                   .product(name: "ParticleUniverseCore", package: "ParticleUniverseCore"),
                                   .product(name: "VisualCoreExperience", package: "VisualCore"),
                                   .product(name: "VisualCoreSimulation", package: "VisualCore"),
                                   .product(name: "VisualCoreMath", package: "VisualCore")],
                    path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)
