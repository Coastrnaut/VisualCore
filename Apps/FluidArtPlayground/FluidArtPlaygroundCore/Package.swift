// swift-tools-version: 6.0
// FluidArtPlaygroundCore — the app's GPU-free domain (feature 019 A02-P01): the validated fluid configuration, the
// dissipation rule with its CPU reference, the deterministic dye seed and the spoken canvas description. Host-testable
// with `swift test`. Generic grid, precision and time-step machinery lives in VisualCoreSimulation (constitution
// Principle II, A02 reuse rule); this package holds only fluid-specific rules.
import PackageDescription

let package = Package(
    name: "FluidArtPlaygroundCore",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "FluidArtPlaygroundCore", targets: ["FluidArtPlaygroundCore"])],
    dependencies: [.package(name: "VisualCore", path: "../../../Packages/VisualCore")],
    targets: [
        .target(name: "FluidArtPlaygroundCore", dependencies: [
            .product(name: "VisualCoreSimulation", package: "VisualCore"),
        ]),
        .testTarget(name: "FluidArtPlaygroundCoreTests", dependencies: ["FluidArtPlaygroundCore",
                                                                       .product(name: "VisualCoreSimulation", package: "VisualCore")]),
    ],
    swiftLanguageModes: [.v6]
)
