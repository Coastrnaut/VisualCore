// MazePresenter — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121; clarification Q5; research D5; plan
// "Lifecycle"). Draws Light Maze through the host only (the host's context and registry, VisualCore's
// `PrimitiveRenderer` with a `Camera2D`; no context of its own, no second renderer, no imported assets). The presenter
// reads the core and never writes it:
//   - Scene: one `SceneNode` tree per state, in board coordinates (one unit per cell, x east, y north) under a root
//     scaled by ``MazePresenter/unit`` (10 world units per cell, so the camera's zoom stays inside `Camera2D.zoomRange`
//     on every canvas from 13 to 3,000 pixels): the board background, a faint grid, the tiles (walls as filled squares,
//     mirrors and prisms as thick diagonal lines, targets as squares that turn green and gain a ring when lit, the
//     emitter as a triangle pointing where it shines), the beam as lines of width 0.08 cell along the tracer's exact
//     segments, and an outline around the selected tile. The tree is rebuilt only when the state changes (level,
//     orientations or selection: everything the digest covers, since the beam follows from the state); it is CPU data
//     and survives a context recreation; `shedCaches()` drops it.
//   - GPU objects: one `PrimitiveRenderer`, made in `setup` with the host's registry (so it is made again after a
//     context recreation; `draw` makes it when missing) and released in `teardown`.
//   - Camera: centred on the board, its zoom fitting the board and a margin of half a cell on every side into the
//     canvas; the canvas is cleared to the background colour first.
//   - Probes: the background at (0.02, 0.02) from the top left (always outside the board: the margin is at least
//     0.5 / 13 of either side) and the centre of each target, green when lit, red when not.
//   - Words: the canvas description of `MazeCore` ("Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at
//     the wall; not solved."); the controls show the status, the selected tile and the answer to a refused action.
// There is no motion, so Reduce Motion changes nothing; nothing flashes. No audio.
import Foundation
import LightMazeCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

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
    /// The beam's width in cells.
    nonisolated static let beamWidth = 0.08
    /// The width of a mirror's or a prism's line in cells.
    nonisolated static let mirrorWidth = 0.16
    /// The width of the grid lines in cells.
    nonisolated static let gridWidth = 0.03
    /// The side of a wall's square in cells.
    nonisolated static let wallSide = 0.96
    /// The radius and width of a lit target's ring in cells.
    nonisolated static let ringRadius = 0.42, ringWidth = 0.07
    /// The width of the selection outline in cells.
    nonisolated static let selectionWidth = 0.07

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

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
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
    }

    /// Releases the renderer; the scene tree stays for the next context.
    func teardown(_ context: RenderContext) {
        isLive = false
        primitives?.release()
        primitives = nil
        lastSegmentsDrawn = 0
        lastTriangleCount = 0
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

    /// The points of a closed circle of `radius` around `center` (32 sides).
    nonisolated static func circle(center: Vec2, radius: Double) -> [Vec2] {
        var points: [Vec2] = []
        for i in 0...32 {
            let angle = 2 * Double.pi * Double(i) / 32
            points.append(Vec2(center.x + cos(angle) * radius, center.y + sin(angle) * radius))
        }
        return points
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
                                       primitive: .polyline(circle(center: center, radius: ringRadius),
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
            root.add(SceneNode(id: "beam\(index)", z: 3, primitive: .line(segment.start, segment.end, width: beamWidth),
                               color: beamColor))
        }
        if let selected = core.state.selectedTileIndex, board.tiles.indices.contains(selected) {
            root.add(SceneNode(id: "selection", z: 4,
                               primitive: .polyline(square(center: board.tiles[selected].cell.center, side: 0.92),
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

    /// The actions the native controls send (every action but `level.select`, which the controls reach step by step
    /// through Previous level and Next level); there is no canvas gesture in this phase.
    var nativeActions: Set<String> { ["level.next", "level.previous", "tile.select", "tile.turn", "level.reset"] }
}
