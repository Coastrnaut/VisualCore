// MoleculePresenter — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; SC-A15-104). Draws Molecular
// Explorer through the host only (the host's context and registry, VisualCore's `DepthMeshPass` and `MeshRenderer`
// with an `OrbitCamera`; no context of its own, no second renderer, no imported assets). The presenter reads the core
// and never writes it:
//   - Atoms: every atom of the selected molecule is a UV sphere (`Mesh.uvSphere(segments: 32, rings: 16, radius:)`)
//     at its recorded position (ångström used as scene units) with display radius 0.35 × its element's van der Waals
//     radius (``MoleculePresenter/displayRadius(symbol:)``), drawn in its element's display colour (the draw colour of
//     the item; the meshes carry no colour stream). Recorded bonds are counted in the words, drawn from A15-P02.
//   - Meshes: one sphere per catalog element (ten, in `Elements.all` order), made once per presenter as CPU data and
//     kept across context recreations; an atom picks its element's mesh.
//   - Renderers: one `MeshRenderer` per element sphere, all ten made together in `setup` once the context is current
//     (again after a context recreation; `draw` makes them all again if any is missing) and all released together in
//     `teardown`. Every mesh renderer shares one cached shader program in the host's registry and releasing a renderer
//     releases that program for all of them, so no renderer is ever released while the others are in use.
//   - Light from the camera's side: every renderer lights toward ``MoleculePresenter/lightDirection`` (the camera's
//     direction turned a little up and to the right) with ambient 0.3.
//   - Camera: an `OrbitCamera` (yaw 0.6, pitch 0.35, so a planar molecule is never seen edge-on along an axis, 60°
//     vertical field of view) whose target is the molecule's centre (the mean of its atom positions) and whose
//     distance fits the bounding sphere (the largest distance from the centre to an atom plus that atom's display
//     radius) with a 25 % margin inside the narrower of the vertical and the horizontal field of view
//     (``MoleculePresenter/camera(for:aspect:)``), so every atom is in view at every aspect. Nothing moves; there is
//     no gesture in this phase.
//   - Background: a dark canvas (``MoleculePresenter/backgroundColor``).
//   - Probes: the background at (0.5, 0.04) from the top left (always outside the bounding sphere: its projection
//     stays within 76 % of the half height) expected dark, and the centre of the frontmost atom (the smallest distance
//     from the eye minus the display radius, so nothing covers its centre) with the colour class of its element colour
//     under the light there, when that class is robust at 0.7…1.3 times the brightness (oxygen: red; nitrogen: blue).
//   - Words: the canvas description of `MoleculeCore`; the mirror holds the name and formula line, the counts line,
//     the source line, the status and the answer to a refused action for the controls.
// There is no motion, so Reduce Motion changes nothing; nothing flashes. No audio.
import Foundation
import MolecularExplorerCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class MoleculeMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The selected molecule's index, 0 (water) … 4 (caffeine).
    var selection = 0
    /// The number of molecules.
    var moleculeCount = MoleculeCore.moleculeCount
    /// The name and formula line ("Caffeine — C8H10N4O2").
    var nameLine = ""
    /// The counts line ("24 atoms, 25 bonds").
    var countsLine = ""
    /// The source line ("PubChem Compound CID 2519, 3D conformer — public domain").
    var sourceLine = ""
    /// The status line ("Caffeine selected, molecule 5 of 5").
    var status = ""
    /// The answer to the last refused action; empty after an accepted one.
    var message = ""
}

/// Draws Molecular Explorer and owns its presentation state (meshes, renderers and the depth pass).
@MainActor
final class MoleculePresenter: ExperiencePresenter {
    /// The display radius as a fraction of the van der Waals radius (clarification Q5).
    nonisolated static let displayScale = 0.35
    /// Longitude segments of each sphere.
    nonisolated static let sphereSegments = 32
    /// Latitude rings of each sphere.
    nonisolated static let sphereRings = 16
    /// The vertical field of view of the camera (60°).
    nonisolated static let fieldOfView = Double.pi / 3
    /// The framing margin: the bounding sphere fills at most 1 / 1.25 of the narrower field of view's half angle sine.
    nonisolated static let margin = 1.25
    /// The camera's yaw, radians.
    nonisolated static let cameraYaw = 0.6
    /// The camera's pitch, radians.
    nonisolated static let cameraPitch = 0.35
    /// The atoms' ambient light fraction.
    nonisolated static let ambient = 0.3
    /// The direction toward the light: the camera's direction turned 0.35 rad to the right and 0.35 rad up.
    nonisolated static let lightDirection: Vec3 = {
        let yaw = cameraYaw + 0.35, pitch = cameraPitch + 0.35
        return Vec3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)).normalized
    }()
    /// The canvas around the molecule.
    nonisolated static let backgroundColor = Vec4(0.03, 0.035, 0.06, 1)

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = MoleculeMirror()

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// How many times the element renderers were made (all ten together each time).
    private(set) var rendererBuildCount = 0
    /// How many times the CPU meshes were made (once per presenter).
    private(set) var meshBuildCount = 0
    /// The number of atoms drawn by the last frame.
    private(set) var lastAtomsDrawn = 0
    /// The selection the last frame drew; nil before the first frame.
    private(set) var lastSelection: Int?
    /// The camera target (the molecule's centre) of the last frame; nil before the first frame.
    private(set) var lastCenter: Vec3?
    /// The camera distance of the last frame; nil before the first frame.
    private(set) var lastCameraDistance: Double?
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The element sphere meshes in `Elements.all` order; empty until first needed.
    private(set) var elementMeshes: [Mesh] = []
    /// The element renderers in `Elements.all` order, made and released all together; empty after `teardown`.
    private(set) var elementRenderers: [MeshRenderer] = []
    /// The depth-correct pass the atoms are drawn through; made in `setup`, released in `teardown`.
    private(set) var depthPass: DepthMeshPass?

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
    }

    // MARK: Render scene

    /// Makes the depth pass and all element renderers with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        releaseGPU()
        depthPass = DepthMeshPass(registry: context.resources)
        try makeRenderers(context)
        isLive = true
    }

    /// Draws the selected molecule's atoms lit, with depth, through the camera fitted to its bounding sphere.
    func draw(_ core: MoleculeCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        lastCanvas = Vec2(width, height)
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        if elementRenderers.count != Elements.all.count {
            // Something is missing: release them all together and make them all again (never one at a time).
            releaseRenderers()
            try makeRenderers(context)
        }
        guard let depthPass, let molecule = core.molecule else { return }
        depthPass.clearColor = Self.backgroundColor
        var items: [DepthMeshPass.Item] = []
        items.reserveCapacity(molecule.atoms.count)
        for atom in molecule.atoms {
            guard let index = Self.elementIndex(symbol: atom.symbol), elementRenderers.indices.contains(index) else {
                continue
            }
            items.append(DepthMeshPass.Item(renderer: elementRenderers[index],
                                            model: Mat4.translation(Self.position(atom)),
                                            color: Self.color(hex: Elements.all[index].colorHex)))
        }
        let camera = Self.camera(for: molecule, aspect: width / height)
        try depthPass.draw(items, camera: camera, context: context)
        lastAtomsDrawn = items.count
        lastSelection = core.selection
        lastCenter = camera.target
        lastCameraDistance = camera.distance
    }

    /// Releases every GPU object; the CPU meshes stay for the next context.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
        lastAtomsDrawn = 0
    }

    /// Releases the renderers and the depth pass.
    private func releaseGPU() {
        releaseRenderers()
        depthPass?.release()
        depthPass = nil
    }

    /// Releases every element renderer, all together.
    private func releaseRenderers() {
        for renderer in elementRenderers { renderer.release() }
        elementRenderers = []
    }

    /// Makes the ten element renderers together (lit from the camera's side); a failure releases the renderers made
    /// so far and rethrows.
    private func makeRenderers(_ context: RenderContext) throws {
        if elementMeshes.count != Elements.all.count {
            elementMeshes = Self.meshes()
            meshBuildCount += 1
        }
        var made: [MeshRenderer] = []
        do {
            for mesh in elementMeshes {
                let renderer = try MeshRenderer(mesh: mesh, registry: context.resources)
                renderer.lightDirection = Self.lightDirection
                renderer.ambient = Self.ambient
                made.append(renderer)
            }
        } catch {
            for renderer in made { renderer.release() }
            throw error
        }
        elementRenderers = made
        rendererBuildCount += 1
    }

    // MARK: Geometry

    /// The index of the element `symbol` in `Elements.all`, or nil outside the catalog.
    nonisolated static func elementIndex(symbol: String) -> Int? {
        guard let element = Elements.element(symbol: symbol) else { return nil }
        return Elements.all.firstIndex(of: element)
    }

    /// The display radius of an atom of `symbol`: 0.35 × the element's van der Waals radius (ångström as scene
    /// units); 0.35 × 1.5 for a symbol outside the catalog (never for a validated molecule).
    nonisolated static func displayRadius(symbol: String) -> Double {
        displayScale * (Elements.element(symbol: symbol)?.vanDerWaalsRadius ?? 1.5)
    }

    /// The ten element sphere meshes in `Elements.all` order.
    nonisolated static func meshes() -> [Mesh] {
        var meshes: [Mesh] = []
        for element in Elements.all {
            meshes.append(Mesh.uvSphere(segments: sphereSegments, rings: sphereRings,
                                        radius: displayScale * element.vanDerWaalsRadius))
        }
        return meshes
    }

    /// The position of `atom` in scene units (ångström).
    nonisolated static func position(_ atom: Atom) -> Vec3 { Vec3(atom.x, atom.y, atom.z) }

    /// The centre of `molecule`: the mean of its atom positions (the origin for no atom).
    nonisolated static func center(of molecule: Molecule) -> Vec3 {
        guard !molecule.atoms.isEmpty else { return Vec3(0, 0, 0) }
        var sum = Vec3(0, 0, 0)
        for atom in molecule.atoms { sum = sum + position(atom) }
        return sum * (1 / Double(molecule.atoms.count))
    }

    /// The radius of `molecule`'s bounding sphere around its centre: the largest distance from the centre to an atom
    /// plus that atom's display radius.
    nonisolated static func boundingRadius(of molecule: Molecule) -> Double {
        let c = center(of: molecule)
        var radius = 0.0
        for atom in molecule.atoms {
            radius = max(radius, (position(atom) - c).length + displayRadius(symbol: atom.symbol))
        }
        return radius
    }

    /// The camera for `molecule` at canvas aspect `aspect` (width / height): looking at its centre from yaw 0.6 and
    /// pitch 0.35, at the distance where the bounding sphere × 1.25 just fits the narrower half angle of the vertical
    /// and the horizontal field of view.
    nonisolated static func camera(for molecule: Molecule, aspect: Double) -> OrbitCamera {
        let a = aspect.isFinite && aspect > 0 ? aspect : 1
        let halfVertical = fieldOfView / 2
        let halfHorizontal = atan(tan(halfVertical) * a)
        let half = min(halfVertical, halfHorizontal)
        let radius = max(boundingRadius(of: molecule), 0.1)
        let distance = radius * margin / sin(half)
        return OrbitCamera(target: center(of: molecule), distance: distance, yaw: cameraYaw, pitch: cameraPitch,
                           fovY: fieldOfView, near: 0.05, far: distance + 2 * radius + 10)
    }

    /// The pixel (x from the left, y from the bottom, as the host reads frames back) where the world point `point` is
    /// drawn for `molecule` on a canvas of `canvas` pixels.
    nonisolated static func pixel(of point: Vec3, molecule: Molecule, canvas: Vec2) -> Vec2 {
        let width = max(canvas.x, 1), height = max(canvas.y, 1)
        let ndc = camera(for: molecule, aspect: width / height).project(point, aspect: width / height)
        return Vec2((ndc.x + 1) / 2 * width, (ndc.y + 1) / 2 * height)
    }

    /// The colour (RGB 0…1, alpha 1) of six hex digits ("FF0D0D"); mid grey for text that is not six hex digits.
    nonisolated static func color(hex: String) -> Vec4 {
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return Vec4(0.5, 0.5, 0.5, 1) }
        return Vec4(Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255,
                    1)
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

    /// The colour class of `color` (channels 0…1) when it is robust: the same class at every brightness 0.7…1.3
    /// times and every channel moved by up to 3 of 255; nil otherwise.
    nonisolated static func robustClass(_ color: Vec3) -> String? {
        var classes: Set<String> = []
        let scales: [Double] = [0.7, 0.85, 1, 1.15, 1.3]
        let nudges: [Int] = [-3, 0, 3]
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
        return classes.count == 1 ? classes.first : nil
    }

    /// The index of the frontmost atom of `molecule` seen through the camera of `aspect`: the smallest distance from
    /// the eye minus the display radius (no other sphere covers its centre); nil for no atom.
    nonisolated static func frontmostAtom(_ molecule: Molecule, aspect: Double) -> Int? {
        let eye = camera(for: molecule, aspect: aspect).eye
        var best: (index: Int, depth: Double)?
        for (index, atom) in molecule.atoms.enumerated() {
            let depth = (position(atom) - eye).length - displayRadius(symbol: atom.symbol)
            if let current = best, depth >= current.depth { continue }
            best = (index, depth)
        }
        return best?.index
    }

    /// The lit colour (RGB 0…1) at the visible centre of atom `index` of `molecule` through the camera of `aspect`:
    /// the element colour times ambient + (1 − ambient) · Lambert, the normal pointing from the atom to the eye.
    nonisolated static func centerColor(_ molecule: Molecule, index: Int, aspect: Double) -> Vec3 {
        let atom = molecule.atoms[index]
        let base = color(hex: Elements.element(symbol: atom.symbol)?.colorHex ?? "")
        let normal = (camera(for: molecule, aspect: aspect).eye - position(atom)).normalized
        let f = ambient + (1 - ambient) * max(0, normal.dot(lightDirection))
        return Vec3(base.x * f, base.y * f, base.z * f)
    }

    /// The probes of `core` on the last canvas (see the file header); none before the first frame.
    func probes(_ core: MoleculeCore) -> [FrameProbe] {
        guard let canvas = lastCanvas else { return [] }
        var probes: [FrameProbe] = []
        if let background = FrameProbe(name: "background", x: 0.5, y: 0.04, expected: FrameColorClass.dark.rawValue) {
            probes.append(background)
        }
        guard let molecule = core.molecule else { return probes }
        let aspect = canvas.x / canvas.y
        if let index = Self.frontmostAtom(molecule, aspect: aspect),
           let expected = Self.robustClass(Self.centerColor(molecule, index: index, aspect: aspect)) {
            let p = Self.pixel(of: Self.position(molecule.atoms[index]), molecule: molecule, canvas: canvas)
            if let probe = FrameProbe(name: "atom-\(index)", x: p.x / canvas.x, y: 1 - p.y / canvas.y,
                                      expected: expected) {
                probes.append(probe)
            }
        }
        return probes
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: MoleculeCore) {
        if !mirror.ready { mirror.ready = true }
        let selection = core.selection
        if mirror.selection != selection { mirror.selection = selection }
        let name = MoleculeCore.nameLine(index: selection)
        if mirror.nameLine != name { mirror.nameLine = name }
        let counts = MoleculeCore.countsLine(index: selection)
        if mirror.countsLine != counts { mirror.countsLine = counts }
        let source = MoleculeCore.sourceLine(index: selection)
        if mirror.sourceLine != source { mirror.sourceLine = source }
        let status = MoleculeCore.status(selection: selection)
        if mirror.status != status { mirror.status = status }
    }

    /// The answer to `result` of `control`: empty when accepted, else why it was refused.
    nonisolated static func answerWords(control: String, result: ActionResult) -> String {
        guard !result.isAccepted else { return "" }
        switch control {
        case "molecule.next": return "Caffeine is the last molecule."
        case "molecule.previous": return "Water is the first molecule."
        case "molecule.select": return "There is no such molecule."
        default: return "That is not possible here."
        }
    }

    /// Sends `control` with `values` through `port` and shows the answer in the mirror (empty when accepted).
    @discardableResult
    func send(_ control: String, _ values: [Double] = [], through port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.message = Self.answerWords(control: control, result: result)
        return result
    }

    /// The description of `core`'s molecule.
    func describe(_ core: MoleculeCore) -> String {
        sync(core)
        return core.canvasDescription
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MoleculeControls(port: port, mirror: mirror, presenter: self))
    }

    /// The actions the native controls send: every action (Previous molecule, Next molecule and the Molecule menu);
    /// there is no canvas gesture in this phase.
    var nativeActions: Set<String> {
        ["molecule.select", "molecule.next", "molecule.previous"]
    }
}
