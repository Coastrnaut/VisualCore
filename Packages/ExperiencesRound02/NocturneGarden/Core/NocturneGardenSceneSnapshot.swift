// NocturneGardenSceneSnapshot — feature 383 (R02-G09-03) T-R02G0903-002 (FR-R02G0903-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the bed size, the target, forbidden,
// shadow (the kernel's exact mask) and leaking cells (mask ∩ forbidden) as sorted arrays, the planted blooms in
// canonical order, the sun elevation, the stage, the failure, the moves spent, the budget, the level number and the
// presentation time; plus the palette and the three quality tiers. The shadow drawn is the kernel's mask, never a
// shadow computed by the graphics; the renderer never holds the kernel, so no drawing result can change the game
// (renderer purity).
import Foundation

/// The palette of Nocturne Garden, sRGB components 0 … 1 (clarification Q3; the design's "midnight blue, lantern coral
/// and parchment gold").
public enum NocturneGardenPalette {
    /// The midnight ground, #0A1230.
    public static let ground = rgb(0x0A, 0x12, 0x30)
    /// The pearlescent mist of the bed, #B8C4E0.
    public static let mist = rgb(0xB8, 0xC4, 0xE0)
    /// The highlight of the drifting mist, #E6ECF7.
    public static let mistHighlight = rgb(0xE6, 0xEC, 0xF7)
    /// The deep black shadow, #05060A.
    public static let shadow = rgb(0x05, 0x06, 0x0A)
    /// The parchment-gold rim of the target, #E8C872.
    public static let gold = rgb(0xE8, 0xC8, 0x72)
    /// The lantern-coral hatch of the forbidden cells, #FF7A5C.
    public static let coral = rgb(0xFF, 0x7A, 0x5C)
    /// The cross on a leaking cell, #FF3B30.
    public static let leak = rgb(0xFF, 0x3B, 0x30)
    /// The dark botanical body of a bloom, #10131C.
    public static let body = rgb(0x10, 0x13, 0x1C)
    /// The glowing rim of a bloom's head, #FFB88A.
    public static let glow = rgb(0xFF, 0xB8, 0x8A)
    /// The lantern (the sun), #FFD9A0.
    public static let lantern = rgb(0xFF, 0xD9, 0xA0)
    /// A spent bar of the move gauge, #FF7A5C.
    public static let spent = rgb(0xFF, 0x7A, 0x5C)
    /// An unspent bar of the move gauge, #3A4558.
    public static let unspent = rgb(0x3A, 0x45, 0x58)

    /// The catalog palette as hex strings: ground, mist, gold, coral, shadow.
    public static let hex: [String] = ["#0A1230", "#B8C4E0", "#E8C872", "#FF7A5C", "#05060A"]

    /// The colour of `r`, `g`, `b` bytes.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only the mist layers, the stem depth, the shadow feather and the glow shells, never
/// cells, blooms' heads, colours, the gauge or positions. Tiers are ordered richest first: index n is the catalog's
/// `level-n` (the design's "Tier 0 D3-safe" is level-2).
public struct NocturneGardenTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The drifting mist layers of the bed shader.
    public let mistLayers: Int
    /// The L-system depth of a bloom's stem (one leaf pair per level).
    public let stemDepth: Int
    /// The width of the shadow's feathered edge, in cells (0: hard edges).
    public let feather: Double
    /// The glow shells over the blooms' heads (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: 3/2/1 mist layers, stem depth 3/2/1, feather 0.3/0.15/0, glow shells 2/1/0.
    public static let all: [NocturneGardenTier] = [
        NocturneGardenTier(index: 0, mistLayers: 3, stemDepth: 3, feather: 0.3, glowShells: 2),
        NocturneGardenTier(index: 1, mistLayers: 2, stemDepth: 2, feather: 0.15, glowShells: 1),
        NocturneGardenTier(index: 2, mistLayers: 1, stemDepth: 1, feather: 0, glowShells: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> NocturneGardenTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of everything the renderer may read about one Nocturne Garden play at one frame.
public struct NocturneGardenSceneSnapshot: Sendable, Equatable {
    /// The bed width in cells.
    public let width: Int
    /// The bed height in cells.
    public let height: Int
    /// The target cells, ascending.
    public let target: [Int]
    /// The forbidden cells, ascending.
    public let forbidden: [Int]
    /// The shadow cells: the kernel's mask, ascending.
    public let shadow: [Int]
    /// The leaking cells (mask ∩ forbidden), ascending; crossed in the picture only after a leak failure.
    public let leaking: [Int]
    /// The planted blooms, in the kernel's canonical order.
    public let blooms: [NocturneGardenBloom]
    /// The level's allowed bloom sizes, ascending (the camera fits every head they can make).
    public let sizes: [Int]
    /// The sun elevation (1 high … 4 low).
    public let sun: Int
    /// The play's stage.
    public let stage: NocturneGardenStage
    /// Why the play failed, if it did.
    public let failure: NocturneGardenFailure?
    /// The moves spent.
    public let moves: Int
    /// The move budget.
    public let budget: Int
    /// The catalog level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (mist drift and sway only).
    public let time: Double
    /// The would-be shadow cells of a drag in progress, ascending (feature 384, R02-G09-04: the silhouette preview as
    /// exact diagnostic); empty when no bloom is being dragged. Presentation only.
    public private(set) var preview: [Int] = []

    /// The snapshot of `play` at `time` for catalog level `levelNumber`.
    public init(play: NocturneGardenPlay, levelNumber: Int, time: Double) {
        let level: NocturneGardenLevel = play.level
        width = level.width
        height = level.height
        target = level.target.sorted()
        forbidden = level.forbidden.sorted()
        shadow = play.mask.cells.sorted()
        leaking = play.mask.cells.intersection(level.forbidden).sorted()
        blooms = play.blooms
        sizes = level.sizes.sorted()
        sun = play.elevation
        stage = play.stage
        failure = play.failure
        moves = play.moves
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? time : 0
    }

    /// This snapshot with `cells` (sorted, clipped to the bed) as the drag preview.
    public func withPreview(_ cells: [Int]) -> NocturneGardenSceneSnapshot {
        var copy: NocturneGardenSceneSnapshot = self
        copy.preview = cells.filter { $0 >= 0 && $0 < width * height }.sorted()
        return copy
    }

    /// Whether the play failed by a leak (the leaking cells are then crossed).
    public var leakFailure: Bool {
        if case .leak = failure { return true }
        return false
    }
}
