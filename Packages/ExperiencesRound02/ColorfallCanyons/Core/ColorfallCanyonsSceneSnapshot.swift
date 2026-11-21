// ColorfallCanyonsSceneSnapshot — feature 343 (R02-G05-03) T-R02G0503-002 (FR-R02G0503-002, 003, 004; clarifications
// Q1–Q4). What the renderer may read: an immutable copy of the kernel's state (the grid, the current heights, the grounds,
// the springs with their valves and supplies left, the basins with their targets, every cell's colour masses and downhill
// direction, the stage, the failure, the tick and the actions left) with the level number and the presentation time, plus
// the palette, the colour patterns and the three quality tiers. The renderer never holds the kernel, so no drawing result
// can change the game (renderer purity).

import Foundation

/// The palette of Colorfall Canyons, sRGB components 0 … 1 (clarification Q3).
public enum ColorfallCanyonsPalette {
    /// Night background, #05070F.
    public static let night = rgb(0x05, 0x07, 0x0F)
    /// Sandstone (open ground), #8C5A3C.
    public static let sandstone = rgb(0x8C, 0x5A, 0x3C)
    /// Rock, #3B302C.
    public static let rock = rgb(0x3B, 0x30, 0x2C)
    /// Pearl (basin rims), #E8E4DA.
    public static let pearl = rgb(0xE8, 0xE4, 0xDA)
    /// Electric cyan, #19E3F0.
    public static let cyan = rgb(0x19, 0xE3, 0xF0)
    /// Coral, #FF6F59.
    public static let coral = rgb(0xFF, 0x6F, 0x59)
    /// Yellow, #FFD23F.
    public static let yellow = rgb(0xFF, 0xD2, 0x3F)
    /// The catalog palette as hex strings: night, sandstone, cyan, coral, yellow.
    public static let hex: [String] = ["#05070F", "#8C5A3C", "#19E3F0", "#FF6F59", "#FFD23F"]

    /// The colour of a fluid colour.
    public static func colour(_ color: ColorfallCanyonsColor) -> SIMD3<Double> {
        switch color {
        case .cyan: cyan
        case .coral: coral
        case .yellow: yellow
        }
    }

    /// The mass-weighted mix of the three fluid colours for `masses` (three values); night for an empty cell.
    public static func fluid(_ masses: [Int]) -> SIMD3<Double> {
        guard masses.count == 3 else { return night }
        let total: Int = masses.reduce(0, +)
        guard total > 0 else { return night }
        var mix = SIMD3<Double>(0, 0, 0)
        for color in ColorfallCanyonsColor.allCases {
            mix += colour(color) * (Double(masses[color.rawValue]) / Double(total))
        }
        return mix
    }

    /// The brightness of a fluid sheet of volume `volume`: 0.35 + 0.65 · min(volume, 24) / 24 (0 for an empty cell).
    public static func brightness(volume: Int) -> Double {
        guard volume > 0 else { return 0 }
        return 0.35 + 0.65 * Double(min(volume, 24)) / 24
    }

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// The pattern each fluid colour also carries, so no colour is told by hue alone: cyan stripes, coral dots, yellow
/// chevrons (clarification Q1).
public enum ColorfallCanyonsPattern: Int, Sendable, CaseIterable, Hashable {
    /// Parallel stripes (cyan).
    case stripes = 0
    /// Dots (coral).
    case dots = 1
    /// Chevrons (yellow).
    case chevrons = 2

    /// The pattern of `color`.
    public static func of(_ color: ColorfallCanyonsColor) -> ColorfallCanyonsPattern {
        switch color {
        case .cyan: .stripes
        case .coral: .dots
        case .yellow: .chevrons
        }
    }
}

/// One quality tier: it changes only the terrain subdivision, the flow bands and the glow shells, never cells, colours,
/// objective or indicators. Tiers are ordered richest first: index n is the catalog's `level-n` (the design's "Tier 0
/// D3-safe" is level-2).
public struct ColorfallCanyonsTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The subdivisions of each block top per side.
    public let subdivision: Int
    /// The flow bands per channel.
    public let flowBands: Int
    /// The glow shells (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: subdivision 4/2/1, flow bands 3/2/1, glow shells 2/1/0.
    public static let all: [ColorfallCanyonsTier] = [
        ColorfallCanyonsTier(index: 0, subdivision: 4, flowBands: 3, glowShells: 2),
        ColorfallCanyonsTier(index: 1, subdivision: 2, flowBands: 2, glowShells: 1),
        ColorfallCanyonsTier(index: 2, subdivision: 1, flowBands: 1, glowShells: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> ColorfallCanyonsTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of everything the renderer may read about one Colorfall Canyons play at one frame.
public struct ColorfallCanyonsSceneSnapshot: Sendable, Equatable {
    /// A spring as the renderer sees it.
    public struct Spring: Sendable, Equatable, Hashable {
        /// The cell it sits on.
        public let cell: Int
        /// Its colour.
        public let color: ColorfallCanyonsColor
        /// Whether its valve is open.
        public let open: Bool
        /// The units it can still release.
        public let supplyLeft: Int

        /// Whether it is releasing (open with supply left).
        public var flowing: Bool { open && supplyLeft > 0 }
    }

    /// The grid's columns.
    public let columns: Int
    /// The grid's rows.
    public let rows: Int
    /// The current height of every cell, row-major.
    public let heights: [Int]
    /// The ground of every cell.
    public let grounds: [ColorfallCanyonsGround]
    /// The springs.
    public let springs: [Spring]
    /// The basins with their targets.
    public let basins: [ColorfallCanyonsBasin]
    /// The colour masses of every cell.
    public let masses: [[Int]]
    /// Every cell's downhill neighbour (nil: none).
    public let downhill: [Int?]
    /// The play's stage.
    public let stage: ColorfallCanyonsStage
    /// Why the play failed, if it did.
    public let failure: ColorfallCanyonsFailure?
    /// The ticks run.
    public let tick: Int
    /// The level's tick limit.
    public let tickLimit: Int
    /// The carves and valve toggles left.
    public let remaining: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (flow bands only; never read by the rules).
    public let time: Double

    /// A snapshot of `play` at presentation time `time` (non-finite times become 0).
    public init(play: ColorfallCanyonsPlay, levelNumber: Int, time: Double) {
        let level: ColorfallCanyonsLevel = play.level
        let fluid: ColorfallCanyonsFluid = play.fluid
        columns = level.columns
        rows = level.rows
        heights = fluid.heights
        grounds = level.grounds
        springs = level.springs.indices.map { i in
            Spring(cell: level.springs[i].cell, color: level.springs[i].color, open: fluid.valves[i],
                   supplyLeft: fluid.supplies[i])
        }
        basins = level.basins
        masses = fluid.masses
        downhill = (0..<level.cellCount).map { fluid.downhill(of: $0, level: level) }
        stage = play.stage
        failure = play.failure
        tick = fluid.tick
        tickLimit = level.tickLimit
        remaining = play.remaining
        self.levelNumber = levelNumber
        self.time = time.isFinite ? time : 0
    }

    /// The number of cells.
    public var cellCount: Int { columns * rows }

    /// The volume of `cell`.
    public func volume(_ cell: Int) -> Int { masses[cell].reduce(0, +) }

    /// Whether a basin sits on `cell`.
    public func isBasin(_ cell: Int) -> Bool { basins.contains { $0.cell == cell } }

    /// Whether a spring sits on `cell`.
    public func isSpring(_ cell: Int) -> Bool { springs.contains { $0.cell == cell } }
}
