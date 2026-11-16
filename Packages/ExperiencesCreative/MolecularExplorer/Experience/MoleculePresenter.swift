// MoleculePresenter — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; SC-A15-104) and feature 111
// (A15-P02) T-A15-205 (FR-A15-202, FR-A15-210, FR-A15-220, FR-A15-230; clarifications Q2–Q5; SC-A15-202, SC-A15-203;
// contracts/renderer.md). Draws Molecular Explorer through the host only (the host's context and registry,
// VisualCore's `DepthMeshPass` and `MeshRenderer` with an `OrbitCamera`; no context of its own, no second renderer, no
// imported assets). The presenter reads the core and never writes it:
//   - Scene: the core state's `MoleculeScene` (the selected molecule in the display mode): one atom item per atom and,
//     in ball-and-stick, two bond halves per bond; exactly the scene's items are drawn (at most 82 for the library,
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
//
// Feature 112 (A15-P03) T-A15-305 and T-A15-306 (FR-A15-301, FR-A15-310, FR-A15-320–323; clarifications Q1, Q3–Q5;
// SC-A15-301–304; contracts/selection.md):
//   - Gestures: `pointer(_:viewSize:port:)` feeds ``MoleculeGestures`` (drag turns and tilts, pinch zooms, two fingers
//     pan, tap picks); a tap is picked with the camera, the scene and the canvas aspect of the LAST DRAWN frame
//     (`AtomPicker.pick(ndc:camera:aspect:scene:)` through the view point turned into normalised device coordinates
//     with the view size), so what is tapped is what was seen; a hit sends `atom.select [index]`, a miss sends
//     `atom.clear` while an atom is selected. Gesture steps go straight to the port: a refusal is dropped quietly (no
//     answer in the mirror). `teardown` and suspension (`cancelPointers()`, T-A15-313) forget every touch.
//   - Sticks: in ball-and-stick the scene's styled sticks are drawn (`MoleculeScene.sticks`: one per single or
//     inferred half, two per double, three per triple, each moved by its offset): the unit stick (built with radius
//     0.12 Å) turned from +y onto the stick, scaled by radius ÷ 0.12 across (x and z alike) and by the length along y,
//     and moved to its start (translate(from) × rotate × scale(r ÷ 0.12, length, r ÷ 0.12)). With equal x and z factors
//     the side normals (no y part) keep their direction after the shader's normalisation, so the lighting stays right.
//     The item count is the atoms plus the sticks (caffeine: 24 + 58 = 82). ``drawsBondStyles`` (tests only) draws one
//     0.12 Å stick per half instead, the comparison drawing for "double bonds change the pixels".
//   - Camera: the state's camera with its pan (`CameraSettings.camera(centre:boundingRadius:aspect:)` moves the target
//     by the pan steps), so `lastCenter` is the panned target.
//   - Overlay: ``MoleculeOverlay`` (``makeCanvasOverlay(_:)``) shows the element labels `LabelLayout` places for the
//     last drawn frame and a ring around the selected atom (its projected centre and projected radius + 1 pt), laid out
//     in the overlay's reported size in points (before it reports: the pixels over ``displayScale``).
//   - Panel and words: the mirror holds the selected atom's panel lines ("Nitrogen (N), atom 3 of 24"; "Position x
//     −0.97, y −1.31, z 0.00 Å"; "Covalent radius 0.71 Å, van der Waals radius 1.55 Å") and one line per bond ("Single
//     bond to carbon, atom 8, recorded"), the pan in words and the answers to the new refusals. The description adds
//     "; selected nitrogen, atom 3" after the mode (`MoleculeCore.canvasDescription`).
//   - Announcements: a selection change seen by `sync` (a new atom, or a clear with the molecule kept) announces the
//     first panel line (or "No atom selected") through the injected ``AnnouncementSink`` (the system's VoiceOver
//     announcements by default); `sync` sees each state once per change, so one action gives at most one announcement.
//     The first state seen and a molecule change announce nothing.
//
// Feature 113 (A15-P04) T-A15-404 and T-A15-405 (FR-A15-401, FR-A15-410, FR-A15-411, FR-A15-420, FR-A15-440;
// clarifications Q1–Q4; contracts/library.md):
//   - Recent molecules: ``RecentStore`` (`recent.json` in the experience's storage, loaded once when the presenter is
//     made). `sync` records the selected molecule's id on every molecule change it sees, the first state included (the
//     molecule opened at start counts as opened). When the file was refused or unreadable the first state is recorded
//     in memory only, so the refused file stays byte for byte until the next molecule change replaces it.
//   - Settings: ``SettingsStore`` (`settings.json`, loaded once). Its label mode filters the overlay's labels: all the
//     labels `LabelLayout` placed, only the selected atom's label (none when nothing is selected), or none; the ring is
//     drawn whenever an atom is selected. ``setLabelMode(_:)`` (the Labels picker) is not an engine action: it writes
//     the settings and filters the labels of the last frame at once.
//   - Both stores live outside the engine state, so digests and replays are unchanged; the mirror holds the recent ids
//     and titles (newest first), the label mode and the stores' messages for the controls.
//
// Feature 114 (A15-P05) T-A15-506 (FR-A15-501–506, FR-A15-540; clarifications Q1–Q3; contracts/import.md):
//   - Import: ``importFile(at:)`` (the Import button's picker result) runs ``MoleculeImporter`` with the port and the
//     activity attached by ``attach(port:isActive:)`` (the factory attaches the shell's; nothing is read without
//     them). On success the file's title (`import-title.txt`, "Imported molecule" when missing) names molecule 6 in the
//     name line, the status and the description, "<title> imported, N atoms" is announced and the mirror's
//     `importMessage` is empty, or reads "The molecule was opened but could not be kept for the recent list (<storage
//     code>)." when the copy could not be written; a refusal announces its sentence and shows it, changing nothing. An
//     inactive import (suspended or closing) does nothing at all.
//   - Recent list: the id `imported` (`ImportedMolecule.id`) is recorded when molecule 6 is shown, and offered while
//     the engine holds an import or a readable stored copy exists. ``chooseRecent(_:through:)`` selects a library
//     molecule, the engine's import, or, with no import in the engine, replays the stored copy; when the copy is
//     missing or refused the entry is dropped from the list.
//   - Panel: the line `inferred-note` (``inferredNote``, `MoleculeReview.inferredStatement`) under the bonds.
//
// Feature 115 (A15-P06) T-A15-604 (FR-A15-611; clarification Q5): the test-only seam `failNextDraw` makes the next
// `draw` throw `MoleculeDrawError.injected` once (and clears itself) before anything is synced or written, so a test can
// drive the host into its failure state; nothing in the experience sets it.
import Foundation
import MolecularExplorerCore
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
    /// The horizontal pan steps, −10…10 (feature 112).
    var panX = 0
    /// The vertical pan steps, −10…10 (feature 112).
    var panY = 0
    /// The pan in words ("View centred", "View panned 2 right and 1 up"; feature 112).
    var panWords = ""
    /// The number of atoms of the selected molecule (feature 112).
    var atomCount = 0
    /// The selected atom's index, or nil when none is selected (feature 112).
    var selectedAtom: Int?
    /// The selected atom in words: its first panel line, or "No atom selected" (feature 112).
    var atomWords = ""
    /// The selected atom's panel lines (name and place, position, radii); empty when none is selected (feature 112).
    var atomPanel: [String] = []
    /// One line per bond of the selected atom; empty when none is selected (feature 112).
    var bondLines: [String] = []
    /// The element labels of the last drawn frame, in canvas points (feature 112).
    var labels: [LabelLayout.Label] = []
    /// The ring around the selected atom in canvas points, or nil (feature 112).
    var ring: MoleculeSelectionRing?
    /// The canvas size in points the labels and the ring were laid out in (feature 112).
    var canvasSize = Vec2(0, 0)
    /// The overlay's size in points as it reported it; nil before it is shown (feature 112).
    var overlaySize: Vec2?
    /// The recent molecule ids, newest first (feature 113).
    var recentIDs: [String] = []
    /// The recent molecules' titles, newest first (feature 113).
    var recentTitles: [String] = []
    /// The label mode of the settings (feature 113).
    var labelMode = LabelMode.all
    /// Why the recent list could not be read or saved; empty otherwise (feature 113).
    var recentMessage = ""
    /// Why the settings could not be read or saved; empty otherwise (feature 113).
    var settingsMessage = ""
    /// The selected molecule's title as shown ("Caffeine"; the imported file's title for molecule 6; feature 114).
    var title = ""
    /// Whether the engine holds an imported molecule (molecule 6 can be selected; feature 114).
    var hasImport = false
    /// The imported molecule's title (the file's, else "Imported molecule"; feature 114).
    var importTitle = MoleculeImport.fallbackTitle
    /// The answer to the last import: the refusal sentence, the copy's storage message, or empty (feature 114).
    var importMessage = ""
    /// Whether the Import button's file picker is shown (kept here so the controls hold references only; feature
    /// 114).
    var importing = false
}

/// The ring drawn around the selected atom on the canvas overlay (feature 112, T-A15-306).
struct MoleculeSelectionRing: Equatable, Sendable {
    /// The atom's projected centre in canvas points (origin top-left, y down).
    let centre: Vec2
    /// The ring's radius in canvas points: the atom's projected radius plus 1 pt.
    let radius: Double
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
    /// Where announcements go (the system's VoiceOver announcements by default; feature 112).
    let announcementSink: any AnnouncementSink
    /// Points per pixel, to lay the overlay out before it reports its size (feature 112).
    let displayScale: Double
    /// Draws the styled sticks (true) or one 0.12 Å stick per half (false: the comparison drawing of the tests).
    var drawsBondStyles = true
    /// The recent-molecules list in the experience's storage (feature 113).
    let recentStore: RecentStore
    /// The settings in the experience's storage (feature 113).
    let settingsStore: SettingsStore
    /// The molecule last recorded into the recent list; nil before the first state (feature 113).
    private(set) var recordedSelection: Int?
    /// Every label `LabelLayout` placed for the last frame, before the label mode filtered them (feature 113).
    private(set) var lastPlacedLabels: [LabelLayout.Label] = []
    /// The selected atom of the last frame (feature 113: the label mode `selected` keeps its label only).
    private(set) var lastSelectedAtom: Int?

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// How many times the renderers were made (sphere and stick together each time).
    private(set) var rendererBuildCount = 0
    /// How many times the CPU meshes were made (once per presenter).
    private(set) var meshBuildCount = 0
    /// The number of atoms drawn by the last frame.
    private(set) var lastAtomsDrawn = 0
    /// The number of sticks drawn by the last frame (feature 112: the styled sticks, not the halves).
    private(set) var lastSticksDrawn = 0
    /// The number of items (atoms plus sticks) drawn by the last frame.
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
    /// The scene of the last frame; nil before the first frame (feature 112: taps pick against it).
    private(set) var lastScene: MoleculeScene?
    /// The labels shown for the last frame, after the label mode (feature 112; filtered since feature 113).
    private(set) var lastLabels: [LabelLayout.Label] = []
    /// The canvas size in points the last labels were laid out in (feature 112).
    private(set) var lastCanvasPoints: Vec2?
    /// The canvas gestures (feature 112).
    private(set) var gestures = MoleculeGestures()
    /// The imports of a person's XYZ files and the stored copy (feature 114).
    let importer: MoleculeImporter
    /// Set by a test to make the next `draw` throw ``MoleculeDrawError/injected`` once; the seam clears itself and
    /// nothing in the experience sets it (feature 115, T-A15-604).
    var failNextDraw = false
    /// The port imports and replays are sent through; set by ``attach(port:isActive:)`` (feature 114).
    private(set) weak var port: ExperienceActionPort?
    /// Whether the experience is active now (imports are refused otherwise); set by ``attach(port:isActive:)``.
    private var isActive: @MainActor () -> Bool = { false }
    /// The title of the imported molecule: the stored `import-title.txt`, else "Imported molecule" (feature 114).
    private(set) var importTitle: String
    /// The core last seen by `sync`; nil before the first state (feature 114).
    private(set) var lastCore: MoleculeCore?
    /// The selected atom last seen by `sync` or set by an accepted pick (decides whether a miss clears).
    private(set) var seenSelectedAtom: Int?
    /// The molecule and atom last seen by the announcements; nil until the first state.
    private(set) var announcedSelection: (molecule: Int, atom: Int?)?
    /// The last text announced; empty before the first announcement.
    private(set) var lastAnnouncement = ""
    /// The number of announcements made.
    private(set) var announcementCount = 0
    /// The unit sphere mesh; nil until first needed.
    private(set) var sphereMesh: Mesh?
    /// The unit stick mesh; nil until first needed.
    private(set) var stickMesh: Mesh?
    /// The renderers, sphere first and stick second, made and released together; empty after `teardown`.
    private(set) var renderers: [MeshRenderer] = []
    /// The depth-correct pass the items are drawn through; made in `setup`, released in `teardown`.
    private(set) var depthPass: DepthMeshPass?

    /// A presenter for the experience `experienceID`; `announcementSink` replaces the system's VoiceOver
    /// announcements (nil: the system's); `displayScale` is the points-per-pixel factor used before the overlay reports
    /// its size (nil: the current trait collection's, else 2); `recentStore` and `settingsStore` keep the recent list
    /// and the settings (nil: in memory; feature 113). Both stores have loaded their files already; nothing is written
    /// here. `importer` opens XYZ files (nil: one keeping its copy in the recent store's storage; feature 114).
    init(experienceID: ExperienceID, announcementSink: (any AnnouncementSink)? = nil, displayScale: Double? = nil,
         recentStore: RecentStore? = nil, settingsStore: SettingsStore? = nil, importer: MoleculeImporter? = nil) {
        self.experienceID = experienceID
        self.announcementSink = announcementSink ?? SystemAnnouncementSink()
        let traitScale = Double(UITraitCollection.current.displayScale)
        self.displayScale = displayScale ?? (traitScale > 0 ? traitScale : 2)
        let recent = recentStore ?? RecentStore(storage: nil)
        self.recentStore = recent
        self.settingsStore = settingsStore ?? SettingsStore(storage: nil)
        let imports = importer ?? MoleculeImporter(storage: recent.storage)
        self.importer = imports
        importTitle = imports.storedTitle() ?? MoleculeImport.fallbackTitle
        syncStores()
    }

    /// Attaches the port imports are sent through and the question whether the experience is active (the factory
    /// passes the shell's port and `shell.state == .active`; tests attach their own shell; feature 114).
    func attach(port: ExperienceActionPort, isActive: @escaping @MainActor () -> Bool) {
        self.port = port
        self.isActive = isActive
    }

    // MARK: Render scene

    /// Makes the depth pass and both renderers with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        releaseGPU()
        depthPass = DepthMeshPass(registry: context.resources)
        try makeRenderers(context)
        isLive = true
    }

    /// Draws the state's scene lit, with depth, through the state's camera framed on the scene; throws
    /// ``MoleculeDrawError/injected`` (once, drawing and syncing nothing) while ``failNextDraw`` is set.
    func draw(_ core: MoleculeCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw MoleculeDrawError.injected
        }
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
        for item in drawsBondStyles ? scene.sticks : Self.plainSticks(scene) {
            guard let model = Self.stickModel(item) else { continue }
            items.append(DepthMeshPass.Item(renderer: stick, model: model, color: Self.color(symbol: item.symbol)))
        }
        try depthPass.draw(items, camera: camera, context: context)
        lastAtomsDrawn = atoms
        lastSticksDrawn = items.count - atoms
        lastItemCount = items.count
        lastSelection = core.selection
        lastMode = core.mode
        lastCamera = camera
        lastCenter = camera.target
        lastCameraDistance = camera.distance
        lastScene = scene
        placeOverlay(scene: scene, camera: camera, selected: core.selectedAtom, pixels: Vec2(width, height))
    }

    /// Places the labels and the selection ring of the frame just drawn through `camera` on the canvas in points (the
    /// overlay's reported size, else `pixels` over ``displayScale``) and shows them in the mirror.
    private func placeOverlay(scene: MoleculeScene, camera: OrbitCamera, selected: Int?, pixels: Vec2) {
        let canvas: Vec2
        if let reported = mirror.overlaySize, reported.x > 0, reported.y > 0 {
            canvas = reported
        } else {
            canvas = Vec2(pixels.x / displayScale, pixels.y / displayScale)
        }
        let placed = LabelLayout.labels(scene: scene, camera: camera, canvas: canvas, selected: selected)
        let ring = selected.flatMap { Self.selectionRing(scene: scene, index: $0, camera: camera, canvas: canvas) }
        lastPlacedLabels = placed
        lastSelectedAtom = selected
        lastCanvasPoints = canvas
        showLabels()
        if mirror.ring != ring { mirror.ring = ring }
        if mirror.canvasSize != canvas { mirror.canvasSize = canvas }
    }

    /// The labels of `placed` the label mode `mode` shows with atom `selected` (or none): all of them, only the
    /// selected atom's (none when nothing is selected) or none (feature 113).
    nonisolated static func shownLabels(_ placed: [LabelLayout.Label], mode: LabelMode, selected: Int?)
        -> [LabelLayout.Label] {
        switch mode {
        case .all: return placed
        case .none: return []
        case .selected:
            guard let selected else { return [] }
            return placed.filter { $0.index == selected }
        }
    }

    /// Shows the last frame's placed labels through the settings' label mode in the mirror (feature 113).
    private func showLabels() {
        let labels = Self.shownLabels(lastPlacedLabels, mode: settingsStore.labels, selected: lastSelectedAtom)
        lastLabels = labels
        if mirror.labels != labels { mirror.labels = labels }
    }

    /// Releases every GPU object; the CPU meshes stay for the next context.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
        lastAtomsDrawn = 0
        lastSticksDrawn = 0
        lastItemCount = 0
        gestures.reset()
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

    /// The model matrix of `stick`: translate(from) × rotate(+y onto the stick's direction) × scale(r ÷ 0.12,
    /// length, r ÷ 0.12) with r the stick's radius (the unit stick is built with radius 0.12 Å); nil for a stick
    /// without length, with a non-finite end or a radius that is not finite and positive.
    nonisolated static func stickModel(_ stick: MoleculeScene.Stick) -> Mat4? {
        let d = stick.to - stick.from
        let length = d.length
        guard length.isFinite, length > 1e-9, stick.radius.isFinite, stick.radius > 0 else { return nil }
        let rotation = rotationFromUp(to: d * (1 / length))
        let across = stick.radius / DisplayMode.stickRadius
        return Mat4.translation(stick.from) * Mat4.rotation(rotation) * Mat4.scale(Vec3(across, length, across))
    }

    /// One 0.12 Å stick on the line of every bond half of `scene` (the comparison drawing without bond styles).
    nonisolated static func plainSticks(_ scene: MoleculeScene) -> [MoleculeScene.Stick] {
        var sticks: [MoleculeScene.Stick] = []
        sticks.reserveCapacity(scene.bondHalves.count)
        for half in scene.bondHalves {
            sticks.append(MoleculeScene.Stick(from: half.from, to: half.to, symbol: half.symbol,
                                              radius: DisplayMode.stickRadius))
        }
        return sticks
    }

    /// The canvas point (origin top-left, y down) of `point` through `camera` on a canvas of `canvas` points, without
    /// clipping to the canvas; nil behind the camera or when not finite.
    nonisolated static func canvasProjection(of point: Vec3, camera: OrbitCamera, canvas: Vec2) -> Vec2? {
        guard canvas.x > 0, canvas.y > 0 else { return nil }
        let clip = camera.viewProjection(aspect: canvas.x / canvas.y) * Vec4(point, 1)
        guard clip.w.isFinite, clip.w > 0 else { return nil }
        let p = Vec2((clip.x / clip.w + 1) / 2 * canvas.x, (1 - clip.y / clip.w) / 2 * canvas.y)
        return p.isFinite ? p : nil
    }

    /// The ring around atom `index` of `scene` through `camera` on a canvas of `canvas` points: the projected centre
    /// (on the canvas, by `LabelLayout.canvasPoint`) and the projected radius (the centre to the point one display
    /// radius along the view's right) plus 1 pt; nil when the atom's centre is not on the canvas.
    nonisolated static func selectionRing(scene: MoleculeScene, index: Int, camera: OrbitCamera, canvas: Vec2)
        -> MoleculeSelectionRing? {
        guard scene.atoms.indices.contains(index) else { return nil }
        let atom = scene.atoms[index]
        guard let centre = LabelLayout.canvasPoint(of: atom.position, camera: camera, canvas: canvas) else {
            return nil
        }
        let forward = camera.target - camera.eye
        let right = forward.cross(Vec3(0, 1, 0)).normalized
        guard right.isFinite,
              let edge = canvasProjection(of: atom.position + right * atom.radius, camera: camera, canvas: canvas)
        else { return MoleculeSelectionRing(centre: centre, radius: 1) }
        return MoleculeSelectionRing(centre: centre, radius: (edge - centre).length + 1)
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
    /// radius + 0.05 and every stick (sampled at 17 points) farther than 1.1 × its radius + 0.05.
    nonisolated static func rayMisses(origin: Vec3, direction: Vec3, scene: MoleculeScene) -> Bool {
        /// The distance from `point` to the ray.
        func distance(_ point: Vec3) -> Double {
            let v = point - origin
            return (v - direction * max(v.dot(direction), 0)).length
        }
        for atom in scene.atoms where distance(atom.position) <= atom.radius * 1.1 + 0.05 { return false }
        for stick in scene.sticks {
            for k in 0...16 {
                let point = stick.from + (stick.to - stick.from) * (Double(k) / 16)
                if distance(point) <= stick.radius * 1.1 + 0.05 { return false }
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

    /// The pan of `camera` in words: "View centred", or the non-zero axes as "View panned 2 right and 1 up" (a
    /// positive pan moves the view right or up; feature 112).
    nonisolated static func panWords(_ camera: CameraSettings) -> String {
        var parts: [String] = []
        if camera.panX != 0 { parts.append("\(abs(camera.panX)) \(camera.panX > 0 ? "right" : "left")") }
        if camera.panY != 0 { parts.append("\(abs(camera.panY)) \(camera.panY > 0 ? "up" : "down")") }
        return parts.isEmpty ? "View centred" : "View panned " + parts.joined(separator: " and ")
    }

    /// `value` with two decimals and a true minus sign when negative; a value that rounds to zero has no sign
    /// ("−0.97", "0.00"; feature 112).
    nonisolated static func decimal(_ value: Double) -> String {
        let text = String(format: "%.2f", abs(value))
        let rounded = (abs(value) * 100).rounded() / 100
        return value < 0 && rounded > 0 ? "\u{2212}" + text : text
    }

    /// The word of a bond order: "Single", "Double" or "Triple" (another order: "Single", as it is drawn).
    nonisolated static func orderWord(_ order: Int) -> String {
        switch order {
        case 2: return "Double"
        case 3: return "Triple"
        default: return "Single"
        }
    }

    /// The panel lines of atom `atom` of `molecule` (FR-A15-322): "Nitrogen (N), atom 3 of 24", "Position x −0.97,
    /// y −1.31, z 0.00 Å" and "Covalent radius 0.71 Å, van der Waals radius 1.55 Å"; empty for an index outside the
    /// molecule.
    nonisolated static func atomPanel(_ molecule: Molecule, atom: Int) -> [String] {
        guard molecule.atoms.indices.contains(atom) else { return [] }
        let item = molecule.atoms[atom]
        let element = Elements.element(symbol: item.symbol)
        let name = element?.name ?? item.symbol
        var lines = ["\(name) (\(item.symbol)), atom \(atom + 1) of \(molecule.atoms.count)",
                     "Position x \(decimal(item.x)), y \(decimal(item.y)), z \(decimal(item.z)) Å"]
        if let element {
            lines.append("Covalent radius \(decimal(element.covalentRadius)) Å, van der Waals radius "
                         + "\(decimal(element.vanDerWaalsRadius)) Å")
        }
        return lines
    }

    /// One line per bond of atom `atom` of `molecule`, in bond order (FR-A15-322): "Single bond to carbon, atom 8,
    /// recorded"; an inferred bond ends "inferred". Empty for an index outside the molecule.
    nonisolated static func bondLines(_ molecule: Molecule, atom: Int) -> [String] {
        guard molecule.atoms.indices.contains(atom) else { return [] }
        var lines: [String] = []
        for bond in molecule.bonds where bond.a == atom || bond.b == atom {
            let other = bond.a == atom ? bond.b : bond.a
            guard let name = MoleculeCore.atomElementName(molecule, atom: other) else { continue }
            lines.append("\(orderWord(bond.order)) bond to \(name), atom \(other + 1), \(bond.origin.rawValue)")
        }
        return lines
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
            // copy-claims: allow (a display fraction of the radius, not a measured claim)
            return "Ball and stick: atoms at 30 % of their van der Waals radius, bonds as sticks. " + legendNote // copy-claims: allow
        case .spaceFilling:
            return "Space filling: atoms at their van der Waals radius, no bonds. " + legendNote
        }
    }

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: MoleculeCore) {
        lastCore = core
        if !mirror.ready { mirror.ready = true }
        let selection = core.selection
        if mirror.selection != selection { mirror.selection = selection }
        let shownTitle = title(of: core)
        if mirror.title != shownTitle { mirror.title = shownTitle }
        let hasImport = core.imported != nil
        if mirror.hasImport != hasImport { mirror.hasImport = hasImport }
        if mirror.importTitle != importTitle { mirror.importTitle = importTitle }
        let named = selection == MoleculeCore.importedSelection ? importTitle : nil
        let name = core.nameLine(title: named)
        if mirror.nameLine != name { mirror.nameLine = name }
        let counts = core.countsLine
        if mirror.countsLine != counts { mirror.countsLine = counts }
        let source = core.sourceLine
        if mirror.sourceLine != source { mirror.sourceLine = source }
        let status = core.status(title: named)
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
        if mirror.panX != camera.panX { mirror.panX = camera.panX }
        if mirror.panY != camera.panY { mirror.panY = camera.panY }
        let pan = Self.panWords(camera)
        if mirror.panWords != pan { mirror.panWords = pan }
        let atomCount = core.state.atomCount
        if mirror.atomCount != atomCount { mirror.atomCount = atomCount }
        let atom = core.selectedAtom
        if mirror.selectedAtom != atom { mirror.selectedAtom = atom }
        var panel: [String] = []
        var bonds: [String] = []
        if let atom, let molecule = core.molecule {
            panel = Self.atomPanel(molecule, atom: atom)
            bonds = Self.bondLines(molecule, atom: atom)
        }
        if mirror.atomPanel != panel { mirror.atomPanel = panel }
        if mirror.bondLines != bonds { mirror.bondLines = bonds }
        let atomWords = panel.first ?? Self.noAtomWords
        if mirror.atomWords != atomWords { mirror.atomWords = atomWords }
        seenSelectedAtom = atom
        announceSelection(molecule: selection, atom: atom, words: atomWords)
        recordMolecule(selection, id: core.molecule?.id)
    }

    /// The title `core`'s selected molecule is shown with: the imported file's title for molecule 6, else the
    /// molecule's own title (feature 114).
    func title(of core: MoleculeCore) -> String {
        core.selection == MoleculeCore.importedSelection && core.imported != nil ? importTitle : core.title
    }

    // MARK: Recent molecules and settings (feature 113)

    /// Records the molecule `id` shown at `selection` (a library id, or `imported` for molecule 6 since feature 114)
    /// into the recent list when the selection differs from the one last recorded (the first state included). The
    /// first state is written only when the file was read or missing, so a refused or unreadable file stays as it was
    /// until the next molecule change.
    private func recordMolecule(_ selection: Int, id: String?) {
        guard selection != recordedSelection, let id else { return }
        let first = recordedSelection == nil
        recordedSelection = selection
        let persist: Bool
        switch recentStore.loadResult {
        case .refused, .unreadable: persist = !first
        case .loaded, .missing: persist = true
        }
        recentStore.record(id, persist: persist)
        syncStores()
    }

    /// The titles of the molecules `ids`, in order: library titles, `importedTitle` for `imported` (feature 114);
    /// other ids are left out.
    nonisolated static func recentTitles(_ ids: [String], importedTitle: String = MoleculeImport.fallbackTitle)
        -> [String] {
        ids.compactMap { id in
            id == ImportedMolecule.id ? importedTitle : MoleculeCore.library.first { $0.id == id }?.title
        }
    }

    /// The library index of the molecule `id`, or nil outside the library.
    nonisolated static func libraryIndex(id: String) -> Int? {
        MoleculeCore.library.firstIndex { $0.id == id }
    }

    /// The name of `mode` on the Labels picker: "All", "Selected" or "None".
    nonisolated static func labelTitle(_ mode: LabelMode) -> String {
        switch mode {
        case .all: return "All"
        case .selected: return "Selected"
        case .none: return "None"
        }
    }

    /// Sets the label mode (the Labels picker; not an engine action): the settings are written and the last frame's
    /// labels are filtered at once.
    func setLabelMode(_ mode: LabelMode) {
        settingsStore.setLabels(mode)
        syncStores()
        showLabels()
    }

    /// Whether the imported molecule can be shown: the engine holds an import or a readable stored copy exists
    /// (feature 114).
    var importAvailable: Bool {
        lastCore?.imported != nil || importer.hasReadableCopy
    }

    /// Brings the mirror's recent list, label mode and store messages in line with the stores (`imported` only while
    /// ``importAvailable``; feature 114).
    private func syncStores() {
        let ids = recentStore.availableIDs(importAvailable: importAvailable)
        if mirror.recentIDs != ids { mirror.recentIDs = ids }
        let titles = Self.recentTitles(ids, importedTitle: importTitle)
        if mirror.recentTitles != titles { mirror.recentTitles = titles }
        let mode = settingsStore.labels
        if mirror.labelMode != mode { mirror.labelMode = mode }
        if mirror.recentMessage != recentStore.message { mirror.recentMessage = recentStore.message }
        if mirror.settingsMessage != settingsStore.message { mirror.settingsMessage = settingsStore.message }
    }

    // MARK: Import (feature 114)

    /// The panel line under the bonds (`inferred-note`): "Bonds marked inferred are estimated from atom distances."
    nonisolated static let inferredNote = MoleculeReview.inferredStatement

    /// The message of an import whose copy could not be written: "The molecule was opened but could not be kept for
    /// the recent list (<storage code>)."
    nonisolated static func keepFailedWords(_ code: String) -> String {
        "The molecule was opened but could not be kept for the recent list (\(code))."
    }

    /// The announcement of a successful import: "<title> imported, N atoms" ("1 atom" for one).
    nonisolated static func importedWords(title: String, atoms: Int) -> String {
        "\(title) imported, \(MoleculeCore.counted(atoms, "atom"))"
    }

    /// The message of an `imported` entry that could no longer be opened (no import in the engine and no readable
    /// copy): the entry is dropped from the recent list.
    nonisolated static let importGoneWords = "The imported molecule is no longer kept, so it was removed from the "
        + "recent list."

    /// Whether imports can run now: a port is attached and the experience is active.
    private var canImport: Bool {
        port != nil && isActive()
    }

    /// Sends `control` with `values` through the attached port (refused as not active without one).
    private func sendThroughPort(_ control: String, _ values: [Double]) -> ActionResult {
        port?.send(control, values) ?? .rejected(.notActive(.inactive))
    }

    /// Imports the XYZ file at `url` (the Import button's picker result; see the file header): nothing at all while
    /// the experience is not active; a refusal shows and announces its sentence and changes nothing; a success names
    /// the molecule with the file's title, announces "<title> imported, N atoms" and shows the copy's storage message
    /// when it could not be kept.
    @discardableResult
    func importFile(at url: URL) -> MoleculeImporter.Outcome {
        let outcome = importer.importFile(at: url, isActive: canImport) { [weak self] control, values in
            self?.sendThroughPort(control, values) ?? .rejected(.notActive(.inactive))
        }
        switch outcome {
        case .inactive:
            return outcome
        case .refused(let sentence):
            mirror.importMessage = sentence
            announce(sentence)
        case .imported(let title, let atoms, let code):
            importTitle = title
            mirror.importMessage = code.map(Self.keepFailedWords) ?? ""
            announce(Self.importedWords(title: title, atoms: atoms))
        }
        if let lastCore { sync(lastCore) }
        syncStores()
        return outcome
    }

    /// Opens the recent entry `id` through `port`: a library molecule by `molecule.select`; `imported` by
    /// `molecule.select [5]` when the engine holds an import, else by replaying the stored copy (only while the
    /// experience is active); when the copy is missing or refused the entry is dropped and ``importGoneWords`` shown.
    /// Returns the answer of the selection, or nil when nothing was sent (an unknown id, or a replay while inactive).
    @discardableResult
    func chooseRecent(_ id: String, through port: ExperienceActionPort) -> ActionResult? {
        if let index = Self.libraryIndex(id: id) {
            return send("molecule.select", [Double(index)], through: port)
        }
        guard id == ImportedMolecule.id else { return nil }
        if lastCore?.imported != nil {
            return send("molecule.select", [Double(MoleculeCore.importedSelection)], through: port)
        }
        guard canImport else { return nil }
        importer.forgetCopyCheck()
        let replayed = importer.replay { control, values in port.send(control, values) }
        if !replayed {
            recentStore.drop(ImportedMolecule.id)
            mirror.importMessage = Self.importGoneWords
        } else {
            importTitle = importer.storedTitle() ?? MoleculeImport.fallbackTitle
            mirror.importMessage = ""
            if let lastCore { sync(lastCore) }
        }
        syncStores()
        return replayed ? .accepted : .rejected(.rule(code: MoleculeRule.invalidImport))
    }

    /// Announces `text` through the sink and counts it.
    private func announce(_ text: String) {
        announcementSink.announce(text)
        lastAnnouncement = text
        announcementCount += 1
    }

    /// The words of no selected atom.
    nonisolated static let noAtomWords = "No atom selected"

    /// Announces a change of the selected atom since the state last seen: a new atom announces its first panel line,
    /// a clear with the molecule kept announces "No atom selected"; the first state and a molecule change announce
    /// nothing (FR-A15-323).
    private func announceSelection(molecule: Int, atom: Int?, words: String) {
        defer { announcedSelection = (molecule, atom) }
        guard let seen = announcedSelection, seen.molecule == molecule, seen.atom != atom else { return }
        announcementSink.announce(words)
        lastAnnouncement = words
        announcementCount += 1
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
        case "camera.pan":
            return result == .rejected(.rule(code: MoleculeRule.cameraLimit))
                ? "The view is panned as far as it goes." : "The view pans one step at a time."
        case "atom.select": return "There is no such atom."
        case "atom.next": return "This is the last atom."
        case "atom.previous": return "This is the first atom."
        case "atom.clear": return "No atom is selected."
        case "import.begin", "import.atom", "import.end": return "The molecule file could not be opened."
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

    /// The description of `core`'s molecule and mode (the imported molecule named by its file's title; feature 114).
    func describe(_ core: MoleculeCore) -> String {
        sync(core)
        return core.titledCanvasDescription(core.selection == MoleculeCore.importedSelection ? importTitle : nil)
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MoleculeControls(port: port, mirror: mirror, presenter: self))
    }

    /// The element labels and the selection ring drawn over the canvas (``MoleculeOverlay``); it never takes touches.
    func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView? {
        AnyView(MoleculeOverlay(mirror: mirror))
    }

    /// The actions the native controls send: every action (the molecule buttons and menu, the mode picker, the turn,
    /// tilt, zoom and pan buttons, Reset view, Previous atom, Next atom and Clear selection, and the Import button,
    /// which sends the three import actions and `molecule.select [5]`; feature 114).
    var nativeActions: Set<String> {
        Set(MoleculeCore.actionIDs)
    }

    // MARK: Gestures and picking (feature 112)

    /// The actions the canvas gestures send (``MoleculeGestures/gestureActions``), each with a native control.
    var gestureActions: Set<String> { MoleculeGestures.gestureActions }

    /// Turns a canvas pointer event into camera steps or a pick sent through `port`.
    /// Forgets every touch in progress: the shell calls it on suspension (T-A15-313), since the events of a suspended
    /// experience, the touches' cancellation among them, never arrive.
    func cancelPointers() {
        gestures.reset()
    }

    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        pointer(event, viewSize: viewSize) { port.send($0, $1) }
    }

    /// The pointer event `event` turned into actions sent through `send` (tests record them); a recognized tap is
    /// picked (``pick(at:viewSize:send:)``).
    func pointer(_ event: PointerEvent, viewSize: Vec2, send: MoleculeGestures.Send) {
        var current = gestures
        var taps: [Vec2] = []
        current.handle(event, send: send) { taps.append($0) }
        gestures = current
        for point in taps { pick(at: point, viewSize: viewSize, send: send) }
    }

    /// The normalised device point (x, y in −1…1, y up) of the view point `point` in a view of `viewSize` points;
    /// nil for an empty view or a non-finite point.
    nonisolated static func ndc(of point: Vec2, viewSize: Vec2) -> Vec2? {
        guard viewSize.x > 0, viewSize.y > 0, point.isFinite, viewSize.isFinite else { return nil }
        return Vec2(2 * point.x / viewSize.x - 1, 1 - 2 * point.y / viewSize.y)
    }

    /// Picks the atom under the view point `point` with the camera, the scene and the canvas aspect of the last drawn
    /// frame and sends `atom.select [index]`; on a miss sends `atom.clear` when an atom is selected. Returns the atom
    /// picked, or nil (also before the first frame, when nothing is sent).
    @discardableResult
    func pick(at point: Vec2, viewSize: Vec2, send: MoleculeGestures.Send) -> Int? {
        guard let camera = lastCamera, let scene = lastScene, let canvas = lastCanvas, canvas.y > 0,
              let ndc = Self.ndc(of: point, viewSize: viewSize) else { return nil }
        if let index = AtomPicker.pick(ndc: ndc, camera: camera, aspect: canvas.x / canvas.y, scene: scene) {
            if send("atom.select", [Double(index)]).isAccepted { seenSelectedAtom = index }
            return index
        }
        if seenSelectedAtom != nil, send("atom.clear", []).isAccepted { seenSelectedAtom = nil }
        return nil
    }
}

/// Why a draw of Molecular Explorer failed on purpose (feature 115, test-only seam ``MoleculePresenter/failNextDraw``).
enum MoleculeDrawError: Error, Equatable {
    /// The test-only seam asked for one failed draw.
    case injected
}
