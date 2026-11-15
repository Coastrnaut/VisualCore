// SolarPresenter — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5). Draws Solar System
// Explorer through the host only (the host's context and registry, VisualCore's `DepthMeshPass` and `MeshRenderer`
// with a fixed `OrbitCamera`; no context of its own, no second renderer, no imported assets). The presenter reads the
// core and never writes it:
//   - The line-up of clarification Q4, a static visibility-enhanced row on the x axis (y up, z toward the camera):
//     the Sun at x = 0 with display radius 1.6 (``SolarPresenter/sunDisplayRadius``); planet `i` (1…8) at
//     x = 1.6 + 2.4 · (i − 0.5) (``SolarPresenter/xPosition(index:)``) with display radius
//     0.25 + 0.15 · log₂(radius / Mercury's radius) (``SolarPresenter/displayRadius(radiusKm:kind:)``). Sizes and
//     spacing are not to scale; the canvas description and the legend say so.
//   - Meshes: one UV sphere per body (`MeshGenerators`' `Mesh.uvSphere(segments: 32, rings: 16, radius:)`) with
//     per-vertex colours from a seeded two-band latitude palette made in code (``SolarPresenter/palettes``: two
//     colours and an odd number of latitude bands per body, each band's brightness scaled by 0.88…1 from a SplitMix64
//     hash of the body index and the band, so the equator always lies in the middle of one band). The meshes and
//     colours are CPU data, made once and kept across context recreations.
//   - Light from the Sun's side: every planet renderer lights toward ``SolarPresenter/lightDirection`` (to the left,
//     slightly up and toward the camera) with ambient 0.25; the Sun is drawn fully bright (ambient 1).
//   - The selected body gets a ring outline: a closed `Mesh.tube` circle in the x–y plane facing the camera, of
//     radius ``SolarPresenter/ringRadius(displayRadius:)`` around the body, drawn fully bright in the ring colour. The
//     nine ring renderers are made once with the bodies and the selection only picks one: every mesh renderer shares
//     one cached shader program in the host's registry and releasing a renderer releases that program for all of
//     them, so no renderer is released while the others are in use.
//   - Camera: a fixed `OrbitCamera` (yaw 0, pitch 0, 60° field of view) looking at the middle of the row from +z, its
//     distance the smallest that fits the row with a 10 % side margin and its height with a 25 % margin into the
//     canvas's aspect (``SolarPresenter/camera(aspect:)``). Nothing moves; there is no gesture in this phase.
//   - GPU objects: one `DepthMeshPass`, nine body renderers and one ring renderer, made in `setup` with the host's
//     registry (so they are made again after a context recreation; `draw` makes any that are missing) and all
//     released in `teardown`.
//   - Probes: the background at (0.5, 0.04) from the top left (always above the row: the camera keeps the row's top
//     below 80 % of the half height) expected dark, and the selected body's centre with the colour class of its
//     equator band and the bands of the vertex rows next to it under the light there, when that class is robust at
//     0.7…1.3 times the brightness (it is for the Sun, drawn at full brightness: red).
//   - Words: the canvas description of `SolarCore`; the controls show the status, the fact card and the answer to a
//     refused action.
// There is no motion, so Reduce Motion changes nothing; nothing flashes. No audio.
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
    /// The Sun's display radius (clarification Q4).
    nonisolated static let sunDisplayRadius = 1.6
    /// The distance between neighbouring planets on the row.
    nonisolated static let spacing = 2.4
    /// The display radius of a planet of Mercury's size.
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
    /// The ring outline's tube radius.
    nonisolated static let ringTubeRadius = 0.05
    /// The points of the ring outline's circle.
    nonisolated static let ringPoints = 64
    /// The sides of the ring outline's tube.
    nonisolated static let ringSides = 8
    /// The vertical field of view of the camera (60°).
    nonisolated static let fieldOfView = Double.pi / 3
    /// The side margin of the framing (10 % of the row's half width).
    nonisolated static let sideMargin = 1.1
    /// The top and bottom margin of the framing (25 % of the row's half height).
    nonisolated static let heightMargin = 1.25
    /// The planets' ambient light fraction.
    nonisolated static let planetAmbient = 0.25
    /// The direction toward the light: the Sun's side (left), slightly up and toward the camera.
    nonisolated static let lightDirection = Vec3(-1, 0.3, 0.6).normalized

    /// The canvas around the bodies.
    nonisolated static let backgroundColor = Vec4(0.02, 0.025, 0.05, 1)
    /// The ring outline around the selected body.
    nonisolated static let ringColor = Vec4(0.35, 0.8, 1, 1)

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
    /// How many times the nine body renderers were made.
    private(set) var rendererBuildCount = 0
    /// How many times the nine ring renderers were made (with the body renderers; never per selection).
    private(set) var ringBuildCount = 0
    /// How many times the CPU meshes were made (once per presenter).
    private(set) var meshBuildCount = 0
    /// The number of bodies drawn by the last frame.
    private(set) var lastBodiesDrawn = 0
    /// Whether the last frame drew the ring outline.
    private(set) var lastRingDrawn = false
    /// The selection the last frame drew; nil before the first frame.
    private(set) var lastSelection: Int?
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The body meshes with their colours in catalog order; empty until first needed.
    private(set) var bodyMeshes: [(mesh: Mesh, colors: [Vec4])] = []
    /// The body renderers in catalog order; empty after `teardown`.
    private(set) var bodyRenderers: [MeshRenderer] = []
    /// The ring renderers of the nine bodies in catalog order, made once with the body renderers; empty after
    /// `teardown`. All mesh renderers share one cached shader program in the host's registry, and releasing any
    /// renderer releases that program for all of them, so no renderer is released while the others are in use: the
    /// selection only chooses which ring is drawn.
    private(set) var ringRenderers: [MeshRenderer] = []
    /// The ring renderer of the last drawn selection; nil after `teardown` or before the first frame.
    var ringRenderer: MeshRenderer? {
        guard let selection = lastSelection, ringRenderers.indices.contains(selection) else { return nil }
        return ringRenderers[selection]
    }
    /// The depth-correct pass the bodies are drawn through; made in `setup`, released in `teardown`.
    private(set) var depthPass: DepthMeshPass?

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
    }

    // MARK: Render scene

    /// Makes the depth pass and the body renderers with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        releaseGPU()
        depthPass = DepthMeshPass(registry: context.resources)
        try makeBodyRenderers(context)
        isLive = true
    }

    /// Draws the nine bodies lit, with depth, through the fixed camera, and the ring outline on the selected body.
    func draw(_ core: SolarCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        lastCanvas = Vec2(width, height)
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        if bodyRenderers.count != SolarCore.bodyCount { try makeBodyRenderers(context) }
        let selection = core.selection
        if ringRenderers.count != SolarCore.bodyCount { try makeRingRenderers(context) }
        guard let depthPass else { return }
        depthPass.clearColor = Self.backgroundColor
        var items: [DepthMeshPass.Item] = []
        for (index, renderer) in bodyRenderers.enumerated() {
            items.append(DepthMeshPass.Item(renderer: renderer, model: Self.model(index: index),
                                            color: Vec4(1, 1, 1, 1)))
        }
        let bodies = items.count
        if ringRenderers.indices.contains(selection) {
            items.append(DepthMeshPass.Item(renderer: ringRenderers[selection], model: Self.model(index: selection),
                                            color: Self.ringColor))
        }
        try depthPass.draw(items, camera: Self.camera(aspect: width / height), context: context)
        lastBodiesDrawn = bodies
        lastRingDrawn = ringRenderers.indices.contains(selection)
        lastSelection = selection
    }

    /// Releases every GPU object; the CPU meshes stay for the next context.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
        lastBodiesDrawn = 0
        lastRingDrawn = false
    }

    /// Releases the renderers and the depth pass.
    private func releaseGPU() {
        for renderer in bodyRenderers { renderer.release() }
        bodyRenderers = []
        for renderer in ringRenderers { renderer.release() }
        ringRenderers = []
        depthPass?.release()
        depthPass = nil
    }

    /// Makes the nine body renderers (the Sun fully bright, the planets lit from the Sun's side); a failure releases
    /// the renderers made so far and rethrows.
    private func makeBodyRenderers(_ context: RenderContext) throws {
        for renderer in bodyRenderers { renderer.release() }
        bodyRenderers = []
        if bodyMeshes.count != SolarCore.bodyCount {
            bodyMeshes = Self.meshes()
            meshBuildCount += 1
        }
        var made: [MeshRenderer] = []
        do {
            for (index, part) in bodyMeshes.enumerated() {
                let renderer = try MeshRenderer(mesh: part.mesh, colors: part.colors, registry: context.resources)
                renderer.lightDirection = Self.lightDirection
                renderer.ambient = index == 0 ? 1 : Self.planetAmbient
                made.append(renderer)
            }
        } catch {
            for renderer in made { renderer.release() }
            throw error
        }
        bodyRenderers = made
        rendererBuildCount += 1
    }

    /// Makes the nine ring renderers (fully bright), one per body, once; a failure releases those made.
    private func makeRingRenderers(_ context: RenderContext) throws {
        var made: [MeshRenderer] = []
        do {
            for index in 0..<SolarCore.bodyCount {
                let renderer = try MeshRenderer(mesh: try Self.ringMesh(selection: index), registry: context.resources)
                renderer.lightDirection = Self.lightDirection
                renderer.ambient = 1
                made.append(renderer)
            }
        } catch {
            for renderer in made { renderer.release() }
            throw error
        }
        ringRenderers = made
        ringBuildCount += 1
    }

    // MARK: Geometry

    /// The display radius of a body of `radiusKm` and `kind` (clarification Q4): 1.6 for the star; for a planet
    /// 0.25 + 0.15 · log₂(radiusKm / 2,439.7), at least 0.05 (a non-finite or non-positive radius gives 0.25).
    nonisolated static func displayRadius(radiusKm: Double, kind: BodyKind) -> Double {
        if kind == .star { return sunDisplayRadius }
        guard radiusKm.isFinite, radiusKm > 0 else { return basePlanetRadius }
        return max(0.05, basePlanetRadius + radiusPerDoubling * log2(radiusKm / referenceRadiusKm))
    }

    /// The display radius of the catalog body at `index` (0.25 outside the catalog).
    nonisolated static func displayRadius(index: Int) -> Double {
        guard let body = BodyCatalog.bundled.body(at: index) else { return basePlanetRadius }
        return displayRadius(radiusKm: body.meanRadiusKm, kind: body.kind)
    }

    /// The x position of the body at `index`: 0 for the Sun, 1.6 + 2.4 · (index − 0.5) for planet `index` (1…8).
    nonisolated static func xPosition(index: Int) -> Double {
        index <= 0 ? 0 : sunDisplayRadius + spacing * (Double(index) - 0.5)
    }

    /// The centre of the body at `index` on the row.
    nonisolated static func center(index: Int) -> Vec3 { Vec3(xPosition(index: index), 0, 0) }

    /// The model transform of the body at `index` (a translation to its centre; the meshes carry their radius).
    nonisolated static func model(index: Int) -> Mat4 { Mat4.translation(center(index: index)) }

    /// The radius of the ring outline around a body of display radius `displayRadius`: 1.18 · radius + 0.12.
    nonisolated static func ringRadius(displayRadius: Double) -> Double { displayRadius * 1.18 + 0.12 }

    /// The extent of the row on x (the Sun's ring on the left to Neptune's ring on the right) and its half height
    /// (the Sun's ring).
    nonisolated static var rowExtent: (minX: Double, maxX: Double, halfHeight: Double) {
        let last = SolarCore.bodyCount - 1
        let sunRing = ringRadius(displayRadius: sunDisplayRadius)
        return (-sunRing, xPosition(index: last) + ringRadius(displayRadius: displayRadius(index: last)), sunRing)
    }

    /// The fixed camera at canvas aspect `aspect` (width / height): looking from +z at the middle of the row, at the
    /// smallest distance that fits the row's half width × 1.1 and half height × 1.25.
    nonisolated static func camera(aspect: Double) -> OrbitCamera {
        let a = aspect.isFinite && aspect > 0 ? aspect : 1
        let extent = rowExtent
        let halfWidth = (extent.maxX - extent.minX) / 2
        let t = tan(fieldOfView / 2)
        let distance = max(halfWidth * sideMargin / (t * a), extent.halfHeight * heightMargin / t)
        return OrbitCamera(target: Vec3((extent.minX + extent.maxX) / 2, 0, 0), distance: distance, yaw: 0, pitch: 0,
                           fovY: fieldOfView, near: 0.1, far: 1000)
    }

    /// The pixel (x from the left, y from the bottom, as the host reads frames back) where the world point `point` is
    /// drawn on a canvas of `canvas` pixels.
    nonisolated static func pixel(of point: Vec3, canvas: Vec2) -> Vec2 {
        let width = max(canvas.x, 1), height = max(canvas.y, 1)
        let ndc = camera(aspect: width / height).project(point, aspect: width / height)
        return Vec2((ndc.x + 1) / 2 * width, (ndc.y + 1) / 2 * height)
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

    /// The nine sphere meshes of the catalog with their colours.
    nonisolated static func meshes() -> [(mesh: Mesh, colors: [Vec4])] {
        var parts: [(mesh: Mesh, colors: [Vec4])] = []
        for index in 0..<SolarCore.bodyCount {
            let mesh = Mesh.uvSphere(segments: sphereSegments, rings: sphereRings, radius: displayRadius(index: index))
            parts.append((mesh, colors(mesh: mesh, index: index)))
        }
        return parts
    }

    /// The ring outline around the body `selection`, centred on the origin: a closed tube along a circle in the x–y
    /// plane.
    nonisolated static func ringMesh(selection: Int) throws -> Mesh {
        let radius = ringRadius(displayRadius: displayRadius(index: selection))
        var path: [Vec3] = []
        for i in 0..<ringPoints {
            let angle = 2 * Double.pi * Double(i) / Double(ringPoints)
            path.append(Vec3(cos(angle) * radius, sin(angle) * radius, 0))
        }
        return try Mesh.tube(path: path, radius: ringTubeRadius, sides: ringSides, caps: false, closed: true)
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
    /// `aspect`: the band colours of the equator's vertex row and of the rows above and below it (the pixel there
    /// blends them), each times ambient + (1 − ambient) · Lambert, the normal pointing from the body's centre to the
    /// eye.
    nonisolated static func centerColors(index: Int, aspect: Double) -> [Vec3] {
        let palette = palettes[min(max(index, 0), palettes.count - 1)]
        let ambient = index == 0 ? 1 : planetAmbient
        let normal = (camera(aspect: aspect).eye - center(index: index)).normalized
        let lambert = max(0, normal.dot(lightDirection))
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
        var probes: [FrameProbe] = []
        if let background = FrameProbe(name: "background", x: 0.5, y: 0.04, expected: FrameColorClass.dark.rawValue) {
            probes.append(background)
        }
        let selection = core.selection
        let p = Self.pixel(of: Self.center(index: selection), canvas: canvas)
        if let expected = Self.robustClass(Self.centerColors(index: selection, aspect: canvas.x / canvas.y)),
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
        if mirror.selection != core.selection { mirror.selection = core.selection }
        let name = core.body?.name ?? ""
        if mirror.bodyName != name { mirror.bodyName = name }
        let facts = Self.factLines(core.factCard)
        if mirror.facts != facts { mirror.facts = facts }
        let status = SolarCore.status(selection: core.selection)
        if mirror.status != status { mirror.status = status }
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
        default: return "That is not possible here."
        }
    }

    /// The description of `core`'s line-up.
    func describe(_ core: SolarCore) -> String {
        sync(core)
        return core.canvasDescription
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(SolarControls(port: port, mirror: mirror))
    }

    /// The actions the native controls send: every action (Previous body, Next body and the Body menu); there is no
    /// canvas gesture in this phase.
    var nativeActions: Set<String> {
        ["body.select", "body.next", "body.previous"]
    }
}
