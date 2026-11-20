// swift-tools-version: 6.0
// ExperiencesRound02 — feature 301 (R02-G01-01; Auto-Creator.md section 16). The round-two game experiences of the one
// app (R02-G01 … R02-G25), one group of targets per experience:
//   <Name>Core         the game's pure rules, levels and solver (host-testable: `swift test` runs on macOS)
//   <Name>Experience   the adapter, scene, shaders and controls (added by each game's later features; simulator-tested)
//   ...Tests           their tests
// The app links an experience only at its integration gate X-<code>.
import PackageDescription

let visualCore = "VisualCore"
let rendering = "VisualCoreRendering"

let package = Package(
    name: "ExperiencesRound02",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [
        // Feature 301 (R02-G01-01): Aurora Loom's rule kernel, a candidate until X-R02-G01.
        .library(name: "AuroraLoomCore", targets: ["AuroraLoomCore"]),
        // Feature 303 (R02-G01-03): Aurora Loom's experience (iOS only; a registered candidate until X-R02-G01).
        .library(name: "AuroraLoomExperience", targets: ["AuroraLoomExperience"]),
        // Feature 311 (R02-G02-01): Lissajous Labyrinth's rule kernel, a candidate until X-R02-G02.
        .library(name: "LissajousLabyrinthCore", targets: ["LissajousLabyrinthCore"]),
        // Feature 313 (R02-G02-03): Lissajous Labyrinth's experience (iOS only; a registered candidate until X-R02-G02).
        .library(name: "LissajousLabyrinthExperience", targets: ["LissajousLabyrinthExperience"]),
    ],
    dependencies: [
        .package(name: visualCore, path: "../VisualCore"),
        .package(name: rendering, path: "../VisualCoreRendering"),
    ],
    targets: [
        .target(name: "AuroraLoomCore",
                dependencies: [.product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreMath", package: visualCore),
                               // Feature 303 (R02-G01-03): ribbon meshes and the experience adapter, host-testable.
                               .product(name: "VisualCoreScenes", package: visualCore),
                               .product(name: "VisualCoreExperience", package: visualCore),
                               .product(name: "VisualCoreDiagnostics", package: visualCore),
                               .product(name: "VisualCorePersistence", package: visualCore),
                               // Feature 306 (R02-G01-06): the ambient recipe (pure, host-testable).
                               .product(name: "VisualCoreAudioDSP", package: visualCore)],
                path: "AuroraLoom/Core"),
        .testTarget(name: "AuroraLoomCoreTests",
                    dependencies: ["AuroraLoomCore",
                                   .product(name: "VisualCoreSimulation", package: visualCore),
                                   .product(name: "VisualCoreMath", package: visualCore),
                                   .product(name: "VisualCoreScenes", package: visualCore),
                                   .product(name: "VisualCoreExperience", package: visualCore),
                                   .product(name: "VisualCoreDiagnostics", package: visualCore),
                                   .product(name: "VisualCoreAudioDSP", package: visualCore)],
                    path: "AuroraLoom/CoreTests"),
        // The Experience targets build for iOS only: their rendering dependencies are conditional and their sources sit in
        // `#if os(iOS)`, so `swift test` on the macOS host still builds and runs the Cores (feature 303, research R1).
        .target(name: "AuroraLoomExperience",
                dependencies: ["AuroraLoomCore",
                               .product(name: "VisualCoreMath", package: visualCore),
                               .product(name: "VisualCoreScenes", package: visualCore),
                               .product(name: "VisualCoreExperience", package: visualCore),
                               .product(name: "VisualCoreRendering", package: rendering, condition: .when(platforms: [.iOS])),
                               .product(name: "VisualCoreExperienceHost", package: rendering, condition: .when(platforms: [.iOS])),
                               // Feature 306 (R02-G01-06): the ambient loop, haptics and announcements.
                               .product(name: "VisualCoreAudioDSP", package: visualCore),
                               .product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreAudio", package: rendering, condition: .when(platforms: [.iOS])),
                               .product(name: "VisualCoreUI", package: rendering, condition: .when(platforms: [.iOS]))],
                path: "AuroraLoom/Experience"),
        .testTarget(name: "AuroraLoomExperienceTests",
                    dependencies: ["AuroraLoomExperience", "AuroraLoomCore",
                                   .product(name: "VisualCoreMath", package: visualCore),
                                   .product(name: "VisualCoreScenes", package: visualCore),
                                   .product(name: "VisualCoreExperience", package: visualCore),
                                   .product(name: "VisualCoreRendering", package: rendering, condition: .when(platforms: [.iOS])),
                                   .product(name: "VisualCoreExperienceHost", package: rendering, condition: .when(platforms: [.iOS])),
                                   .product(name: "VisualCoreSimulation", package: visualCore),
                                   .product(name: "VisualCoreAudioDSP", package: visualCore),
                                   .product(name: "VisualCoreUI", package: rendering, condition: .when(platforms: [.iOS]))],
                    path: "AuroraLoom/ExperienceTests"),
        .target(name: "LissajousLabyrinthCore",
                dependencies: [.product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreMath", package: visualCore),
                               // Feature 313 (R02-G02-03): meshes and the experience adapter, host-testable.
                               .product(name: "VisualCoreScenes", package: visualCore),
                               .product(name: "VisualCoreExperience", package: visualCore),
                               .product(name: "VisualCoreDiagnostics", package: visualCore),
                               .product(name: "VisualCorePersistence", package: visualCore)],
                path: "LissajousLabyrinth/Core"),
        .testTarget(name: "LissajousLabyrinthCoreTests",
                    dependencies: ["LissajousLabyrinthCore",
                                   .product(name: "VisualCoreSimulation", package: visualCore),
                                   .product(name: "VisualCoreMath", package: visualCore),
                                   .product(name: "VisualCoreScenes", package: visualCore),
                                   .product(name: "VisualCoreExperience", package: visualCore),
                                   .product(name: "VisualCoreDiagnostics", package: visualCore)],
                    path: "LissajousLabyrinth/CoreTests"),
        .target(name: "LissajousLabyrinthExperience",
                dependencies: ["LissajousLabyrinthCore",
                               .product(name: "VisualCoreMath", package: visualCore),
                               .product(name: "VisualCoreScenes", package: visualCore),
                               .product(name: "VisualCoreExperience", package: visualCore),
                               .product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreRendering", package: rendering, condition: .when(platforms: [.iOS])),
                               .product(name: "VisualCoreExperienceHost", package: rendering, condition: .when(platforms: [.iOS])),
                               .product(name: "VisualCoreUI", package: rendering, condition: .when(platforms: [.iOS]))],
                path: "LissajousLabyrinth/Experience"),
        .testTarget(name: "LissajousLabyrinthExperienceTests",
                    dependencies: ["LissajousLabyrinthExperience", "LissajousLabyrinthCore",
                                   .product(name: "VisualCoreMath", package: visualCore),
                                   .product(name: "VisualCoreScenes", package: visualCore),
                                   .product(name: "VisualCoreExperience", package: visualCore),
                                   .product(name: "VisualCoreSimulation", package: visualCore),
                                   .product(name: "VisualCoreDiagnostics", package: visualCore),
                                   .product(name: "VisualCoreRendering", package: rendering, condition: .when(platforms: [.iOS])),
                                   .product(name: "VisualCoreExperienceHost", package: rendering, condition: .when(platforms: [.iOS])),
                                   .product(name: "VisualCoreUI", package: rendering, condition: .when(platforms: [.iOS]))],
                    path: "LissajousLabyrinth/ExperienceTests"),
    ]
)
