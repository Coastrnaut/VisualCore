// SolarPresenter — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5), the orbit view by feature
// 104 (A14-P02) T-A14-207 and T-A14-208 (FR-A14-220, FR-A14-221; research D4; contracts/orbit-view.md), the 3D bodies,
// scale modes and focus flight by feature 105 (A14-P03) T-A14-308 (FR-A14-301–303, FR-A14-311, FR-A14-312,
// FR-A14-320–322; clarifications Q1–Q5; contracts/bodies.md). Draws Solar System Explorer through the host only (the
// host's context and registry, VisualCore's `DepthMeshPass` and `MeshRenderer` with an `OrbitCamera`; no context of
// its own, no second renderer, no imported assets). The presenter reads the core and never writes it:
//   - Bodies: each body is the unit 48 × 24 sphere of ``SceneMeshes`` with per-vertex colours from its `SurfaceRecipe`
//     (seam-free procedural surfaces), drawn at its position in the state's scale mode (``OrbitLayout/scenePosition(
//     index:day:mode:)``), scaled to the mode's drawn radius and tilted by its catalog axial tilt about the scene x
//     axis. The Sun is emissive (ambient 1); each planet is lit from the Sun (its light direction points from the
//     planet toward the origin, ``lightDirection(at:)``, ambient 0.25).
//   - Saturn's ring: the two-sided annulus of ``SceneMeshes/saturnRing(_:)`` (Cassini division darker) around Saturn,
//     scaled with Saturn's drawn radius and tilted with it, lit from the Sun with ambient 0.7.
//   - Orbits: eight closed tubes per scale mode along 128 samples of each planet's orbit
//     (``OrbitLayout/orbitPath(bodyID:mode:)``); the active mode's set is drawn fully bright in a dim colour.
//   - Starfield: 400 seeded stars (``SceneMeshes/starMesh(directions:)``) centred on the eye at 0.9 × the active far
//     plane, white at ambient 1, drawn last; in the enhanced mode every body lies nearer (at most 75 + 22 units from
//     the eye against 180), so no star is ever drawn in front of a body.
//   - Markers (true-relative mode): every body drawn under 2 pixels in radius gets a camera-facing marker ring of 6
//     pixels in its recipe's primary colour (``OrbitLayout/markerIndices(mode:day:eye:heightPixels:)``); markers never
//     change the drawn body.
//   - The selected body gets a ring outline: a closed `Mesh.tube` circle of radius ``OrbitLayout/selectionRingRadius(
//     index:)`` facing the camera, scaled by max(1, distance / 20) (enhanced) or to 10 pixels (true-relative), drawn
//     fully bright in the ring colour.
//   - Focus flight: the drawn camera follows a ``FocusFlight``. When the selection or the scale mode changes, a flight
//     starts from the view drawn last to the new view (restarted from the current view if one is running); every drawn
//     frame advances it one of its 30 frames, so the new view is reached on the 30th frame; Reduce Motion (passed at
//     make) cuts to it on the first. A zoom or date change only moves the flight's destination. The eye is pushed out
//     of every body's clearance (``FocusFlight/eye(at:yaw:pitch:bodies:near:)``); near and far come from the mode's
//     clip range at the drawn distance. The flight is presentation state and never reaches the core.
//   - Camera-relative drawing (FR-A14-322): every model matrix is built from the position minus the drawn target,
//     subtracted in Double and rounded to Float (``CameraRelative/relative(_:to:)``), and the scene is drawn through an
//     orbit camera with the same yaw, pitch and distance whose target is the origin, so precision does not depend on
//     the distance from the Sun.
//   - GPU objects: one `DepthMeshPass` and 37 mesh renderers (nine bodies, nine selection rings, eight orbits per
//     scale mode, Saturn's ring, the starfield and one marker ring), all made together with the host's registry in
//     `setup` (so they are made again after a context recreation; `draw` releases and makes them all if any is
//     missing) and all released together in `teardown`. Every mesh renderer shares one cached shader program in the
//     host's registry and releasing any renderer releases that program for all of them (A14-P01 research, As built),
//     so no renderer is ever released while others are in use. The CPU meshes are made once and kept.
//   - Probes (from the camera and eye of the last drawn frame): the background at the first of
//     ``backgroundProbes`` whose ray misses every body, Saturn's ring, the selection ring, every marker, the orbits
//     and every star (``OrbitLayout/rayMissesScene(ndc:camera:state:aspect:heightPixels:)``), expected dark; and the focused body's centre with the colour class of the recipe colours
//     of the sphere vertices around the point facing the eye, lit as drawn, when the body is at least 3 pixels in
//     radius, inside the canvas and the star sphere, nothing lies in front of its centre and the class is robust (at
//     0.7…1.3 times the brightness for a lit planet; for the emissive Sun, drawn exactly in its vertex colours, at 1).
//   - Words: the canvas description of `SolarCore` (ending with the scale mode's label); the controls show the date,
//     the camera, the scale mode, the status, the fact card with the distance from the Sun and the answer to a refused
//     action. A change of the scale mode is announced with the new description (through the system's VoiceOver
//     announcements; tests inject a sink).
// Nothing flashes; the only motion is the focus flight, cut by Reduce Motion. No audio.
import Foundation
import SolarSystemExplorerCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreUI

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class SolarMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The selected body's index, 0 (the Sun) … 8 (Neptune).
    var selection = 0
    /// The number of bodies.
    var bodyCount = SolarCore.bodyCount
    /// The selected body's name.
    var bodyName = ""
    /// The selected body's fact card, one line per fact ("Mean radius: 6,371 km — Planetary Fact Sheet — Metric").
    var facts: [String] = []
    /// The status line ("Earth selected, body 4 of 9").
    var status = ""
    /// The answer to the last refused action; empty after an accepted one.
    var message = ""
    /// The simulated date in days since J2000.0.
    var dayOffset = 0.0
    /// The simulated date as `yyyy-MM-dd` ("2000-01-01").
    var dateLabel = SimulatedDate.j2000.label
    /// The selected planet's distance from the Sun on the date ("0.983 AU (147,099,000 km)"); empty for the Sun.
    var distance = ""
    /// The camera yaw in degrees, 0 ≤ yaw < 360.
    var yawDegrees = 0.0
    /// The camera pitch in degrees, 5…85.
    var pitchDegrees = SolarState.overviewPitch
    /// The zoom steps, −1…12.
    var zoomSteps = 0
    /// The camera distance in scene units of the active scale mode (60 or 120 · 1.25^−zoomSteps).
    var cameraDistance = SolarState.overviewDistance
    /// The active scale mode.
    var scaleMode = ScaleMode.enhanced
    /// The active scale mode's name ("Enhanced", "True relative").
    var scaleName = ScaleMode.enhanced.name
    /// The active scale mode's label ("Distances and sizes not to scale").
    var scaleLabel = ScaleMode.enhanced.label
}

/// Draws Solar System Explorer and owns its presentation state (meshes, renderers, the depth pass and the flight).
@MainActor
final class SolarPresenter: ExperiencePresenter {
    /// A14-P01's display radius of the Sun (clarification Q4); the enhanced mode draws it × 0.5.
    nonisolated static let sunDisplayRadius = 1.6
    /// A14-P01's display radius of a planet of Mercury's size; the enhanced mode draws planets × 0.6.
    nonisolated static let basePlanetRadius = 0.25
    /// The display radius added per doubling of the mean radius.
    nonisolated static let radiusPerDoubling = 0.15
    /// Mercury's mean radius in km, the reference of the display radius (the catalog's value, 2,439.7 km).
    nonisolated static let referenceRadiusKm: Double = {
        BodyCatalog.bundled.bodies.first { $0.id == "mercury" }?.meanRadiusKm ?? 2_439.7
    }()
    /// The ring outline's tube radius (before the ring scale).
    nonisolated static let ringTubeRadius = 0.05
    /// The points of the ring outline's circle.
    nonisolated static let ringPoints = 64
    /// The sides of the ring outline's tube.
    nonisolated static let ringSides = 8
    /// The enhanced orbit tubes' radius (A14-P02 research D4).
    nonisolated static let orbitTubeRadius = OrbitLayout.enhancedOrbitTubeRadius
    /// The sides of the orbit tubes (research D4).
    nonisolated static let orbitSides = 6
    /// The planets' ambient light fraction.
    nonisolated static let planetAmbient = 0.25
    /// The smallest radius in pixels a body needs for a centre probe.
    nonisolated static let probeMinimumPixels = 3.0
    /// The background probe's first position from the top left.
    nonisolated static let backgroundProbe = Vec2(0.5, 0.04)
    /// The background probe's positions from the top left, tried in order (the first whose ray misses everything).
    nonisolated static let backgroundProbes: [Vec2] = [Vec2(0.5, 0.04), Vec2(0.25, 0.04), Vec2(0.75, 0.04),
                                                       Vec2(0.06, 0.06), Vec2(0.94, 0.06), Vec2(0.5, 0.1),
                                                       Vec2(0.06, 0.94), Vec2(0.94, 0.94)]
    /// The angle around the point facing the eye within which sphere vertices feed the centre probe (radians; one
    /// cell diagonal of the 48 × 24 sphere is about 0.185).
    nonisolated static let centerNeighbourAngle = 0.19
    /// The brightness factors a lit planet's centre class must survive.
    nonisolated static let litScales: [Double] = [0.7, 0.85, 1, 1.15, 1.3]

    /// The canvas around the bodies.
    nonisolated static let backgroundColor = Vec4(0.02, 0.025, 0.05, 1)
    /// The ring outline around the selected body.
    nonisolated static let ringColor = Vec4(0.35, 0.8, 1, 1)
    /// The orbit lines (dim, so the bodies stand out).
    nonisolated static let orbitColor = Vec4(0.24, 0.3, 0.42, 1)

    /// The selection and scale mode a flight goes to.
    struct FocusKey: Equatable {
        /// The selected body.
        var selection: Int
        /// The scale mode.
        var mode: ScaleMode
    }

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// Whether Reduce Motion is on (the focus flight cuts).
    let reduceMotion: Bool
    /// Where announcements go (the system's VoiceOver announcements by default).
    let announcementSink: any AnnouncementSink
    /// What the controls show.
    let mirror = SolarMirror()

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// How many times the renderers (all 37, always together) were made.
    private(set) var rendererBuildCount = 0
    /// How many times the nine selection ring renderers were made (with the others; never per selection).
    private(set) var ringBuildCount = 0
    /// How many times the CPU meshes were made (once per presenter).
    private(set) var meshBuildCount = 0
    /// The number of bodies drawn by the last frame.
    private(set) var lastBodiesDrawn = 0
    /// The number of orbit lines drawn by the last frame.
    private(set) var lastOrbitsDrawn = 0
    /// Whether the last frame drew the selection ring.
    private(set) var lastRingDrawn = false
    /// Whether the last frame drew Saturn's ring.
    private(set) var lastSaturnRingDrawn = false
    /// Whether the last frame drew the starfield.
    private(set) var lastStarsDrawn = false
    /// The star sphere's radius in the last frame (0.9 × its far plane); 0 before the first frame.
    private(set) var lastStarRadius = 0.0
    /// The number of markers drawn by the last frame.
    private(set) var lastMarkersDrawn = 0
    /// The bodies marked in the last frame, in catalog order.
    private(set) var lastMarkedBodies: [Int] = []
    /// The selection the last frame drew; nil before the first frame.
    private(set) var lastSelection: Int?
    /// The simulated date (days since J2000.0) the last frame drew; nil before the first frame.
    private(set) var lastDayOffset: Double?
    /// The scale mode the last frame drew; nil before the first frame.
    private(set) var lastScaleMode: ScaleMode?
    /// The drawn camera of the last frame in scene coordinates (target = the drawn target); nil before the first.
    private(set) var lastCamera: OrbitCamera?
    /// The drawn eye of the last frame in scene coordinates (after the clearance push); nil before the first frame.
    private(set) var lastEye: Vec3?
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The focus flight the drawn camera follows; nil before the first frame.
    private(set) var flight: FocusFlight?
    /// The flight frame the last frame drew (0…30).
    private(set) var flightFrame = 0
    /// The view the last frame drew; nil before the first frame.
    private(set) var lastDrawnView: FocusFlight.View?
    /// The selection and scale mode of the last frame's flight destination; nil before the first frame.
    private(set) var focusKey: FocusKey?
    /// The scale mode last seen by the announcements; nil until the first state.
    private(set) var announcedScaleMode: ScaleMode?
    /// The last text announced; empty before the first announcement.
    private(set) var lastAnnouncement = ""
    /// The number of announcements made.
    private(set) var announcementCount = 0
    /// The unit body spheres with their recipe colours in catalog order; empty until first needed.
    private(set) var bodyMeshes: [(mesh: Mesh, colors: [Vec4])] = []
    /// The selection ring meshes in catalog order (centred on the origin, x–y plane); empty until first needed.
    private(set) var ringMeshes: [Mesh] = []
    /// The enhanced orbit meshes of ``OrbitLayout/orbitBodyIDs`` (scene coordinates); empty until first needed.
    private(set) var orbitMeshes: [Mesh] = []
    /// The true-relative orbit meshes of ``OrbitLayout/orbitBodyIDs``; empty until first needed.
    private(set) var trueOrbitMeshes: [Mesh] = []
    /// Saturn's two-sided ring in Saturn radii with its colours; nil until first needed.
    private(set) var saturnRingMesh: (mesh: Mesh, colors: [Vec4])?
    /// The starfield on the unit sphere; nil until first needed.
    private(set) var starMesh: Mesh?
    /// The unit marker ring; nil until first needed.
    private(set) var markerMesh: Mesh?
    /// The body renderers in catalog order; empty after `teardown`.
    private(set) var bodyRenderers: [MeshRenderer] = []
    /// The selection ring renderers of the nine bodies in catalog order, made once with the others; empty after
    /// `teardown`. The selection only chooses which ring is drawn.
    private(set) var ringRenderers: [MeshRenderer] = []
    /// The eight enhanced orbit renderers in the order of ``OrbitLayout/orbitBodyIDs``; empty after `teardown`.
    private(set) var orbitRenderers: [MeshRenderer] = []
    /// The eight true-relative orbit renderers; empty after `teardown`.
    private(set) var trueOrbitRenderers: [MeshRenderer] = []
    /// Saturn's ring renderer; nil after `teardown`.
    private(set) var saturnRingRenderer: MeshRenderer?
    /// The starfield renderer; nil after `teardown`.
    private(set) var starRenderer: MeshRenderer?
    /// The marker renderer (drawn once per marked body); nil after `teardown`.
    private(set) var markerRenderer: MeshRenderer?
    /// The selection ring renderer of the last drawn selection; nil after `teardown` or before the first frame.
    var ringRenderer: MeshRenderer? {
        guard let selection = lastSelection, ringRenderers.indices.contains(selection) else { return nil }
        return ringRenderers[selection]
    }
    /// The depth-correct pass the scene is drawn through; made in `setup`, released in `teardown`.
    private(set) var depthPass: DepthMeshPass?

    /// A presenter for the experience `experienceID`; `reduceMotion` cuts the focus flight; `announcementSink`
    /// replaces the system's VoiceOver announcements (nil: the system's).
    init(experienceID: ExperienceID, reduceMotion: Bool = false, announcementSink: (any AnnouncementSink)? = nil) {
        self.experienceID = experienceID
        self.reduceMotion = reduceMotion
        self.announcementSink = announcementSink ?? SystemAnnouncementSink()
    }

    // MARK: Render scene

    /// Makes the depth pass and every renderer with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        releaseGPU()
        depthPass = DepthMeshPass(registry: context.resources)
        try makeRenderers(context)
        isLive = true
    }

    /// Whether every renderer is present.
    private var renderersComplete: Bool {
        bodyRenderers.count == SolarCore.bodyCount && ringRenderers.count == SolarCore.bodyCount
            && !orbitRenderers.isEmpty && orbitRenderers.count == orbitMeshes.count
            && trueOrbitRenderers.count == trueOrbitMeshes.count && saturnRingRenderer != nil && starRenderer != nil
            && markerRenderer != nil
    }

    /// Draws the bodies, Saturn's ring, the active mode's orbits, the selection ring, the markers and the starfield
    /// with depth through the drawn camera of the focus flight, camera-relative.
    func draw(_ core: SolarCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        lastCanvas = Vec2(width, height)
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        if !renderersComplete {
            // Something is missing: release them all together and make them all again (never one at a time).
            releaseRenderers()
            try makeRenderers(context)
        }
        guard let depthPass, let saturnRingRenderer, let starRenderer, let markerRenderer else { return }
        depthPass.clearColor = Self.backgroundColor
        let state = core.state
        let mode = state.scaleMode
        let day = state.dayOffset
        let drawn = advanceView(state: state)
        let camera = drawn.camera
        let eye = drawn.eye
        let target = camera.target
        // Draw relative to the drawn target: the same yaw, pitch and distance looking at the origin.
        let relativeCamera = OrbitCamera(target: .zero, distance: camera.distance, yaw: camera.yaw,
                                         pitch: camera.pitch, fovY: camera.fovY, near: camera.near, far: camera.far)
        func relative(_ p: Vec3) -> Vec3 {
            let f = CameraRelative.relative(p, to: target)
            return Vec3(Double(f.x), Double(f.y), Double(f.z))
        }
        var items: [DepthMeshPass.Item] = []
        var centers: [Vec3] = []
        for (index, renderer) in bodyRenderers.enumerated() {
            let center = OrbitLayout.scenePosition(index: index, day: day, mode: mode)
            centers.append(center)
            if index > 0 { renderer.lightDirection = Self.lightDirection(at: center) }
            let r = mode.drawnRadius(index: index)
            let model = Mat4.translation(relative(center)) * SceneMeshes.bodyTilt(index: index)
                * Mat4.scale(Vec3(r, r, r))
            items.append(DepthMeshPass.Item(renderer: renderer, model: model, color: Vec4(1, 1, 1, 1)))
        }
        let bodies = items.count
        // Saturn's ring (unit = Saturn radii), tilted with Saturn.
        let saturn = SceneMeshes.saturnIndex
        let saturnCenter = centers.indices.contains(saturn) ? centers[saturn] : .zero
        let saturnRadius = mode.drawnRadius(index: saturn)
        saturnRingRenderer.lightDirection = Self.lightDirection(at: saturnCenter)
        items.append(DepthMeshPass.Item(renderer: saturnRingRenderer,
                                        model: Mat4.translation(relative(saturnCenter))
                                            * SceneMeshes.bodyTilt(index: saturn)
                                            * Mat4.scale(Vec3(saturnRadius, saturnRadius, saturnRadius)),
                                        color: Vec4(1, 1, 1, 1)))
        let orbits = mode == .enhanced ? orbitRenderers : trueOrbitRenderers
        let orbitModel = Mat4.translation(relative(.zero))
        for renderer in orbits {
            items.append(DepthMeshPass.Item(renderer: renderer, model: orbitModel, color: Self.orbitColor))
        }
        let selection = state.selection
        let ringDrawn = ringRenderers.indices.contains(selection) && centers.indices.contains(selection)
        if ringDrawn {
            let center = centers[selection]
            let scale = OrbitLayout.selectionRingScale(index: selection, mode: mode, cameraDistance: camera.distance,
                                                       eyeDistance: (center - eye).length, heightPixels: height)
            items.append(DepthMeshPass.Item(renderer: ringRenderers[selection],
                                            model: OrbitLayout.facingModel(center: relative(center), yaw: camera.yaw,
                                                                           pitch: camera.pitch, scale: scale),
                                            color: Self.ringColor))
        }
        let marked = OrbitLayout.markerIndices(mode: mode, day: day, eye: eye, heightPixels: height)
        for index in marked where centers.indices.contains(index) {
            let center = centers[index]
            let scale = OrbitLayout.markerScale(center: center, eye: eye, heightPixels: height)
            items.append(DepthMeshPass.Item(renderer: markerRenderer,
                                            model: OrbitLayout.facingModel(center: relative(center), yaw: camera.yaw,
                                                                           pitch: camera.pitch, scale: scale),
                                            color: SceneMeshes.markerColor(index: index)))
        }
        // The starfield last, centred on the eye at 0.9 × far.
        let starRadius = SceneMeshes.starRadius(far: camera.far)
        items.append(DepthMeshPass.Item(renderer: starRenderer,
                                        model: Mat4.translation(relative(eye))
                                            * Mat4.scale(Vec3(starRadius, starRadius, starRadius)),
                                        color: SceneMeshes.starColor))
        try depthPass.draw(items, camera: relativeCamera, context: context)
        lastBodiesDrawn = bodies
        lastOrbitsDrawn = orbits.count
        lastRingDrawn = ringDrawn
        lastSaturnRingDrawn = true
        lastStarsDrawn = true
        lastStarRadius = starRadius
        lastMarkersDrawn = marked.count
        lastMarkedBodies = marked
        lastSelection = selection
        lastDayOffset = day
        lastScaleMode = mode
        lastCamera = camera
        lastEye = eye
    }

    /// Advances the focus flight by one drawn frame for `state` and returns the drawn camera (scene coordinates) and
    /// eye (see the file header).
    private func advanceView(state: SolarState) -> (camera: OrbitCamera, eye: Vec3) {
        let mode = state.scaleMode
        let destination = FocusFlight.View(
            target: OrbitLayout.scenePosition(index: state.selection, day: state.dayOffset, mode: mode),
            distance: mode.cameraDistance(zoomSteps: state.zoomSteps))
        let key = FocusKey(selection: state.selection, mode: mode)
        var current: FocusFlight
        if let running = flight, let drawnView = lastDrawnView {
            if key != focusKey {
                current = running.restarted(from: drawnView, to: destination)
                flightFrame = 0
            } else {
                current = running
                current.to = destination
            }
        } else {
            current = FocusFlight(from: destination, to: destination, reduceMotion: reduceMotion)
            flightFrame = FocusFlight.frameCount
        }
        flightFrame = min(flightFrame + 1, FocusFlight.frameCount)
        flight = current
        focusKey = key
        let view = current.view(at: flightFrame)
        lastDrawnView = view
        let degrees = Double.pi / 180
        let yaw = state.yawDegrees * degrees, pitch = Double(state.pitchDegrees) * degrees
        let clip = mode.clipRange(distance: view.distance)
        let raw = OrbitCamera(target: view.target, distance: view.distance, yaw: yaw, pitch: pitch,
                              fovY: OrbitLayout.fieldOfView, near: clip.near, far: clip.far)
        let eye = current.eye(at: flightFrame, yaw: yaw, pitch: pitch,
                              bodies: FocusFlight.bodies(mode: mode, day: state.dayOffset), near: clip.near)
        if eye == raw.eye { return (raw, eye) }
        return (OrbitLayout.camera(target: view.target, eye: eye, near: clip.near, far: clip.far), eye)
    }

    /// Releases every GPU object; the CPU meshes and the flight stay for the next context.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
        lastBodiesDrawn = 0
        lastOrbitsDrawn = 0
        lastRingDrawn = false
        lastSaturnRingDrawn = false
        lastStarsDrawn = false
        lastMarkersDrawn = 0
        lastMarkedBodies = []
    }

    /// Releases every renderer and the depth pass.
    private func releaseGPU() {
        releaseRenderers()
        depthPass?.release()
        depthPass = nil
    }

    /// Releases every mesh renderer, all together.
    private func releaseRenderers() {
        for renderer in bodyRenderers { renderer.release() }
        for renderer in ringRenderers { renderer.release() }
        for renderer in orbitRenderers { renderer.release() }
        for renderer in trueOrbitRenderers { renderer.release() }
        saturnRingRenderer?.release()
        starRenderer?.release()
        markerRenderer?.release()
        bodyRenderers = []
        ringRenderers = []
        orbitRenderers = []
        trueOrbitRenderers = []
        saturnRingRenderer = nil
        starRenderer = nil
        markerRenderer = nil
    }

    /// Whether every CPU mesh is present.
    private var meshesComplete: Bool {
        bodyMeshes.count == SolarCore.bodyCount && ringMeshes.count == SolarCore.bodyCount && !orbitMeshes.isEmpty
            && trueOrbitMeshes.count == orbitMeshes.count && saturnRingMesh != nil && starMesh != nil
            && markerMesh != nil
    }

    /// Makes the CPU meshes once: bodies, selection rings, both orbit sets, Saturn's ring, the stars and the marker.
    private func buildMeshes() throws {
        let bodies = SceneMeshes.bodies()
        var rings: [Mesh] = []
        for index in 0..<SolarCore.bodyCount { rings.append(try Self.ringMesh(selection: index)) }
        var orbits: [Mesh] = []
        var trueOrbits: [Mesh] = []
        for id in OrbitLayout.orbitBodyIDs {
            orbits.append(try SceneMeshes.orbitMesh(bodyID: id, mode: .enhanced))
            trueOrbits.append(try SceneMeshes.orbitMesh(bodyID: id, mode: .trueRelative))
        }
        let saturnRing = try SceneMeshes.saturnRing()
        let marker = try SceneMeshes.markerMesh()
        bodyMeshes = bodies
        ringMeshes = rings
        orbitMeshes = orbits
        trueOrbitMeshes = trueOrbits
        saturnRingMesh = saturnRing
        starMesh = SceneMeshes.starMesh()
        markerMesh = marker
        meshBuildCount += 1
    }

    /// Makes all the renderers together: the nine bodies (the Sun fully bright, the planets lit from the Sun), the
    /// nine selection rings, both orbit sets, Saturn's ring (ambient 0.7), the stars and the marker (fully bright); a
    /// failure releases every renderer made so far and rethrows.
    private func makeRenderers(_ context: RenderContext) throws {
        if !meshesComplete { try buildMeshes() }
        guard let saturnRingMesh, let starMesh, let markerMesh else { return }
        var made: [MeshRenderer] = []
        func renderer(_ mesh: Mesh, colors: [Vec4]? = nil, ambient: Double) throws -> MeshRenderer {
            let renderer = try MeshRenderer(mesh: mesh, colors: colors, registry: context.resources)
            renderer.ambient = ambient
            made.append(renderer)
            return renderer
        }
        do {
            var bodies: [MeshRenderer] = []
            for (index, part) in bodyMeshes.enumerated() {
                bodies.append(try renderer(part.mesh, colors: part.colors, ambient: index == 0 ? 1 : Self.planetAmbient))
            }
            var rings: [MeshRenderer] = []
            for mesh in ringMeshes { rings.append(try renderer(mesh, ambient: 1)) }
            var orbits: [MeshRenderer] = []
            for mesh in orbitMeshes { orbits.append(try renderer(mesh, ambient: 1)) }
            var trueOrbits: [MeshRenderer] = []
            for mesh in trueOrbitMeshes { trueOrbits.append(try renderer(mesh, ambient: 1)) }
            let saturnRing = try renderer(saturnRingMesh.mesh, colors: saturnRingMesh.colors,
                                          ambient: SceneMeshes.ringAmbient)
            let stars = try renderer(starMesh, ambient: 1)
            let marker = try renderer(markerMesh, ambient: 1)
            bodyRenderers = bodies
            ringRenderers = rings
            orbitRenderers = orbits
            trueOrbitRenderers = trueOrbits
            saturnRingRenderer = saturnRing
            starRenderer = stars
            markerRenderer = marker
        } catch {
            for renderer in made { renderer.release() }
            throw error
        }
        rendererBuildCount += 1
        ringBuildCount += 1
    }

    // MARK: Geometry

    /// A14-P01's display radius of a body of `radiusKm` and `kind` (clarification Q4): 1.6 for the star; for a planet
    /// 0.25 + 0.15 · log₂(radiusKm / 2,439.7), at least 0.05 (a non-finite or non-positive radius gives 0.25). The
    /// enhanced mode draws it scaled (``OrbitLayout/displayRadius(index:)``).
    nonisolated static func displayRadius(radiusKm: Double, kind: BodyKind) -> Double {
        if kind == .star { return sunDisplayRadius }
        guard radiusKm.isFinite, radiusKm > 0 else { return basePlanetRadius }
        return max(0.05, basePlanetRadius + radiusPerDoubling * log2(radiusKm / referenceRadiusKm))
    }

    /// A14-P01's display radius of the catalog body at `index` (0.25 outside the catalog).
    nonisolated static func displayRadius(index: Int) -> Double {
        guard let body = BodyCatalog.bundled.body(at: index) else { return basePlanetRadius }
        return displayRadius(radiusKm: body.meanRadiusKm, kind: body.kind)
    }

    /// The radius of the ring outline around a body of display radius `displayRadius`: 1.18 · radius + 0.12.
    nonisolated static func ringRadius(displayRadius: Double) -> Double { displayRadius * 1.18 + 0.12 }

    /// The direction toward the light for a planet at the scene point `center`: toward the Sun at the origin (straight
    /// up for a point at the origin).
    nonisolated static func lightDirection(at center: Vec3) -> Vec3 {
        let length = center.length
        guard length.isFinite, length > 0 else { return Vec3(0, 1, 0) }
        return Vec3(-center.x / length, -center.y / length, -center.z / length)
    }

    /// The nine unit body spheres with their recipe colours (``SceneMeshes/bodies()``).
    nonisolated static func meshes() -> [(mesh: Mesh, colors: [Vec4])] {
        SceneMeshes.bodies()
    }

    /// The ring outline around the body `selection`, centred on the origin: a closed tube along a circle in the x–y
    /// plane of radius ``OrbitLayout/selectionRingRadius(index:)``.
    nonisolated static func ringMesh(selection: Int) throws -> Mesh {
        let radius = OrbitLayout.selectionRingRadius(index: selection)
        var path: [Vec3] = []
        for i in 0..<ringPoints {
            let angle = 2 * Double.pi * Double(i) / Double(ringPoints)
            path.append(Vec3(cos(angle) * radius, sin(angle) * radius, 0))
        }
        return try Mesh.tube(path: path, radius: ringTubeRadius, sides: ringSides, caps: false, closed: true)
    }

    /// The enhanced orbit line of `bodyID` (``SceneMeshes/orbitMesh(bodyID:mode:)``).
    nonisolated static func orbitMesh(bodyID: String) throws -> Mesh {
        try SceneMeshes.orbitMesh(bodyID: bodyID, mode: .enhanced)
    }

    // MARK: Probes

    /// The `FrameColorClass` raw value of 8-bit channels by the frame checks' rules (luma below 40 dark; luma above
    /// 215 with a spread below 30 light; a channel 30 above both others red, green or blue; otherwise other).
    nonisolated static func classify(red r: Int, green g: Int, blue b: Int) -> String {
        let luma = 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
        if luma < 40 { return FrameColorClass.dark.rawValue }
        if luma > 215, max(r, g, b) - min(r, g, b) < 30 { return FrameColorClass.light.rawValue }
        if r - g >= 30, r - b >= 30 { return FrameColorClass.red.rawValue }
        if g - r >= 30, g - b >= 30 { return FrameColorClass.green.rawValue }
        if b - r >= 30, b - g >= 30 { return FrameColorClass.blue.rawValue }
        return FrameColorClass.other.rawValue
    }

    /// The colour class shared by every colour of `colors` (channels 0…1) when it is robust: the same class for each
    /// colour at every brightness factor of `scales` and every channel moved by up to 3 of 255; nil otherwise (or for
    /// no colour).
    nonisolated static func robustClass(_ colors: [Vec3], scales: [Double] = SolarPresenter.litScales) -> String? {
        var classes: Set<String> = []
        let nudges: [Int] = [-3, 0, 3]
        for color in colors {
            for scale in scales {
                let r = Int((min(max(color.x * scale, 0), 1) * 255).rounded())
                let g = Int((min(max(color.y * scale, 0), 1) * 255).rounded())
                let b = Int((min(max(color.z * scale, 0), 1) * 255).rounded())
                for nr in nudges {
                    for ng in nudges {
                        for nb in nudges { classes.insert(classify(red: r + nr, green: g + ng, blue: b + nb)) }
                    }
                }
            }
        }
        return classes.count == 1 ? classes.first : nil
    }

    /// The lit colours (RGB 0…1) around the visible centre of the body at `index` seen from `eye` in the scene of
    /// `state`: the recipe colours of the unit sphere's vertices within ``centerNeighbourAngle`` of the point facing
    /// the eye (in the body's own frame, the axial tilt undone), each times ambient + (1 − ambient) · Lambert with the
    /// normal toward the eye and the light from the Sun (the Sun: ambient 1).
    nonisolated static func centerColors(index: Int, eye: Vec3, state: SolarState) -> [Vec3] {
        guard let recipe = SceneMeshes.recipe(index: index) else { return [] }
        let mode = state.scaleMode
        let ambient = index == 0 ? 1 : planetAmbient
        let center = OrbitLayout.scenePosition(index: index, day: state.dayOffset, mode: mode)
        let normal = (eye - center).normalized
        let lambert = max(0, normal.dot(lightDirection(at: center)))
        let f = ambient + (1 - ambient) * lambert
        let untilt = Mat4.rotation(Quat(axis: Vec3(1, 0, 0), angle: -SceneMeshes.axialTilt(index: index)))
        let local = untilt.applyVector(normal)
        let limit = cos(centerNeighbourAngle)
        var colors: [Vec3] = []
        for p in SceneMeshes.unitSphere.positions where p.dot(local) >= limit {
            let c = recipe.color(at: p)
            colors.append(Vec3(c.r * f, c.g * f, c.b * f))
        }
        return colors
    }

    /// The probes of `core` on the last canvas through the last drawn camera (see the file header); none before the
    /// first frame.
    func probes(_ core: SolarCore) -> [FrameProbe] {
        guard let canvas = lastCanvas, let camera = lastCamera, let eye = lastEye else { return [] }
        let state = core.state
        let mode = state.scaleMode
        let aspect = canvas.x / max(canvas.y, 1)
        var probes: [FrameProbe] = []
        for candidate in Self.backgroundProbes {
            let ndc = Vec2(candidate.x * 2 - 1, 1 - candidate.y * 2)
            guard OrbitLayout.rayMissesScene(ndc: ndc, camera: camera, state: state, aspect: aspect,
                                             heightPixels: canvas.y) else { continue }
            if let background = FrameProbe(name: "background", x: candidate.x, y: candidate.y,
                                           expected: FrameColorClass.dark.rawValue) {
                probes.append(background)
            }
            break
        }
        let selection = state.selection
        let center = OrbitLayout.scenePosition(index: selection, day: state.dayOffset, mode: mode)
        let drawnRadius = mode.drawnRadius(index: selection)
        let radius = OrbitLayout.pixelRadius(drawnRadius, at: center, eye: eye, heightPixels: canvas.y)
        let insideStars = (center - eye).length + drawnRadius < SceneMeshes.starRadius(far: camera.far)
        guard radius >= Self.probeMinimumPixels, insideStars,
              OrbitLayout.centreUnobstructed(index: selection, eye: eye, state: state) else { return probes }
        let p = OrbitLayout.pixel(of: center, camera: camera, canvas: canvas)
        guard p.x >= 1, p.y >= 1, p.x <= canvas.x - 1, p.y <= canvas.y - 1 else { return probes }
        let scales: [Double] = selection == 0 ? [1] : Self.litScales
        if let expected = Self.robustClass(Self.centerColors(index: selection, eye: eye, state: state), scales: scales),
           let probe = FrameProbe(name: "body-\(selection)", x: p.x / canvas.x, y: 1 - p.y / canvas.y,
                                  expected: expected) {
            probes.append(probe)
        }
        return probes
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core` and announces a change of the scale mode.
    func sync(_ core: SolarCore) {
        if !mirror.ready { mirror.ready = true }
        let state = core.state
        if mirror.selection != state.selection { mirror.selection = state.selection }
        let name = core.body?.name ?? ""
        if mirror.bodyName != name { mirror.bodyName = name }
        let facts = Self.factLines(core.factCard)
        if mirror.facts != facts { mirror.facts = facts }
        let status = SolarCore.status(selection: state.selection)
        if mirror.status != status { mirror.status = status }
        if mirror.dayOffset != state.dayOffset { mirror.dayOffset = state.dayOffset }
        let label = state.date.label
        if mirror.dateLabel != label { mirror.dateLabel = label }
        let distance = SolarCore.distanceWords(index: state.selection, dayOffset: state.dayOffset) ?? ""
        if mirror.distance != distance { mirror.distance = distance }
        if mirror.yawDegrees != state.yawDegrees { mirror.yawDegrees = state.yawDegrees }
        if mirror.pitchDegrees != state.pitchDegrees { mirror.pitchDegrees = state.pitchDegrees }
        if mirror.zoomSteps != state.zoomSteps { mirror.zoomSteps = state.zoomSteps }
        let mode = state.scaleMode
        let cameraDistance = mode.cameraDistance(zoomSteps: state.zoomSteps)
        if mirror.cameraDistance != cameraDistance { mirror.cameraDistance = cameraDistance }
        if mirror.scaleMode != mode { mirror.scaleMode = mode }
        if mirror.scaleName != mode.name { mirror.scaleName = mode.name }
        if mirror.scaleLabel != mode.label { mirror.scaleLabel = mode.label }
        if let announced = announcedScaleMode, announced != mode {
            let text = core.canvasDescription
            announcementSink.announce(text)
            lastAnnouncement = text
            announcementCount += 1
        }
        announcedScaleMode = mode
    }

    /// The lines of `card` ("Mean radius: 6,371 km — Planetary Fact Sheet — Metric"); none without a card.
    nonisolated static func factLines(_ card: FactCard?) -> [String] {
        card?.facts.map(\.text) ?? []
    }

    /// The answer to `result` of `control`: empty when accepted, else why it was refused.
    nonisolated static func answerWords(control: String, result: ActionResult) -> String {
        guard !result.isAccepted else { return "" }
        switch control {
        case "body.next": return "Neptune is the last body."
        case "body.previous": return "The Sun is the first body."
        case "body.select": return "There is no such body."
        case "date.step": return "The date stays within 1950-01-01 to 2051-01-01."
        case "camera.tilt": return "The view cannot tilt further."
        case "camera.zoom": return "The view cannot zoom further."
        case "scale.mode": return "There is no such scale."
        default: return "That is not possible here."
        }
    }

    /// The description of `core`'s view.
    func describe(_ core: SolarCore) -> String {
        sync(core)
        return core.canvasDescription
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(SolarControls(port: port, mirror: mirror))
    }

    /// The actions the native controls send: every action (body, date, camera and scale controls and the Body menu);
    /// there is no canvas gesture in this phase.
    var nativeActions: Set<String> {
        Set(SolarCore.actionIDs)
    }
}
