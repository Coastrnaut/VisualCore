// swift-tools-version: 6.0
// GardenKit — the host-testable domain model of Lumen Garden, the second VisualCore consumer (feature 009; FR-F804).
// Depends only on pure VisualCore modules, so `swift test` runs on the Mac.
import PackageDescription

let package = Package(
    name: "GardenKit",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "GardenKit", targets: ["GardenKit"])],
    dependencies: [.package(path: "../../../Packages/VisualCore")],
    targets: [
        .target(name: "GardenKit", dependencies: [
            .product(name: "VisualCoreMath", package: "VisualCore"),
            .product(name: "VisualCoreSimulation", package: "VisualCore"),
        ]),
        .testTarget(name: "GardenKitTests", dependencies: ["GardenKit"]),
    ],
    swiftLanguageModes: [.v6]
)
