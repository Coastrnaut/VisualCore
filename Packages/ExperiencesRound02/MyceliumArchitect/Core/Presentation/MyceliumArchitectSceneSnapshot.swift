// MyceliumArchitectSceneSnapshot — feature 513 (R02-G22-03) T-R02G2203-002 (FR-R02G2203-002, 003, 004; clarifications
// Q1–Q4; data-model.md; contracts/api.md). What the renderer may read: an immutable copy of the kernel's state — the
// level (board, root, terminals, rocks, toxins, fixed nutrients, sites, budgets and limits); the arrangement; from the
// kernel's growth report of the current arrangement the grown cells in growth order with their pulses and parent
// indices, each grown cell's path weight from the root (the sum of the step weights along its parents, exactly as the
// kernel sums a terminal's path weight), the cells whose nutrient a step consumed, the total weight, the terminal
// pulses and the pulses run; the shown pulse (0 … pulses run), the fit scale s = 1.9 / max(W, H), the failure, the
// stage, the actions left, the level number and the presentation time; plus the palette and the three quality tiers.
// The renderer never holds the kernel, so no drawing result can change the game (renderer purity), and every drawn
// cell, segment, weight and terminal state is the kernel's integer. Lives in `Core/Presentation/`, outside the kernel's
// source scans of features 511 and 512 (research R2). Modelled on `BinaryGardensSceneSnapshot` (feature 503).
import Foundation
import VisualCoreMath

/// The palette of Mycelium Architect, as linear colours 0 … 1 with alpha 1 (emerald, copper and violet roots in a dark
/// cave; clarification Q3).
public enum MyceliumArchitectPalette {
    /// The cave at the bottom of the backdrop, #06070A.
    public static let cave: Vec4 = rgb(0x06, 0x07, 0x0A)
    /// The cave at the top of the backdrop, #12161C.
    public static let caveTop: Vec4 = rgb(0x12, 0x16, 0x1C)
    /// The hashed spore points of the backdrop, #9FE8C8.
    public static let spore: Vec4 = rgb(0x9F, 0xE8, 0xC8)
    /// The floor plate under the board, #14171C.
    public static let floor: Vec4 = rgb(0x14, 0x17, 0x1C)
    /// The grid lines of the floor, #1E232B.
    public static let grid: Vec4 = rgb(0x1E, 0x23, 0x2B)
    /// A placement site's dashed square, #4A5568.
    public static let site: Vec4 = rgb(0x4A, 0x55, 0x68)
    /// A toxin pool, violet, #7B3FB8.
    public static let toxin: Vec4 = rgb(0x7B, 0x3F, 0xB8)
    /// A rock block, #3B2F2A.
    public static let rock: Vec4 = rgb(0x3B, 0x2F, 0x2A)
    /// The copper veins of a rock, #C8743A.
    public static let veinCopper: Vec4 = rgb(0xC8, 0x74, 0x3A)
    /// A blocker's stone disc, #2A2D33.
    public static let blocker: Vec4 = rgb(0x2A, 0x2D, 0x33)
    /// A blocker's ring, #8A8F98.
    public static let ring: Vec4 = rgb(0x8A, 0x8F, 0x98)
    /// A nutrient orb, fixed or placed, copper, #E08A3C.
    public static let nutrient: Vec4 = rgb(0xE0, 0x8A, 0x3C)
    /// A grown vein, emerald, #2FE08A.
    public static let emerald: Vec4 = rgb(0x2F, 0xE0, 0x8A)
    /// A seeded direction's sprout, #5BE38F.
    public static let sprout: Vec4 = rgb(0x5B, 0xE3, 0x8F)
    /// The root cap, #9FF2D0.
    public static let cap: Vec4 = rgb(0x9F, 0xF2, 0xD0)
    /// A terminal cap not reached by the shown pulse (closed, hollow), #4B6B60.
    public static let capClosed: Vec4 = rgb(0x4B, 0x6B, 0x60)
    /// A terminal cap reached by the shown pulse (open, lit), #C9FFE9.
    public static let capOpen: Vec4 = rgb(0xC9, 0xFF, 0xE9)
    /// A gauge's plate, #1A2347.
    public static let gaugePlate: Vec4 = rgb(0x1A, 0x23, 0x47)
    /// The weight bar's fill, #2FE08A.
    public static let weight: Vec4 = rgb(0x2F, 0xE0, 0x8A)
    /// The weight limit's tick, #E0E6EE.
    public static let limit: Vec4 = rgb(0xE0, 0xE6, 0xEE)
    /// A lit actions bar, copper, #E08A3C.
    public static let actionsLit: Vec4 = rgb(0xE0, 0x8A, 0x3C)
    /// An unlit actions bar, #1E2648.
    public static let actionsUnlit: Vec4 = rgb(0x1E, 0x26, 0x48)
    /// What a failure names, #FF6B5E.
    public static let broken: Vec4 = rgb(0xFF, 0x6B, 0x5E)
    /// The glow shells, #F2FFF8.
    public static let glow: Vec4 = rgb(0xF2, 0xFF, 0xF8)

    /// The palette's main hex values (cave, emerald, copper nutrient, violet toxin, cave top), as registered in the
    /// catalog.
    public static let hex: [String] = ["#06070A", "#2FE08A", "#E08A3C", "#7B3FB8", "#12161C"]

    /// Every colour of the palette by name with its hex value, in declaration order (24 entries).
    static let all: [(name: String, hex: String, colour: Vec4)] = [
        ("cave", "#06070A", cave), ("caveTop", "#12161C", caveTop), ("spore", "#9FE8C8", spore),
        ("floor", "#14171C", floor), ("grid", "#1E232B", grid), ("site", "#4A5568", site),
        ("toxin", "#7B3FB8", toxin), ("rock", "#3B2F2A", rock), ("veinCopper", "#C8743A", veinCopper),
        ("blocker", "#2A2D33", blocker), ("ring", "#8A8F98", ring), ("nutrient", "#E08A3C", nutrient),
        ("emerald", "#2FE08A", emerald), ("sprout", "#5BE38F", sprout), ("cap", "#9FF2D0", cap),
        ("capClosed", "#4B6B60", capClosed), ("capOpen", "#C9FFE9", capOpen), ("gaugePlate", "#1A2347", gaugePlate),
        ("weight", "#2FE08A", weight), ("limit", "#E0E6EE", limit), ("actionsLit", "#E08A3C", actionsLit),
        ("actionsUnlit", "#1E2648", actionsUnlit), ("broken", "#FF6B5E", broken), ("glow", "#F2FFF8", glow),
    ]

    /// The linear colour of 8-bit components, alpha 1.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Vec4 {
        Vec4(Double(r) / 255, Double(g) / 255, Double(b) / 255, 1)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). The backdrop, the floor and grid,
/// the cells, the network's segments and radii, the caps' positions and sizes, the pips, gauges, actions bars and
/// colours are the same at every tier; only the tube sides, the cap segments, the hyphae fuzz, the spores and the glow
/// differ.
public struct MyceliumArchitectTier: Sendable, Equatable, Hashable {
    /// The tier's name, `level-0` … `level-2`.
    public let name: String
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// The sides of each tapered vein tube (8, 6, 4).
    public let tubeSides: Int
    /// The segments around each root and terminal cap (16, 12, 8).
    public let capSegments: Int
    /// The hyphae fuzz strands at every branch point and under every open cap (6, 3, 0: none).
    public let fuzzStrands: Int
    /// The drifting spores (24, 12, 0: none).
    public let spores: Int
    /// The glow shells around the root, the open caps and the blooms (2, 1, 0: no glow).
    public let glowShells: Int

    /// The three tiers, richest first.
    public static let all: [MyceliumArchitectTier] = [
        MyceliumArchitectTier(index: 0, tubeSides: 8, capSegments: 16, fuzzStrands: 6, spores: 24, glowShells: 2),
        MyceliumArchitectTier(index: 1, tubeSides: 6, capSegments: 12, fuzzStrands: 3, spores: 12, glowShells: 1),
        MyceliumArchitectTier(index: 2, tubeSides: 4, capSegments: 8, fuzzStrands: 0, spores: 0, glowShells: 0),
    ]

    /// A tier of the given values, named `level-<index>`.
    init(index: Int, tubeSides: Int, capSegments: Int, fuzzStrands: Int, spores: Int, glowShells: Int) {
        name = "level-\(index)"
        self.index = index
        self.tubeSides = tubeSides
        self.capSegments = capSegments
        self.fuzzStrands = fuzzStrands
        self.spores = spores
        self.glowShells = glowShells
    }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> MyceliumArchitectTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct MyceliumArchitectSceneSnapshot: Sendable, Equatable {
    /// The side of the square every board fills (clarification Q1).
    public static let boardSide: Double = 1.9

    /// The level: board, root, terminals, rocks, toxins, fixed nutrients, sites, budgets and limits.
    public let level: MyceliumArchitectLevel
    /// The arrangement: placed nutrients, placed blockers and seeds.
    public let arrangement: MyceliumArchitectArrangement
    /// The grown cells in growth order, the root first (the report's `grown`).
    public let grown: [MyceliumArchitectCell]
    /// The pulse each grown cell was grown, aligned with ``grown`` (root: 0).
    public let grownPulses: [Int]
    /// Each grown cell's parent as an index into ``grown`` (root: nil).
    public let parents: [Int?]
    /// Each grown cell's path weight from the root, aligned with ``grown`` (root: 0): the parent's path weight plus the
    /// weight of the step that grew it.
    public let pathWeights: [Int]
    /// The cells whose nutrient a step consumed, in step order.
    public let consumed: [MyceliumArchitectCell]
    /// The network's total branch weight.
    public let totalWeight: Int
    /// Each terminal's reach pulse, or nil when the network never reaches it.
    public let terminalPulses: [Int?]
    /// The pulses in which at least one tip was growing.
    public let pulsesRun: Int
    /// The shown pulse, 0 … ``pulsesRun`` (presentation only; never part of the digest).
    public let shownPulse: Int
    /// The fit scale s = 1.9 / max(W, H).
    public let fitScale: Double
    /// The failure: the play's on a failed play, otherwise the report's prediction (nil when a run would win).
    public let failure: MyceliumArchitectFailure?
    /// The stage.
    public let stage: MyceliumArchitectStage
    /// The actions left.
    public let actionsLeft: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double

    /// A snapshot of `play` with pulse `shownPulse` shown (clamped to 0 … the pulses run), at presentation time `time`
    /// (a non-finite or negative time becomes 0). Copies the play's report; never holds the kernel.
    public init(play: MyceliumArchitectPlay, shownPulse: Int, levelNumber: Int, time: Double) {
        self.init(level: play.level, arrangement: play.arrangement, report: play.report,
                  failure: play.failure ?? play.report.failure, stage: play.stage, actionsLeft: play.actionsLeft,
                  shownPulse: shownPulse, levelNumber: levelNumber, time: time)
    }

    /// A snapshot of `report` of `arrangement` in `level` with the given failure, stage and actions left, unchecked
    /// (presentation variants and tests: failures and stages a play may not reach); `shownPulse` is clamped to 0 … the
    /// report's pulses run and `time` made finite and non-negative.
    init(level: MyceliumArchitectLevel, arrangement: MyceliumArchitectArrangement, report: MyceliumArchitectReport,
         failure: MyceliumArchitectFailure?, stage: MyceliumArchitectStage, actionsLeft: Int, shownPulse: Int,
         levelNumber: Int, time: Double) {
        self.level = level
        self.arrangement = arrangement
        grown = report.grown
        grownPulses = report.grownPulses
        parents = report.parents
        pathWeights = Self.pathWeights(report)
        var eaten: [MyceliumArchitectCell] = []
        for step in report.steps where step.consumed { eaten.append(step.to) }
        consumed = eaten
        totalWeight = report.totalWeight
        terminalPulses = report.terminalPulses
        pulsesRun = report.pulsesRun
        self.shownPulse = min(max(shownPulse, 0), report.pulsesRun)
        fitScale = Self.fitScale(width: level.width, height: level.height)
        self.failure = failure
        self.stage = stage
        self.actionsLeft = actionsLeft
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// The fit scale s = 1.9 / max(W, H) (W and H at least 1).
    public static func fitScale(width: Int, height: Int) -> Double {
        boardSide / Double(max(width, height, 1))
    }

    /// Each grown cell's path weight of `report` (root 0; cell i ≥ 1 is grown by step i − 1, so its path weight is its
    /// parent's plus that step's weight); a cell without a matching step or parent keeps its parent's weight or 0.
    static func pathWeights(_ report: MyceliumArchitectReport) -> [Int] {
        var weights: [Int] = []
        for index in report.grown.indices {
            var weight: Int = 0
            if index > 0, index < report.parents.count, let parent = report.parents[index], parent < weights.count {
                weight = weights[parent]
                if index - 1 < report.steps.count { weight += report.steps[index - 1].weight }
            }
            weights.append(weight)
        }
        return weights
    }

    /// The action budget.
    public var budget: Int { level.budget }
    /// The nutrient budget (the weight bar's end).
    public var nutrientBudget: Int { level.nutrientBudget }
    /// The branch-weight limit (the weight bar's tick).
    public var weightLimit: Int { level.weightLimit }
    /// The largest path weight of the network (0 for the root alone).
    public var largestPathWeight: Int { pathWeights.max() ?? 0 }

    /// Whether the play is won (the won stage, or the result shown after a winning run).
    public var isWon: Bool { stage == .won || (stage == .result && failure == nil) }

    /// Whether grown cell `grownIndex` is drawn at the shown pulse: its grown pulse is at most ``shownPulse`` (false
    /// for an index the snapshot lacks).
    public func isShown(_ grownIndex: Int) -> Bool {
        guard grownPulses.indices.contains(grownIndex) else { return false }
        return grownPulses[grownIndex] <= shownPulse
    }

    /// Whether terminal `terminal` is reached at the shown pulse: the network reaches it at a pulse of at most
    /// ``shownPulse`` (false for a terminal the snapshot lacks or never reached).
    public func isReached(_ terminal: Int) -> Bool {
        guard terminalPulses.indices.contains(terminal), let pulse = terminalPulses[terminal] else { return false }
        return pulse <= shownPulse
    }
}
