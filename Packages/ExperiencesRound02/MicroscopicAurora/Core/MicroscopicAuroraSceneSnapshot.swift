// MicroscopicAuroraSceneSnapshot — feature 483 (R02-G19-03) T-R02G1903-002 (FR-R02G1903-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the enclosure radius, every swimmer's
// integer position and velocity at each tick of the predicted swim of the current wells, the ticks swum and the shown
// tick, the trail density with the lit stencil and stray cells, the stencil, the sites, the wells, the coverage and the
// smallest coherence with their requirements, the failure, the stage, the actions left and the budget, the level number
// and the presentation time; plus the palette and the three quality tiers. The renderer never holds the kernel, so no
// drawing result can change the game (renderer purity), and every drawn swimmer stands at a kernel position.
import Foundation

/// The palette of Microscopic Aurora, as linear colours 0 … 1 (sea glass green, heliotrope and white on an abyss).
public enum MicroscopicAuroraPalette {
    /// The water at the bottom, #04110F.
    public static let abyss = rgb(0x04, 0x11, 0x0F)
    /// The water at the top, #0B2A26.
    public static let abyssTop = rgb(0x0B, 0x2A, 0x26)
    /// The dish field, #0E2E2A.
    public static let field = rgb(0x0E, 0x2E, 0x2A)
    /// The decorative fronds at the rim, #2E6B5C.
    public static let frond = rgb(0x2E, 0x6B, 0x5C)
    /// The enclosure's rim, #6FB7A6.
    public static let rim = rgb(0x6F, 0xB7, 0xA6)
    /// A stencil cell's outline, #3E7F72.
    public static let stencil = rgb(0x3E, 0x7F, 0x72)
    /// A lit stencil cell, #7FE0C4.
    public static let lit = rgb(0x7F, 0xE0, 0xC4)
    /// A lit cell outside the stencil, #2F6B5F.
    public static let stray = rgb(0x2F, 0x6B, 0x5F)
    /// A site's ring, #B58CE0.
    public static let site = rgb(0xB5, 0x8C, 0xE0)
    /// A well's spiral and arrow, #D2A8FF.
    public static let well = rgb(0xD2, 0xA8, 0xFF)
    /// A swimmer's ribbon trail, #8FF0D6.
    public static let ribbon = rgb(0x8F, 0xF0, 0xD6)
    /// A swimmer's capsule, #E9FFF8.
    public static let swimmer = rgb(0xE9, 0xFF, 0xF8)
    /// A met gauge's mark (filled), #B58CE0.
    public static let met = rgb(0xB5, 0x8C, 0xE0)
    /// An unmet gauge's mark (hollow), #E9FFF8.
    public static let unmet = rgb(0xE9, 0xFF, 0xF8)
    /// A lit actions bar, #B58CE0.
    public static let actionsLit = rgb(0xB5, 0x8C, 0xE0)
    /// An unlit actions bar, #1E3A35.
    public static let actionsUnlit = rgb(0x1E, 0x3A, 0x35)
    /// What a failure names, #FF6B5E.
    public static let broken = rgb(0xFF, 0x6B, 0x5E)
    /// The glow shells, #F2FFFB.
    public static let glow = rgb(0xF2, 0xFF, 0xFB)

    /// The palette's main hex values (abyss, ribbon, site, swimmer, field), as registered in the catalog.
    public static let hex: [String] = ["#04110F", "#8FF0D6", "#B58CE0", "#E9FFF8", "#0E2E2A"]

    /// The linear colour of 8-bit components.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). The backdrop, field, rim, cells,
/// sites, wells, gauges, colours and positions are the same at every tier; only the capsule detail, the ribbon length,
/// the fronds and the glow differ.
public struct MicroscopicAuroraTier: Sendable, Equatable, Hashable {
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// A capsule's segments around each end (0: a flat screen-facing capsule).
    public let capsuleSegments: Int
    /// The ticks a ribbon reaches back from the shown tick.
    public let ribbonTicks: Int
    /// Whether the decorative fronds are drawn.
    public let fronds: Bool
    /// The glow shells around the swimmers and ribbons.
    public let glowShells: Int

    /// The three tiers, richest first.
    public static let all: [MicroscopicAuroraTier] = [
        MicroscopicAuroraTier(index: 0, capsuleSegments: 12, ribbonTicks: 64, fronds: true, glowShells: 2),
        MicroscopicAuroraTier(index: 1, capsuleSegments: 8, ribbonTicks: 32, fronds: true, glowShells: 1),
        MicroscopicAuroraTier(index: 2, capsuleSegments: 0, ribbonTicks: 16, fronds: false, glowShells: 0),
    ]

    /// The tier's name, `level-0` … `level-2`.
    public var name: String { "level-\(index)" }

    /// Whether capsules are flat.
    public var flatCapsules: Bool { capsuleSegments == 0 }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> MicroscopicAuroraTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct MicroscopicAuroraSceneSnapshot: Sendable, Equatable {
    /// The enclosure radius in cells.
    public let radius: Int
    /// Each swimmer's position at ticks 0 … ticksSwum (dish units; the kernel's), indexed [swimmer][tick].
    public let positions: [[MicroscopicAuroraPoint]]
    /// Each swimmer's velocity at ticks 0 … ticksSwum, indexed [swimmer][tick].
    public let velocities: [[MicroscopicAuroraPoint]]
    /// The ticks swum by the predicted swim (the swim length, or the failing tick).
    public let ticksSwum: Int
    /// The shown tick, 0 … ticksSwum (presentation only; never part of the digest).
    public let shownTick: Int
    /// The trail density of every cell, row-major (576 values).
    public let density: [Int]
    /// The lit stencil cells, row-major.
    public let litStencil: [MicroscopicAuroraCell]
    /// The lit cells outside the stencil, row-major.
    public let stray: [MicroscopicAuroraCell]
    /// The stencil, row-major.
    public let stencil: [MicroscopicAuroraCell]
    /// The well sites, row-major (empty for a level without sites).
    public let sites: [MicroscopicAuroraCell]
    /// The wells, one entry per slot.
    public let wells: [MicroscopicAuroraWell?]
    /// The coverage in tenths of a percent.
    public let coverage: Int
    /// The required coverage.
    public let requiredCoverage: Int
    /// The smallest coherence over the swim.
    public let coherence: Int
    /// The required coherence.
    public let requiredCoherence: Int
    /// The number of swimmers.
    public let swarm: Int
    /// The coherence radius κ in cells (the level's rule), so the scene can find the largest linked group.
    public let coherenceRadius: Int
    /// The failure: the play's on a failed play, otherwise the report's prediction.
    public let failure: MicroscopicAuroraFailure?
    /// The stage.
    public let stage: MicroscopicAuroraStage
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double

    /// A snapshot of `play` with tick `shownTick` shown (clamped to 0 … ticks swum).
    public init(play: MicroscopicAuroraPlay, shownTick: Int, levelNumber: Int, time: Double) {
        let level: MicroscopicAuroraLevel = play.level
        let wells: [MicroscopicAuroraWell] = play.wells.compactMap { $0 }
        var swimmers: [MicroscopicAuroraSwimmer] = level.swimmers
        var positions: [[MicroscopicAuroraPoint]] = swimmers.map { [$0.position] }
        var velocities: [[MicroscopicAuroraPoint]] = swimmers.map { [$0.velocity] }
        let report: MicroscopicAuroraReport = play.report
        // Replay exactly the ticks the report swam, keeping positions and velocities (the kernel's step, no other law).
        var tick: Int = 0
        while tick < report.ticks {
            swimmers = MicroscopicAuroraDish.step(swimmers, wells: wells, rules: level.rules)
            for (index, swimmer) in swimmers.enumerated() {
                positions[index].append(swimmer.position)
                velocities[index].append(swimmer.velocity)
            }
            tick += 1
        }
        radius = level.radius
        self.positions = positions
        self.velocities = velocities
        ticksSwum = report.ticks
        self.shownTick = min(max(shownTick, 0), report.ticks)
        density = report.density
        litStencil = report.litStencil
        let stencilSet: Set<MicroscopicAuroraCell> = Set(level.stencil)
        var stray: [MicroscopicAuroraCell] = []
        for index in report.density.indices where report.density[index] >= level.threshold {
            let cell = MicroscopicAuroraCell(row: index / MicroscopicAuroraDish.cells,
                                             column: index % MicroscopicAuroraDish.cells)
            if !stencilSet.contains(cell) { stray.append(cell) }
        }
        self.stray = stray
        stencil = level.stencil
        sites = level.sites ?? []
        self.wells = play.wells
        coverage = report.coverage
        requiredCoverage = level.coverage
        coherence = report.smallestCoherence
        requiredCoherence = level.coherence
        swarm = level.swimmers.count
        coherenceRadius = level.rules.coherenceRadius
        failure = play.failure ?? report.failure
        stage = play.stage
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// A snapshot of the given values, unchecked (presentation variants and tests: lit cells, readings, failures and
    /// stages a play may not reach); `shownTick` is clamped to 0 … `ticksSwum` and `time` made finite and non-negative.
    init(radius: Int, positions: [[MicroscopicAuroraPoint]], velocities: [[MicroscopicAuroraPoint]], ticksSwum: Int,
         shownTick: Int, density: [Int], litStencil: [MicroscopicAuroraCell], stray: [MicroscopicAuroraCell],
         stencil: [MicroscopicAuroraCell], sites: [MicroscopicAuroraCell], wells: [MicroscopicAuroraWell?],
         coverage: Int, requiredCoverage: Int, coherence: Int, requiredCoherence: Int, swarm: Int,
         coherenceRadius: Int, failure: MicroscopicAuroraFailure?, stage: MicroscopicAuroraStage, actionsLeft: Int,
         budget: Int, levelNumber: Int, time: Double) {
        self.radius = radius
        self.positions = positions
        self.velocities = velocities
        self.ticksSwum = ticksSwum
        self.shownTick = min(max(shownTick, 0), max(ticksSwum, 0))
        self.density = density
        self.litStencil = litStencil
        self.stray = stray
        self.stencil = stencil
        self.sites = sites
        self.wells = wells
        self.coverage = coverage
        self.requiredCoverage = requiredCoverage
        self.coherence = coherence
        self.requiredCoherence = requiredCoherence
        self.swarm = swarm
        self.coherenceRadius = coherenceRadius
        self.failure = failure
        self.stage = stage
        self.actionsLeft = actionsLeft
        self.budget = budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// Whether the play is won.
    public var isWon: Bool { stage == .won }

    /// Swimmer `index`'s position at the shown tick.
    public func position(_ index: Int) -> MicroscopicAuroraPoint { positions[index][shownTick] }

    /// Swimmer `index`'s velocity at the shown tick.
    public func velocity(_ index: Int) -> MicroscopicAuroraPoint { velocities[index][shownTick] }
}
