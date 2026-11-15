// MazePresenter — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121; clarification Q5; research D5; plan
// "Lifecycle"). Draws Light Maze through the host only (the host's context and registry, VisualCore's
// `PrimitiveRenderer` with a `Camera2D`; no context of its own, no second renderer, no imported assets). The presenter
// reads the core and never writes it:
//   - Scene: one `SceneNode` tree per state, in board coordinates (one unit per cell, x east, y north) under a root
//     scaled by ``MazePresenter/unit`` (10 world units per cell, so the camera's zoom stays inside `Camera2D.zoomRange`
//     on every canvas from 13 to 3,000 pixels): the board background, a faint grid, the tiles (walls as filled squares,
//     mirrors and prisms as thick diagonal lines, targets as squares that turn green and gain a ring when lit, the
//     emitter as a triangle pointing where it shines), the beam as a halo and a core line (0.08 cell) along each of
//     the tracer's exact segments (feature 097), and an outline around the selected tile. The tree is rebuilt only
//     when the state changes (level, orientations or selection: everything the digest covers, since the beam follows
//     from the state); it is CPU data and survives a context recreation; `shedCaches()` drops it.
//   - GPU objects: one `PrimitiveRenderer`, made in `setup` with the host's registry (so it is made again after a
//     context recreation; `draw` makes it when missing) and released in `teardown`.
//   - Camera: centred on the board, its zoom fitting the board and a margin of half a cell on every side into the
//     canvas; the canvas is cleared to the background colour first.
//   - Probes: the background at (0.02, 0.02) from the top left (always outside the board: the margin is at least
//     0.5 / 13 of either side) and the centre of each target, green when lit, red when not.
//   - Words: the canvas description of `MazeCore` ("Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at
//     the wall; not solved."); the controls show the status, the selected tile and the answer to a refused action.
// There is no motion, so Reduce Motion changes nothing; nothing flashes. No audio.
//
// Feature 097 (A13-P02) T-A13-204 (FR-A13-201, FR-A13-204; clarifications Q1–Q3; research D1): canvas touches arrive
// through `pointer(_:viewSize:port:)` and go to `MazeGestures` with the live state (the shell's core, else the core of
// the last frame) and the inverse of the board camera of the last frame (`boardPoint`: view points, top-left origin, to
// board units); the gestures send only `tile.select` and `tile.turn` through the port, so `gestureActions` ⊆
// `nativeActions`. A gesture that changes nothing is answered in words in the controls' message. Every touch is
// forgotten on suspension (`suspended()`, called by `MazeExperience`) and in `teardown`.
// Feature 097 (A13-P02) T-A13-205 (FR-A13-210–212; clarifications Q4–Q5; research D2, D2b): each beam segment is drawn
// as a halo line (width ``haloWidth`` 0.30 cell, the beam colour at opacity ``haloOpacity`` 0.25) under the core line
// (``beamWidth`` 0.08 cell, full opacity), so the glow never reaches more than 0.15 cell from the tracer's segment;
// nothing is post-processed or animated, and drawing decides nothing about the solved state. A lit target carries a
// ring (an outline square inset ``ringInset`` 0.05 inside the target's square) and the selected tile an outline
// (inset ``selectionInset`` 0.04 inside its cell): shapes as well as colours. Spoken changes: when the beam's end words
// or the solved state change ("Beam ends at the target; solved."), the text is offered to `BeamAnnouncer`, which speaks
// at most once per second of frame time (the latest text wins); texts are posted to the announcement sink only while
// VoiceOver runs. The announcement clock is the sum of the frame times since `setup`; it starts over in `teardown`.
import Foundation
import LightMazeCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import UIKit
import VisualCoreUI

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class MazeMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The level index, 0…19.
    var levelIndex = 0
    /// The number of levels.
    var levelCount = MazeCore.levelCount
    /// The current level's number of turnable tiles.
    var turnableCount = 0
    /// The selected turnable tile's index, −1 for none.
    var selection = MazeState.noSelection
    /// The selected tile in words ("Mirror 1 of 1, leaning left, column 3, row 3" or "No tile selected").
    var selectedWords = "No tile selected"
    /// Whether the current level is solved.
    var solved = false
    /// The status line: level, tiles, where the beam ends and whether it is solved.
    var status = ""
    /// The answer to the last refused action; empty after an accepted one.
    var message = ""
}

/// Draws Light Maze and owns its presentation state (the scene tree and the renderer).
@MainActor
final class MazePresenter: ExperiencePresenter {
    /// World units per board cell under the root node.
    nonisolated static let unit = 10.0
    /// The margin around the board, in cells, on every side.
    nonisolated static let margin = 0.5
    /// The beam's core width in cells.
    nonisolated static let beamWidth = 0.08
    /// The width in cells of the halo under each beam segment.
    nonisolated static let haloWidth = 0.30
    /// The opacity of the halo.
    nonisolated static let haloOpacity = 0.25
    /// The farthest the glow reaches from a beam segment, in cells (half the halo's width).
    nonisolated static var glowReach: Double { haloWidth / 2 }
    /// The width of a mirror's or a prism's line in cells.
    nonisolated static let mirrorWidth = 0.16
    /// The width of the grid lines in cells.
    nonisolated static let gridWidth = 0.03
    /// The side of a wall's square in cells.
    nonisolated static let wallSide = 0.96
    /// The width of a lit target's ring in cells.
    nonisolated static let ringWidth = 0.07
    /// How far inside the target's square its ring lies, in cells.
    nonisolated static let ringInset = 0.05
    /// The width of the selection outline in cells.
    nonisolated static let selectionWidth = 0.07
    /// How far inside its cell the selection outline lies, in cells.
    nonisolated static let selectionInset = 0.04

    /// The canvas around the board.
    nonisolated static let backgroundColor = Vec4(0.05, 0.06, 0.09, 1)
    /// The board's background.
    nonisolated static let boardColor = Vec4(0.13, 0.14, 0.19, 1)
    /// The grid lines (faint).
    nonisolated static let gridColor = Vec4(1, 1, 1, 0.1)
    /// The walls.
    nonisolated static let wallColor = Vec4(0.46, 0.48, 0.54, 1)
    /// The mirrors.
    nonisolated static let mirrorColor = Vec4(0.86, 0.9, 0.96, 1)
    /// The prisms.
    nonisolated static let prismColor = Vec4(0.55, 0.85, 1, 1)
    /// A target that is not lit.
    nonisolated static let targetColor = Vec4(0.62, 0.16, 0.18, 1)
    /// A lit target.
    nonisolated static let litTargetColor = Vec4(0.16, 0.86, 0.34, 1)
    /// The ring around a lit target.
    nonisolated static let ringColor = Vec4(0.62, 1, 0.66, 1)
    /// The emitter.
    nonisolated static let emitterColor = Vec4(1, 0.82, 0.25, 1)
    /// The beam.
    nonisolated static let beamColor = Vec4(1, 0.36, 0.16, 1)
    /// The beam's halo: the beam colour at ``haloOpacity``.
    nonisolated static var haloColor: Vec4 { Vec4(beamColor.x, beamColor.y, beamColor.z, haloOpacity) }
    /// The selection outline.
    nonisolated static let selectionColor = Vec4(0.3, 0.68, 1, 1)

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = MazeMirror()

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// How many times the scene tree was (re)built.
    private(set) var rebuildCount = 0
    /// How many times the renderer was made.
    private(set) var rendererBuildCount = 0
    /// The number of beam segments drawn by the last frame.
    private(set) var lastSegmentsDrawn = 0
    /// The number of triangles drawn by the last frame.
    private(set) var lastTriangleCount = 0
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The state the scene tree was built for; nil before the first build and after `shedCaches()`.
    private(set) var sceneState: MazeState?
    /// The scene tree of ``sceneState``.
    private(set) var root: SceneNode?
    /// The renderer, made with the current context's registry; nil after `teardown`.
    private(set) var primitives: PrimitiveRenderer?
    /// The clear to the background colour before the board is drawn.
    private let clear = ClearColorScene(red: Float(MazePresenter.backgroundColor.x),
                                        green: Float(MazePresenter.backgroundColor.y),
                                        blue: Float(MazePresenter.backgroundColor.z))

    /// The shell that holds this presenter: gestures read the live state through it. Set by the factory; weak,
    /// because the shell holds the presenter.
    weak var shell: ExperienceShell<MazePresenter>?
    /// The core of the last frame (gestures resolve against it when no shell is set).
    private(set) var lastCore: MazeCore?
    /// The canvas gestures.
    private(set) var gestures = MazeGestures()
    /// The words of the last gesture that changed nothing; nil before one.
    private(set) var lastGestureWords: String?
    /// Whether VoiceOver runs (announcements are posted only then).
    private let voiceOverRunning: @MainActor () -> Bool
    /// Where announcements go.
    let announcementSink: any AnnouncementSink
    /// The rate limit of the spoken beam changes.
    private(set) var announcer = BeamAnnouncer()
    /// The frame clock of the announcements: the sum of the frame times since `setup`, in seconds.
    private(set) var announcementClock = 0.0
    /// The spoken beam text of the last frame; nil before the first.
    private(set) var announcedText: String?
    /// Every text spoken (whether or not VoiceOver ran), oldest first.
    private(set) var spoken: [String] = []

    /// A presenter for the experience `experienceID`. `voiceOverRunning` (nil: `UIAccessibility.isVoiceOverRunning`)
    /// and `announcementSink` (nil: the system's VoiceOver announcements) replace the system's answers in tests.
    init(experienceID: ExperienceID, voiceOverRunning: (@MainActor () -> Bool)? = nil,
         announcementSink: (any AnnouncementSink)? = nil) {
        self.experienceID = experienceID
        self.voiceOverRunning = voiceOverRunning ?? { UIAccessibility.isVoiceOverRunning }
        self.announcementSink = announcementSink ?? SystemAnnouncementSink()
    }

    // MARK: Render scene

    /// Makes the renderer with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        primitives?.release()
        primitives = try PrimitiveRenderer(registry: context.resources)
        rendererBuildCount += 1
        isLive = true
    }

    /// Clears the canvas, rebuilds the scene tree when the state changed, and draws it through the fitting camera.
    func draw(_ core: MazeCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        lastCore = core
        try clear.render(context, frame: frame)
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        let canvas = Vec2(width, height)
        lastCanvas = canvas
        if root == nil || sceneState != core.state {
            root = Self.scene(core)
            sceneState = core.state
            rebuildCount += 1
        }
        if primitives == nil {
            primitives = try PrimitiveRenderer(registry: context.resources)
            rendererBuildCount += 1
        }
        guard let root, let primitives else { return }
        try primitives.draw(root, camera: Self.camera(board: core.board, canvas: canvas),
                            metrics: ViewMetrics(size: canvas, scale: 1))
        lastSegmentsDrawn = core.beam.segments.count
        lastTriangleCount = primitives.lastTriangleCount
        updateAnnouncements(core, delta: frame.delta)
    }

    /// Releases the renderer; the scene tree stays for the next context. The announcements and the gestures start
    /// over.
    func teardown(_ context: RenderContext) {
        isLive = false
        primitives?.release()
        primitives = nil
        lastSegmentsDrawn = 0
        lastTriangleCount = 0
        announcer.reset()
        announcementClock = 0
        announcedText = nil
        gestures.reset()
    }

    /// The experience was suspended or is leaving: every touch is forgotten (nothing is sent).
    func suspended() {
        gestures.reset()
    }

    /// Drops the scene tree; the next draw builds it again from the core.
    func shedCaches() {
        root = nil
        sceneState = nil
    }

    // MARK: Geometry

    /// The camera that fits `board` and a margin of ``margin`` cells on every side into a canvas of `canvas` pixels,
    /// centred on the board (world units: ``unit`` per cell).
    nonisolated static func camera(board: Board, canvas: Vec2) -> Camera2D {
        let w = (Double(board.width) + 2 * margin) * unit, h = (Double(board.height) + 2 * margin) * unit
        let zoom = min(max(canvas.x, 1) / w, max(canvas.y, 1) / h)
        return Camera2D(center: Vec2(Double(board.width) / 2 * unit, Double(board.height) / 2 * unit), zoom: zoom)
    }

    /// The pixel (x from the left, y from the bottom, as the host reads frames back) where the board point `point`
    /// (cells) is drawn on a canvas of `canvas` pixels.
    nonisolated static func pixel(of point: Vec2, board: Board, canvas: Vec2) -> Vec2 {
        let fitted = Self.camera(board: board, canvas: canvas)
        let c = fitted.matrix.apply(point * unit)
        return Vec2(c.x + canvas.x / 2, c.y + canvas.y / 2)
    }

    /// The points of a closed square outline of side `side` centred at `center`.
    nonisolated static func square(center: Vec2, side: Double) -> [Vec2] {
        let h = side / 2
        return [Vec2(center.x - h, center.y - h), Vec2(center.x + h, center.y - h), Vec2(center.x + h, center.y + h),
                Vec2(center.x - h, center.y + h), Vec2(center.x - h, center.y - h)]
    }

    /// The emitter's triangle in its cell: the tip 0.38 cell from the centre toward `direction`, the base 0.3 cell
    /// behind it, 0.6 cell wide.
    nonisolated static func emitterTriangle(center: Vec2, direction: Direction) -> [Vec2] {
        let d = direction.vector, n = Vec2(-d.y, d.x)
        return [center + d * 0.38, center - d * 0.3 + n * 0.3, center - d * 0.3 - n * 0.3]
    }

    /// The scene tree of `core` (see the file header).
    static func scene(_ core: MazeCore) -> SceneNode {
        let board = core.board
        let beam = core.beam
        let root = SceneNode(id: "maze", scale: Vec2(unit, unit))
        let w = Double(board.width), h = Double(board.height)
        root.add(SceneNode(id: "board", position: Vec2(w / 2, h / 2), z: 0, primitive: .rect(Vec2(w, h)),
                           color: boardColor))
        for x in 1..<board.width {
            root.add(SceneNode(id: "grid.x\(x)", z: 1,
                               primitive: .line(Vec2(Double(x), 0), Vec2(Double(x), h), width: gridWidth),
                               color: gridColor))
        }
        for y in 1..<board.height {
            root.add(SceneNode(id: "grid.y\(y)", z: 1,
                               primitive: .line(Vec2(0, Double(y)), Vec2(w, Double(y)), width: gridWidth),
                               color: gridColor))
        }
        let lit = Set(beam.litTargets)
        for (index, tile) in board.tiles.enumerated() {
            let center = tile.cell.center
            switch tile.kind {
            case .wall:
                root.add(SceneNode(id: "tile\(index).wall", position: center, z: 2,
                                   primitive: .rect(Vec2(wallSide, wallSide)), color: wallColor))
            case .mirror, .prism:
                guard let diagonal = tile.segments.first else { continue }
                let color = tile.kind == .mirror ? mirrorColor : prismColor
                root.add(SceneNode(id: "tile\(index).\(tile.kind.rawValue)", z: 2,
                                   primitive: .line(diagonal.a, diagonal.b, width: mirrorWidth), color: color))
                if tile.kind == .prism {
                    root.add(SceneNode(id: "tile\(index).prism.core", z: 2,
                                       primitive: .line(diagonal.a, diagonal.b, width: mirrorWidth / 3),
                                       color: mirrorColor))
                }
            case .target:
                let isLit = lit.contains(tile.cell)
                root.add(SceneNode(id: "tile\(index).target", position: center, z: 2,
                                   primitive: .rect(Vec2(Tile.targetSide, Tile.targetSide)),
                                   color: isLit ? litTargetColor : targetColor))
                if isLit {
                    root.add(SceneNode(id: "tile\(index).ring", z: 2,
                                       primitive: .polyline(square(center: center,
                                                                   side: Tile.targetSide - 2 * ringInset),
                                                            width: ringWidth),
                                       color: ringColor))
                }
            case .emitter:
                root.add(SceneNode(id: "tile\(index).emitter", z: 2,
                                   primitive: .polygon(emitterTriangle(center: center,
                                                                       direction: tile.direction ?? .east)),
                                   color: emitterColor))
            }
        }
        for (index, segment) in beam.segments.enumerated() {
            root.add(SceneNode(id: "beam\(index).halo", z: 3,
                               primitive: .line(segment.start, segment.end, width: haloWidth), color: haloColor))
        }
        for (index, segment) in beam.segments.enumerated() {
            root.add(SceneNode(id: "beam\(index)", z: 4, primitive: .line(segment.start, segment.end, width: beamWidth),
                               color: beamColor))
        }
        if let selected = core.state.selectedTileIndex, board.tiles.indices.contains(selected) {
            root.add(SceneNode(id: "selection", z: 5,
                               primitive: .polyline(square(center: board.tiles[selected].cell.center,
                                                           side: 1 - 2 * selectionInset),
                                                    width: selectionWidth),
                               color: selectionColor))
        }
        return root
    }

    // MARK: Probes

    /// The probes of `core` on the last canvas (see the file header); none before the first frame.
    func probes(_ core: MazeCore) -> [FrameProbe] {
        guard let canvas = lastCanvas else { return [] }
        var probes: [FrameProbe] = []
        if let background = FrameProbe(name: "background", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue) {
            probes.append(background)
        }
        let board = core.board
        let lit = Set(core.beam.litTargets)
        for cell in board.targetCells {
            let p = Self.pixel(of: cell.center, board: board, canvas: canvas)
            let expected = lit.contains(cell) ? FrameColorClass.green : FrameColorClass.red
            if let probe = FrameProbe(name: "target-\(cell.column)-\(cell.row)", x: p.x / canvas.x,
                                      y: 1 - p.y / canvas.y, expected: expected.rawValue) {
                probes.append(probe)
            }
        }
        return probes
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: MazeCore) {
        let state = core.state
        if !mirror.ready { mirror.ready = true }
        if mirror.levelIndex != state.levelIndex { mirror.levelIndex = state.levelIndex }
        if mirror.turnableCount != state.orientations.count { mirror.turnableCount = state.orientations.count }
        if mirror.selection != state.selection { mirror.selection = state.selection }
        let selected = Self.selectedWords(state)
        if mirror.selectedWords != selected { mirror.selectedWords = selected }
        if mirror.solved != core.isSolved { mirror.solved = core.isSolved }
        let status = MazeCore.status(state, beam: core.beam)
        if mirror.status != status { mirror.status = status }
    }

    /// An orientation in words: slash "leaning right", backslash "leaning left".
    nonisolated static func orientationWords(_ orientation: Orientation) -> String {
        orientation == .slash ? "leaning right" : "leaning left"
    }

    /// The selected tile in words: "Mirror 1 of 1, leaning left, column 3, row 3" (columns and rows counted from 1,
    /// rows from the bottom), or "No tile selected".
    nonisolated static func selectedWords(_ state: MazeState) -> String {
        guard let index = state.selectedTileIndex, state.orientations.indices.contains(state.selection) else {
            return "No tile selected"
        }
        let tile = state.board.tiles[index]
        let kind = tile.kind == .prism ? "Prism" : "Mirror"
        return "\(kind) \(state.selection + 1) of \(state.orientations.count), "
            + "\(orientationWords(state.orientations[state.selection])), column \(tile.cell.column + 1), "
            + "row \(tile.cell.row + 1)"
    }

    /// The answer to `result` of `control`: empty when accepted, else why it was refused.
    nonisolated static func answerWords(control: String, result: ActionResult) -> String {
        guard !result.isAccepted else { return "" }
        switch control {
        case "level.next": return "This is the last level."
        case "level.previous": return "This is the first level."
        case "tile.turn": return "Select a mirror or prism first."
        case "tile.select": return "This level has no such tile."
        case "level.select": return "There is no such level."
        default: return "That is not possible here."
        }
    }

    /// The description of `core`'s maze.
    func describe(_ core: MazeCore) -> String {
        sync(core)
        return core.canvasDescription
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MazeControls(port: port, mirror: mirror))
    }

    /// The actions the native controls send (every action: `level.select` through the Level menu).
    var nativeActions: Set<String> {
        ["level.select", "level.next", "level.previous", "tile.select", "tile.turn", "level.reset"]
    }

    // MARK: Gestures

    /// The two tile actions the canvas gestures send (both also sent by the native controls).
    var gestureActions: Set<String> { MazeGestures.gestureActions }

    /// The current state: the shell's, or the one of the last frame.
    var currentState: MazeState? { shell?.engine.core?.state ?? lastCore?.state }

    /// The board point (cells, x east, y north) under the view point `point` (points, top-left origin) of a view of
    /// `viewSize` points whose drawable is `canvas` pixels: the inverse of the board camera (`camera(board:canvas:)`);
    /// nil for a non-finite point or a degenerate view.
    nonisolated static func boardPoint(view point: Vec2, viewSize: Vec2, canvas: Vec2, board: Board) -> Vec2? {
        guard point.isFinite, viewSize.isFinite, canvas.isFinite, viewSize.x > 0, viewSize.y > 0, canvas.x > 0,
              canvas.y > 0 else { return nil }
        let pixel = Vec2(point.x * canvas.x / viewSize.x, (viewSize.y - point.y) * canvas.y / viewSize.y)
        let world = camera(board: board, canvas: canvas).inverse.apply(pixel - canvas / 2)
        let board = world / unit
        return board.isFinite ? board : nil
    }

    /// Turns a canvas pointer event into tile actions sent through `port`.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        pointer(event, viewSize: viewSize) { port.send($0, $1) }
    }

    /// The pointer event `event` turned into tile actions sent through `send` (tests record them). The view maps to
    /// the board through the camera of the last frame (the drawable of the last frame, else the view itself); a
    /// gesture that changed nothing is answered in the controls' message, an accepted action clears it.
    func pointer(_ event: PointerEvent, viewSize: Vec2, send: MazeGestures.Send) {
        let canvas = lastCanvas ?? viewSize
        var sent = false
        var current = gestures
        let words = current.handle(event, state: { self.currentState }, toBoard: { point in
            guard let board = self.currentState?.board else { return nil }
            return Self.boardPoint(view: point, viewSize: viewSize, canvas: canvas, board: board)
        }, send: { control, values in
            sent = true
            return send(control, values)
        })
        gestures = current
        if let words {
            lastGestureWords = words
            mirror.message = words
        } else if sent {
            mirror.message = ""
        }
        if sent, let core = shell?.engine.core { sync(core) }
    }

    // MARK: Spoken changes

    /// The spoken beam text: "Beam ends at the target; solved." (the end words with a capital first letter and
    /// "solved" or "not solved").
    nonisolated static func spokenBeam(_ beam: Beam) -> String {
        let words = MazeCore.endWords(beam)
        let sentence = (words.first.map { $0.uppercased() } ?? "") + String(words.dropFirst())
        return sentence + "; " + (beam.isSolved ? "solved." : "not solved.")
    }

    /// Advances the announcement clock by `delta` seconds of frame time, offers a change of the beam's end words or
    /// solved state and speaks what is due (called by every frame; tests call it with synthetic frame times).
    func updateAnnouncements(_ core: MazeCore, delta: Double) {
        if delta.isFinite, delta > 0 { announcementClock += delta }
        let text = Self.spokenBeam(core.beam)
        if let previous = announcedText, previous != text {
            if let now = announcer.offer(text, at: announcementClock) { speak(now) }
        } else if let due = announcer.tick(at: announcementClock) {
            speak(due)
        }
        announcedText = text
    }

    /// Records `text` and posts it to the sink while VoiceOver runs.
    private func speak(_ text: String) {
        spoken.append(text)
        if voiceOverRunning() { announcementSink.announce(text) }
    }
}

/// The rate limit of Light Maze's spoken beam changes (research D2b; app-local, since Tiny Worlds' `ViewAnnouncer` is
/// internal to its module): an offered text is spoken at once when a second of frame time has passed since the last
/// spoken one, otherwise it is held (the latest offered text wins) and spoken by `tick(at:)` once the second has
/// passed.
struct BeamAnnouncer: Sendable, Equatable {
    /// The least time between two spoken texts, in seconds.
    static let interval = 1.0

    /// The time the last text was spoken; nil before the first.
    private(set) var lastSpoken: Double?
    /// The text held back until the interval has passed (the latest offered).
    private(set) var pending: String?

    /// Creates an announcer that has spoken nothing.
    init() {}

    /// Offers `text` at `time` seconds: returns it when it may be spoken now, otherwise holds it and returns nil.
    mutating func offer(_ text: String, at time: Double) -> String? {
        pending = text
        return tick(at: time)
    }

    /// Returns the held text when the interval since the last spoken text has passed at `time`, otherwise nil.
    mutating func tick(at time: Double) -> String? {
        guard let text = pending else { return nil }
        if let last = lastSpoken, time - last < Self.interval { return nil }
        pending = nil
        lastSpoken = time
        return text
    }

    /// Forgets the held text and the last spoken time.
    mutating func reset() { self = BeamAnnouncer() }
}
