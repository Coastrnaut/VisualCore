// swift-tools-version: 6.0
// FractalExplorerAdapter — feature 193 (UA-F07) T-U07-024 (research R1; data-model section 2). The pure core that
// adapts Fractal Explorer to the experience contract, with its manifest: host-testable with `swift test`. The
// presenter and controls in `Experience/` need UIKit and the GPU; the framework target `FractalExplorerExperience` of
// project.yml compiles them with the app's sources.
import PackageDescription

let package = Package(
    name: "FractalExplorerAdapter",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "FractalExplorerAdapterCore", targets: ["FractalExplorerAdapterCore"])],
    dependencies: [
        .package(name: "VisualCore", path: "../../../Packages/VisualCore"),
        .package(name: "FractalExplorerCore", path: "../FractalExplorerCore"),
    ],
    targets: [
        .target(name: "FractalExplorerAdapterCore",
                dependencies: [.product(name: "FractalExplorerCore", package: "FractalExplorerCore"),
                               .product(name: "VisualCoreExperience", package: "VisualCore"),
                               .product(name: "VisualCoreMath", package: "VisualCore"),
                               .product(name: "VisualCorePersistence", package: "VisualCore")],
                path: "Core"),
        .testTarget(name: "FractalExplorerAdapterCoreTests",
                    dependencies: ["FractalExplorerAdapterCore",
                                   .product(name: "FractalExplorerCore", package: "FractalExplorerCore"),
                                   .product(name: "VisualCoreExperience", package: "VisualCore"),
                                   .product(name: "VisualCoreMath", package: "VisualCore")],
                    path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)
