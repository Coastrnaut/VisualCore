// GenerativeArtPresenter — feature 193 (UA-F07) T-U07-009 (FR-U07-001 to FR-U07-004, FR-U07-010; research R1,
// data-model section 2). Draws the core of Generative Art Studio with the app's own scenes (`ArtSceneFactory`,
// `ParticlesArtScene`) at the core's time, behind the app's Reduce-Flashing limiter (`EffectScene`), and builds the
// controls. It never steps the time: the core advances it in fixed steps.
//
// Differences from the standalone app's `SceneModel` (FR-U07-003):
//   1. The time comes from the core (`fixedTime`), not from a `SceneClock` advanced by the frame delta.
//   2. One canvas scene switches between the four families; the standalone app builds one scene per screen.
//   3. Shaders load from this framework's bundle, not from `Bundle.main`.
//   4. Reduce Flashing is the person's stored choice handed over at open; it applies to the next open.
import Foundation
import GenerativeArtStudioAdapterCore
import GenerativeArtStudioCore
import SwiftUI
import UIKit
import VisualCoreEffects
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters
import VisualCoreRendering

/// The latest core the presenter saw, for the controls: refreshed with every description of the state, which the
/// shell asks for after every accepted action.
@MainActor
@Observable
final class GenerativeArtMirror {
    /// The current state; nil before the first description.
    var core: GenerativeArtCore?
}

/// A render scene that shows one composition at one time and switches its inner scene when the family changes.
@MainActor
final class ArtCanvasScene: RenderScene {
    /// Where the shaders are.
    let bundle: ShaderBundle
    /// Points → pixels factor of the screen, for the particle sizes.
    let displayScale: Double
    /// The scene of the current family; nil before the first frame and after a teardown.
    private(set) var inner: ArtScene?
    /// The family of `inner`.
    private var family: SceneFamilyID?
    /// The document last applied to `inner`.
    private var applied: ArtDocument?
    /// The composition and the time to show at the next frame.
    private var document: ArtDocument?
    private var time = 0.0

    init(bundle: ShaderBundle, displayScale: Double) {
        self.bundle = bundle
        self.displayScale = displayScale
    }

    /// Sets what the next frame shows.
    func show(_ document: ArtDocument, time: Double) {
        self.document = document
        self.time = time
    }

    /// The first shader diagnostic of the current scene, if any.
    var errorMessage: String? { inner?.errorMessage }

    func setup(_ context: RenderContext) throws {
        if let inner { try inner.setup(context) }
    }

    func resize(_ context: RenderContext) {
        inner?.resize(context)
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let document else { return }
        let wanted = document.family?.id ?? .gradientNoise
        if inner == nil || family != wanted {
            inner?.teardown(context)
            inner = nil
            let scene = ArtSceneFactory.makeScene(for: document, bundle: bundle)
            scene.displayScale = displayScale
            try scene.setup(context)
            inner = scene
            family = wanted
            applied = document
        } else if applied != document, let inner {
            // Only a changed composition is applied: a particle scene replays from the start after an apply.
            ArtSceneFactory.apply(document, to: inner)
            applied = document
        }
        guard let inner else { return }
        inner.fixedTime = time
        try inner.render(context, frame: frame)
    }

    func teardown(_ context: RenderContext) {
        inner?.teardown(context)
        inner = nil
        family = nil
        applied = nil
    }
}

/// The presenter of Generative Art Studio.
@MainActor
final class GenerativeArtPresenter: ExperiencePresenter {
    typealias Core = GenerativeArtCore

    /// The experience's id; the prefix of its accessibility identifiers.
    let experienceID: ExperienceID
    /// The experience's own storage: the saved compositions.
    let storage: ExperienceStorage
    /// Whether Reduce Motion is in effect at open; the controls then set the rate to 0.5.
    let reduceMotion: Bool
    /// What the controls read.
    let mirror = GenerativeArtMirror()
    /// The saved compositions.
    let library: GenerativeArtLibrary
    private let canvas: ArtCanvasScene
    private let effect: EffectScene

    /// The framework's shaders.
    static var shaders: ShaderBundle {
        ShaderBundle(bundle: Bundle(for: GenerativeArtPresenter.self), subdirectory: "Shaders")
    }

    init(experienceID: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool, reduceFlashing: Bool,
         displayScale: Double) {
        self.experienceID = experienceID
        self.storage = storage
        self.reduceMotion = reduceMotion
        library = GenerativeArtLibrary(storage: storage)
        canvas = ArtCanvasScene(bundle: Self.shaders, displayScale: displayScale)
        effect = EffectScene(content: canvas, graph: SceneModel.limiterGraph)
        effect.reduceFlashing = reduceFlashing
        effect.bypassEffects = !reduceFlashing
    }

    func setup(_ context: RenderContext) throws {
        try effect.setup(context)
    }

    func resize(_ context: RenderContext) {
        effect.resize(context)
    }

    func draw(_ core: GenerativeArtCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        canvas.show(core.document, time: core.time)
        try effect.render(context, frame: frame)
    }

    func teardown(_ context: RenderContext) {
        effect.teardown(context)
    }

    func describe(_ core: GenerativeArtCore) -> String {
        mirror.core = core
        return CanvasDescription(document: core.document, isPlaying: core.playing).text
    }

    /// The upper-left corner of the Particles family while no particle can reach it: the background there is a
    /// palette colour over a known range, scaled by a known factor (`particles-background.frag`), so its colour class
    /// follows from the palette when every colour of that range has the same class. Particles start at the bottom
    /// centre at most 500 pt/s fast (the schema's limit) and 24 pt large, so before `GenerativeArtProbe.maxTime`
    /// none is nearer than 149 pt to it; the corner lies farther in a canvas at least 150 pt tall. Other states
    /// declare none.
    func probes(_ core: GenerativeArtCore) -> [FrameProbe] {
        guard core.family.id == .particles, core.time < GenerativeArtProbe.maxTime,
              let palette = FamilyCatalog.palette(core.document.paletteID),
              let expected = GenerativeArtProbe.particleCornerClass(palette: palette) else { return [] }
        return [FrameProbe(name: "background-corner", x: GenerativeArtProbe.cornerX, y: GenerativeArtProbe.cornerY,
                           expected: expected.rawValue)].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(GenerativeArtControls(port: port, mirror: mirror, library: library, experienceID: experienceID,
                                      reduceMotion: reduceMotion))
    }
}

/// The colour class of the Particles background corner, derived on the CPU from the palette.
enum GenerativeArtProbe {
    /// The probe point, measured from the top left (FrameChecks' convention).
    static let cornerX = 0.03
    static let cornerY = 0.03
    /// The time before which no particle can reach the corner.
    static let maxTime = 0.25

    /// The class every colour of the corner can take, or nil when two of them could differ. The shader's colour
    /// is `palette(0.04 + 0.16 (1 − v) + 0.05 n) × (0.35 + 0.4 v)` with `v` the height from the bottom and `n` noise
    /// in 0…1; the probe covers the pixel's rows and every noise value, and each channel is moved by ±4 levels to
    /// stay clear of a class boundary.
    static func particleCornerClass(palette: Palette) -> FrameColorClass? {
        let v = 1 - cornerY
        let base = 0.04 + 0.16 * (1 - v)
        var found: FrameColorClass?
        for vStep in 0...4 {
            let height = v - 0.01 + 0.005 * Double(vStep)
            let factor = 0.35 + 0.4 * height
            for nStep in 0...10 {
                let t = base + 0.005 * Double(vStep - 2) * 0.16 + 0.05 * Double(nStep) / 10
                let linear = palette.sample(t) * factor
                let srgb = [linear.x, linear.y, linear.z].map(encode)
                for dr in [-4, 0, 4] {
                    for dg in [-4, 0, 4] {
                        for db in [-4, 0, 4] {
                            let c = FrameChecks.classify(r: level(srgb[0], dr), g: level(srgb[1], dg),
                                                         b: level(srgb[2], db))
                            if found == nil { found = c } else if found != c { return nil }
                        }
                    }
                }
            }
        }
        return found
    }

    /// `vc_srgbEncode` of one channel.
    static func encode(_ linear: Double) -> Double {
        let c = min(max(linear, 0), 1)
        return c < 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    private static func level(_ value: Double, _ offset: Int) -> UInt8 {
        UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded()) + offset)
    }
}
