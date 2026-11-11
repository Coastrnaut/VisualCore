// swift-tools-version: 6.0
// GenerativeArtStudioCore — the app's GPU-free domain (feature 012 A01-P01): scene families, presets, the versioned
// composition document, seed offsets and deterministic particle replay. Host-testable with `swift test`.
// Reusable logic lives in VisualCore (constitution Principle II); this package holds only product rules and content.
import PackageDescription

let package = Package(
    name: "GenerativeArtStudioCore",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "GenerativeArtStudioCore", targets: ["GenerativeArtStudioCore"])],
    dependencies: [.package(name: "VisualCore", path: "../../../Packages/VisualCore")],
    targets: [
        .target(name: "GenerativeArtStudioCore", dependencies: [
            .product(name: "VisualCoreParameters", package: "VisualCore"),
            .product(name: "VisualCoreSimulation", package: "VisualCore"),
            .product(name: "VisualCoreMath", package: "VisualCore"),
            .product(name: "VisualCorePersistence", package: "VisualCore"),
        ]),
        .testTarget(name: "GenerativeArtStudioCoreTests", dependencies: ["GenerativeArtStudioCore"]),
    ],
    swiftLanguageModes: [.v6]
)
