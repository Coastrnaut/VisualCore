// EchoCartographerSceneSnapshot — feature 403 (R02-G11-03) T-R02G1103-002 (FR-R02G1103-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of what the player knows of the kernel's state — the chamber's
// size, the knowledge of every cell (unknown, open, wall), the entry, the markers, the cells of the located beacons, the
// last pulse's echo report (emitter, rays, beacon distances), the stage, the failure, the energy left and the energy
// budget, the level number and the presentation time; plus the palette and the three quality tiers. The snapshot holds
// no unknown wall and no unlocated beacon (nothing hidden can be drawn), and the renderer never holds the kernel, so no
// drawing result can change the game (renderer purity).
import Foundation

/// The palette of Echo Cartographer, sRGB components 0 … 1 (clarification Q3; the design's "abyss black, sonar mint and
/// opal").
public enum EchoCartographerPalette {
    /// The abyss-black ground, #05070A.
    public static let ground = rgb(0x05, 0x07, 0x0A)
    /// A known floor tile, dim opal, #3A4A46.
    public static let floor = rgb(0x3A, 0x4A, 0x46)
    /// A known wall's dark face, #12302A.
    public static let wallFace = rgb(0x12, 0x30, 0x2A)
    /// A known wall's sonar-mint edge strips, #3DF5C4.
    public static let wallEdge = rgb(0x3D, 0xF5, 0xC4)
    /// The flare of a wall struck by the pulse, #B8FFF0.
    public static let flare = rgb(0xB8, 0xFF, 0xF0)
    /// The pulse ring, echo rings and rays, #5FF7FF.
    public static let pulse = rgb(0x5F, 0xF7, 0xFF)
    /// The entry diamond, opal, #CFE3DD.
    public static let entry = rgb(0xCF, 0xE3, 0xDD)
    /// A marker ring, #E8F1EE.
    public static let marker = rgb(0xE8, 0xF1, 0xEE)
    /// A located beacon's pillar, #5FF7FF.
    public static let pillar = rgb(0x5F, 0xF7, 0xFF)
    /// The glow around edges and pillars, #9FFFF7.
    public static let glow = rgb(0x9F, 0xFF, 0xF7)
    /// A lit bar of the energy gauge, #3DF5C4.
    public static let gaugeLit = rgb(0x3D, 0xF5, 0xC4)
    /// An unlit bar of the energy gauge, #1E2A2A.
    public static let gaugeUnlit = rgb(0x1E, 0x2A, 0x2A)

    /// The catalog palette as hex strings: ground, wall edge, floor, entry, pulse.
    public static let hex: [String] = ["#05070A", "#3DF5C4", "#3A4A46", "#CFE3DD", "#5FF7FF"]

    /// The colour of `r`, `g`, `b` bytes.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only the pulse and echo rings, the flare trails and the glow shells, never cells,
/// markers, colours, the gauge or positions. Tiers are ordered richest first: index n is the catalog's `level-n` (the
/// design's "Tier 0 D3-safe" is level-2).
public struct EchoCartographerTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// Whether the pulse ring and the echo rings are drawn.
    public let rings: Bool
    /// Whether struck walls leave flare trails.
    public let flareTrails: Bool
    /// The glow shells around edges and pillars (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: rings, trails and 2 shells; rings and 1 shell; none.
    public static let all: [EchoCartographerTier] = [
        EchoCartographerTier(index: 0, rings: true, flareTrails: true, glowShells: 2),
        EchoCartographerTier(index: 1, rings: true, flareTrails: false, glowShells: 1),
        EchoCartographerTier(index: 2, rings: false, flareTrails: false, glowShells: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> EchoCartographerTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of everything the renderer may read about one Echo Cartographer play at one frame.
public struct EchoCartographerSceneSnapshot: Sendable, Equatable {
    /// The chamber's width in cells.
    public let width: Int
    /// The chamber's height in cells.
    public let height: Int
    /// The knowledge of every cell, by cell index (y · width + x).
    public let knowledge: [EchoCartographerKnown]
    /// The entry.
    public let entry: EchoCartographerCell
    /// The markers, in cell order.
    public let markers: [EchoCartographerCell]
    /// The cells of the located beacons, in beacon order (unlocated beacons are absent).
    public let located: [EchoCartographerCell]
    /// The last pulse's report, if a pulse has been sent (its rays end at revealed walls or the edge).
    public let lastEcho: EchoCartographerEcho?
    /// The play's stage.
    public let stage: EchoCartographerStage
    /// Why the play failed, if it did.
    public let failure: EchoCartographerFailure?
    /// The energy left.
    public let energy: Int
    /// The level's energy budget.
    public let budget: Int
    /// The catalog level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds since the last pulse (rings and flares only).
    public let time: Double

    /// The snapshot of `play` at `time` for catalog level `levelNumber`.
    public init(play: EchoCartographerPlay, levelNumber: Int, time: Double) {
        let level: EchoCartographerLevel = play.level
        width = level.chamber.width
        height = level.chamber.height
        knowledge = play.knowledge.cells
        entry = level.entry
        markers = play.markers.sorted()
        var cells: [EchoCartographerCell] = []
        for index in play.located.keys.sorted() {
            if let cell = level.beacons.indices.contains(index) ? level.beacons[index] : nil { cells.append(cell) }
        }
        located = cells
        lastEcho = play.lastEcho
        stage = play.stage
        failure = play.failure
        energy = play.energy
        budget = level.energy
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// The knowledge of `cell` (`.wall` outside the chamber).
    public func known(_ cell: EchoCartographerCell) -> EchoCartographerKnown {
        guard cell.x >= 0, cell.x < width, cell.y >= 0, cell.y < height else { return .wall }
        return knowledge[cell.y * width + cell.x]
    }

    /// The cells known open, in cell order.
    public var openCells: [EchoCartographerCell] { cells(.open) }

    /// The cells known to be walls, in cell order.
    public var wallCells: [EchoCartographerCell] { cells(.wall) }

    /// The cells with knowledge `kind`, in cell order.
    func cells(_ kind: EchoCartographerKnown) -> [EchoCartographerCell] {
        var result: [EchoCartographerCell] = []
        for (index, known) in knowledge.enumerated() where known == kind {
            result.append(EchoCartographerCell(x: index % width, y: index / width))
        }
        return result
    }

    /// The failure in words, naming the action as the kernel's reason does: "The energy ran out on action 4."; nil when
    /// the play has not failed.
    public static func failureText(_ failure: EchoCartographerFailure?) -> String? {
        switch failure {
        case let .energy(action)?: return "The energy ran out on action \(action + 1)."
        case nil: return nil
        }
    }
}
