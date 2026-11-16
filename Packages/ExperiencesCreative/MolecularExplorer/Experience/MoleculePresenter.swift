// MoleculePresenter — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; SC-A15-104) and feature 111
// (A15-P02) T-A15-205 (FR-A15-202, FR-A15-210, FR-A15-220, FR-A15-230; clarifications Q2–Q5; SC-A15-202, SC-A15-203;
// contracts/renderer.md). Draws Molecular Explorer through the host only (the host's context and registry,
// VisualCore's `DepthMeshPass` and `MeshRenderer` with an `OrbitCamera`; no context of its own, no second renderer, no
// imported assets). The presenter reads the core and never writes it:
//   - Scene: the core state's `MoleculeScene` (the selected molecule in the display mode): one atom item per atom and,
//     in ball-and-stick, two bond halves per bond; exactly the scene's items are drawn (at most 74 for the library,
//     within the draw budget of 1,500).
//   - Meshes: ONE unit sphere (`Mesh.uvSphere(segments: 32, rings: 16, radius: 1)`) and ONE unit stick
//     (`Mesh.tube(path: [(0, 0, 0), (0, 1, 0)], radius: DisplayMode.stickRadius, sides: 16, caps: false,
//     closed: false)`), made together once per presenter as CPU data and kept across context recreations.
//   - Model matrices: an atom is the unit sphere scaled uniformly by its display radius and moved to its position
//     (translate(position) × scale(radius)); a bond half is the unit stick turned from +y onto the half's direction
//     (the shortest-arc quaternion; a half along −y turns half a revolution about x), scaled along y only by the half's
//     length and moved to its start (translate(from) × rotate × scale(1, length, 1)). The mesh shader turns normals by
//     the model's 3 × 3 part and normalises them, so the uniform scale and the stretch along the stick's own axis (its
//     side normals have no axial part) keep the lighting right. Each item is drawn in its element's display colour.
//   - Renderers: the sphere and the stick `MeshRenderer`, both made together in `setup` once the context is current
//     (again after a context recreation; `draw` makes both again if either is missing) and both released together in
//     `teardown`. Every mesh renderer shares one cached shader program in the host's registry and releasing a renderer
//     releases that program for all of them, so no renderer is ever released while the other is in use.
//   - Camera: `state.camera.camera(centre:boundingRadius:aspect:)` of the scene's centre and bounding radius at the
//     canvas aspect (turn 15° and tilt 10° steps, zoom 0.85 per step of the framed distance; clarification Q3), so the
//     molecule's centre is always drawn at the canvas centre and, at zoom 0 or farther, every atom is in view.
//   - Light from the camera's side: both renderers light toward ``MoleculePresenter/lightDirection(for:)`` (the
//     camera's direction turned 0.35 rad to the right and 0.35 rad up) with ambient 0.3.
//   - Background: a dark canvas (``MoleculePresenter/backgroundColor``).
//   - Probes: the background at (0.5, 0.04) from the top left, expected dark, whenever the ray through it passes every
//     atom and stick with a margin (always at zoom 0 or farther, where the bounding sphere stays within 76 % of the
//     half height), and the centre of the frontmost atom (the smallest distance
//     from the eye minus the display radius, so no other sphere covers its centre) with the colour class of its element
//     colour under the light there, when that class is robust at 0.7…1.3 times the brightness (oxygen: red; nitrogen:
//     blue).
//   - Words: the canvas description of `MoleculeCore` (ending with the mode); the mirror holds the name and formula
//     line, the counts line, the source line, the status, the mode and its legend ("Display radii, not measured
//     sizes"), the camera in words ("Turned 30°, tilted 20°", "Zoom step 0 of −4 to 4") and the answer to a refused
//     action for the controls.
// Camera steps, resets and molecule changes cut to the new view in one frame (no animated move), so Reduce Motion
// changes nothing; nothing flashes. No audio.
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
    /// The display mode.
    var mode = DisplayMode.ballAndStick
    /// The legend of the mode, ending with "Display radii, not measured sizes."
    var legend = ""
    /// The camera's turn steps, 0…23.
    var turnSteps = CameraSettings.default.turnSteps
    /// The camera's tilt steps, −8…8.
    var tiltSteps = CameraSettings.default.tiltSteps
    /// The camera's zoom steps, −4…4.
    var zoomSteps = CameraSettings.default.zoomSteps
    /// The turn and tilt in words ("Turned 30°, tilted 20°").
    var cameraWords = ""
    /// The zoom in words ("Zoom step 0 of −4 to 4").
    var zoomWords = ""
    /// The answer to the last refused action; empty after an accepted one.
    var message = ""
}

/// Draws Molecular Explorer and owns its presentation state (meshes, renderers and the depth pass).
@MainActor
final class MoleculePresenter: ExperiencePresenter {
    /// Longitude segments of the unit sphere.
    nonisolated static let sphereSegments = 32
    /// Latitude rings of the unit sphere.
    nonisolated static let sphereRings = 16
    /// Sides of the unit stick.
    nonisolated static let stickSides = 16
    /// The atoms' and sticks' ambient light fraction.
    nonisolated static let ambient = 0.3
    /// The light's turn to the right and up from the camera's direction, radians.
    nonisolated static let lightOffset = 0.35
    /// The canvas around the molecule.
    nonisolated static let backgroundColor = Vec4(0.03, 0.035, 0.06, 1)
    /// The legend's closing sentence (clarification Q2).
    nonisolated static let legendNote = "Display radii, not measured sizes."

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = MoleculeMirror()

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// How many times the renderers were made (sphere and stick together each time).
    private(set) var rendererBuildCount = 0
    /// How many times the CPU meshes were made (once per presenter).
    private(set) var meshBuildCount = 0
    /// The number of atoms drawn by the last frame.
    private(set) var lastAtomsDrawn = 0
    /// The number of bond halves drawn by the last frame.
    private(set) var lastHalvesDrawn = 0
    /// The number of items (atoms plus halves) drawn by the last frame.
    private(set) var lastItemCount = 0
    /// The selection the last frame drew; nil before the first frame.
    private(set) var lastSelection: Int?
    /// The display mode the last frame drew; nil before the first frame.
    private(set) var lastMode: DisplayMode?
    /// The camera of the last frame; nil before the first frame.
    private(set) var lastCamera: OrbitCamera?
    /// The camera target (the scene's centre) of the last frame; nil before the first frame.
    private(set) var lastCenter: Vec3?
    /// The camera distance of the last frame; nil before the first frame.
    private(set) var lastCameraDistance: Double?
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The unit sphere mesh; nil until first needed.
    private(set) var sphereMesh: Mesh?
    /// The unit stick mesh; nil until first needed.
    private(set) var stickMesh: Mesh?
    /// The renderers, sphere first and stick second, made and released together; empty after `teardown`.
    private(set) var renderers: [MeshRenderer] = []
    /// The depth-correct pass the items are drawn through; made in `setup`, released in `teardown`.
    private(set) var depthPass: DepthMeshPass?

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
    }

    // MARK: Render scene

    /// Makes the depth pass and both renderers with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        releaseGPU()
        depthPass = DepthMeshPass(registry: context.resources)
        try makeRenderers(context)
        isLive = true
    }

    /// Draws the state's scene lit, with depth, through the state's camera framed on the scene.
    func draw(_ core: MoleculeCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        lastCanvas = Vec2(width, height)
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        if renderers.count != 2 {
            // Something is missing: release both together and make both again (never one at a time).
            releaseRenderers()
            try makeRenderers(context)
        }
        guard let depthPass, let scene = core.state.scene else { return }
        let sphere = renderers[0], stick = renderers[1]
        let camera = Self.camera(core.state, scene: scene, aspect: width / height)
        let light = Self.lightDirection(for: camera)
        sphere.lightDirection = light
        stick.lightDirection = light
        depthPass.clearColor = Self.backgroundColor
        var items: [DepthMeshPass.Item] = []
        items.reserveCapacity(scene.itemCount)
        for atom in scene.atoms {
            items.append(DepthMeshPass.Item(renderer: sphere, model: Self.atomModel(atom),
                                            color: Self.color(symbol: atom.symbol)))
        }
        let atoms = items.count
        for half in scene.bondHalves {
            guard let model = Self.halfModel(half) else { continue }
            items.append(DepthMeshPass.Item(renderer: stick, model: model, color: Self.color(symbol: half.symbol)))
        }
        try depthPass.draw(items, camera: camera, context: context)
        lastAtomsDrawn = atoms
        lastHalvesDrawn = items.count - atoms
        lastItemCount = items.count
        lastSelection = core.selection
        lastMode = core.mode
        lastCamera = camera
        lastCenter = camera.target
        lastCameraDistance = camera.distance
    }

    /// Releases every GPU object; the CPU meshes stay for the next context.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
        lastAtomsDrawn = 0
        lastHalvesDrawn = 0
        lastItemCount = 0
    }

    /// Releases the renderers and the depth pass.
    private func releaseGPU() {
        releaseRenderers()
        depthPass?.release()
        depthPass = nil
    }

    /// Releases both renderers, together.
    private func releaseRenderers() {
        for renderer in renderers { renderer.release() }
        renderers = []
    }

    /// Makes the sphere and the stick renderer together (ambient 0.3); a failure releases the renderer made so far
    /// and rethrows.
    private func makeRenderers(_ context: RenderContext) throws {
        if sphereMesh == nil || stickMesh == nil {
            sphereMesh = Self.unitSphere()
            stickMesh = try Self.unitStick()
            meshBuildCount += 1
        }
        guard let sphereMesh, let stickMesh else { return }
        var made: [MeshRenderer] = []
        do {
            for mesh in [sphereMesh, stickMesh] {
                let renderer = try MeshRenderer(mesh: mesh, registry: context.resources)
                renderer.ambient = Self.ambient
                made.append(renderer)
            }
        } catch {
            for renderer in made { renderer.release() }
            throw error
        }
        renderers = made
        rendererBuildCount += 1
    }

    // MARK: Geometry

    /// The unit sphere: radius 1, 32 × 16.
    nonisolated static func unitSphere() -> Mesh {
        Mesh.uvSphere(segments: sphereSegments, rings: sphereRings, radius: 1)
    }

    /// The unit stick: from the origin to (0, 1, 0), radius `DisplayMode.stickRadius`, 16 sides, open, no caps.
    nonisolated static func unitStick() throws -> Mesh {
        try Mesh.tube(path: [Vec3(0, 0, 0), Vec3(0, 1, 0)], radius: DisplayMode.stickRadius, sides: stickSides,
                      caps: false, closed: false)
    }

    /// The model matrix of `atom`: translate(position) × scale(radius).
    nonisolated static func atomModel(_ atom: MoleculeScene.AtomItem) -> Mat4 {
        Mat4.translation(atom.position) * Mat4.scale(Vec3(atom.radius, atom.radius, atom.radius))
    }

    /// The model matrix of `half`: translate(from) × rotate(+y onto the half's direction) × scale(1, length, 1); nil
    /// for a half without length or with a non-finite end.
    nonisolated static func halfModel(_ half: MoleculeScene.BondHalf) -> Mat4? {
        let d = half.to - half.from
        let length = d.length
        guard length.isFinite, length > 1e-9 else { return nil }
        let rotation = rotationFromUp(to: d * (1 / length))
        return Mat4.translation(half.from) * Mat4.rotation(rotation) * Mat4.scale(Vec3(1, length, 1))
    }

    /// The shortest-arc rotation turning +y onto the unit vector `direction`: the identity along +y, half a
    /// revolution about x along −y.
    nonisolated static func rotationFromUp(to direction: Vec3) -> Quat {
        let up = Vec3(0, 1, 0)
        let c = min(max(up.dot(direction), -1), 1)
        if c > 1 - 1e-12 { return .identity }
        if c < -1 + 1e-12 { return Quat(axis: Vec3(1, 0, 0), angle: .pi) }
        return Quat(axis: up.cross(direction), angle: acos(c))
    }

    /// The camera of `state` framed on `scene` at canvas aspect `aspect` (width / height).
    nonisolated static func camera(_ state: MoleculeState, scene: MoleculeScene, aspect: Double) -> OrbitCamera {
        state.camera.camera(centre: scene.centre, boundingRadius: scene.boundingRadius, aspect: aspect)
    }

    /// The direction toward the light for `camera`: its direction from the target turned 0.35 rad to the right and
    /// 0.35 rad up (the elevation kept within ±85°).
    nonisolated static func lightDirection(for camera: OrbitCamera) -> Vec3 {
        let yaw = camera.yaw + lightOffset
        let pitch = min(max(camera.pitch + lightOffset, -85 * Double.pi / 180), 85 * Double.pi / 180)
        return Vec3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)).normalized
    }

    /// The pixel (x from the left, y from the bottom, as the host reads frames back) where the world point `point` is
    /// drawn through `camera` on a canvas of `canvas` pixels.
    nonisolated static func pixel(of point: Vec3, camera: OrbitCamera, canvas: Vec2) -> Vec2 {
        let width = max(canvas.x, 1), height = max(canvas.y, 1)
        let ndc = camera.project(point, aspect: width / height)
        return Vec2((ndc.x + 1) / 2 * width, (ndc.y + 1) / 2 * height)
    }

    /// The display colour of the element `symbol`; mid grey outside the catalog.
    nonisolated static func color(symbol: String) -> Vec4 {
        color(hex: Elements.element(symbol: symbol)?.colorHex ?? "")
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

    /// The index of the frontmost atom of `scene` seen through `camera`: the smallest distance from the eye minus the
    /// display radius (no other sphere covers its centre); nil for no atom.
    nonisolated static func frontmostAtom(_ scene: MoleculeScene, camera: OrbitCamera) -> Int? {
        let eye = camera.eye
        var best: (index: Int, depth: Double)?
        for (index, atom) in scene.atoms.enumerated() {
            let depth = (atom.position - eye).length - atom.radius
            if let current = best, depth >= current.depth { continue }
            best = (index, depth)
        }
        return best?.index
    }

    /// True when the ray from `origin` along the unit `direction` passes every atom of `scene` farther than 1.1 × its
    /// radius + 0.05 and every bond half (sampled at 17 points) farther than 1.1 × its radius + 0.05.
    nonisolated static func rayMisses(origin: Vec3, direction: Vec3, scene: MoleculeScene) -> Bool {
        /// The distance from `point` to the ray.
        func distance(_ point: Vec3) -> Double {
            let v = point - origin
            return (v - direction * max(v.dot(direction), 0)).length
        }
        for atom in scene.atoms where distance(atom.position) <= atom.radius * 1.1 + 0.05 { return false }
        for half in scene.bondHalves {
            for k in 0...16 {
                let point = half.from + (half.to - half.from) * (Double(k) / 16)
                if distance(point) <= half.radius * 1.1 + 0.05 { return false }
            }
        }
        return true
    }

    /// The lit colour (RGB 0…1) at the visible centre of atom `index` of `scene` through `camera`: the element colour
    /// times ambient + (1 − ambient) · Lambert, the normal pointing from the atom to the eye.
    nonisolated static func centerColor(_ scene: MoleculeScene, index: Int, camera: OrbitCamera) -> Vec3 {
        let atom = scene.atoms[index]
        let base = color(symbol: atom.symbol)
        let normal = (camera.eye - atom.position).normalized
        let f = ambient + (1 - ambient) * max(0, normal.dot(lightDirection(for: camera)))
        return Vec3(base.x * f, base.y * f, base.z * f)
    }

    /// The probes of `core` on the last canvas (see the file header); none before the first frame.
    func probes(_ core: MoleculeCore) -> [FrameProbe] {
        guard let canvas = lastCanvas else { return [] }
        var probes: [FrameProbe] = []
        guard let scene = core.state.scene else {
            if let background = FrameProbe(name: "background", x: 0.5, y: 0.04,
                                           expected: FrameColorClass.dark.rawValue) {
                probes.append(background)
            }
            return probes
        }
        let aspect = canvas.x / canvas.y
        let camera = Self.camera(core.state, scene: scene, aspect: aspect)
        let ray = camera.ray(ndc: Vec2(0, 1 - 2 * 0.04), aspect: aspect)
        if Self.rayMisses(origin: ray.origin, direction: ray.direction, scene: scene),
           let background = FrameProbe(name: "background", x: 0.5, y: 0.04, expected: FrameColorClass.dark.rawValue) {
            probes.append(background)
        }
        if let index = Self.frontmostAtom(scene, camera: camera),
           let expected = Self.robustClass(Self.centerColor(scene, index: index, camera: camera)) {
            let p = Self.pixel(of: scene.atoms[index].position, camera: camera, canvas: canvas)
            if p.x > 0, p.x < canvas.x, p.y > 0, p.y < canvas.y,
               let probe = FrameProbe(name: "atom-\(index)", x: p.x / canvas.x, y: 1 - p.y / canvas.y,
                                      expected: expected) {
                probes.append(probe)
            }
        }
        return probes
    }

    // MARK: Words and controls

    /// `value` with a true minus sign when negative ("−20").
    nonisolated static func signed(_ value: Int) -> String {
        value < 0 ? "\u{2212}\(-value)" : "\(value)"
    }

    /// The turn and tilt of `camera` in words: "Turned 30°, tilted 20°".
    nonisolated static func cameraWords(_ camera: CameraSettings) -> String {
        "Turned \(camera.turnDegrees)°, tilted \(signed(camera.tiltDegrees))°"
    }

    /// The zoom of `camera` in words: "Zoom step 0 of −4 to 4".
    nonisolated static func zoomWords(_ camera: CameraSettings) -> String {
        "Zoom step \(signed(camera.zoomSteps)) of \(signed(CameraSettings.zoomRange.lowerBound)) to "
            + "\(CameraSettings.zoomRange.upperBound)"
    }

    /// The name of `mode` on its control: "Ball and stick" or "Space filling".
    nonisolated static func modeTitle(_ mode: DisplayMode) -> String {
        switch mode {
        case .ballAndStick: return "Ball and stick"
        case .spaceFilling: return "Space filling"
        }
    }

    /// The legend of `mode`, ending with "Display radii, not measured sizes.": ball-and-stick "Ball and stick: atoms at
    /// 30 % of their van der Waals radius, bonds as sticks. …"; space-filling "Space filling: atoms at their van der
    /// Waals radius, no bonds. …".
    nonisolated static func legend(_ mode: DisplayMode) -> String {
        switch mode {
        case .ballAndStick:
            return "Ball and stick: atoms at 30 % of their van der Waals radius, bonds as sticks. " + legendNote
        case .spaceFilling:
            return "Space filling: atoms at their van der Waals radius, no bonds. " + legendNote
        }
    }

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
        let mode = core.mode
        if mirror.mode != mode { mirror.mode = mode }
        let legend = Self.legend(mode)
        if mirror.legend != legend { mirror.legend = legend }
        let camera = core.camera
        if mirror.turnSteps != camera.turnSteps { mirror.turnSteps = camera.turnSteps }
        if mirror.tiltSteps != camera.tiltSteps { mirror.tiltSteps = camera.tiltSteps }
        if mirror.zoomSteps != camera.zoomSteps { mirror.zoomSteps = camera.zoomSteps }
        let words = Self.cameraWords(camera)
        if mirror.cameraWords != words { mirror.cameraWords = words }
        let zoom = Self.zoomWords(camera)
        if mirror.zoomWords != zoom { mirror.zoomWords = zoom }
    }

    /// The answer to `result` of `control`: empty when accepted, else why it was refused.
    nonisolated static func answerWords(control: String, result: ActionResult) -> String {
        guard !result.isAccepted else { return "" }
        switch control {
        case "molecule.next": return "Caffeine is the last molecule."
        case "molecule.previous": return "Water is the first molecule."
        case "molecule.select": return "There is no such molecule."
        case "display.mode": return "There is no such display mode."
        case "camera.orbit": return "The camera turns one step left or right."
        case "camera.tilt": return "The camera is tilted as far as it goes."
        case "camera.zoom": return "The camera is zoomed as far as it goes."
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

    /// The description of `core`'s molecule and mode.
    func describe(_ core: MoleculeCore) -> String {
        sync(core)
        return core.canvasDescription
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MoleculeControls(port: port, mirror: mirror, presenter: self))
    }

    /// The actions the native controls send: every action (the molecule buttons and menu, the mode picker, the turn,
    /// tilt and zoom buttons and Reset view); there is no canvas gesture in this phase.
    var nativeActions: Set<String> {
        Set(MoleculeCore.actionIDs)
    }
}
