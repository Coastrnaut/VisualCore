// swift-tools-version: 6.0
// GenerativeArtStudioAdapter — feature 193 (UA-F07) T-U07-008 (research R1, data-model section 2). The pure core
// that adapts Generative Art Studio to the experience contract: host-testable with `swift test`. The presenter,
// controls and manifest in `Experience/` need UIKit and the GPU; the framework target
// `GenerativeArtStudioExperience` of project.yml compiles them with the app's sources.
import PackageDescription

let package = Package(
    name: "GenerativeArtStudioAdapter",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "GenerativeArtStudioAdapterCore", targets: ["GenerativeArtStudioAdapterCore"])],
    dependencies: [
        .package(name: "VisualCore", path: "../../../Packages/VisualCore"),
        .package(name: "GenerativeArtStudioCore", path: "../Core"),
    ],
    targets: [
        .target(name: "GenerativeArtStudioAdapterCore",
                dependencies: [.product(name: "GenerativeArtStudioCore", package: "GenerativeArtStudioCore"),
                               .product(name: "VisualCoreExperience", package: "VisualCore"),
                               .product(name: "VisualCoreParameters", package: "VisualCore"),
                               .product(name: "VisualCorePersistence", package: "VisualCore"),
                               .product(name: "VisualCoreSimulation", package: "VisualCore")],
                path: "Core"),
        .testTarget(name: "GenerativeArtStudioAdapterCoreTests",
                    dependencies: ["GenerativeArtStudioAdapterCore",
                                   .product(name: "GenerativeArtStudioCore", package: "GenerativeArtStudioCore"),
                                   .product(name: "VisualCoreExperience", package: "VisualCore"),
                                   .product(name: "VisualCoreParameters", package: "VisualCore"),
                                   .product(name: "VisualCoreSimulation", package: "VisualCore")],
                    path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)
