// ChronoConstellatorSceneSnapshot — feature 353 (R02-G06-03) T-R02G0603-002 (FR-R02G0603-002, 003, 004; clarifications
// Q1–Q4). What the renderer may read: an immutable copy of the kernel's state (the grid, every star's loop, target, current
// cell and the cells of its last 24 ticks oldest first, the timeline's phases and holds, the stage, the failure, the tick,
// the tick limit and the edits left) with the level number and the presentation time, plus the palette and the three
// quality tiers. The renderer never holds the kernel, so no drawing result can change the game (renderer purity).
import Foundation

/// The palette of Chrono Constellator, sRGB components 0 … 1 (clarification Q3; the design's "indigo, silver and rose").
public enum ChronoConstellatorPalette {
    /// The indigo field, #0B0A24.
    public static let field = rgb(0x0B, 0x0A, 0x24)
    /// The faint grid lines, #1C1A44.
    public static let grid = rgb(0x1C, 0x1A, 0x44)
    /// The silver loop tracks, #C9CED8.
    public static let silver = rgb(0xC9, 0xCE, 0xD8)
    /// The star nodes, #F2F4FF.
    public static let star = rgb(0xF2, 0xF4, 0xFF)
    /// The rose target rings and ribbons, #FF5C8A.
    public static let rose = rgb(0xFF, 0x5C, 0x8A)
    /// The amber collision mark, #FFB020.
    public static let amber = rgb(0xFF, 0xB0, 0x20)

    /// The catalog palette as hex strings: field, silver, star, rose, amber.
    public static let hex: [String] = ["#0B0A24", "#C9CED8", "#F2F4FF", "#FF5C8A", "#FFB020"]

    /// The colour of `r`, `g`, `b` bytes.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only the ribbon length, the ribbon segments and the glow shells, never stars, targets,
/// colours, objective or indicators. Tiers are ordered richest first: index n is the catalog's `level-n` (the design's
/// "Tier 0 D3-safe" is level-2).
public struct ChronoConstellatorTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The ticks of history each ribbon shows.
    public let ribbonTicks: Int
    /// The ribbon segments per tick.
    public let segments: Int
    /// The glow shells (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: ribbons of 24/12/6 ticks, 4/2/1 segments per tick, 2/1/0 glow shells.
    public static let all: [ChronoConstellatorTier] = [
        ChronoConstellatorTier(index: 0, ribbonTicks: 24, segments: 4, glowShells: 2),
        ChronoConstellatorTier(index: 1, ribbonTicks: 12, segments: 2, glowShells: 1),
        ChronoConstellatorTier(index: 2, ribbonTicks: 6, segments: 1, glowShells: 0),
    ]

    /// The longest ribbon of any tier, the history every snapshot carries.
    public static let historyTicks: Int = 24

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> ChronoConstellatorTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of everything the renderer may read about one Chrono Constellator play at one frame.
public struct ChronoConstellatorSceneSnapshot: Sendable, Equatable {
    /// A star as the renderer sees it.
    public struct Star: Sendable, Equatable, Hashable {
        /// The cells of its loop in travel order.
        public let loop: [Int]
        /// Its target cell.
        public let target: Int
        /// The cell it stands on at the current tick.
        public let cell: Int
        /// The cells it stood on over the last ticks, oldest first, ending with ``cell`` (at most
        /// ``ChronoConstellatorTier/historyTicks`` + 1 entries; ticks before 0 are not included).
        public let history: [Int]
        /// Whether it stands on its target.
        public var onTarget: Bool { cell == target }
    }

    /// The grid's columns.
    public let columns: Int
    /// The grid's rows.
    public let rows: Int
    /// The stars in order (star i has shape i).
    public let stars: [Star]
    /// The timeline's start phase of every star.
    public let phases: [Int]
    /// The timeline's holds.
    public let holds: [ChronoConstellatorHold]
    /// The play's stage.
    public let stage: ChronoConstellatorStage
    /// Why the play failed, if it did.
    public let failure: ChronoConstellatorFailure?
    /// The replay tick.
    public let tick: Int
    /// The level's tick limit.
    public let tickLimit: Int
    /// The edits left.
    public let remaining: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (ribbon shimmer only; never read by the rules).
    public let time: Double

    /// A snapshot of `play` at presentation time `time` (non-finite times become 0).
    public init(play: ChronoConstellatorPlay, levelNumber: Int, time: Double) {
        let level: ChronoConstellatorLevel = play.level
        let timeline: ChronoConstellatorTimeline = play.timeline
        columns = level.columns
        rows = level.rows
        let first: Int = max(0, play.tick - ChronoConstellatorTier.historyTicks)
        var stars: [Star] = []
        for index in level.stars.indices {
            var history: [Int] = []
            for t in first...play.tick { history.append(timeline.position(star: index, at: t, level: level)) }
            let star: ChronoConstellatorStar = level.stars[index]
            stars.append(Star(loop: star.loop, target: star.target, cell: history.last ?? star.loop[0], history: history))
        }
        self.stars = stars
        phases = timeline.phases
        holds = timeline.holds
        stage = play.stage
        failure = play.failure
        tick = play.tick
        tickLimit = level.tickLimit
        remaining = play.remaining
        self.levelNumber = levelNumber
        self.time = time.isFinite ? time : 0
    }
}
