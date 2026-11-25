// CelestialEclipseLabSceneSnapshot — feature 463 (R02-G17-03) T-R02G1703-002 (FR-R02G1703-002, 003, 004;
// clarifications Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the bodies (orbits,
// radii, fixed flags), the current phases, every body's lattice position at the shown tick, the eclipses under way at
// the shown tick with their visibility classes (the kernel's strict overlap and class rules, front and back by the
// level's depth order), the target with its windows, the predicted intervals and the matched count of the current
// timeline, the failure, the shown tick and horizon, the chosen body, the stage, the actions left and the budget, the
// level number and the presentation time; plus the palette and the three quality tiers. The renderer never holds the
// kernel, so no drawing result can change the game (renderer purity), and the drawn bodies sit at the kernel's
// positions.
import Foundation

/// The palette of Celestial Eclipse Lab, as linear colours 0 … 1 (corona gold and muted ember on ink navy).
public enum CelestialEclipseLabPalette {
    /// The sky at the bottom, #0B1530.
    public static let ink = rgb(0x0B, 0x15, 0x30)
    /// The sky at the top, #16224A.
    public static let inkTop = rgb(0x16, 0x22, 0x4A)
    /// The sky's specks, #C9D2FF.
    public static let speck = rgb(0xC9, 0xD2, 0xFF)
    /// A body's lit disc, #E9E1CF.
    public static let disc = rgb(0xE9, 0xE1, 0xCF)
    /// A body's limb, #7A829A.
    public static let discShade = rgb(0x7A, 0x82, 0x9A)
    /// An orbital ring and its notches, #33406E.
    public static let orbit = rgb(0x33, 0x40, 0x6E)
    /// The square frame of a fixed body, #8A93B0.
    public static let fixedFrame = rgb(0x8A, 0x93, 0xB0)
    /// The chosen body's dashed ring, #F2C14E.
    public static let chosen = rgb(0xF2, 0xC1, 0x4E)
    /// A corona halo, #F2C14E.
    public static let corona = rgb(0xF2, 0xC1, 0x4E)
    /// The halos' glow, #FFE7A3.
    public static let coronaGlow = rgb(0xFF, 0xE7, 0xA3)
    /// The shadow inside an eclipse's crescent, #050A18.
    public static let crescentShadow = rgb(0x05, 0x0A, 0x18)
    /// Muted ember accents, #C8553D.
    public static let ember = rgb(0xC8, 0x55, 0x3D)
    /// A target window's bracket, #E8E2D0.
    public static let window = rgb(0xE8, 0xE2, 0xD0)
    /// A matched predicted event (filled diamond), #F2C14E.
    public static let matched = rgb(0xF2, 0xC1, 0x4E)
    /// The failing predicted event (cross), #C8553D.
    public static let unwanted = rgb(0xC8, 0x55, 0x3D)
    /// A predicted event after the last match, #5A6488.
    public static let faintEvent = rgb(0x5A, 0x64, 0x88)
    /// The playhead at the shown tick, #FFE7A3.
    public static let playhead = rgb(0xFF, 0xE7, 0xA3)
    /// A lit actions bar, #F2C14E.
    public static let actionsLit = rgb(0xF2, 0xC1, 0x4E)
    /// An unlit actions bar, #24305A.
    public static let actionsUnlit = rgb(0x24, 0x30, 0x5A)
    /// What a failure names, #E0533A.
    public static let broken = rgb(0xE0, 0x53, 0x3A)
    /// The glow shells, #FFF1D0.
    public static let glow = rgb(0xFF, 0xF1, 0xD0)

    /// The palette's main hex values (ink navy, corona gold, muted ember, disc ivory, ink top), as registered in the
    /// catalog.
    public static let hex: [String] = ["#0B1530", "#F2C14E", "#C8553D", "#E9E1CF", "#16224A"]

    /// The linear colour of 8-bit components.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). Rings, crescents, halos, the
/// timeline, gauges, colours and positions are the same at every tier; only the body sphere detail and the glow differ.
public struct CelestialEclipseLabTier: Sendable, Equatable, Hashable {
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// The body sphere's segments around its axis (0: a flat screen-facing disc of ``discSides`` sides).
    public let longitudes: Int
    /// The body sphere's segments from pole to pole (0: a flat disc).
    public let latitudes: Int
    /// The glow shells around the halos, the chosen ring and the lit marks.
    public let glowShells: Int

    /// The sides of a flat body disc (level-2).
    public static let discSides: Int = 20

    /// The three tiers, richest first.
    public static let all: [CelestialEclipseLabTier] = [
        CelestialEclipseLabTier(index: 0, longitudes: 24, latitudes: 16, glowShells: 2),
        CelestialEclipseLabTier(index: 1, longitudes: 16, latitudes: 12, glowShells: 1),
        CelestialEclipseLabTier(index: 2, longitudes: 0, latitudes: 0, glowShells: 0),
    ]

    /// The tier's name, `level-0` … `level-2`.
    public var name: String { "level-\(index)" }

    /// Whether bodies are flat discs rather than spheres.
    public var flatBodies: Bool { longitudes == 0 }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> CelestialEclipseLabTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// One eclipse under way at the shown tick: its front and back body and its class at that tick.
public struct CelestialEclipseLabEclipse: Sendable, Equatable, Hashable {
    /// The nearer body.
    public let front: Int
    /// The farther body.
    public let back: Int
    /// The class at the shown tick (the kernel's rule for one tick).
    public let visibility: CelestialEclipseLabVisibility

    /// An eclipse of the given values.
    public init(front: Int, back: Int, visibility: CelestialEclipseLabVisibility) {
        self.front = front
        self.back = back
        self.visibility = visibility
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct CelestialEclipseLabSceneSnapshot: Sendable, Equatable {
    /// The bodies (orbits, radii, fixed flags).
    public let bodies: [CelestialEclipseLabBody]
    /// The current phases (one per body).
    public let phases: [Int]
    /// Every body's lattice position at the shown tick for the current phases (the kernel's).
    public let positions: [CelestialEclipseLabVector]
    /// The eclipses under way at the shown tick, ordered by front body, then back body.
    public let eclipses: [CelestialEclipseLabEclipse]
    /// The target eclipses with their windows.
    public let target: [CelestialEclipseLabTarget]
    /// The predicted eclipse intervals of the current phases, in timeline order.
    public let intervals: [CelestialEclipseLabInterval]
    /// How many target eclipses the predicted timeline matches.
    public let matched: Int
    /// The failure: the play's on a failed run, otherwise the predicted timeline's.
    public let failure: CelestialEclipseLabFailure?
    /// The shown tick, 0 … horizon − 1 (presentation only; never part of the digest).
    public let shownTick: Int
    /// The horizon in ticks.
    public let horizon: Int
    /// The chosen body (presentation only; never part of the digest).
    public let chosenBody: Int
    /// The stage.
    public let stage: CelestialEclipseLabStage
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double

    /// A snapshot of `play` with body `chosenBody` chosen and tick `shownTick` shown (a body the level does not have
    /// falls back to ``defaultChoice(_:)``; the tick is clamped to 0 … horizon − 1).
    public init(play: CelestialEclipseLabPlay, chosenBody: Int, shownTick: Int, levelNumber: Int, time: Double) {
        let level: CelestialEclipseLabLevel = play.level
        bodies = level.bodies
        phases = play.phases
        horizon = level.horizon
        let tick: Int = min(max(shownTick, 0), level.horizon - 1)
        self.shownTick = tick
        var positions: [CelestialEclipseLabVector] = []
        for (index, body) in level.bodies.enumerated() {
            positions.append(body.position(at: tick, phase: play.phases[index]))
        }
        self.positions = positions
        eclipses = Self.eclipses(level, phases: play.phases, tick: tick)
        target = level.target
        intervals = play.timeline.intervals
        matched = play.timeline.matched
        failure = play.failure ?? play.timeline.failure
        let valid: Bool = (0..<level.bodies.count).contains(chosenBody)
        self.chosenBody = valid ? chosenBody : Self.defaultChoice(level)
        stage = play.stage
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// Whether the play is won.
    public var isWon: Bool { stage == .won }

    /// The default chosen body (clarification Q1): the lowest-numbered movable body (a level always has one).
    public static func defaultChoice(_ level: CelestialEclipseLabLevel) -> Int {
        for (index, body) in level.bodies.enumerated() where !body.fixed { return index }
        return 0
    }

    /// The eclipses under way at `tick` with `phases`: every pair whose discs overlap by the kernel's strict rule,
    /// front and back by the level's depth order, with the kernel's class for that tick.
    public static func eclipses(_ level: CelestialEclipseLabLevel, phases: [Int],
                                tick: Int) -> [CelestialEclipseLabEclipse] {
        var result: [CelestialEclipseLabEclipse] = []
        let count: Int = level.bodies.count
        for i in 0..<count {
            for j in (i + 1)..<max(count, i + 1) {
                let pair: (front: Int, back: Int) = CelestialEclipseLabSky.order(level, i, j)
                let front: CelestialEclipseLabBody = level.bodies[pair.front]
                let back: CelestialEclipseLabBody = level.bodies[pair.back]
                guard CelestialEclipseLabSky.eclipses(front, back, at: tick,
                                                      phases: (phases[pair.front], phases[pair.back])) else { continue }
                let d2: Int = front.position(at: tick, phase: phases[pair.front])
                    .projectedSquaredDistance(to: back.position(at: tick, phase: phases[pair.back]))
                result.append(CelestialEclipseLabEclipse(
                    front: pair.front, back: pair.back,
                    visibility: CelestialEclipseLabSky.visibility(front: front, back: back, squaredDistance: d2)))
            }
        }
        result.sort { ($0.front, $0.back) < ($1.front, $1.back) }
        return result
    }
}
