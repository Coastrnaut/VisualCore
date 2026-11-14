// OdysseyPresenter — feature 054 (A07-P01) T-A07-104 (FR-A07-121, FR-A07-122). Draws Audio Odyssey through the host
// only (the host's context and resource registry, VisualCore's `DepthMeshPass` and `MeshRenderer`; no context of its
// own) and owns everything that is not state: the rail of the current seed, the piece meshes of the current window and
// the origin rebase.
//
//   - Rail: `JourneyRail.make(seed:)` for the journey's seed, rebuilt when the seed changes (a new journey).
//   - Pieces: one `MeshRenderer` per piece of the window `WorldPieces.indices(around: distance)` (2 behind, 8 ahead)
//     of the current world, made lazily in `draw` (the host's context is current there) and released as soon as they
//     leave the window; a change of world or seed releases every piece; `teardown` releases everything (it runs again
//     before a new `setup` after a context loss).
//   - Camera: `rail.orbitCamera(at: distance, fovY: 60°, near: 0.1, far: 120)` moved sideways along the pose's right
//     axis by the flight's sway (0 under Reduce Motion), so the horizon stays level (no roll).
//   - Precision: the origin rebase follows the camera's world position each frame; pieces are generated in world
//     coordinates and drawn with the model matrix `translation(−origin)` and the camera shifted by `−origin`, so what is
//     drawn near the camera stays small in single precision.
//   - Colours: one per world (tunnel teal, landscape green-brown, star corridor pale blue-white) lit by a headlight
//     above and behind the camera, on a dark clear colour.
//   - Reduce Motion: from the factory; mirrored into the core with `comfort.reduce-motion` (see OdysseyCore) once the
//     experience is active, after the current frame, never from inside it.
//   - Leaving: a suspended experience runs no steps, so the flight holds still while away and resumes on return.
import Foundation
import SwiftUI
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the display fields of the journey, updated only when one of them changes (not every frame).
@MainActor
@Observable
final class OdysseyMirror {
    /// The world shown; nil before the first description.
    var world: JourneyWorld?
    /// The chosen speed.
    var speedChoice: SpeedChoice = .medium
    /// Whether the flight is paused.
    var paused = false
}

/// The error of a draw failed on purpose through `OdysseyPresenter.failNextDraw`: it lets a test prove the
/// host-to-session failure path.
enum OdysseyDrawError: Error, Equatable {
    /// The draw was failed by the test seam.
    case injected
}

/// The presenter of Audio Odyssey.
@MainActor
final class OdysseyPresenter: ExperiencePresenter {
    typealias Core = OdysseyCore

    /// The vertical field of view (60°).
    nonisolated static let fovY = 60.0 * Double.pi / 180
    /// The near and far clipping distances.
    nonisolated static let near = 0.1, far = 120.0
    /// The clear colour (dark blue-black).
    nonisolated static let background = Vec4(0.02, 0.02, 0.05, 1)
    /// The ambient share of the lighting.
    nonisolated static let ambient = 0.35

    /// The colour of `world`: tunnel teal, landscape green-brown, star corridor pale blue-white.
    nonisolated static func color(_ world: JourneyWorld) -> Vec4 {
        switch world {
        case .tunnel: Vec4(0.1, 0.65, 0.6, 1)
        case .landscape: Vec4(0.45, 0.5, 0.22, 1)
        case .starCorridor: Vec4(0.82, 0.88, 1.0, 1)
        }
    }

    /// The camera at `distance` along `rail`, moved sideways by `sway` along the pose's right axis and shifted by
    /// `-origin` (drawing coordinates).
    nonisolated static func camera(rail: CameraRail, distance: Double, sway: Double, origin: Vec3) -> OrbitCamera {
        var camera = rail.orbitCamera(at: distance, fovY: fovY, near: near, far: far)
        let pose = rail.pose(at: distance)
        camera.target = camera.target + pose.right * sway - origin
        return camera
    }

    /// The world position of the eye at `distance` along `rail` with the sideways `sway`.
    nonisolated static func eye(rail: CameraRail, distance: Double, sway: Double) -> Vec3 {
        let pose = rail.pose(at: distance)
        return pose.position + pose.right * sway
    }

    let experienceID: ExperienceID
    let mirror = OdysseyMirror()
    /// Whether the system Reduce Motion setting is on (from the factory).
    let reduceMotion: Bool
    /// The port of the shell, set by `AudioOdysseyExperience.make`; the presenter sends the Reduce Motion mirror
    /// through it.
    weak var port: ExperienceActionPort?

    /// The rail of `railSeed`.
    private(set) var rail: CameraRail?
    private(set) var railSeed: UInt64?
    /// The renderers of the cached pieces by piece index, all of `cacheWorld` and `cacheSeed`.
    private(set) var pieces: [Int: MeshRenderer] = [:]
    private var cacheWorld: JourneyWorld?
    private var cacheSeed: UInt64?
    private var pass: DepthMeshPass?
    /// The floating origin of the drawing coordinates.
    private(set) var rebase = OriginRebase()
    private var mirrorScheduled = false

    /// True between `setup` and `teardown`.
    private(set) var isLive = false
    /// The camera of the last frame (drawing coordinates).
    private(set) var lastCamera: OrbitCamera?
    /// The world drawn by the last frame.
    private(set) var lastWorld: JourneyWorld?
    /// The piece indices drawn by the last frame.
    private(set) var lastIndices: ClosedRange<Int>?
    /// The number of piece renderers made since the presenter was created (tests read it).
    private(set) var piecesMade = 0
    /// Set only by tests; the next draw throws `OdysseyDrawError.injected` and clears the flag.
    var failNextDraw = false

    init(experienceID: ExperienceID, reduceMotion: Bool = false) {
        self.experienceID = experienceID
        self.reduceMotion = reduceMotion
    }

    // MARK: Render scene

    func setup(_ context: RenderContext) throws {
        let pass = DepthMeshPass(registry: context.resources)
        pass.clearColor = Self.background
        self.pass = pass
        isLive = true
    }

    func draw(_ core: OdysseyCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw OdysseyDrawError.injected
        }
        updateDisplay(core)
        scheduleMirrorIfNeeded(core)
        let state = core.state
        let path = makeRail(for: state.seed)
        if cacheWorld != state.world || cacheSeed != state.seed {
            releasePieces()
            cacheWorld = state.world
            cacheSeed = state.seed
        }
        let window = WorldPieces.indices(around: state.distance)
        for index in Array(pieces.keys) where !window.contains(index) {
            pieces[index]?.release()
            pieces[index] = nil
        }
        let sway = core.flight.sway(limits: core.limits)
        rebase.update(camera: Self.eye(rail: path, distance: state.distance, sway: sway))
        let origin = rebase.origin
        let camera = Self.camera(rail: path, distance: state.distance, sway: sway, origin: origin)
        let pose = path.pose(at: state.distance)
        let light = (pose.up * 0.7 - pose.direction * 0.7).normalized
        let model = Mat4.translation(-origin)
        let color = Self.color(state.world)
        var items: [DepthMeshPass.Item] = []
        items.reserveCapacity(window.count)
        for index in window {
            let renderer: MeshRenderer
            if let cached = pieces[index] {
                renderer = cached
            } else {
                renderer = try MeshRenderer(mesh: WorldPieces.piece(state.world, index: index, rail: path,
                                                                    seed: state.seed),
                                            registry: context.resources)
                renderer.ambient = Self.ambient
                pieces[index] = renderer
                piecesMade += 1
            }
            renderer.lightDirection = light
            items.append(DepthMeshPass.Item(renderer: renderer, model: model, color: color))
        }
        if pass == nil {
            let made = DepthMeshPass(registry: context.resources)
            made.clearColor = Self.background
            pass = made
        }
        try pass?.draw(items, camera: camera, context: context)
        lastCamera = camera
        lastWorld = state.world
        lastIndices = window
    }

    func teardown(_ context: RenderContext) {
        releasePieces()
        cacheWorld = nil
        cacheSeed = nil
        pass?.release()
        pass = nil
        isLive = false
    }

    /// The rail of `seed`, made once per seed.
    private func makeRail(for seed: UInt64) -> CameraRail {
        if let rail, railSeed == seed { return rail }
        let made = JourneyRail.make(seed: seed)
        rail = made
        railSeed = seed
        return made
    }

    /// Releases every piece renderer.
    private func releasePieces() {
        for renderer in pieces.values { renderer.release() }
        pieces = [:]
    }

    /// Mirrors the factory's Reduce Motion into the core after the current frame when they differ (once per change).
    private func scheduleMirrorIfNeeded(_ core: OdysseyCore) {
        guard core.reduceMotion != reduceMotion, !mirrorScheduled, port != nil else { return }
        mirrorScheduled = true
        let value: Double = reduceMotion ? 1 : 0
        Task { @MainActor [weak self] in
            guard let self else { return }
            mirrorScheduled = false
            port?.send("comfort.reduce-motion", [value])
        }
    }

    // MARK: Description

    /// Records the display fields when one of them changed.
    private func updateDisplay(_ core: OdysseyCore) {
        let state = core.state
        if mirror.world != state.world { mirror.world = state.world }
        if mirror.speedChoice != state.speedChoice { mirror.speedChoice = state.speedChoice }
        if mirror.paused != state.paused { mirror.paused = state.paused }
    }

    /// "Tunnel, medium speed, flying." or "…, paused." (world, speed choice and pause in words).
    static func description(of state: JourneyState) -> String {
        "\(state.world.displayName), \(state.speedChoice.displayName.lowercased()) speed, "
            + (state.paused ? "paused." : "flying.")
    }

    /// "Audio Odyssey: Tunnel, medium speed, flying." Also mirrors Reduce Motion when needed.
    func describe(_ core: OdysseyCore) -> String {
        updateDisplay(core)
        scheduleMirrorIfNeeded(core)
        return "Audio Odyssey: " + Self.description(of: core.state)
    }

    /// The tunnel floor below the view centre (lit teal, class `other`) and, in the landscape, the sky above the view
    /// centre (`dark`); the star corridor's sparse stars and thin rings give no point whose class is certain.
    func probes(_ core: OdysseyCore) -> [FrameProbe] {
        switch core.state.world {
        case .tunnel: [FrameProbe(name: "tunnel-floor", x: 0.5, y: 0.96, expected: "other")].compactMap { $0 }
        case .landscape: [FrameProbe(name: "sky", x: 0.5, y: 0.04, expected: "dark")].compactMap { $0 }
        case .starCorridor: []
        }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(OdysseyControls(port: port, mirror: mirror))
    }

    /// Every action has a native control; the Reduce Motion mirror is sent by the presenter from the system setting.
    var nativeActions: Set<String> {
        ["world.select", "speed.select", "flight.pause", "flight.resume", "journey.reseed", "comfort.reduce-motion"]
    }
}
