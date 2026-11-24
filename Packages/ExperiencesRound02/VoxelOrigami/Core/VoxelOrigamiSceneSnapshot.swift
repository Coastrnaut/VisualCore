// VoxelOrigamiSceneSnapshot — feature 443 (R02-G15-03) T-R02G1503-002 (FR-R02G1503-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the cubes (parents, rest directions,
// start turns), the pose's cells and orientations, the quarter turns, the hinges that can turn, the chosen hinge, the
// target cells at the best allowed alignment (the alignment the kernel's covered count uses), the kernel's shape report,
// the stage, the failure, the actions left and the budget, the level number and the presentation time; plus the palette
// and the three quality tiers. The renderer never holds the kernel, so no drawing result can change the game (renderer
// purity), and the drawn cubes are the kernel's cells.
import Foundation

/// The palette of Voxel Origami, as linear colours 0 … 1 (frosted ivory and laser turquoise on night).
public enum VoxelOrigamiPalette {
    /// The night backdrop, #0B0D16.
    public static let night = rgb(0x0B, 0x0D, 0x16)
    /// The frosted-ivory cube faces, #EDE8DC.
    public static let ivory = rgb(0xED, 0xE8, 0xDC)
    /// The shaded facets and bevels of the cubes, #B9B2A3.
    public static let ivoryShade = rgb(0xB9, 0xB2, 0xA3)
    /// The target wireframe, #2EE6D6.
    public static let target = rgb(0x2E, 0xE6, 0xD6)
    /// The target's glow, #8FF5EC.
    public static let targetGlow = rgb(0x8F, 0xF5, 0xEC)
    /// A hinge bar, #7F7A70.
    public static let hinge = rgb(0x7F, 0x7A, 0x70)
    /// The chosen hinge's bar and stripes, #FF3C8C.
    public static let hingeChosen = rgb(0xFF, 0x3C, 0x8C)
    /// The solid inner glyph of a cube on a target cell, #2EE6D6.
    public static let glyphSolid = rgb(0x2E, 0xE6, 0xD6)
    /// The hollow inner glyph of a cube off the target, #4A4E5C.
    public static let glyphHollow = rgb(0x4A, 0x4E, 0x5C)
    /// The dots naming a cube, #3A3D48.
    public static let dots = rgb(0x3A, 0x3D, 0x48)
    /// A lit covered pip, #FF3C8C.
    public static let coveredLit = rgb(0xFF, 0x3C, 0x8C)
    /// An unlit covered pip, #2A2D3A.
    public static let coveredUnlit = rgb(0x2A, 0x2D, 0x3A)
    /// A lit moves bar, #2EE6D6.
    public static let movesLit = rgb(0x2E, 0xE6, 0xD6)
    /// An unlit moves bar, #2A2D3A.
    public static let movesUnlit = rgb(0x2A, 0x2D, 0x3A)
    /// The outline of what a failure names, #FF6B4A.
    public static let broken = rgb(0xFF, 0x6B, 0x4A)
    /// The glow shells, #FFF4E0.
    public static let glow = rgb(0xFF, 0xF4, 0xE0)

    /// The palette's main hex values (night, ivory, turquoise, magenta, shade), as registered in the catalog.
    public static let hex: [String] = ["#0B0D16", "#EDE8DC", "#2EE6D6", "#FF3C8C", "#B9B2A3"]

    /// The linear colour of 8-bit components.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). Cubes, cells, orientations,
/// hinges, target, glyphs, dots, gauges, colours and positions are the same at every tier; only the chamfer bevel, the
/// edge width and the glow differ.
public struct VoxelOrigamiTier: Sendable, Equatable, Hashable {
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// The chamfer bevel steps of each cube edge (0 is a plain box).
    public let bevelSteps: Int
    /// The target wireframe's edge width, as a fraction of the cell scale s.
    public let edgeWidth: Double
    /// The glow shells around the lit cubes and the target outline.
    public let glowShells: Int

    /// The three tiers, richest first.
    public static let all: [VoxelOrigamiTier] = [
        VoxelOrigamiTier(index: 0, bevelSteps: 2, edgeWidth: 0.06, glowShells: 2),
        VoxelOrigamiTier(index: 1, bevelSteps: 1, edgeWidth: 0.05, glowShells: 1),
        VoxelOrigamiTier(index: 2, bevelSteps: 0, edgeWidth: 0.04, glowShells: 0),
    ]

    /// The tier's name, `level-0` … `level-2`.
    public var name: String { "level-\(index)" }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> VoxelOrigamiTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct VoxelOrigamiSceneSnapshot: Sendable, Equatable {
    /// The cubes (parents, rest directions, start turns).
    public let cubes: [VoxelOrigamiCube]
    /// The pose's cells, one per cube (the kernel's).
    public let cells: [VoxelOrigamiVector]
    /// The pose's orientations, one per cube.
    public let orientations: [VoxelOrigamiRotation]
    /// The quarter turns, one per cube (the root's is 0).
    public let turns: [Int]
    /// The hinges that can turn now (ascending).
    public let turnable: [Int]
    /// The chosen hinge, 1 … cubes − 1 (presentation only; never part of the digest).
    public let chosenHinge: Int
    /// The target cells at the best allowed alignment (sorted): the rotation and translation of the kernel's covered
    /// count applied to the level's target.
    public let target: [VoxelOrigamiVector]
    /// The kernel's shape report at the current turns.
    public let report: VoxelOrigamiShapeReport
    /// The stage.
    public let stage: VoxelOrigamiStage
    /// The failure, if the play failed.
    public let failure: VoxelOrigamiFailure?
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double

    /// A snapshot of `play` with hinge `chosenHinge` chosen (clamped to 1 … cubes − 1).
    public init(play: VoxelOrigamiPlay, chosenHinge: Int, levelNumber: Int, time: Double) {
        let level: VoxelOrigamiLevel = play.level
        cubes = level.cubes
        cells = play.pose.cells
        orientations = play.pose.orientations
        turns = play.turns
        var turnable: [Int] = []
        for hinge in 1..<level.cubes.count where level.canTurn(hinge, turns: play.turns) { turnable.append(hinge) }
        self.turnable = turnable
        self.chosenHinge = min(max(chosenHinge, 1), level.cubes.count - 1)
        let group: [VoxelOrigamiRotation] = level.orientations.group
        let best = VoxelOrigamiLattice.covered(target: level.target, occupied: play.pose.occupied, group: group)
        let rotation: VoxelOrigamiRotation = group[best.rotation]
        target = level.target.map { rotation.applied(to: $0) + best.translation }.sorted()
        report = play.report
        stage = play.stage
        failure = play.failure
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// Whether the play is won.
    public var isWon: Bool { stage == .won }

    /// Whether cube `index`'s cell is a target cell (its glyph is solid).
    public func isOnTarget(_ index: Int) -> Bool { Set(target).contains(cells[index]) }

    /// The hinge, moving cube, still cube and cell a collision or sweep failure names, if any.
    public var brokenTurn: (hinge: Int, moving: Int, still: Int, cell: VoxelOrigamiVector)? {
        switch failure {
        case .collision(let hinge, let moving, let still, let cell), .sweep(let hinge, let moving, let still, let cell):
            (hinge, moving, still, cell)
        default: nil
        }
    }
}
