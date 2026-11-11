// swift-tools-version: 6.0
// FractalExplorerCore — the app's GPU-free domain (feature 026 A03-P01): the escape-time iteration with its CPU
// reference, the validated fractal state, mode explanations and the bounded CPU preview. Host-testable with
// `swift test`. The generic plane viewport lives in VisualCoreMath (constitution Principle II, A03 reuse rule); this
// package holds only fractal-specific rules.
import PackageDescription

let package = Package(
    name: "FractalExplorerCore",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "FractalExplorerCore", targets: ["FractalExplorerCore"])],
    dependencies: [.package(name: "VisualCore", path: "../../../Packages/VisualCore")],
    targets: [
        .target(name: "FractalExplorerCore", dependencies: [.product(name: "VisualCoreMath", package: "VisualCore")]),
        .testTarget(name: "FractalExplorerCoreTests", dependencies: ["FractalExplorerCore",
                                                                    .product(name: "VisualCoreMath", package: "VisualCore")]),
    ],
    swiftLanguageModes: [.v6]
)
