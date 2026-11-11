// AppAutomation.swift — the device-campaign automation entry (feature 023 T-A02-510; FR-A02-508, FR-A02-509; spec
// clarifications 1–2). Compiled only under DEBUG || VISUALCORE_AUTOMATION; the only trigger is the launch environment
// (VISUALCORE_AUTORUN=<mode>, VISUALCORE_AUTORUN_SEED, VISUALCORE_AUTORUN_FRAMES) set by simctl/devicectl. The
// shipping Release build contains none of it (scripts/check_release_symbols.py). VisualCore's AutomationView owns the
// one RenderHost; the playground model runs unhosted in the deterministic test mode.
#if DEBUG || VISUALCORE_AUTOMATION
import FluidArtPlaygroundCore
import SwiftUI
import VisualCoreAutomation
import VisualCoreRendering

@MainActor
enum AppAutomation {
    /// The requested mode, if this launch is an automation run.
    static let mode = AutomationRunner.requestedMode()
    /// The script's canvas in points (positions are normalized, so any fixed size gives the same splats).
    static let canvas = CGSize(width: 390, height: 844)
    /// The model of the current run (kept alive for the run's lifetime).
    private(set) static var model: PlaygroundModel?

    /// An unhosted playground model in the test mode with the requested seed.
    static func makeModel(seed: UInt64 = AutomationRunner.requestedSeed()) -> PlaygroundModel {
        let model = PlaygroundModel(configuration: TestMode.configuration(seed: seed), hosted: false)
        TestMode.configure(model, seed: seed, viewSize: canvas)
        return model
    }

    /// The post-run domain check: nil when every field value is finite and in range (FR-A02-507).
    static func check(_ model: PlaygroundModel) -> String? {
        if let error = model.scene.lastError { return "field pass error: \(error)" }
        return model.scene.fieldCheck().firstBad
    }

    /// The note of a passing run: the dye digest and the field extremes.
    static func note(_ model: PlaygroundModel) -> String {
        let check = model.scene.fieldCheck()
        let digest = TestMode.fieldDigest(model.scene) ?? "unavailable"
        return "digest=\(digest) steps=\(model.scene.stepCount) splats=\(model.scene.appliedSplats) "
            + "maxVelocity=\(check.maxVelocity) maxDye=\(check.maxDye) maxPressure=\(check.maxPressure) "
            + "grid=\(model.scene.configuration.gridWidth)x\(model.scene.configuration.gridHeight) "
            + "storage=\(model.scene.precision.map { "\($0)" } ?? "none")"
    }

    /// The full-screen run: AutomationView hosts the model's effect scene and runs the mode, then the check.
    @ViewBuilder
    static func root(mode: String) -> some View {
        let model = Self.model ?? makeModel()
        let _ = (Self.model = model)
        AutomationView(mode: mode, bundleID: Bundle.main.bundleIdentifier ?? "dev.visualcore.FluidArtPlayground",
                       makeScene: { model.effects },
                       postRunCheck: { _ in check(model) },
                       checkNote: { _ in note(model) })
            .ignoresSafeArea()
            .accessibilityIdentifier("fap.automation")
    }
}
#endif
