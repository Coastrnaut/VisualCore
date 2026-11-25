// StarlitCartoucheSceneSnapshot — feature 453 (R02-G16-03) T-R02G1603-002 (FR-R02G1603-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the stars, their lattice positions at
// the current beat, the corridors, the hazards and which are active at the beat, the flown legs with the lattice
// positions of their departure and arrival, the drawn strokes and the symbol, the ship's star and beat, the beacon, the
// deadline, the chosen destination and wait, the kernel's route report, the stage, the failure and the failed leg
// (recomputed through the chart from the last record's action, since a window or deadline failure names no corridor),
// the actions left and the budget, the level number and the presentation time; plus the palette and the three quality
// tiers. The renderer never holds the kernel, so no drawing result can change the game (renderer purity), and the drawn
// stars sit at the kernel's positions.
import Foundation

/// The palette of Starlit Cartouche, as linear colours 0 … 1 (pearl and meteor gold on deep ultramarine).
public enum StarlitCartouchePalette {
    /// The firmament at the bottom, #0A1240.
    public static let night = rgb(0x0A, 0x12, 0x40)
    /// The firmament at the top, #141E5C.
    public static let nightTop = rgb(0x14, 0x1E, 0x5C)
    /// The firmament's specks, #C9D2FF.
    public static let speck = rgb(0xC9, 0xD2, 0xFF)
    /// The pearl stars, #F2EEE6.
    public static let pearl = rgb(0xF2, 0xEE, 0xE6)
    /// The stars' limb and rings, #B8C0D8.
    public static let pearlShade = rgb(0xB8, 0xC0, 0xD8)
    /// A corridor off the symbol, #3A4478.
    public static let corridor = rgb(0x3A, 0x44, 0x78)
    /// An undrawn symbol stroke (dashed), #C9CCE0.
    public static let symbolDash = rgb(0xC9, 0xCC, 0xE0)
    /// A flown trail and a drawn stroke, #F5B83D.
    public static let trail = rgb(0xF5, 0xB8, 0x3D)
    /// The trails' glow, #FFE3A0.
    public static let trailGlow = rgb(0xFF, 0xE3, 0xA0)
    /// The sapphire ship, #2F6BFF.
    public static let ship = rgb(0x2F, 0x6B, 0xFF)
    /// The ship's glow, #8FB0FF.
    public static let shipGlow = rgb(0x8F, 0xB0, 0xFF)
    /// The beacon ring, #F2EEE6.
    public static let beacon = rgb(0xF2, 0xEE, 0xE6)
    /// The chosen destination's dashed ring, #2F6BFF.
    public static let chosen = rgb(0x2F, 0x6B, 0xFF)
    /// A hazard tube while active, #FF5A5F.
    public static let hazardActive = rgb(0xFF, 0x5A, 0x5F)
    /// A hazard tube while idle, #5A3A58.
    public static let hazardIdle = rgb(0x5A, 0x3A, 0x58)
    /// A lit actions bar, #F5B83D.
    public static let actionsLit = rgb(0xF5, 0xB8, 0x3D)
    /// An unlit actions bar, #283058.
    public static let actionsUnlit = rgb(0x28, 0x30, 0x58)
    /// The beat track's fill, #8FB0FF.
    public static let beatTrack = rgb(0x8F, 0xB0, 0xFF)
    /// A lit wait pip, #2F6BFF.
    public static let waitLit = rgb(0x2F, 0x6B, 0xFF)
    /// An unlit wait pip, #283058.
    public static let waitUnlit = rgb(0x28, 0x30, 0x58)
    /// What a failure names, #FF6B4A.
    public static let broken = rgb(0xFF, 0x6B, 0x4A)
    /// The glow shells, #FFF4E0.
    public static let glow = rgb(0xFF, 0xF4, 0xE0)

    /// The palette's main hex values (ultramarine, pearl, meteor gold, sapphire, ultramarine top), as registered in the
    /// catalog.
    public static let hex: [String] = ["#0A1240", "#F2EEE6", "#F5B83D", "#2F6BFF", "#141E5C"]

    /// The linear colour of 8-bit components.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). Stars, corridors, hazards,
/// trails, the ship, the rings, the cartouche, gauges, colours and positions are the same at every tier; only the star
/// sphere detail, the trail ghosts and the glow differ.
public struct StarlitCartoucheTier: Sendable, Equatable, Hashable {
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// The star sphere's segments around its axis (0: a flat screen-facing disc of ``discSides`` sides).
    public let longitudes: Int
    /// The star sphere's segments from pole to pole (0: a flat disc).
    public let latitudes: Int
    /// The motion-blur ghosts trailing each trail's end.
    public let ghosts: Int
    /// The glow shells around the stars, the ship and the lit trails.
    public let glowShells: Int

    /// The sides of a flat star disc (level-2).
    public static let discSides: Int = 12

    /// The three tiers, richest first.
    public static let all: [StarlitCartoucheTier] = [
        StarlitCartoucheTier(index: 0, longitudes: 16, latitudes: 12, ghosts: 3, glowShells: 2),
        StarlitCartoucheTier(index: 1, longitudes: 12, latitudes: 8, ghosts: 1, glowShells: 1),
        StarlitCartoucheTier(index: 2, longitudes: 0, latitudes: 0, ghosts: 0, glowShells: 0),
    ]

    /// The tier's name, `level-0` … `level-2`.
    public var name: String { "level-\(index)" }

    /// Whether stars are flat discs rather than spheres.
    public var flatStars: Bool { longitudes == 0 }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> StarlitCartoucheTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct StarlitCartoucheSceneSnapshot: Sendable, Equatable {
    /// The stars (orbits, glyph points, windows).
    public let stars: [StarlitCartoucheStar]
    /// Every star's lattice position at the current beat (the kernel's).
    public let positions: [StarlitCartoucheVector]
    /// The corridors.
    public let corridors: [StarlitCartoucheCorridor]
    /// The hazards.
    public let hazards: [StarlitCartoucheHazard]
    /// Whether each hazard is active at the current beat (from ≤ beat ≤ to).
    public let active: [Bool]
    /// The flown legs, in order.
    public let legs: [StarlitCartoucheLeg]
    /// The lattice position of each leg's from-star at its departure beat.
    public let departures: [StarlitCartoucheVector]
    /// The lattice position of each leg's to-star at its arrival beat.
    public let arrivals: [StarlitCartoucheVector]
    /// The corridors drawn so far (sorted).
    public let drawn: [Int]
    /// The symbol's corridors (sorted).
    public let symbol: [Int]
    /// The ship's star.
    public let star: Int
    /// The current beat.
    public let beat: Int
    /// The beacon star.
    public let beacon: Int
    /// The deadline beat.
    public let deadline: Int
    /// The chosen destination star (presentation only; never part of the digest).
    public let chosenStar: Int
    /// The chosen wait, 0 … 8 (presentation only; never part of the digest).
    public let chosenWait: Int
    /// The kernel's route report.
    public let report: StarlitCartoucheRouteReport
    /// The stage.
    public let stage: StarlitCartoucheStage
    /// The failure, if the play failed.
    public let failure: StarlitCartoucheFailure?
    /// The leg that failed (recomputed through the chart from the last record's action), if the play failed on a leg.
    public let failedLeg: StarlitCartoucheLeg?
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double

    /// A snapshot of `play` with destination `chosenStar` and wait `chosenWait` chosen (a choice the level cannot take —
    /// an unknown star or the ship's own star — falls back to ``defaultChoice(_:star:)``; the wait is clamped to 0 … 8).
    public init(play: StarlitCartouchePlay, chosenStar: Int, chosenWait: Int, levelNumber: Int, time: Double) {
        let level: StarlitCartoucheLevel = play.level
        stars = level.stars
        var positions: [StarlitCartoucheVector] = []
        for star in level.stars { positions.append(star.position(at: play.beat)) }
        self.positions = positions
        corridors = level.corridors
        hazards = level.hazards
        var active: [Bool] = []
        for hazard in level.hazards { active.append(hazard.from <= play.beat && play.beat <= hazard.to) }
        self.active = active
        legs = play.legs
        var departures: [StarlitCartoucheVector] = []
        var arrivals: [StarlitCartoucheVector] = []
        for leg in play.legs {
            departures.append(level.stars[leg.from].position(at: leg.depart))
            arrivals.append(level.stars[leg.to].position(at: leg.arrive))
        }
        self.departures = departures
        self.arrivals = arrivals
        drawn = play.drawn.sorted()
        symbol = level.symbol
        star = play.star
        beat = play.beat
        beacon = level.beacon
        deadline = level.deadline
        let valid: Bool = (0..<level.stars.count).contains(chosenStar) && chosenStar != play.star
        self.chosenStar = valid ? chosenStar : Self.defaultChoice(level, star: play.star)
        self.chosenWait = min(max(chosenWait, 0), 8)
        report = play.report
        stage = play.stage
        failure = play.failure
        failedLeg = Self.failedLeg(play)
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// Whether the play is won.
    public var isWon: Bool { stage == .won }

    /// The default destination from `star` (clarification Q1): the other end of the lowest-index corridor touching it,
    /// or the lowest-numbered other star when none does.
    public static func defaultChoice(_ level: StarlitCartoucheLevel, star: Int) -> Int {
        for corridor in level.corridors where corridor.a == star || corridor.b == star {
            return corridor.a == star ? corridor.b : corridor.a
        }
        return star == 0 ? 1 : 0
    }

    /// The leg the play failed on, recomputed through the chart from the last record's action (the ship stays at its
    /// star and beat on a failed leg); nil unless the play failed on a leg (a budget failure follows a flown leg).
    static func failedLeg(_ play: StarlitCartouchePlay) -> StarlitCartoucheLeg? {
        guard play.stage == .failed, let failure = play.failure else { return nil }
        if case .budget = failure { return nil }
        guard let record = play.records.last, let action = record.action else { return nil }
        switch action {
        case .leg(let destination, let wait):
            return try? StarlitCartoucheChart.leg(play.level, from: play.star, at: play.beat, to: destination,
                                                  wait: wait)
        }
    }
}
