// swift-tools-version: 6.0
// FluidArtPlaygroundAdapter — feature 193 (UA-F07) T-U07-021 (research R1, R3; data-model section 2; ADR-0011). The
// pure core that adapts Fluid Art Playground to the experience contract, with its manifest: host-testable with
// `swift test`. The presenter and controls in `Experience/` need UIKit and the GPU; the framework target
// `FluidArtPlaygroundExperience` of project.yml compiles them with the app's sources.
import PackageDescription

let package = Package(
    name: "FluidArtPlaygroundAdapter",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "FluidArtPlaygroundAdapterCore", targets: ["FluidArtPlaygroundAdapterCore"])],
    dependencies: [
        .package(name: "VisualCore", path: "../../../Packages/VisualCore"),
        .package(name: "FluidArtPlaygroundCore", path: "../FluidArtPlaygroundCore"),
    ],
    targets: [
        .target(name: "FluidArtPlaygroundAdapterCore",
                dependencies: [.product(name: "FluidArtPlaygroundCore", package: "FluidArtPlaygroundCore"),
                               .product(name: "VisualCoreExperience", package: "VisualCore"),
                               .product(name: "VisualCoreDiagnostics", package: "VisualCore"),
                               .product(name: "VisualCorePersistence", package: "VisualCore")],
                path: "Core"),
        .testTarget(name: "FluidArtPlaygroundAdapterCoreTests",
                    dependencies: ["FluidArtPlaygroundAdapterCore",
                                   .product(name: "FluidArtPlaygroundCore", package: "FluidArtPlaygroundCore"),
                                   .product(name: "VisualCoreExperience", package: "VisualCore"),
                                   .product(name: "VisualCoreDiagnostics", package: "VisualCore"),
                                   .product(name: "VisualCoreMath", package: "VisualCore"),
                                   .product(name: "VisualCoreScenes", package: "VisualCore")],
                    path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)
