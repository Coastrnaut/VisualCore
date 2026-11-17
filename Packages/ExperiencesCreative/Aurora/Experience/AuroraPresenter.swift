// AuroraPresenter — feature 153 (A21-P02) T-A21-203, T-A21-206 (FR-A21-201, FR-A21-203–205, FR-A21-207;
// clarifications Q2–Q4; contracts/experience.md). Draws Aurora through the host only and owns its presentation state:
//
//   - Scene: one `FullScreenShaderScene` with `SkyShader.source` (`aurora-sky.frag`, the `vc/` library through an
//     empty `ShaderBundle`), made and set up in every `setup`: after a context recreation the host calls `setup` again
//     and the scene is rebuilt; the clock and the blend are not GPU objects and stay, so the picture is the same. A
//     resize passes the new size on. A compile or link error throws `SkyShaderError` with the shader's message.
//   - Draw: the target inputs follow the core (`SkyInputs` of the scene with the hue shift); a preset change starts
//     the 1.5 s blend (`SkyBlend`) from the current blend, a control moved during a change retargets it, any other
//     change is immediate, and under Reduce Motion every change is immediate. Each draw advances the `SkyClock` (the
//     scene's speed; held under Reduce Motion) and the blend by the frame's delta, then sets the palette, the
//     parameters of `SkyUniforms` (phase from the clock, the tier's octaves, the core's limit) and `fixedTime` (the
//     clock's time) and draws once. An off-screen still (delta 0) shows the sky as it is. `maxFramesPerSecond` 30.
//   - Chrome: `controlsHidden` (presentation only, not in the snapshot or the digest). `hideControls()` hides the
//     controls; a tap on the sky (a touch that lifts within ``tapSlop`` points of where it landed) or the
//     accessibility action "Show controls" (`showControls()`) brings them back. The tap sends no action, so the
//     canvas has no gesture action (`gestureActions` is empty) and every action is a native control's.
//   - Words: the canvas label names the preset, the colour shift, the speed, the ribbons, the stars, the clouds and
//     the brightness limit. Probes: the bottom-leading corner is the dark sky below the ribbons (`dark`).
//
// No GL call: everything is drawn through VisualCoreRendering's scene.
import Foundation
import AuroraCore
import Observation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// A sky shader that failed to build (feature 153): the shader's message.
struct SkyShaderError: Error, Equatable, CustomStringConvertible {
    /// The compiler's or linker's message, naming `aurora-sky.frag`.
    let message: String

    /// "The Aurora sky shader failed: <message>".
    var description: String { "The Aurora sky shader failed: " + message }
}

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class SkyMirror {
    /// The preset's index in `SkyPresets.all`.
    var preset = 0
    /// The hue shift in turns.
    var hue = 0.0
    /// The speed (0…2).
    var speed = SkyPresets.defaultPreset.scene.speed
    /// The turbulence (0…1).
    var turbulence = SkyPresets.defaultPreset.scene.turbulence
    /// The ribbon count (1…4).
    var ribbons = SkyPresets.defaultPreset.scene.ribbons
    /// The star count (0…400).
    var stars = SkyPresets.defaultPreset.scene.stars
    /// The cloudiness (0…1).
    var clouds = SkyPresets.defaultPreset.scene.cloudiness
    /// The brightness limit (0.2…0.72).
    var limit = SkyCore.defaultLimit
    /// Whether the controls are hidden (presentation only).
    var controlsHidden = false
}

/// Draws Aurora and owns its presentation state (see the file header).
@MainActor
final class AuroraPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = SkyCore

    /// How far, in view points, a finger may move and still tap.
    static let tapSlop = 10.0

    /// Whether Reduce Motion is on: the sky holds still and every change is immediate.
    var reduceMotion: Bool
    /// What the controls show.
    let mirror = SkyMirror()
    /// The port of the shell, for the controls; set by the factory.
    var port: ExperienceActionPort?
    /// The sky drawn; made in `setup`, released in `teardown`.
    private(set) var scene: FullScreenShaderScene?
    /// How many times `setup` made the scene.
    private(set) var setupCount = 0
    /// The sky's animation clock, advanced by frame deltas.
    private(set) var clock = SkyClock()
    /// The change between skies.
    private(set) var blend = SkyBlend(SkyInputs(scene: SkyPresets.defaultPreset.scene, hue: 0))
    /// The last core drawn or followed.
    private(set) var lastCore = SkyCore()
    /// Whether a core was followed yet (the first is shown at once).
    private var followed = false
    /// The uniforms of the last frame drawn; nil before one.
    private(set) var lastUniforms: SkyUniforms?
    /// The touches on the canvas: where each landed, in view points.
    private var touches: [Int: Vec2] = [:]
    /// The frame cap: 30 frames per second (the sky moves slowly).
    var maxFramesPerSecond: Int { 30 }

    /// A presenter; with `reduceMotion` on the sky holds still and changes are immediate.
    init(reduceMotion: Bool = false) {
        self.reduceMotion = reduceMotion
        clock.reducedMotion = reduceMotion
    }

    // MARK: Render scene

    /// Makes and sets up the sky's scene (again after a context recreation); a build error throws
    /// ``SkyShaderError``.
    func setup(_ context: RenderContext) throws {
        scene = nil
        let made = FullScreenShaderScene(fragment: SkyShader.source, fragmentName: SkyShader.fragmentName,
                                         bundle: ShaderBundle(files: [:]))
        try made.setup(context)
        setupCount += 1
        if let message = made.errorMessage {
            made.teardown(context)
            throw SkyShaderError(message: message)
        }
        scene = made
    }

    /// Passes the new drawable size to the scene.
    func resize(_ context: RenderContext) {
        scene?.resize(context)
    }

    /// Follows `core`, advances the clock and the blend by the frame's delta and draws the sky once at `tier`.
    func draw(_ core: SkyCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        follow(core)
        guard let scene else { return }
        clock.reducedMotion = reduceMotion
        clock.speed = core.scene.speed
        clock.advance(by: frame.delta)
        if reduceMotion {
            blend.finish()
        } else {
            blend.advance(by: frame.delta)
        }
        let uniforms = blend.current.uniforms(phase: clock.phase, level: tier, limit: core.limit)
        scene.resize(context)
        scene.palette = uniforms.palette
        scene.parameters = uniforms.shaderParameters
        scene.fixedTime = clock.time
        try scene.render(context, frame: frame)
        lastUniforms = uniforms
    }

    /// Releases the scene's program.
    func teardown(_ context: RenderContext) {
        scene?.teardown(context)
        scene = nil
    }

    // MARK: Chrome

    /// Hides the controls (presentation only; the state does not change).
    func hideControls() {
        if !mirror.controlsHidden { mirror.controlsHidden = true }
    }

    /// Shows the controls again (the tap on the sky and the accessibility action "Show controls").
    func showControls() {
        if mirror.controlsHidden { mirror.controlsHidden = false }
    }

    /// A touch that lifts within ``tapSlop`` points of where it landed shows hidden controls; nothing is sent.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard event.location.isFinite else { return }
        switch event.phase {
        case .began:
            touches[event.id] = event.location
        case .moved:
            if let start = touches[event.id], (event.location - start).length > Self.tapSlop {
                touches[event.id] = nil
            }
        case .ended:
            guard let start = touches.removeValue(forKey: event.id) else { return }
            if (event.location - start).length <= Self.tapSlop { showControls() }
        case .cancelled:
            touches[event.id] = nil
        }
    }

    /// Forgets the touches in progress.
    func cancelPointers() {
        touches = [:]
    }

    /// The actions of the native controls: all eight.
    var nativeActions: Set<String> { Set(SkyCore.actionIDs) }

    // MARK: Words, probes and views

    /// Brings the mirror and the blend's target up to `core` (see the file header).
    func follow(_ core: SkyCore) {
        let target = SkyInputs(scene: core.scene, hue: core.hue)
        if !followed || reduceMotion {
            if blend.to != target || blend.isBlending { blend.jump(to: target) }
        } else if target != blend.to {
            if core.scene.preset != lastCore.scene.preset {
                blend.start(to: target)
            } else {
                blend.retarget(target)
            }
        }
        followed = true
        lastCore = core
        if mirror.preset != core.presetIndex { mirror.preset = core.presetIndex }
        if mirror.hue != core.hue { mirror.hue = core.hue }
        if mirror.speed != core.scene.speed { mirror.speed = core.scene.speed }
        if mirror.turbulence != core.scene.turbulence { mirror.turbulence = core.scene.turbulence }
        if mirror.ribbons != core.scene.ribbons { mirror.ribbons = core.scene.ribbons }
        if mirror.stars != core.scene.stars { mirror.stars = core.scene.stars }
        if mirror.clouds != core.scene.cloudiness { mirror.clouds = core.scene.cloudiness }
        if mirror.limit != core.limit { mirror.limit = core.limit }
    }

    /// The preset's display name of `core`.
    static func presetName(_ core: SkyCore) -> String { SkyPresets.all[core.presetIndex].name }

    /// The canvas label, for example "Aurora, Polar night, colour shift 0°, speed 1.0 times, 3 ribbons, 320 stars,
    /// clouds 10 %, brightness limit 60 %".
    func describe(_ core: SkyCore) -> String {
        follow(core)
        let ribbons = core.scene.ribbons
        return "Aurora, " + Self.presetName(core) + ", colour shift " + AuroraControls.hueText(core.hue)
            + ", speed " + AuroraControls.speedText(core.scene.speed) + ", \(ribbons) "
            + (ribbons == 1 ? "ribbon" : "ribbons") + ", \(core.scene.stars) stars, clouds "
            + AuroraControls.percentText(core.scene.cloudiness) + ", brightness limit "
            + AuroraControls.percentText(core.limit)
    }

    /// One probe at the bottom-leading corner, below the ribbons and the stars: `dark`.
    func probes(_ core: SkyCore) -> [FrameProbe] {
        [FrameProbe(name: "horizon", x: 0, y: 1, expected: FrameColorClass.dark.rawValue)].compactMap { $0 }
    }

    /// The native controls (``AuroraControls``), sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AuroraControls(port: port, mirror: mirror, presenter: self))
    }
}
