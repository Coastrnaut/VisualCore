// OdysseyPresenter — feature 054 (A07-P01) T-A07-104 (FR-A07-121, FR-A07-122). Draws Audio Odyssey through the host
// only (the host's context and resource registry, VisualCore's `DepthMeshPass` and `MeshRenderer`; no context of its
// own) and owns everything that is not state: the rail of the current seed, the piece meshes of the current window and
// the origin rebase.
//
//   - Rail: `JourneyRail.make(seed:)` for the journey's seed, rebuilt when the seed changes (a new journey).
//   - Pieces (landscape, star corridor): one `MeshRenderer` per piece of the window `WorldPieces.indices(around:
//     distance)` (2 behind, 8 ahead) of the current world, made lazily in `draw` (the host's context is current there)
//     and released as soon as they leave the window; a change of world or seed releases every piece; `teardown`
//     releases everything (it runs again before a new `setup` after a context loss).
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
//
// Feature 055 (A07-P02) T-A07-205 (FR-A07-210, FR-A07-211, FR-A07-220, FR-A07-221, FR-A07-230; clarifications 1–5):
//   - Streaming tunnel: the tunnel's pieces stream through `TunnelStream` (VisualCore's `SegmentWindow` with 2 behind,
//     8 ahead, capacity 12, and a `SlotPool` of 12 renderer slots): at most 2 pieces are built per frame, nearest
//     first, retired pieces release their renderer's GPU resources at once and their slot takes the next piece's new
//     renderer (a renderer's mesh is fixed, so a reused slot gets a new one). A change of world or seed empties the
//     stream. The landscape and the star corridor keep the fixed window of A07-P01.
//   - Drawing: every world is drawn with `DepthMeshPass.draw(_:view:projection:fog:context:)` with the camera's view
//     and projection and linear fog from 40 to 110 units toward the clear colour, so the far end of the window
//     dissolves into the background instead of popping in.
//   - Audio: the presenter owns the active `AudioSource` (the demo signal by default, the microphone behind the
//     injected `MicrophonePermission`, or a picked file) and one `SampleRingBuffer` it writes into; once per frame a
//     `FeatureExtractor` (1,024 samples, 16 bands) analyses the newest samples, two `AudioMapper`s turn the features
//     into targets 0…1 (ripple ← low band, gain 1.5, attack 0.05 s, release 0.4 s; brightness ← level, gain 1.2,
//     attack 0.03 s, release 0.5 s) and `TunnelResponse` (with the factory's Reduce Motion and Reduce Flashing) moves
//     toward them within its bounds and step limits. Audio never moves the camera.
//   - Breathing: the response's `breathingScale` is applied at draw time through the model matrix of every tunnel
//     piece, never by rebuilding a mesh. The decision: ONE radial scaling for all tunnel pieces of a frame, about the
//     camera's current rail point, in the plane perpendicular to the rail direction there (scale `s` across, 1 along).
//     The same matrix for every piece keeps the joins watertight. A uniform 3-D scaling about a point next to the eye
//     would be almost invisible (every ray through the eye maps to itself), and a per-piece centre would open the
//     joins; the radial plane scaling widens the tube around the camera as clarification 4 asks. The ambient light of
//     the tunnel pieces is the response's `ambient`.
//   - Sources (as Music Lab, A06): `sync(_:)` makes the running source match the core's `source` on every draw and
//     description; each start gets a fresh ring buffer and resets the analysis and the mappers, so nothing of the
//     previous source lingers; at most one source runs. The microphone is chosen through `chooseMicrophone()`, which
//     mirrors the permission first (`permission.mirror`): denied or restricted is refused by the core's rule
//     (`a07.permission-denied`) with the demo playing and a message with the way to Settings; not determined is
//     accepted, the system is asked once, and a refusal falls back to the demo. A file is opened by `chooseFile(url:)`
//     before `source.file` is sent; an undecodable file keeps the previous source. Sources run only between `setup`
//     and `teardown` and not in the background; teardown stops the source and releases the microphone. Nothing is
//     recorded and nothing leaves the device.
//
// Feature 056 (A07-P03) T-A07-303 (FR-A07-301–303, FR-A07-310–312, FR-A07-320, FR-A07-330; clarifications 1–5):
//   - Envelope: the two `AudioMapper`s and the tunnel-only `TunnelResponse` are replaced by one `AudioEnvelope` (Core),
//     updated once per frame from the `FeatureExtractor`'s `AudioFeatures` (band energies, flux, onset) with the
//     frame's time and elapsed time, and one `WorldResponse` for the world drawn. The response is rebuilt (at rest)
//     when the world changes and when its reduce flags change: Reduce Motion = the factory's system setting OR the
//     journey's in-app calm motion (so calm motion halves the primary range as Reduce Motion does), Reduce Flashing =
//     the factory's. The targets are `state.mapping(for: world).target(from: envelope)`. A source start resets the
//     envelope, so nothing of the previous source lingers. Audio never moves the camera.
//   - Primary (`WorldResponse.primaryScale`), always ONE model matrix for every piece of the world in a frame, so the
//     joins stay watertight and no mesh is rebuilt:
//       tunnel: the radial breathing of A07-P02 (`breathingModel`, about the camera's rail point, across the rail);
//       landscape: a vertical scaling along the rail's local up at the camera's rail point (`swellModel`), about the
//         strip's base below that point (`WorldPieces.landscapeDrop` under the rail), so the relief above the base
//         swells by up to 1.6× while the base under the camera stays put. Decision: a single matrix is exact at the
//         camera; far ahead, where the rail's height differs from the camera's, the strip shifts by that difference
//         × (scale − 1) (at most a few units, inside the fog), which is accepted to keep the joins closed;
//       star corridor: the stars are not separate draws (48 per piece mesh, with the guide rings), so the star field
//         is scaled like the tunnel, radially across the rail about the camera's rail point (`breathingModel` with
//         the primary scale 1…1.6): the stars and rings spread out from the rail as the sparkle rises.
//   - Light: `WorldResponse.light` is the ambient of every renderer drawn in the frame, in every world.
//   - Description: names the chosen speed ("2.5 units per second"), the easing and "calm motion" when calm motion is
//     in effect (in-app or the system's Reduce Motion).
//
// Feature 057 (A07-P04) T-A07-403 (FR-A07-401–404, FR-A07-410, FR-A07-430; clarifications 1, 3 and 5):
//   - Journeys: with the experience's storage (from the factory) the presenter owns a `JourneyPresetStore`, reloaded
//     whenever the scene is set up (each time the experience is opened or its context returns); without storage (some
//     tests) only `JourneyPreset.builtIns` are offered. A journey is applied by sending its `actionValues` as one
//     `preset.apply` action, so the core validates and sets every field at once and the flight eases to the new
//     speed. The selected journey's id is display state only (`OdysseyMirror.selectedPresetID`, never in the core);
//     it marks the row and names what Rename and Delete act on. Saving captures the last core's journey state.
//   - Sound picker: `pickSource(_:)` is what the segmented picker calls: the demo sends `source.demo`, the microphone
//     goes through `chooseMicrophone()` (permission first), and File returns nil so the controls open the system file
//     importer (`chooseFile(url:)` then opens the file before `source.file` is sent). The status line is
//     `OdysseyMirror.sourceName` ("Demo signal", "Microphone" or the file's name).
import Foundation
import SwiftUI
import UIKit
import AudioOdysseyCore
import VisualCoreAudio
import VisualCoreAudioDSP
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
    /// The speed preset nearest to the speed target.
    var speedChoice: SpeedChoice = .medium
    /// The chosen speed target in units per second (feature 056).
    var speedTarget = JourneyState.defaultSpeedTarget
    /// The camera easing (feature 056).
    var easing: Easing = .standard
    /// The in-app calm-motion setting (feature 056).
    var calmMotion = false
    /// The mapping of the world shown (feature 056).
    var mapping = WorldMapping.defaults(for: .tunnel)
    /// Whether the flight is paused.
    var paused = false
    /// The chosen audio source (feature 055).
    var source: SourceKind = .demo
    /// The source as the status line names it: "Demo signal", "Microphone" or the picked file's name.
    var sourceName = SourceKind.demo.displayName
    /// A plain message (refused microphone access, an unplayable file, a stopped source); nil when all is well.
    var message: String?
    /// Whether the message concerns microphone access that only Settings can change.
    var showsSettingsLink = false
    /// Whether the system permission request is open.
    var isRequestingPermission = false
    /// The journey last applied or saved here (feature 057; display only, never state); nil when none is selected.
    var selectedPresetID: UUID?
}

/// How the presenter makes its audio sources; tests replace them with doubles (feature 055).
struct OdysseySourceFactory {
    /// The demo source for a signal.
    var demo: @MainActor (DemoSignal) -> any AudioSource
    /// The file source for a picked URL; throws for a file the system cannot decode.
    var file: @MainActor (URL) throws -> any AudioSource
    /// The microphone source behind a permission.
    var microphone: @MainActor (any MicrophonePermission) -> any AudioSource

    /// The VisualCoreAudio sources.
    static var system: OdysseySourceFactory {
        OdysseySourceFactory(demo: { DemoAudioSource(signal: $0) },
                             file: { try FileAudioSource(url: $0) },
                             microphone: { MicrophoneAudioSource(permission: $0) })
    }
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
    /// The linear depth fog of every world: from 40 to 110 units toward the clear colour (feature 055).
    nonisolated static let fog = MeshFog(start: 40, end: 110, color: background)
    /// The ring buffer's capacity in samples (a third of a second at 48 kHz).
    nonisolated static let ringCapacity = 16_384
    /// The analysis window in samples.
    nonisolated static let analysisSize = 1_024
    /// The number of analysis bands.
    nonisolated static let bandCount = 16

    /// The message when microphone access is off.
    static let deniedMessage = "Microphone access is off. Allow it for VisualCore in Settings, or use the demo signal or a file."
    /// The message when a picked file cannot be played.
    static let undecodableMessage = "This file can't be played. Choose a WAV, AIFF, CAF, M4A or MP3 file."
    /// The message when a restored session's file is no longer reachable.
    static let fileGoneMessage = "Choose the audio file again to play it."

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

    /// The model matrix of every tunnel piece in a frame (feature 055): the radial scaling by `scale` in the plane
    /// perpendicular to the unit `direction` about the world point `centre` (1 along `direction`), then the shift by
    /// `-origin` into drawing coordinates: `T(centre − origin) · (I + (scale − 1)(I − d dᵀ)) · T(−centre)`.
    nonisolated static func breathingModel(scale: Double, centre: Vec3, direction: Vec3, origin: Vec3) -> Mat4 {
        let k = scale.isFinite ? scale - 1 : 0
        let d = direction.length > 0 ? direction.normalized : Vec3(0, 0, 1)
        func column(_ axis: Vec3, _ component: Double) -> Vec4 { Vec4(axis * (1 + k) - d * (k * component), 0) }
        let radial = Mat4(column(Vec3(1, 0, 0), d.x), column(Vec3(0, 1, 0), d.y), column(Vec3(0, 0, 1), d.z),
                          Vec4(0, 0, 0, 1))
        return Mat4.translation(centre - origin) * radial * Mat4.translation(-centre)
    }

    /// The model matrix of every landscape piece in a frame (feature 056): the scaling by `scale` along the unit `up`
    /// about the world point `centre` (1 across `up`), then the shift by `-origin` into drawing coordinates:
    /// `T(centre − origin) · (I + (scale − 1) u uᵀ) · T(−centre)`.
    nonisolated static func swellModel(scale: Double, centre: Vec3, up: Vec3, origin: Vec3) -> Mat4 {
        let k = scale.isFinite ? scale - 1 : 0
        let u = up.length > 0 ? up.normalized : Vec3(0, 1, 0)
        func column(_ axis: Vec3, _ component: Double) -> Vec4 { Vec4(axis + u * (k * component), 0) }
        let swell = Mat4(column(Vec3(1, 0, 0), u.x), column(Vec3(0, 1, 0), u.y), column(Vec3(0, 0, 1), u.z),
                         Vec4(0, 0, 0, 1))
        return Mat4.translation(centre - origin) * swell * Mat4.translation(-centre)
    }

    /// The model matrix of every piece of `world` in a frame for the primary `scale` at the camera's rail `pose`:
    /// tunnel and star corridor the radial `breathingModel`, landscape the `swellModel` about the strip's base.
    nonisolated static func pieceModel(world: JourneyWorld, scale: Double, pose: RailPose, origin: Vec3) -> Mat4 {
        switch world {
        case .tunnel, .starCorridor:
            breathingModel(scale: scale, centre: pose.position, direction: pose.direction, origin: origin)
        case .landscape:
            swellModel(scale: scale, centre: pose.position - pose.up * WorldPieces.landscapeDrop, up: pose.up,
                       origin: origin)
        }
    }

    /// What runs (or should run): the demo with its seed and mode, the picked file (by pick number) or the microphone.
    enum SourceKey: Equatable {
        case demo(seed: UInt64, mode: Int)
        case file(pick: Int)
        case microphone
    }

    /// A picked, opened file.
    private struct PickedFile {
        let url: URL
        let name: String
        let pick: Int
        let source: any AudioSource
        let accessing: Bool
    }

    let experienceID: ExperienceID
    let mirror = OdysseyMirror()
    /// Whether the system Reduce Motion setting is on (from the factory).
    let reduceMotion: Bool
    /// Whether the system Reduce Flashing setting is on (from the factory; caps the brightness response).
    let reduceFlashing: Bool
    /// The microphone permission (the system's by default; a double in tests).
    let permission: any MicrophonePermission
    /// How the audio sources are made.
    let factory: OdysseySourceFactory
    /// The port of the shell, set by `AudioOdysseyExperience.make`; the presenter sends the Reduce Motion mirror and
    /// the file and microphone choices through it.
    weak var port: ExperienceActionPort?
    /// The demo signal's mode (the melody in the app; tests may choose a tone or silence before the source starts).
    var demoMode: DemoSignal.Mode = .sequence
    /// The journeys in the experience's own storage (feature 057); nil without storage (some tests).
    let presets: JourneyPresetStore?

    /// The rail of `railSeed`.
    private(set) var rail: CameraRail?
    private(set) var railSeed: UInt64?
    /// The renderers of the cached landscape or star corridor pieces by piece index, all of `cacheWorld` and
    /// `cacheSeed` (the tunnel streams through `tunnel`).
    private(set) var pieces: [Int: MeshRenderer] = [:]
    private var cacheWorld: JourneyWorld?
    private var cacheSeed: UInt64?
    /// The streamed tunnel pieces and their renderers.
    private(set) var tunnel = TunnelStream<MeshRenderer>()
    private var tunnelSeed: UInt64?
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
    /// The piece window of the last frame (`WorldPieces.indices(around:)`; in the tunnel the window being streamed).
    private(set) var lastIndices: ClosedRange<Int>?
    /// The piece indices actually drawn by the last frame, ascending.
    private(set) var lastDrawnPieces: [Int] = []
    /// The model matrix of the tunnel pieces in the last frame (nil outside the tunnel).
    private(set) var lastTunnelModel: Mat4?
    /// The model matrix shared by every piece drawn in the last frame, in any world (feature 056).
    private(set) var lastModel: Mat4?
    /// The number of piece renderers made since the presenter was created (tests read it).
    private(set) var piecesMade = 0
    /// The number of tunnel pieces built by the last frame (at most `SegmentWindow.maxBuildsPerStep`).
    private(set) var tunnelBuiltLastFrame = 0
    /// Set only by tests; the next draw throws `OdysseyDrawError.injected` and clears the flag.
    var failNextDraw = false

    /// The buffer of the running source (a fresh one per start).
    private(set) var ring = SampleRingBuffer(capacity: OdysseyPresenter.ringCapacity)
    /// The running source, if any.
    private(set) var activeSource: (any AudioSource)?
    /// What `activeSource` was started for.
    private(set) var activeKey: SourceKey?
    /// A key whose start failed; not retried until the selection changes.
    private var failedKey: SourceKey?
    private var pickedFile: PickedFile?
    private var pickCount = 0
    private var isBackgrounded = false
    private var fallbackScheduled = false
    private var observers: [NSObjectProtocol] = []
    /// The core of the last draw or description.
    private(set) var lastCore: OdysseyCore?

    /// The analysis of the running source, made for its sample rate and reset on every source change.
    private(set) var extractor: FeatureExtractor?
    /// The features of the last frame (silence before the first).
    private(set) var lastFeatures = AudioFeatures.silent(bandCount: OdysseyPresenter.bandCount)
    private var scratch = [Float](repeating: 0, count: OdysseyPresenter.analysisSize)
    /// The audio envelope, updated once per frame from the features (feature 056).
    private(set) var envelope = AudioEnvelope()
    /// The audio response of the world drawn, updated once per frame (feature 056: per world).
    private(set) var response: WorldResponse

    init(experienceID: ExperienceID, permission: any MicrophonePermission, factory: OdysseySourceFactory = .system,
         reduceMotion: Bool = false, reduceFlashing: Bool = false, storage: ExperienceStorage? = nil) {
        self.experienceID = experienceID
        presets = storage.map { JourneyPresetStore(storage: $0) }
        self.permission = permission
        self.factory = factory
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        response = WorldResponse(world: .tunnel, reduceMotion: reduceMotion, reduceFlashing: reduceFlashing)
    }

    /// The number of live piece renderers: the fixed window's and the streamed tunnel's.
    var liveRendererCount: Int { pieces.count + tunnel.liveCount }

    // MARK: Render scene

    func setup(_ context: RenderContext) throws {
        let pass = DepthMeshPass(registry: context.resources)
        pass.clearColor = Self.background
        self.pass = pass
        isLive = true
        presets?.reload()
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.enterBackground() }
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isBackgrounded = false }
            },
        ]
        if let lastCore { sync(lastCore) }
    }

    func draw(_ core: OdysseyCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw OdysseyDrawError.injected
        }
        sync(core)
        if case .failed(let reason)? = activeSource?.state, mirror.message == nil {
            mirror.message = "The sound stopped: \(reason)"
        }
        scheduleMirrorIfNeeded(core)
        updateResponse(core, frame: frame)
        let state = core.state
        let path = makeRail(for: state.seed)
        if cacheWorld != state.world || cacheSeed != state.seed {
            releasePieces()
            cacheWorld = state.world
            cacheSeed = state.seed
        }
        let window = WorldPieces.indices(around: state.distance)
        let sway = core.flight.sway(limits: core.limits)
        rebase.update(camera: Self.eye(rail: path, distance: state.distance, sway: sway))
        let origin = rebase.origin
        let camera = Self.camera(rail: path, distance: state.distance, sway: sway, origin: origin)
        let pose = path.pose(at: state.distance)
        let light = (pose.up * 0.7 - pose.direction * 0.7).normalized
        let color = Self.color(state.world)
        var items: [DepthMeshPass.Item] = []
        var drawn: [Int] = []
        items.reserveCapacity(TunnelStream<MeshRenderer>.capacity)
        if state.world == .tunnel {
            if tunnelSeed != state.seed {
                tunnel.reset { $0.release() }
                tunnelSeed = state.seed
            }
            let seed = state.seed
            let registry = context.resources
            let step = try tunnel.advance(to: state.distance, pieceLength: WorldPieces.pieceLength, build: { index in
                let renderer = try MeshRenderer(mesh: WorldPieces.piece(.tunnel, index: index, rail: path, seed: seed),
                                                registry: registry)
                piecesMade += 1
                return renderer
            }, retire: { $0.release() })
            tunnelBuiltLastFrame = step.toBuild.count
            let model = Self.pieceModel(world: .tunnel, scale: response.primaryScale, pose: pose, origin: origin)
            for index in tunnel.live {
                guard let renderer = tunnel.element(for: index) else { continue }
                renderer.lightDirection = light
                renderer.ambient = response.light
                items.append(DepthMeshPass.Item(renderer: renderer, model: model, color: color))
                drawn.append(index)
            }
            lastTunnelModel = model
            lastModel = model
        } else {
            if tunnel.liveCount > 0 || tunnelSeed != nil {
                tunnel.reset { $0.release() }
                tunnelSeed = nil
            }
            tunnelBuiltLastFrame = 0
            for index in Array(pieces.keys) where !window.contains(index) {
                pieces[index]?.release()
                pieces[index] = nil
            }
            let model = Self.pieceModel(world: state.world, scale: response.primaryScale, pose: pose, origin: origin)
            for index in window {
                let renderer: MeshRenderer
                if let cached = pieces[index] {
                    renderer = cached
                } else {
                    renderer = try MeshRenderer(mesh: WorldPieces.piece(state.world, index: index, rail: path,
                                                                        seed: state.seed),
                                                registry: context.resources)
                    pieces[index] = renderer
                    piecesMade += 1
                }
                renderer.lightDirection = light
                renderer.ambient = response.light
                items.append(DepthMeshPass.Item(renderer: renderer, model: model, color: color))
                drawn.append(index)
            }
            lastTunnelModel = nil
            lastModel = model
        }
        if pass == nil {
            let made = DepthMeshPass(registry: context.resources)
            made.clearColor = Self.background
            pass = made
        }
        let aspect = Double(max(1, context.pixelWidth)) / Double(max(1, context.pixelHeight))
        try pass?.draw(items, view: camera.view(), projection: camera.projection(aspect: aspect), fog: Self.fog,
                       context: context)
        lastCamera = camera
        lastWorld = state.world
        lastIndices = window
        lastDrawnPieces = drawn
    }

    func teardown(_ context: RenderContext) {
        stopActive()
        isLive = false
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
        releasePieces()
        tunnel.reset { $0.release() }
        tunnelSeed = nil
        cacheWorld = nil
        cacheSeed = nil
        pass?.release()
        pass = nil
        extractor = nil
    }

    /// The rail of `seed`, made once per seed.
    private func makeRail(for seed: UInt64) -> CameraRail {
        if let rail, railSeed == seed { return rail }
        let made = JourneyRail.make(seed: seed)
        rail = made
        railSeed = seed
        return made
    }

    /// Releases every renderer of the fixed window.
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

    // MARK: Audio response

    /// Analyses the newest samples once for this frame, updates the envelope and moves the world's response toward
    /// the targets of the world's mapping (the response is rebuilt first when the world or a reduce flag changed).
    private func updateResponse(_ core: OdysseyCore, frame: FrameInfo) {
        let rate = activeSource?.sampleRate ?? 48_000
        if extractor == nil || extractor?.sampleRate != rate {
            extractor = FeatureExtractor(size: Self.analysisSize, sampleRate: rate, bandCount: Self.bandCount)
            lastFeatures = AudioFeatures.silent(bandCount: Self.bandCount)
            envelope = AudioEnvelope()
        }
        let count = ring.latest(Self.analysisSize, into: &scratch)
        let used = max(0, min(count, scratch.count))
        if let extractor {
            scratch.withUnsafeBufferPointer { all in
                extractor.analyze(UnsafeBufferPointer(rebasing: all[0..<used]), time: frame.time,
                                  elapsed: frame.delta, into: &lastFeatures)
            }
        }
        envelope.update(bandEnergies: lastFeatures.bandEnergies, flux: lastFeatures.flux, onset: lastFeatures.onset,
                        time: frame.time, elapsed: frame.delta)
        let world = core.state.world
        let calm = reduceMotion || core.state.calmMotion
        if response.world != world || response.reduceMotion != calm || response.reduceFlashing != reduceFlashing {
            // Continue from the current values (convergence T-A07-313): no frame jumps on a world or flag change.
            response = response.continued(world: world, reduceMotion: calm, reduceFlashing: reduceFlashing)
        }
        let targets = core.state.mapping(for: world).target(from: envelope)
        response.update(primaryTarget: targets.primary, lightTarget: targets.light)
    }

    // MARK: Sources

    /// Makes the running source match `core`'s selection (see the file header).
    func sync(_ core: OdysseyCore) {
        lastCore = core
        updateDisplay(core)
        guard isLive, !isBackgrounded else { return }
        let desired: SourceKey?
        switch core.state.source {
        case .demo:
            desired = .demo(seed: core.preparationSeed, mode: demoMode.rawValue)
        case .file:
            if let pickedFile {
                desired = .file(pick: pickedFile.pick)
            } else {
                desired = nil
                mirror.message = Self.fileGoneMessage
            }
        case .microphone:
            switch permission.state {
            case .granted:
                desired = .microphone
            case .notDetermined:
                desired = activeKey                   // the previous source plays while the system asks
                if !mirror.isRequestingPermission {
                    mirror.isRequestingPermission = true
                    Task { @MainActor [weak self] in await self?.finishPermissionRequest() }
                }
            case .denied, .restricted:
                desired = activeKey                   // the previous source keeps playing
                showDenied()
                scheduleDemoFallback()
            }
        }
        if desired != failedKey { failedKey = nil }
        guard desired != activeKey else { return }
        if let desired, desired == failedKey { return }     // a failed start is not retried every frame
        stopActive()
        if let desired { start(desired) }
    }

    /// Starts the source for `key` into a fresh ring buffer; a failure is shown and not retried for the same key.
    private func start(_ key: SourceKey) {
        let source: any AudioSource
        switch key {
        case .demo(let seed, let mode):
            source = factory.demo(DemoSignal(seed: seed, mode: DemoSignal.Mode(rawValue: mode) ?? .sequence))
        case .file:
            guard let pickedFile else { return }
            source = pickedFile.source
        case .microphone:
            source = factory.microphone(permission)
        }
        let buffer = SampleRingBuffer(capacity: Self.ringCapacity)
        do {
            try source.start(into: buffer)
            ring = buffer
            activeSource = source
            activeKey = key
            extractor?.reset()                                  // no onset of the previous source lingers
            envelope = AudioEnvelope()
            if !mirror.showsSettingsLink { mirror.message = nil }   // a stale file or stop message goes
        } catch {
            failedKey = key
            mirror.message = Self.failureText(error)
            if case .permissionDenied? = error as? AudioSourceError {
                mirror.showsSettingsLink = true
            } else {
                mirror.showsSettingsLink = false
            }
        }
    }

    /// Stops the running source, if any (the microphone is released).
    private func stopActive() {
        activeSource?.stop()
        activeSource = nil
        activeKey = nil
    }

    private func enterBackground() {
        isBackgrounded = true
        stopActive()
    }

    /// Opens the picked file at `url` and, when it decodes, selects the file source. An undecodable file changes
    /// nothing (the previous source keeps playing) and shows `undecodableMessage`. Returns whether the file was taken.
    @discardableResult
    func chooseFile(url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        let source: any AudioSource
        do {
            source = try factory.file(url)
        } catch {
            if accessing { url.stopAccessingSecurityScopedResource() }
            mirror.message = Self.undecodableMessage
            mirror.showsSettingsLink = false
            return false
        }
        let previous = pickedFile
        pickCount += 1
        pickedFile = PickedFile(url: url, name: url.lastPathComponent, pick: pickCount, source: source,
                                accessing: accessing)
        mirror.message = nil
        mirror.showsSettingsLink = false
        guard let port, port.send("source.file").isAccepted else {
            pickedFile = previous
            if accessing { url.stopAccessingSecurityScopedResource() }
            return false
        }
        if let lastCore { sync(lastCore) }
        if let previous, previous.accessing { previous.url.stopAccessingSecurityScopedResource() }
        return true
    }

    /// Chooses the microphone (see the file header). Returns the core's answer to `source.microphone`.
    @discardableResult
    func chooseMicrophone() async -> ActionResult {
        guard let port else { return .rejected(.notActive(.inactive)) }
        let current = permission.state
        mirrorPermission(current)
        if current == .notDetermined { mirror.isRequestingPermission = true }
        let result = port.send("source.microphone")
        guard result.isAccepted else {
            mirror.isRequestingPermission = false
            if case .rejected(.rule(let code)) = result, code == OdysseyRule.permissionDenied { showDenied() }
            return result
        }
        mirror.message = nil
        mirror.showsSettingsLink = false
        if current == .notDetermined { await finishPermissionRequest() }
        return result
    }

    /// Asks the system once; granted starts the microphone, anything else falls back to the demo signal with the
    /// Settings message.
    private func finishPermissionRequest() async {
        let answer = await permission.request()
        mirror.isRequestingPermission = false
        mirrorPermission(answer)
        if answer == .granted {
            mirror.message = nil
            mirror.showsSettingsLink = false
            if let lastCore { sync(lastCore) }
        } else {
            showDenied()
            if lastCore?.state.source == .microphone { port?.send("source.demo") }
        }
    }

    /// Sends `permission.mirror` when the core's mirror differs from `state`.
    private func mirrorPermission(_ state: MicrophonePermissionState) {
        let access = Self.access(state)
        guard lastCore?.permission != access else { return }
        port?.send("permission.mirror", [Double(access.rawValue)])
    }

    /// A restored microphone selection without access: mirror the permission and go back to the demo signal, after
    /// the current frame or description (never from inside it).
    private func scheduleDemoFallback() {
        guard !fallbackScheduled else { return }
        fallbackScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            fallbackScheduled = false
            mirrorPermission(permission.state)
            if lastCore?.state.source == .microphone { port?.send("source.demo") }
        }
    }

    private func showDenied() {
        mirror.message = Self.deniedMessage
        mirror.showsSettingsLink = true
    }

    /// The core's mirror value of a system permission state.
    nonisolated static func access(_ state: MicrophonePermissionState) -> OdysseyMicrophoneAccess {
        switch state {
        case .notDetermined: .notDetermined
        case .granted: .granted
        case .denied: .denied
        case .restricted: .restricted
        }
    }

    /// A plain message for a source that could not start.
    static func failureText(_ error: any Error) -> String {
        guard let error = error as? AudioSourceError else { return "The sound could not start." }
        if case .engineFailed(let reason) = error { return "The sound could not start: \(reason)" }
        if case .undecodable = error { return undecodableMessage }
        return deniedMessage
    }

    // MARK: Journeys (feature 057)

    /// The journeys offered: the store's entries (built-ins, then the user journeys), or the built-ins alone without
    /// storage.
    var presetEntries: [JourneyPreset] { presets?.entries ?? JourneyPreset.builtIns }

    /// The id of the selected journey (display only); nil when none is selected.
    var selectedPresetID: UUID? { mirror.selectedPresetID }

    /// The selected journey when it is a user journey (Rename and Delete act on it); nil otherwise.
    var selectedUserPreset: JourneyPreset? {
        guard let id = mirror.selectedPresetID,
              let preset = presetEntries.first(where: { $0.id == id }), !preset.isBuiltIn else { return nil }
        return preset
    }

    /// Applies `preset` through the port as one `preset.apply` action with its sixteen values; an accepted journey
    /// becomes the selected one. Returns the core's answer.
    @discardableResult
    func apply(_ preset: JourneyPreset) -> ActionResult {
        guard let port else { return .rejected(.notActive(.inactive)) }
        let result = port.send("preset.apply", preset.actionValues)
        if result.isAccepted { mirror.selectedPresetID = preset.id }
        return result
    }

    /// Saves the last core's journey (world, mappings, speed target, easing, calm motion) as a user journey named
    /// `name` (cleaned and made unique); the new journey becomes the selected one. Nil without storage, before the
    /// first frame, or when the store refuses (its `lastMessage` says why).
    @discardableResult
    func saveCurrentPreset(named name: String, now: Date = Date()) -> JourneyPreset? {
        guard let presets, let state = lastCore?.state else { return nil }
        guard let saved = presets.save(name: name, from: state, now: now) else { return nil }
        mirror.selectedPresetID = saved.id
        return saved
    }

    /// Renames the selected user journey to `name` (cleaned and made unique). False without storage, without a
    /// selected user journey, or when the store refuses.
    @discardableResult
    func renameSelectedPreset(to name: String) -> Bool {
        guard let presets, let id = mirror.selectedPresetID else { return false }
        return presets.rename(id, to: name)
    }

    /// Deletes the selected user journey; the selection is cleared on success. False without storage, without a
    /// selected journey, or when the store refuses (a built-in is refused with a plain message).
    @discardableResult
    func deleteSelectedPreset() -> Bool {
        guard let presets, let id = mirror.selectedPresetID else { return false }
        guard presets.delete(id) else { return false }
        mirror.selectedPresetID = nil
        return true
    }

    // MARK: Sound picker (feature 057)

    /// What the segmented sound picker does for `source`: the demo sends `source.demo`, the microphone goes through
    /// `chooseMicrophone()`. Returns the core's answer, or nil for a file, which the controls pick first with the
    /// system file importer (then `chooseFile(url:)`).
    @discardableResult
    func pickSource(_ source: SourceKind) async -> ActionResult? {
        switch source {
        case .demo:
            guard let port else { return .rejected(.notActive(.inactive)) }
            let result = port.send("source.demo")
            return result
        case .microphone:
            return await chooseMicrophone()
        case .file:
            return nil
        }
    }

    // MARK: Description

    /// Records the display fields when one of them changed.
    private func updateDisplay(_ core: OdysseyCore) {
        let state = core.state
        if mirror.world != state.world { mirror.world = state.world }
        if mirror.speedChoice != state.speedChoice { mirror.speedChoice = state.speedChoice }
        if mirror.speedTarget != state.speedTarget { mirror.speedTarget = state.speedTarget }
        if mirror.easing != state.easing { mirror.easing = state.easing }
        if mirror.calmMotion != state.calmMotion { mirror.calmMotion = state.calmMotion }
        let mapping = state.mapping(for: state.world)
        if mirror.mapping != mapping { mirror.mapping = mapping }
        if mirror.paused != state.paused { mirror.paused = state.paused }
        if mirror.source != state.source { mirror.source = state.source }
        let name = sourceName(state.source)
        if mirror.sourceName != name { mirror.sourceName = name }
    }

    /// "Demo signal", "Microphone" or the picked file's name ("File" when none is open).
    private func sourceName(_ source: SourceKind) -> String {
        source == .file ? (pickedFile?.name ?? SourceKind.file.displayName) : source.displayName
    }

    /// The spoken name of the source: "demo signal", "microphone" or the picked file's name.
    private func spokenSourceName(_ source: SourceKind) -> String {
        source == .file ? (pickedFile?.name ?? "audio file") : source.displayName.lowercased()
    }

    /// The response in words: "at rest" (within a tenth of the way from rest to the upper bound), "gentle" (below
    /// half) or "strong", by the larger of the primary's and the light's share.
    nonisolated static func responseWord(_ response: WorldResponse) -> String {
        func share(_ value: Double, rest: Double, upper: Double) -> Double {
            upper > rest ? max(0, (value - rest) / (upper - rest)) : 0
        }
        let level = max(share(response.primary, rest: response.primaryRest, upper: response.primaryRange.upperBound),
                        share(response.light, rest: response.lightRest, upper: response.lightRange.upperBound))
        return level < 0.1 ? "at rest" : (level < 0.5 ? "gentle" : "strong")
    }

    /// A speed in words: "4 units per second", "2.5 units per second" (the target lies on the 0.5 grid).
    nonisolated static func speedWords(_ speed: Double) -> String {
        let text = speed == speed.rounded() && abs(speed) < 1e6 ? String(Int(speed)) : String(speed)
        return "\(text) units per second"
    }

    /// "Tunnel, 4 units per second, standard easing, flying, demo signal, sound response at rest." (world, speed target,
    /// easing, "calm motion" when `calm`, pause, source and the mapped response in words).
    static func description(of state: JourneyState, calm: Bool, source: String, response: String) -> String {
        "\(state.world.displayName), \(speedWords(state.speedTarget)), \(state.easing.displayName.lowercased()) easing, "
            + (calm ? "calm motion, " : "") + (state.paused ? "paused" : "flying")
            + ", \(source), sound response \(response)."
    }

    /// "Audio Odyssey: Tunnel, 4 units per second, standard easing, flying, demo signal, sound response at rest."
    /// Also brings the running source in line with `core` and mirrors Reduce Motion when needed.
    func describe(_ core: OdysseyCore) -> String {
        sync(core)
        scheduleMirrorIfNeeded(core)
        return "Audio Odyssey: " + Self.description(of: core.state, calm: core.state.calmMotion || reduceMotion,
                                                    source: spokenSourceName(core.state.source),
                                                    response: Self.responseWord(response))
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
        AnyView(OdysseyControls(port: port, presenter: self, mirror: mirror))
    }

    /// Every action has a native control; the Reduce Motion mirror is sent by the presenter from the system setting
    /// and the permission mirror by the Microphone button's flow.
    var nativeActions: Set<String> {
        ["world.select", "speed.select", "flight.pause", "flight.resume", "journey.reseed", "comfort.reduce-motion",
         "source.demo", "source.microphone", "source.file", "permission.mirror", "speed.set", "easing.select",
         "comfort.calm", "mapping.set", "mapping.reset", "preset.apply"]
    }
}
