// swift-tools-version: 6.0
// ExperiencesCreative — feature 193 (UA-F07; migration-plan.md section 2.1; research R1). The creative experiences of
// the one app, one group of targets per experience, merged from the standalone apps' per-app packages:
//   <Name>Core         the app's GPU-free domain, unchanged (its tests pass unchanged before and after the move)
//   <Name>Experience   the app's SwiftUI and scene sources, the adapter (core, manifest, presenter, controls) and
//                      the factory the one app's registry calls; shaders are its resources
//   ...Tests           the Core tests, and the experience tests (the app's unit tests, the adapter's tests)
// The Experience targets need UIKit and the GPU, so the package is tested with xcodebuild on the iOS simulators
// (`python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package`).
import PackageDescription

let visualCore = "VisualCore"
let rendering = "VisualCoreRendering"

let package = Package(
    name: "ExperiencesCreative",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "GenerativeArtStudioExperience", targets: ["GenerativeArtStudioExperience"]),
        .library(name: "FluidArtPlaygroundExperience", targets: ["FluidArtPlaygroundExperience"]),
    ],
    dependencies: [
        .package(name: visualCore, path: "../VisualCore"),
        .package(name: rendering, path: "../VisualCoreRendering"),
    ],
    targets: [
        // A01 Generative Art Studio.
        .target(name: "GenerativeArtStudioCore",
                dependencies: [.product(name: "VisualCoreParameters", package: visualCore),
                               .product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreMath", package: visualCore),
                               .product(name: "VisualCorePersistence", package: visualCore),
                               .product(name: "VisualCoreScenes", package: visualCore)],
                path: "GenerativeArtStudio/Core"),
        .testTarget(name: "GenerativeArtStudioCoreTests",
                    dependencies: ["GenerativeArtStudioCore", .product(name: "VisualCoreScenes", package: visualCore)],
                    path: "GenerativeArtStudio/CoreTests",
                    exclude: ["Fixtures"]),
        .target(name: "GenerativeArtStudioExperience",
                dependencies: ["GenerativeArtStudioCore",
                               .product(name: "VisualCoreParameters", package: visualCore),
                               .product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreMath", package: visualCore),
                               .product(name: "VisualCoreScenes", package: visualCore),
                               .product(name: "VisualCorePersistence", package: visualCore),
                               .product(name: "VisualCoreEffectsGraph", package: visualCore),
                               .product(name: "VisualCoreExperience", package: visualCore),
                               .product(name: "VisualCoreDiagnostics", package: visualCore),
                               .product(name: "VisualCoreRendering", package: rendering),
                               .product(name: "VisualCoreUI", package: rendering),
                               .product(name: "VisualCoreEffects", package: rendering),
                               .product(name: "VisualCoreExperienceHost", package: rendering)],
                path: "GenerativeArtStudio",
                exclude: ["Core", "CoreTests", "ExperienceTests", "scenario-manifest.json"],
                sources: ["Experience"],
                resources: [.copy("Shaders")]),
        .testTarget(name: "GenerativeArtStudioExperienceTests",
                    dependencies: ["GenerativeArtStudioExperience", "GenerativeArtStudioCore",
                                   .product(name: "VisualCoreParameters", package: visualCore),
                                   .product(name: "VisualCoreSimulation", package: visualCore),
                                   .product(name: "VisualCoreMath", package: visualCore),
                                   .product(name: "VisualCoreScenes", package: visualCore),
                                   .product(name: "VisualCorePersistence", package: visualCore),
                                   .product(name: "VisualCoreExperience", package: visualCore),
                                   .product(name: "VisualCoreDiagnostics", package: visualCore),
                                   .product(name: "VisualCoreTestSupport", package: visualCore),
                                   .product(name: "VisualCoreRendering", package: rendering),
                                   .product(name: "VisualCoreUI", package: rendering),
                                   .product(name: "VisualCoreEffects", package: rendering),
                                   .product(name: "VisualCoreExperienceHost", package: rendering)],
                    path: "GenerativeArtStudio/ExperienceTests"),
        // A02 Fluid Art Playground.
        .target(name: "FluidArtPlaygroundCore",
                dependencies: [.product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreScenes", package: visualCore)],
                path: "FluidArtPlayground/Core"),
        .testTarget(name: "FluidArtPlaygroundCoreTests",
                    dependencies: ["FluidArtPlaygroundCore", .product(name: "VisualCoreSimulation", package: visualCore),
                                   .product(name: "VisualCoreScenes", package: visualCore)],
                    path: "FluidArtPlayground/CoreTests"),
        .target(name: "FluidArtPlaygroundExperience",
                dependencies: ["FluidArtPlaygroundCore",
                               .product(name: "VisualCorePersistence", package: visualCore),
                               .product(name: "VisualCoreSimulation", package: visualCore),
                               .product(name: "VisualCoreScenes", package: visualCore),
                               .product(name: "VisualCoreMath", package: visualCore),
                               .product(name: "VisualCoreDiagnostics", package: visualCore),
                               .product(name: "VisualCoreEffectsGraph", package: visualCore),
                               .product(name: "VisualCoreExperience", package: visualCore),
                               .product(name: "VisualCoreRendering", package: rendering),
                               .product(name: "VisualCoreUI", package: rendering),
                               .product(name: "VisualCoreEffects", package: rendering),
                               .product(name: "VisualCoreExperienceHost", package: rendering),
                               .product(name: "VisualCoreAutomation", package: rendering)],
                path: "FluidArtPlayground/Experience"),
        .testTarget(name: "FluidArtPlaygroundExperienceTests",
                    dependencies: ["FluidArtPlaygroundExperience", "FluidArtPlaygroundCore",
                                   .product(name: "VisualCorePersistence", package: visualCore),
                                   .product(name: "VisualCoreSimulation", package: visualCore),
                                   .product(name: "VisualCoreScenes", package: visualCore),
                                   .product(name: "VisualCoreMath", package: visualCore),
                                   .product(name: "VisualCoreDiagnostics", package: visualCore),
                                   .product(name: "VisualCoreEffectsGraph", package: visualCore),
                                   .product(name: "VisualCoreExperience", package: visualCore),
                                   .product(name: "VisualCoreTestSupport", package: visualCore),
                                   .product(name: "VisualCoreRendering", package: rendering),
                                   .product(name: "VisualCoreUI", package: rendering),
                                   .product(name: "VisualCoreEffects", package: rendering),
                                   .product(name: "VisualCoreExperienceHost", package: rendering),
                                   .product(name: "VisualCoreAutomation", package: rendering)],
                    path: "FluidArtPlayground/ExperienceTests"),
    ],
    swiftLanguageModes: [.v6]
)
