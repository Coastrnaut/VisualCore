// TestMode.swift — the deterministic seeded test mode (feature 023 T-A02-506; FR-A02-504, MVP-05; clarifications 2–3,
// research R5). Compiled only under DEBUG || VISUALCORE_AUTOMATION: used by unit tests and the device-campaign
// automation (AppAutomation), never reachable from a shipping build, a URL or remote input.
#if DEBUG || VISUALCORE_AUTOMATION
import CryptoKit
import FluidArtPlaygroundCore
import Foundation
import VisualCoreDiagnostics
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

@MainActor
enum TestMode {
    /// The stress script (contract): 4 pointers, 30 samples per stroke, 1,200 points per second.
    struct Script: Equatable {
        var pointers = 4
        var strokeSamples = 30
        var speed = 1_200.0
    }

    /// The configuration of a test-mode run: the seed for the dye pattern, maximum force and splat cap
    /// (aggressive by design), every other value the default.
    static func configuration(seed: UInt64, base: FluidConfiguration = FluidConfiguration()) -> FluidConfiguration {
        var c = base
        c.seed = seed == 0 ? 1 : seed
        c.forceScale = FluidConfiguration.forceScaleRange.upperBound
        c.maxSplatsPerFrame = FluidConfiguration.splatsPerFrameRange.upperBound
        return c
    }

    /// A playground model in the test mode: fixed 1/60 s steps, the quality tier pinned to Full (nominal thermal
    /// state, no Low Power Mode, a frozen clock) and the seeded synthetic gesture script fed once per stepped frame.
    static func makeModel(seed: UInt64, script: Script = Script(), base: FluidConfiguration = FluidConfiguration(),
                          viewSize: CGSize, forceFallback: Bool = false) -> PlaygroundModel {
        let model = PlaygroundModel(configuration: configuration(seed: seed, base: base), forceFallback: forceFallback)
        if let host = model.host {
            host.view.frame = CGRect(origin: .zero, size: viewSize)
            host.view.layoutIfNeeded()
        }
        configure(model, seed: seed, script: script, viewSize: viewSize)
        return model
    }

    /// Puts an existing model into the test mode (its configuration seed is kept as built).
    static func configure(_ model: PlaygroundModel, seed: UInt64, script: Script = Script(), viewSize: CGSize) {
        model.scene.fixedDelta = 1.0 / 60
        model.deviceState = { (.nominal, false) }
        model.clock = { 0 }
        let gestures = SyntheticGestureScript(seed: seed, pointerCount: script.pointers, strokeSamples: script.strokeSamples,
                                              speed: script.speed, viewSize: Vec2(Double(viewSize.width), Double(viewSize.height)))
        model.beforeDrain = { [weak model] frame in
            guard let model else { return }
            for event in gestures.events(forFrame: frame) { model.paint(event, viewSize: viewSize) }
        }
    }

    /// SHA-256 (hex) of the on-screen picture; nil when nothing can be read back.
    static func digest(_ host: RenderHost) -> String? {
        let pixels = host.readPixels()
        guard !pixels.isEmpty else { return nil }
        return SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
