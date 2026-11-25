// ApsidesWorkshopSceneSnapshot — feature 473 (R02-G18-03) T-R02G1803-002 (FR-R02G1803-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the current orbit's steps and its
// integer positions per tick, the starting orbit's positions (the ghost loop), the orbiter's position at the shown
// tick, the eight sector shares, the periapsis and apoapsis readings, the planets, a gauge per target (its band,
// reading, deviation and whether it is met in order), the failure, the shown tick and period, the stage, the actions
// left and the budget, the level number and the presentation time; plus the palette and the three quality tiers. The
// renderer never holds the kernel, so no drawing result can change the game (renderer purity), and the drawn orbit
// passes through the kernel's positions.
//
// Feature 474 (R02-G18-04) T-R02G1804-002 (FR-R02G1804-001, 002, 004; clarification Q3) adds the preview of a pending
// orbit (a knob or size-handle drag, or the panel's pending steps): ``ApsidesWorkshopSceneSnapshot/previewing(_:)``
// returns a copy whose `previewOrbit` is the pending orbit and whose `previewPositions` and `previewGauges` are the
// kernel's positions and readings (`ApsidesWorkshopSky.report` of the level's period, planets and targets) of that
// orbit — only for a valid pending orbit; an invalid one gives the copy without a preview. Without a preview
// (`previewOrbit` nil) `previewPositions` and `previewGauges` equal `positions` and `gauges`, so drawing from them is
// R02-G18-03's drawing. Presentation only: the preview never enters the digest, the game state or the kernel; every
// other field of the copy is unchanged.
import Foundation

/// The palette of Apsides Workshop, as linear colours 0 … 1 (glacial white and deep rose on midnight).
public enum ApsidesWorkshopPalette {
    /// The sky at the bottom, #0A0B1F.
    public static let midnight = rgb(0x0A, 0x0B, 0x1F)
    /// The sky at the top, #1A1438.
    public static let midnightTop = rgb(0x1A, 0x14, 0x38)
    /// The sky's star specks, #D8E4FF.
    public static let speck = rgb(0xD8, 0xE4, 0xFF)
    /// A swept-area wedge, #2A2350.
    public static let wedge = rgb(0x2A, 0x23, 0x50)
    /// A wedge in a sector a sweep target names, #6B2346.
    public static let targetWedge = rgb(0x6B, 0x23, 0x46)
    /// The compass spokes, rim and notches, #3A3F6B.
    public static let compass = rgb(0x3A, 0x3F, 0x6B)
    /// The starting orbit's ghost loop, #5B6390.
    public static let ghost = rgb(0x5B, 0x63, 0x90)
    /// The orbit loop and the orbiter, #E8F1FF.
    public static let glacial = rgb(0xE8, 0xF1, 0xFF)
    /// The apsis markers, target brackets and the orbiter's rim, #C2456E.
    public static let deepRose = rgb(0xC2, 0x45, 0x6E)
    /// An exclusion planet, #8C93B8.
    public static let planet = rgb(0x8C, 0x93, 0xB8)
    /// A planet's hatched hazard ring, #C2456E.
    public static let hazard = rgb(0xC2, 0x45, 0x6E)
    /// The star, #FFF4D6.
    public static let star = rgb(0xFF, 0xF4, 0xD6)
    /// A met target's gauge mark (filled), #C2456E.
    public static let met = rgb(0xC2, 0x45, 0x6E)
    /// An unmet target's gauge mark (hollow), #E8F1FF.
    public static let unmet = rgb(0xE8, 0xF1, 0xFF)
    /// A lit actions bar, #C2456E.
    public static let actionsLit = rgb(0xC2, 0x45, 0x6E)
    /// An unlit actions bar, #262A4E.
    public static let actionsUnlit = rgb(0x26, 0x2A, 0x4E)
    /// What a failure names, #E0533A.
    public static let broken = rgb(0xE0, 0x53, 0x3A)
    /// The glow shells, #F4F8FF.
    public static let glow = rgb(0xF4, 0xF8, 0xFF)

    /// The palette's main hex values (midnight, glacial white, deep rose, planet, midnight top), as registered in the
    /// catalog.
    public static let hex: [String] = ["#0A0B1F", "#E8F1FF", "#C2456E", "#8C93B8", "#1A1438"]

    /// The linear colour of 8-bit components.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). The wedges, compass, ghost loop,
/// apsis markers, gauges, colours and positions are the same at every tier; only the sphere detail, the orbit loop's
/// refinement between ticks and the glow differ.
public struct ApsidesWorkshopTier: Sendable, Equatable, Hashable {
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// A sphere's segments around its axis (0: a flat screen-facing disc of ``discSides`` sides).
    public let longitudes: Int
    /// A sphere's segments from pole to pole (0: a flat disc).
    public let latitudes: Int
    /// The presentation-only points on the analytic ellipse between two ticks of the orbit loop (0: chords only).
    public let refinement: Int
    /// The glow shells around the star, the orbit loop and the orbiter.
    public let glowShells: Int

    /// The sides of a flat disc (level-2).
    public static let discSides: Int = 20

    /// The three tiers, richest first.
    public static let all: [ApsidesWorkshopTier] = [
        ApsidesWorkshopTier(index: 0, longitudes: 24, latitudes: 16, refinement: 4, glowShells: 2),
        ApsidesWorkshopTier(index: 1, longitudes: 16, latitudes: 12, refinement: 2, glowShells: 1),
        ApsidesWorkshopTier(index: 2, longitudes: 0, latitudes: 0, refinement: 0, glowShells: 0),
    ]

    /// The tier's name, `level-0` … `level-2`.
    public var name: String { "level-\(index)" }

    /// Whether spheres are flat discs.
    public var flatSpheres: Bool { longitudes == 0 }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> ApsidesWorkshopTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// One target's gauge: the target with its band, the reading compared with it, the deviation and whether it is met in
/// order (the kernel's report).
public struct ApsidesWorkshopGauge: Sendable, Equatable, Hashable {
    /// The target (its kind, sector and band).
    public let target: ApsidesWorkshopTarget
    /// The reading: the sector's share (sweep) or the apsis distance in twentieths (apsis).
    public let reading: Int
    /// The deviation from the band (0 inside).
    public let deviation: Int
    /// Whether the target is among the targets met in order.
    public let met: Bool

    /// A gauge of the given values.
    public init(target: ApsidesWorkshopTarget, reading: Int, deviation: Int, met: Bool) {
        self.target = target
        self.reading = reading
        self.deviation = deviation
        self.met = met
    }

    /// The upper end of the gauge's scale: 1000 for a share, 1280 for a distance.
    public var scaleTop: Int {
        target.kind == .sweep ? ApsidesWorkshopSky.wholeShare : ApsidesWorkshopLevel.distanceBounds.upperBound
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct ApsidesWorkshopSceneSnapshot: Sendable, Equatable {
    /// The current orbit's steps.
    public let orbit: ApsidesWorkshopOrbit
    /// The current orbit's positions at ticks 0 … period − 1 (sky units; the kernel's).
    public let positions: [ApsidesWorkshopPoint]
    /// The starting orbit's positions (the ghost loop).
    public let ghost: [ApsidesWorkshopPoint]
    /// The orbiter's position at the shown tick.
    public let orbiter: ApsidesWorkshopPoint
    /// The share of each sector 0 … 7 in tenths of a percent.
    public let shares: [Int]
    /// The periapsis sector.
    public let periapsisSector: Int
    /// The periapsis distance in twentieths of a lattice unit.
    public let periapsisDistance: Int
    /// The apoapsis sector.
    public let apoapsisSector: Int
    /// The apoapsis distance in twentieths of a lattice unit.
    public let apoapsisDistance: Int
    /// The exclusion planets.
    public let planets: [ApsidesWorkshopPlanet]
    /// One gauge per target, in target order.
    public let gauges: [ApsidesWorkshopGauge]
    /// The failure: the play's on a failed play, otherwise the report's prediction.
    public let failure: ApsidesWorkshopFailure?
    /// The shown tick, 0 … period − 1 (presentation only; never part of the digest).
    public let shownTick: Int
    /// The period in ticks.
    public let period: Int
    /// The stage.
    public let stage: ApsidesWorkshopStage
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double
    /// The previewed pending orbit; nil when no preview (presentation only; never part of the digest; only ever a
    /// valid orbit).
    public private(set) var previewOrbit: ApsidesWorkshopOrbit?
    /// The kernel's positions of the previewed orbit at ticks 0 … period − 1 (sky units); equal to ``positions`` when
    /// no preview (presentation only).
    public private(set) var previewPositions: [ApsidesWorkshopPoint]
    /// One gauge per target with the previewed orbit's reading, deviation and met flag (the kernel's report); equal to
    /// ``gauges`` when no preview (presentation only).
    public private(set) var previewGauges: [ApsidesWorkshopGauge]

    /// A snapshot of `play` with tick `shownTick` shown (clamped to 0 … period − 1).
    public init(play: ApsidesWorkshopPlay, shownTick: Int, levelNumber: Int, time: Double) {
        let level: ApsidesWorkshopLevel = play.level
        let report: ApsidesWorkshopReport = play.report
        orbit = play.orbit
        positions = report.positions
        ghost = ApsidesWorkshopSky.positions(level.orbit, period: level.period).points
        period = level.period
        let tick: Int = min(max(shownTick, 0), level.period - 1)
        self.shownTick = tick
        orbiter = report.positions[tick]
        shares = report.shares
        periapsisSector = play.orbit.periapsisSector
        periapsisDistance = play.orbit.periapsisDistance
        apoapsisSector = play.orbit.apoapsisSector
        apoapsisDistance = play.orbit.apoapsisDistance
        planets = level.planets
        var gauges: [ApsidesWorkshopGauge] = []
        for (index, target) in level.targets.enumerated() {
            let reading: Int = Self.reading(target, orbit: play.orbit, shares: report.shares)
            gauges.append(ApsidesWorkshopGauge(target: target, reading: reading, deviation: report.deviations[index],
                                               met: index < report.met))
        }
        self.gauges = gauges
        failure = play.failure ?? report.failure
        stage = play.stage
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
        previewOrbit = nil
        previewPositions = positions
        previewGauges = gauges
    }

    /// Whether a pending orbit is previewed (``previewOrbit`` set).
    public var isPreviewing: Bool { previewOrbit != nil }

    /// This snapshot with `orbit` previewed (feature 474): ``previewOrbit`` set and ``previewPositions`` and
    /// ``previewGauges`` the kernel's positions and readings of `orbit` (`ApsidesWorkshopSky.report` of the snapshot's
    /// period, planets and targets; met flags in order as the kernel reports them). An invalid orbit (see
    /// `ApsidesWorkshopOrbit.isValid`) gives the snapshot without a preview. Presentation only: nothing else changes
    /// and nothing reaches the kernel or the digest.
    public func previewing(_ orbit: ApsidesWorkshopOrbit) -> ApsidesWorkshopSceneSnapshot {
        guard orbit.isValid, period > 0 else { return withoutPreview() }
        var targets: [ApsidesWorkshopTarget] = []
        for gauge in gauges { targets.append(gauge.target) }
        let report: ApsidesWorkshopReport = ApsidesWorkshopSky.report(period: period, planets: planets,
                                                                      targets: targets, orbit: orbit)
        var readings: [ApsidesWorkshopGauge] = []
        for (index, target) in targets.enumerated() {
            let reading: Int = Self.reading(target, orbit: orbit, shares: report.shares)
            readings.append(ApsidesWorkshopGauge(target: target, reading: reading, deviation: report.deviations[index],
                                                 met: index < report.met))
        }
        var copy: ApsidesWorkshopSceneSnapshot = self
        copy.previewOrbit = orbit
        copy.previewPositions = report.positions
        copy.previewGauges = readings
        return copy
    }

    /// This snapshot without a preview: ``previewOrbit`` nil, ``previewPositions`` equal to ``positions`` and
    /// ``previewGauges`` equal to ``gauges`` (presentation only).
    public func withoutPreview() -> ApsidesWorkshopSceneSnapshot {
        var copy: ApsidesWorkshopSceneSnapshot = self
        copy.previewOrbit = nil
        copy.previewPositions = positions
        copy.previewGauges = gauges
        return copy
    }

    /// Whether the play is won.
    public var isWon: Bool { stage == .won }

    /// The reading a target's band is compared with: the sector's share for a sweep, the apsis distance otherwise.
    static func reading(_ target: ApsidesWorkshopTarget, orbit: ApsidesWorkshopOrbit, shares: [Int]) -> Int {
        switch target.kind {
        case .sweep: return shares[target.sector]
        case .periapsis: return orbit.periapsisDistance
        case .apoapsis: return orbit.apoapsisDistance
        }
    }
}
