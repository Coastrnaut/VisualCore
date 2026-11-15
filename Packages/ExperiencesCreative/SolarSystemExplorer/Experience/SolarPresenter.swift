// SolarPresenter — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5), the orbit view by feature
// 104 (A14-P02) T-A14-207 and T-A14-208 (FR-A14-220, FR-A14-221; clarifications Q4, Q5; research D4;
// contracts/orbit-view.md). Draws Solar System Explorer through the host only (the host's context and registry,
// VisualCore's `DepthMeshPass` and `MeshRenderer` with an `OrbitCamera`; no context of its own, no second renderer, no
// imported assets). The presenter reads the core and never writes it:
//   - The orbit view: the Sun at the origin and each planet at its scene position for the state's date
//     (``OrbitLayout/scenePosition(index:day:)``: the heliocentric ecliptic position through the 4√r mapping, the
//     ecliptic in the scene's x–z plane, y up), with display radius A14-P01's × 0.6 (planets) or × 0.5 (the Sun)
//     (``OrbitLayout/displayRadius(index:)``). Distances and sizes are not to scale; the canvas description and the
//     legend say so.
//   - Orbits: eight closed `Mesh.tube` loops (radius 0.04, 6 sides) along 128 samples of each planet's orbit
//     (``OrbitLayout/orbitPath(bodyID:)``), drawn fully bright in a dim colour (``SolarPresenter/orbitColor``).
//   - Meshes: one UV sphere per body (`Mesh.uvSphere(segments: 32, rings: 16, radius:)`) with per-vertex colours from a
//     seeded two-band latitude palette made in code (``SolarPresenter/palettes``: two colours and an odd number of
//     latitude bands per body, each band's brightness scaled by 0.88…1 from a SplitMix64 hash of the body index and
//     the band, so the equator always lies in the middle of one band). The body, ring and orbit meshes are CPU data,
//     made once and kept across context recreations.
//   - Light from the Sun: every frame each planet renderer lights toward the Sun from the planet's scene position
//     (``SolarPresenter/lightDirection(at:)``) with ambient 0.25, so the lit half faces the Sun; the Sun is drawn
//     fully bright (ambient 1).
//   - The selected (focused) body gets a ring outline: a closed `Mesh.tube` circle of radius
//     ``SolarPresenter/ringRadius(displayRadius:)`` made in the x–y plane and turned to face the camera, scaled by
//     max(1, distance / 20) so it stays visible from afar (``OrbitLayout/ringModel(center:camera:)``), drawn fully
//     bright in the ring colour.
//   - Camera: ``OrbitLayout/camera(state:)``, target the focused body's scene position, yaw, pitch and distance from
//     the state (the native controls step them), 60° field of view.
//   - GPU objects: one `DepthMeshPass` and 26 mesh renderers (nine bodies, nine rings, eight orbits), all made together
//     with the host's registry in `setup` (so they are made again after a context recreation; `draw` makes them all if
//     any are missing) and all released together in `teardown`. Every mesh renderer shares one cached shader program
//     in the host's registry and releasing any renderer releases that program for all of them (A14-P01 research, As
//     built), so no renderer is ever released while others are in use: the selection only picks a ring.
//   - Probes: the background at (0.5, 0.04) from the top left, expected dark, when the ray through it misses every
//     body, the ring and the orbits' slab (``OrbitLayout/rayMissesScene(ndc:state:aspect:)``); and the focused body's
//     centre with the colour class of its equator band and the bands of the vertex rows next to it under the light
//     there, when the body is at least 3 pixels in radius, nothing lies in front of its centre and the class is robust
//     at 0.7…1.3 times the brightness (it is for the Sun, drawn at full brightness: red).
//   - Words: the canvas description of `SolarCore`; the controls show the date, the camera, the status, the fact card
//     with the distance from the Sun and the answer to a refused action.
// Nothing moves by itself (only an action changes the view), so Reduce Motion changes nothing; nothing flashes. No
// audio.
import Foundation
import SolarSystemExplorerCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

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
    /// The camera distance in scene units (60 · 1.25^−zoomSteps).
    var cameraDistance = SolarState.overviewDistance
}

/// The colours of one body: two band colours (RGB 0…1) and an odd number of latitude bands.
struct BodyPalette: Equatable, Sendable {
    /// The colour of the even bands (the equator band when `bands` is 1, 5 or 9).
    let first: Vec3
    /// The colour of the odd bands.
    let second: Vec3
    /// The number of latitude bands (odd, so the equator lies in the middle of a band).
    let bands: Int
}

/// Draws Solar System Explorer and owns its presentation state (meshes, renderers and the depth pass).
@MainActor
final class SolarPresenter: ExperiencePresenter {
    /// A14-P01's display radius of the Sun (clarification Q4); the orbit view draws it × 0.5.
    nonisolated static let sunDisplayRadius = 1.6
    /// A14-P01's display radius of a planet of Mercury's size; the orbit view draws planets × 0.6.
    nonisolated static let basePlanetRadius = 0.25
    /// The display radius added per doubling of the mean radius.
    nonisolated static let radiusPerDoubling = 0.15
    /// Mercury's mean radius in km, the reference of the display radius (the catalog's value, 2,439.7 km).
    nonisolated static let referenceRadiusKm: Double = {
        BodyCatalog.bundled.bodies.first { $0.id == "mercury" }?.meanRadiusKm ?? 2_439.7
    }()
    /// Longitude segments of each sphere.
    nonisolated static let sphereSegments = 32
    /// Latitude rings of each sphere.
    nonisolated static let sphereRings = 16
    /// The ring outline's tube radius (before the ring scale).
    nonisolated static let ringTubeRadius = 0.05
    /// The points of the ring outline's circle.
    nonisolated static let ringPoints = 64
    /// The sides of the ring outline's tube.
    nonisolated static let ringSides = 8
    /// The orbit tubes' radius (research D4).
    nonisolated static let orbitTubeRadius = 0.04
    /// The sides of the orbit tubes (research D4).
    nonisolated static let orbitSides = 6
    /// The planets' ambient light fraction.
    nonisolated static let planetAmbient = 0.25
    /// The smallest radius in pixels a body needs for a centre probe.
    nonisolated static let probeMinimumPixels = 3.0
    /// The background probe's position from the top left.
    nonisolated static let backgroundProbe = Vec2(0.5, 0.04)

    /// The canvas around the bodies.
    nonisolated static let backgroundColor = Vec4(0.02, 0.025, 0.05, 1)
    /// The ring outline around the selected body.
    nonisolated static let ringColor = Vec4(0.35, 0.8, 1, 1)
    /// The orbit lines (dim, so the bodies stand out).
    nonisolated static let orbitColor = Vec4(0.24, 0.3, 0.42, 1)

    /// The palettes of the nine bodies in catalog order: Sun, Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus,
    /// Neptune (made in code; not imagery).
    nonisolated static let palettes: [BodyPalette] = [
        BodyPalette(first: Vec3(1, 0.62, 0.18), second: Vec3(1, 0.75, 0.3), bands: 5),
        BodyPalette(first: Vec3(0.62, 0.6, 0.58), second: Vec3(0.5, 0.48, 0.46), bands: 3),
        BodyPalette(first: Vec3(0.9, 0.82, 0.6), second: Vec3(0.82, 0.72, 0.5), bands: 3),
        BodyPalette(first: Vec3(0.2, 0.42, 0.85), second: Vec3(0.28, 0.6, 0.32), bands: 5),
        BodyPalette(first: Vec3(0.82, 0.38, 0.2), second: Vec3(0.66, 0.3, 0.16), bands: 3),
        BodyPalette(first: Vec3(0.86, 0.74, 0.58), second: Vec3(0.7, 0.5, 0.36), bands: 9),
        BodyPalette(first: Vec3(0.92, 0.84, 0.62), second: Vec3(0.8, 0.7, 0.5), bands: 7),
        BodyPalette(first: Vec3(0.62, 0.86, 0.9), second: Vec3(0.52, 0.78, 0.84), bands: 3),
        BodyPalette(first: Vec3(0.3, 0.45, 0.95), second: Vec3(0.22, 0.36, 0.82), bands: 5),
    ]

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = SolarMirror()

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// How many times the renderers (bodies, rings and orbits, always together) were made.
    private(set) var rendererBuildCount = 0
    /// How many times the nine ring renderers were made (with the body renderers; never per selection).
    private(set) var ringBuildCount = 0
    /// How many times the CPU meshes were made (once per presenter).
    private(set) var meshBuildCount = 0
    /// The number of bodies drawn by the last frame.
    private(set) var lastBodiesDrawn = 0
    /// The number of orbit lines drawn by the last frame.
    private(set) var lastOrbitsDrawn = 0
    /// Whether the last frame drew the ring outline.
    private(set) var lastRingDrawn = false
    /// The selection the last frame drew; nil before the first frame.
    private(set) var lastSelection: Int?
    /// The simulated date (days since J2000.0) the last frame drew; nil before the first frame.
    private(set) var lastDayOffset: Double?
    /// The camera of the last frame; nil before the first frame.
    private(set) var lastCamera: OrbitCamera?
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The body meshes with their colours in catalog order; empty until first needed.
    private(set) var bodyMeshes: [(mesh: Mesh, colors: [Vec4])] = []
    /// The ring meshes in catalog order (centred on the origin, x–y plane); empty until first needed.
    private(set) var ringMeshes: [Mesh] = []
    /// The orbit meshes of ``OrbitLayout/orbitBodyIDs`` (scene coordinates); empty until first needed.
    private(set) var orbitMeshes: [Mesh] = []
    /// The body renderers in catalog order; empty after `teardown`.
    private(set) var bodyRenderers: [MeshRenderer] = []
    /// The ring renderers of the nine bodies in catalog order, made once with the body renderers; empty after
    /// `teardown`. All mesh renderers share one cached shader program in the host's registry, and releasing any
    /// renderer releases that program for all of them, so no renderer is released while the others are in use: the
    /// selection only chooses which ring is drawn.
    private(set) var ringRenderers: [MeshRenderer] = []
    /// The eight orbit renderers in the order of ``OrbitLayout/orbitBodyIDs``, made with the body renderers; empty
    /// after `teardown`.
    private(set) var orbitRenderers: [MeshRenderer] = []
    /// The ring renderer of the last drawn selection; nil after `teardown` or before the first frame.
    var ringRenderer: MeshRenderer? {
        guard let selection = lastSelection, ringRenderers.indices.contains(selection) else { return nil }
        return ringRenderers[selection]
    }
    /// The depth-correct pass the scene is drawn through; made in `setup`, released in `teardown`.
    private(set) var depthPass: DepthMeshPass?

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
    }

    // MARK: Render scene

    /// Makes the depth pass and every renderer with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        releaseGPU()
        depthPass = DepthMeshPass(registry: context.resources)
        try makeRenderers(context)
        isLive = true
    }

    /// Whether every renderer is present (nine bodies, nine rings and one per orbit).
    private var renderersComplete: Bool {
        bodyRenderers.count == SolarCore.bodyCount && ringRenderers.count == SolarCore.bodyCount
            && !orbitRenderers.isEmpty && orbitRenderers.count == orbitMeshes.count
    }

    /// Draws the nine bodies at their positions on the state's date, lit from the Sun, the orbit lines and the ring
    /// outline on the focused body, with depth, through the state's camera.
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
        guard let depthPass else { return }
        depthPass.clearColor = Self.backgroundColor
        let state = core.state
        let camera = OrbitLayout.camera(state: state)
        var items: [DepthMeshPass.Item] = []
        for (index, renderer) in bodyRenderers.enumerated() {
            let center = OrbitLayout.scenePosition(index: index, day: state.dayOffset)
            if index > 0 { renderer.lightDirection = Self.lightDirection(at: center) }
            items.append(DepthMeshPass.Item(renderer: renderer, model: Mat4.translation(center),
                                            color: Vec4(1, 1, 1, 1)))
        }
        let bodies = items.count
        for renderer in orbitRenderers {
            items.append(DepthMeshPass.Item(renderer: renderer, model: .identity, color: Self.orbitColor))
        }
        let selection = state.selection
        let ringDrawn = ringRenderers.indices.contains(selection)
        if ringDrawn {
            items.append(DepthMeshPass.Item(renderer: ringRenderers[selection],
                                            model: OrbitLayout.ringModel(center: camera.target, camera: camera),
                                            color: Self.ringColor))
        }
        try depthPass.draw(items, camera: camera, context: context)
        lastBodiesDrawn = bodies
        lastOrbitsDrawn = orbitRenderers.count
        lastRingDrawn = ringDrawn
        lastSelection = selection
        lastDayOffset = state.dayOffset
        lastCamera = camera
    }

    /// Releases every GPU object; the CPU meshes stay for the next context.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
        lastBodiesDrawn = 0
        lastOrbitsDrawn = 0
        lastRingDrawn = false
    }

    /// Releases every renderer and the depth pass.
    private func releaseGPU() {
        releaseRenderers()
        depthPass?.release()
        depthPass = nil
    }

    /// Releases the body, ring and orbit renderers, all together.
    private func releaseRenderers() {
        for renderer in bodyRenderers { renderer.release() }
        for renderer in ringRenderers { renderer.release() }
        for renderer in orbitRenderers { renderer.release() }
        bodyRenderers = []
        ringRenderers = []
        orbitRenderers = []
    }

    /// Makes the CPU meshes (bodies, rings and orbits) once.
    private func buildMeshes() throws {
        let bodies = Self.meshes()
        var rings: [Mesh] = []
        for index in 0..<SolarCore.bodyCount { rings.append(try Self.ringMesh(selection: index)) }
        var orbits: [Mesh] = []
        for id in OrbitLayout.orbitBodyIDs { orbits.append(try Self.orbitMesh(bodyID: id)) }
        bodyMeshes = bodies
        ringMeshes = rings
        orbitMeshes = orbits
        meshBuildCount += 1
    }

    /// Makes all the renderers together: the nine bodies (the Sun fully bright, the planets lit from the Sun), the
    /// nine rings and the orbits (fully bright); a failure releases every renderer made so far and rethrows.
    private func makeRenderers(_ context: RenderContext) throws {
        if bodyMeshes.count != SolarCore.bodyCount || ringMeshes.count != SolarCore.bodyCount || orbitMeshes.isEmpty {
            try buildMeshes()
        }
        var bodies: [MeshRenderer] = []
        var rings: [MeshRenderer] = []
        var orbits: [MeshRenderer] = []
        do {
            for (index, part) in bodyMeshes.enumerated() {
                let renderer = try MeshRenderer(mesh: part.mesh, colors: part.colors, registry: context.resources)
                renderer.ambient = index == 0 ? 1 : Self.planetAmbient
                bodies.append(renderer)
            }
            for mesh in ringMeshes {
                let renderer = try MeshRenderer(mesh: mesh, registry: context.resources)
                renderer.ambient = 1
                rings.append(renderer)
            }
            for mesh in orbitMeshes {
                let renderer = try MeshRenderer(mesh: mesh, registry: context.resources)
                renderer.ambient = 1
                orbits.append(renderer)
            }
        } catch {
            for renderer in bodies { renderer.release() }
            for renderer in rings { renderer.release() }
            for renderer in orbits { renderer.release() }
            throw error
        }
        bodyRenderers = bodies
        ringRenderers = rings
        orbitRenderers = orbits
        rendererBuildCount += 1
        ringBuildCount += 1
    }

    // MARK: Geometry

    /// A14-P01's display radius of a body of `radiusKm` and `kind` (clarification Q4): 1.6 for the star; for a planet
    /// 0.25 + 0.15 · log₂(radiusKm / 2,439.7), at least 0.05 (a non-finite or non-positive radius gives 0.25). The
    /// orbit view draws it scaled (``OrbitLayout/displayRadius(index:)``).
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

    /// A number in 0…1 from `seed` and `band` (SplitMix64).
    nonisolated static func unitHash(seed: UInt64, band: Int) -> Double {
        var z = seed &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(truncatingIfNeeded: band) &+ 0x632B_E59B_D9B4_E019
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(UInt64(1) << 53)
    }

    /// The band of latitude fraction `v` (0 at the north pole, 1 at the south pole) among `bands` bands.
    nonisolated static func band(v: Double, bands: Int) -> Int {
        let n = max(1, bands)
        return min(n - 1, max(0, Int(v * Double(n))))
    }

    /// The colour (RGB 0…1, alpha 1) of band `band` of the body at `index`: the palette's first colour on even bands,
    /// its second on odd ones, scaled by 0.88 + 0.12 · hash(index, band).
    nonisolated static func bandColor(index: Int, band: Int) -> Vec4 {
        let palette = palettes[min(max(index, 0), palettes.count - 1)]
        let base = band % 2 == 0 ? palette.first : palette.second
        let scale = 0.88 + 0.12 * unitHash(seed: UInt64(max(index, 0)) + 1, band: band)
        return Vec4(min(1, base.x * scale), min(1, base.y * scale), min(1, base.z * scale), 1)
    }

    /// The per-vertex colours of `mesh` (a UV sphere: texture v is the latitude fraction) for the body at `index`.
    nonisolated static func colors(mesh: Mesh, index: Int) -> [Vec4] {
        let palette = palettes[min(max(index, 0), palettes.count - 1)]
        var colors: [Vec4] = []
        colors.reserveCapacity(mesh.uvs.count)
        for uv in mesh.uvs {
            colors.append(bandColor(index: index, band: band(v: uv.y, bands: palette.bands)))
        }
        return colors
    }

    /// The nine sphere meshes of the catalog at the orbit view's display radii, with their colours.
    nonisolated static func meshes() -> [(mesh: Mesh, colors: [Vec4])] {
        var parts: [(mesh: Mesh, colors: [Vec4])] = []
        for index in 0..<SolarCore.bodyCount {
            let mesh = Mesh.uvSphere(segments: sphereSegments, rings: sphereRings,
                                     radius: OrbitLayout.displayRadius(index: index))
            parts.append((mesh, colors(mesh: mesh, index: index)))
        }
        return parts
    }

    /// The ring outline around the body `selection`, centred on the origin: a closed tube along a circle in the x–y
    /// plane, of radius ``ringRadius(displayRadius:)`` of the body's orbit-view display radius.
    nonisolated static func ringMesh(selection: Int) throws -> Mesh {
        let radius = ringRadius(displayRadius: OrbitLayout.displayRadius(index: selection))
        var path: [Vec3] = []
        for i in 0..<ringPoints {
            let angle = 2 * Double.pi * Double(i) / Double(ringPoints)
            path.append(Vec3(cos(angle) * radius, sin(angle) * radius, 0))
        }
        return try Mesh.tube(path: path, radius: ringTubeRadius, sides: ringSides, caps: false, closed: true)
    }

    /// The orbit line of `bodyID`: a closed tube (radius 0.04, 6 sides) along ``OrbitLayout/orbitPath(bodyID:)``.
    nonisolated static func orbitMesh(bodyID: String) throws -> Mesh {
        try Mesh.tube(path: OrbitLayout.orbitPath(bodyID: bodyID), radius: orbitTubeRadius, sides: orbitSides,
                      caps: false, closed: true)
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
    /// colour at every brightness 0.7…1.3 times and every channel moved by up to 3 of 255; nil otherwise (or for no
    /// colour).
    nonisolated static func robustClass(_ colors: [Vec3]) -> String? {
        var classes: Set<String> = []
        let scales: [Double] = [0.7, 0.85, 1, 1.15, 1.3]
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

    /// The lit colours (RGB 0…1) around the visible centre of the body at `index` seen through the camera of
    /// `state`: the band colours of the equator's vertex row and of the rows above and below it (the pixel there
    /// blends them), each times ambient + (1 − ambient) · Lambert, the normal pointing from the body's centre to the
    /// eye and the light coming from the Sun.
    nonisolated static func centerColors(index: Int, state: SolarState) -> [Vec3] {
        let palette = palettes[min(max(index, 0), palettes.count - 1)]
        let ambient = index == 0 ? 1 : planetAmbient
        let center = OrbitLayout.scenePosition(index: index, day: state.dayOffset)
        let normal = (OrbitLayout.camera(state: state).eye - center).normalized
        let lambert = max(0, normal.dot(lightDirection(at: center)))
        let f = ambient + (1 - ambient) * lambert
        let row = 1.0 / Double(sphereRings)
        let latitudes: [Double] = [0.5 - row, 0.5, 0.5 + row]
        var colors: [Vec3] = []
        for v in latitudes {
            let base = bandColor(index: index, band: band(v: v, bands: palette.bands))
            colors.append(Vec3(base.x * f, base.y * f, base.z * f))
        }
        return colors
    }

    /// The probes of `core` on the last canvas (see the file header); none before the first frame.
    func probes(_ core: SolarCore) -> [FrameProbe] {
        guard let canvas = lastCanvas else { return [] }
        let state = core.state
        let aspect = canvas.x / max(canvas.y, 1)
        var probes: [FrameProbe] = []
        let ndc = Vec2(Self.backgroundProbe.x * 2 - 1, 1 - Self.backgroundProbe.y * 2)
        if OrbitLayout.rayMissesScene(ndc: ndc, state: state, aspect: aspect),
           let background = FrameProbe(name: "background", x: Self.backgroundProbe.x, y: Self.backgroundProbe.y,
                                       expected: FrameColorClass.dark.rawValue) {
            probes.append(background)
        }
        let selection = state.selection
        let center = OrbitLayout.scenePosition(index: selection, day: state.dayOffset)
        let radius = OrbitLayout.pixelRadius(OrbitLayout.displayRadius(index: selection), at: center, state: state,
                                             height: canvas.y)
        guard radius >= Self.probeMinimumPixels, OrbitLayout.centreUnobstructed(index: selection, state: state) else {
            return probes
        }
        let p = OrbitLayout.pixel(of: center, state: state, canvas: canvas)
        if let expected = Self.robustClass(Self.centerColors(index: selection, state: state)),
           let probe = FrameProbe(name: "body-\(selection)", x: p.x / canvas.x, y: 1 - p.y / canvas.y,
                                  expected: expected) {
            probes.append(probe)
        }
        return probes
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core`.
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
        if mirror.cameraDistance != state.cameraDistance { mirror.cameraDistance = state.cameraDistance }
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
        default: return "That is not possible here."
        }
    }

    /// The description of `core`'s orbit view.
    func describe(_ core: SolarCore) -> String {
        sync(core)
        return core.canvasDescription
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(SolarControls(port: port, mirror: mirror))
    }

    /// The actions the native controls send: every action (body, date and camera buttons and the Body menu); there
    /// is no canvas gesture in this phase.
    var nativeActions: Set<String> {
        Set(SolarCore.actionIDs)
    }
}
