// swift-tools-version: 6.0
// ExperiencesRound02 — feature 301 (R02-G01-01; Auto-Creator.md section 16). The round-two game experiences of the one
// app (R02-G01 … R02-G25), one group of targets per experience:
//   <Name>Core         the game's pure rules, levels and solver (host-testable: `swift test` runs on macOS)
//   <Name>Experience   the adapter, scene, shaders and controls (added by each game's later features; simulator-tested)
//   ...Tests           their tests
// The app links an experience only at its integration gate X-<code>.
import PackageDescription

let visualCore = "VisualCore"

let package = Package(
    name: "ExperiencesRound02",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [
        // Feature 301 (R02-G01-01): Aurora Loom's rule kernel, a candidate until X-R02-G01.
        .library(name: "AuroraLoomCore", targets: ["AuroraLoomCore"]),
    ],
    dependencies: [
        .package(name: visualCore, path: "../VisualCore"),
    ],
    targets: [
        .target(name: "AuroraLoomCore",
                dependencies: [.product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreMath", package: visualCore)],
                path: "AuroraLoom/Core"),
        .testTarget(name: "AuroraLoomCoreTests",
                    dependencies: ["AuroraLoomCore",
                                   .product(name: "VisualCoreSimulation", package: visualCore),
                                   .product(name: "VisualCoreMath", package: visualCore)],
                    path: "AuroraLoom/CoreTests"),
    ]
)
