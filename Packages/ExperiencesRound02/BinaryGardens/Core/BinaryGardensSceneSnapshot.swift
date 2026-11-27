// BinaryGardensSceneSnapshot — feature 503 (R02-G21-03) T-R02G2103-002 (FR-R02G2103-002, 003, 004; clarifications
// Q1–Q5; data-model.md). What the renderer may read: an immutable copy of the kernel's state — the level's ring radii,
// luminosity levels, maximum tilt, phase step and lethal tolerance; every world with its orbit, four flux bounds,
// required window and bloom band and, from the kernel's report of the current arrangement, its positions, flux, each
// star's share and band at ticks 1 … 48, its longest lethal run, longest comfortable window and its start, integral
// and bloom result; the arrangement; both stars' positions at ticks 1 … 48; the shown tick (1 … 48), the fit scale
// k = 0.95 / R (R the largest of the level's ring radii and world radii), the failure, the stage, the actions left
// and the budget, the level number and the presentation time; plus the palette and the three quality tiers. The
// renderer never holds the kernel, so no drawing result can change the game (renderer purity), and every drawn
// position, flux, share, band, window and integral is the kernel's integer.
//
// Feature 504 (R02-G21-04) T-R02G2104-002 (FR-R02G2104-002 … 008, 016; SC-R02G2104-003, 006; clarifications Q3, Q4;
// research R4, R10) adds, presentation only: the level's star speed ω and each star's ring, phase and luminosity
// freedoms (copied from the level, so the gesture controller can read the orbit tangent, the phase targets and the
// locks at touch-down); the preview of a drag (``BinaryGardensPreview``: the change as a kernel action and either the
// changed arrangement with the kernel's own report of it — the kernel's internal change rule
// `BinaryGardensSky.changed` and `BinaryGardensSky.report`, never a second law — or the kernel's refusal in the order
// the play gives it); and the inspected world. Every initialiser leaves the preview and the inspection empty, so the
// drawing of R02-G21-03 is unchanged; none of it enters the digest (the snapshot never does) and nothing is saved.
import Foundation

/// The palette of Binary Gardens, as linear colours 0 … 1 (warm vermilion, ice blue and mint world on deep space;
/// clarification Q3).
public enum BinaryGardensPalette {
    /// The space at the bottom of the backdrop, #070815.
    public static let space = rgb(0x07, 0x08, 0x15)
    /// The space at the top of the backdrop, #151B3D.
    public static let spaceTop = rgb(0x15, 0x1B, 0x3D)
    /// The hashed starfield points of the backdrop, #C8D2F0.
    public static let starfield = rgb(0xC8, 0xD2, 0xF0)
    /// A star ring no star stands on (dashed), #2B3560.
    public static let ringIdle = rgb(0x2B, 0x35, 0x60)
    /// A world's orbit, #3A6B66.
    public static let orbit = rgb(0x3A, 0x6B, 0x66)
    /// Star 1, warm vermilion, #FF5A36.
    public static let starOne = rgb(0xFF, 0x5A, 0x36)
    /// Star 2, ice blue, #A6DDFF.
    public static let starTwo = rgb(0xA6, 0xDD, 0xFF)
    /// A star's white-hot core, #FFF4E8.
    public static let core = rgb(0xFF, 0xF4, 0xE8)
    /// A garden world's surface, mint, #7BE8BE.
    public static let world = rgb(0x7B, 0xE8, 0xBE)
    /// The frost caps of a dim or lethally dim world, #DDF2FF.
    public static let frost = rgb(0xDD, 0xF2, 0xFF)
    /// The scorched belt of a bright or lethally bright world, #C2412A.
    public static let scorch = rgb(0xC2, 0x41, 0x2A)
    /// The procedural flowers of a comfortable world, #FFE6F2.
    public static let flower = rgb(0xFF, 0xE6, 0xF2)
    /// The pollen motes circling a comfortable world, #FFE6F2.
    public static let pollen = rgb(0xFF, 0xE6, 0xF2)
    /// A gauge row's plate, #1A2347.
    public static let gaugePlate = rgb(0x1A, 0x23, 0x47)
    /// A lethal-low gauge cell (crossed), #5C8DFF.
    public static let lethalLow = rgb(0x5C, 0x8D, 0xFF)
    /// A dim gauge cell (hollow), #8FB8E0.
    public static let dim = rgb(0x8F, 0xB8, 0xE0)
    /// A comfortable gauge cell (solid), #7BE8BE.
    public static let comfortable = rgb(0x7B, 0xE8, 0xBE)
    /// A bright gauge cell (hollow), #FFB27A.
    public static let bright = rgb(0xFF, 0xB2, 0x7A)
    /// A lethal-high gauge cell (crossed), #FF4A3D.
    public static let lethalHigh = rgb(0xFF, 0x4A, 0x3D)
    /// The window bracket, the guide lines and the bloom bracket, #B8FFE0.
    public static let window = rgb(0xB8, 0xFF, 0xE0)
    /// The shown tick's marker and the bloom marker, #FFF4E8.
    public static let marker = rgb(0xFF, 0xF4, 0xE8)
    /// The current tilt's pip (filled), #A6DDFF.
    public static let tiltLit = rgb(0xA6, 0xDD, 0xFF)
    /// The other tilt pips (rings), #2B3560.
    public static let tiltUnlit = rgb(0x2B, 0x35, 0x60)
    /// A lit actions bar, #FF7A4D.
    public static let actionsLit = rgb(0xFF, 0x7A, 0x4D)
    /// An unlit actions bar, #1E2648.
    public static let actionsUnlit = rgb(0x1E, 0x26, 0x48)
    /// What a failure names, #FF6B5E.
    public static let broken = rgb(0xFF, 0x6B, 0x5E)
    /// The glow shells, #FFF9F0.
    public static let glow = rgb(0xFF, 0xF9, 0xF0)

    /// The palette's main hex values (space, star 1, star 2, world, space top), as registered in the catalog.
    public static let hex: [String] = ["#070815", "#FF5A36", "#A6DDFF", "#7BE8BE", "#151B3D"]

    /// Every colour of the palette by name with its hex value, in declaration order (27 entries).
    static let all: [(name: String, hex: String, colour: SIMD3<Double>)] = [
        ("space", "#070815", space), ("spaceTop", "#151B3D", spaceTop), ("starfield", "#C8D2F0", starfield),
        ("ringIdle", "#2B3560", ringIdle), ("orbit", "#3A6B66", orbit), ("starOne", "#FF5A36", starOne),
        ("starTwo", "#A6DDFF", starTwo), ("core", "#FFF4E8", core), ("world", "#7BE8BE", world),
        ("frost", "#DDF2FF", frost), ("scorch", "#C2412A", scorch), ("flower", "#FFE6F2", flower),
        ("pollen", "#FFE6F2", pollen), ("gaugePlate", "#1A2347", gaugePlate), ("lethalLow", "#5C8DFF", lethalLow),
        ("dim", "#8FB8E0", dim), ("comfortable", "#7BE8BE", comfortable), ("bright", "#FFB27A", bright),
        ("lethalHigh", "#FF4A3D", lethalHigh), ("window", "#B8FFE0", window), ("marker", "#FFF4E8", marker),
        ("tiltLit", "#A6DDFF", tiltLit), ("tiltUnlit", "#2B3560", tiltUnlit), ("actionsLit", "#FF7A4D", actionsLit),
        ("actionsUnlit", "#1E2648", actionsUnlit), ("broken", "#FF6B5E", broken), ("glow", "#FFF9F0", glow),
    ]

    /// The linear colour of 8-bit components.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). The backdrop and starfield, tilt
/// dial, rings, orbits, body positions and sizes, banding, pips, gauges, actions bars and colours are the same at every
/// tier; only the cube-sphere tessellation, the corona rays, the trails, the pollen motes and the glow differ.
public struct BinaryGardensTier: Sendable, Equatable, Hashable {
    /// The tier's name, `level-0` … `level-2`.
    public let name: String
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// The quads along each edge of a cube-sphere face (8, 5, 3: a world has 6 · faceQuads² quads).
    public let faceQuads: Int
    /// The corona rays around each star (0: none).
    public let coronaRays: Int
    /// The ticks before the shown tick whose positions are drawn as trail dots (0: no trails).
    public let trailTicks: Int
    /// The pollen motes circling each comfortable world (0: none).
    public let motes: Int
    /// The glow shells around the stars and the blooming worlds (0: no glow).
    public let glowShells: Int

    /// The three tiers, richest first.
    public static let all: [BinaryGardensTier] = [
        BinaryGardensTier(index: 0, faceQuads: 8, coronaRays: 12, trailTicks: 8, motes: 8, glowShells: 2),
        BinaryGardensTier(index: 1, faceQuads: 5, coronaRays: 6, trailTicks: 4, motes: 4, glowShells: 1),
        BinaryGardensTier(index: 2, faceQuads: 3, coronaRays: 0, trailTicks: 0, motes: 0, glowShells: 0),
    ]

    /// A tier of the given values, named `level-<index>`.
    init(index: Int, faceQuads: Int, coronaRays: Int, trailTicks: Int, motes: Int, glowShells: Int) {
        name = "level-\(index)"
        self.index = index
        self.faceQuads = faceQuads
        self.coronaRays = coronaRays
        self.trailTicks = trailTicks
        self.motes = motes
        self.glowShells = glowShells
    }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> BinaryGardensTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// A world as the scene draws it: its orbit, its four flux bounds, its required window and bloom band, and the
/// kernel's light of the current arrangement (the kernel's integers, copied; positions at scale 2^20, flux and shares
/// in milliflux).
public struct BinaryGardensSceneWorld: Sendable, Equatable {
    /// The orbit radius a in distance units.
    public let radius: Int
    /// The starting phase ψ, 0 … 47.
    public let phase: Int
    /// The speed ν in phase steps per tick, −4 … 4.
    public let speed: Int
    /// The lethal low bound λ_lo in milliflux.
    public let lethalLow: Int
    /// The comfortable low bound c_lo in milliflux.
    public let comfortLow: Int
    /// The comfortable high bound c_hi in milliflux.
    public let comfortHigh: Int
    /// The lethal high bound λ_hi in milliflux.
    public let lethalHigh: Int
    /// The required comfortable window W in ticks.
    public let window: Int
    /// The bloom band's low bound B_lo (an integral in milliflux · ticks).
    public let bloomLow: Int
    /// The bloom band's high bound B_hi.
    public let bloomHigh: Int
    /// The world's position at ticks 1 … 48 (index tick − 1), at scale 2^20.
    public let positions: [BinaryGardensPoint]
    /// The flux at ticks 1 … 48 (index tick − 1), in milliflux.
    public let flux: [Int]
    /// Each star's share at ticks 1 … 48: `shares[tick − 1][star]`, in milliflux.
    public let shares: [[Int]]
    /// The band at ticks 1 … 48 (index tick − 1).
    public let bands: [BinaryGardensBand]
    /// The longest cyclic run of lethal ticks.
    public let longestLethalRun: Int
    /// The longest cyclic comfortable window in ticks (the report's `window`).
    public let longestWindow: Int
    /// The start tick 1 … 48 of ``longestWindow``, 0 when no tick is comfortable.
    public let windowStart: Int
    /// The integrated flux I over ticks 1 … 48.
    public let integral: Int
    /// Where ``integral`` lies against the bloom band.
    public let bloom: BinaryGardensBloom

    /// A scene world of the given values.
    public init(radius: Int, phase: Int, speed: Int, lethalLow: Int, comfortLow: Int, comfortHigh: Int,
                lethalHigh: Int, window: Int, bloomLow: Int, bloomHigh: Int, positions: [BinaryGardensPoint],
                flux: [Int], shares: [[Int]], bands: [BinaryGardensBand], longestLethalRun: Int, longestWindow: Int,
                windowStart: Int, integral: Int, bloom: BinaryGardensBloom) {
        self.radius = radius
        self.phase = phase
        self.speed = speed
        self.lethalLow = lethalLow
        self.comfortLow = comfortLow
        self.comfortHigh = comfortHigh
        self.lethalHigh = lethalHigh
        self.window = window
        self.bloomLow = bloomLow
        self.bloomHigh = bloomHigh
        self.positions = positions
        self.flux = flux
        self.shares = shares
        self.bands = bands
        self.longestLethalRun = longestLethalRun
        self.longestWindow = longestWindow
        self.windowStart = windowStart
        self.integral = integral
        self.bloom = bloom
    }
}

/// Which of a star's ring, phase and luminosity the player may adjust (feature 504): a presentation copy of the level's
/// `BinaryGardensStar` flags.
public struct BinaryGardensStarFreedom: Sendable, Equatable {
    /// Whether the star may move to another ring (`ringAdjustable`).
    public let ring: Bool
    /// Whether the star's phase may shift (`phaseAdjustable`).
    public let phase: Bool
    /// Whether the star's luminosity may change (`luminosityAdjustable`).
    public let luminosity: Bool

    /// A freedom of the given flags.
    public init(ring: Bool, phase: Bool, luminosity: Bool) {
        self.ring = ring
        self.phase = phase
        self.luminosity = luminosity
    }

    /// Every control adjustable (the unchecked snapshot's default).
    public static let free: BinaryGardensStarFreedom = BinaryGardensStarFreedom(ring: true, phase: true,
                                                                               luminosity: true)
}

/// The preview of one drag (feature 504, R02-G21-04): the change as a kernel action and what the kernel makes of it —
/// the changed arrangement with the kernel's report of it, or the kernel's refusal. Presentation only; never in the
/// digest.
public struct BinaryGardensPreview: Sendable, Equatable {
    /// What the kernel makes of the change.
    public enum Outcome: Sendable, Equatable {
        /// The kernel accepts the change: the changed arrangement and the kernel's report of it.
        case accepted(arrangement: BinaryGardensArrangement, report: BinaryGardensReport)
        /// The kernel refuses the change with this refusal (the change rule's, or `.budget` with no action left).
        case refused(BinaryGardensError)
    }

    /// The change: a `.ring`, `.phase`, `.luminosity` or `.tilt` action.
    public let change: BinaryGardensAction
    /// What the kernel makes of it.
    public let outcome: Outcome

    /// A preview of the given values (unchecked; ``of(_:arrangement:actionsLeft:level:)`` computes one).
    public init(change: BinaryGardensAction, outcome: Outcome) {
        self.change = change
        self.outcome = outcome
    }

    /// The previewed report; nil when refused.
    public var report: BinaryGardensReport? {
        if case .accepted(_, let report) = outcome { return report }
        return nil
    }

    /// The previewed arrangement; nil when refused.
    public var arrangement: BinaryGardensArrangement? {
        if case .accepted(let arrangement, _) = outcome { return arrangement }
        return nil
    }

    /// The kernel's refusal; nil when accepted.
    public var refusal: BinaryGardensError? {
        if case .refused(let error) = outcome { return error }
        return nil
    }

    /// The previewed verdict: whether running the changed arrangement would win; nil when refused.
    public var wins: Bool? { report?.wins }

    /// The preview of `change` from `arrangement` with `actionsLeft` actions left in `level`, judged by the kernel in the
    /// order the play judges an arrangement action: the kernel's change rule (`BinaryGardensSky.changed`: range, grid,
    /// locked, unchanged, separation), then `.budget` when no action is left, then `BinaryGardensSky.report` of the
    /// changed arrangement. Nil (no preview) for `.run`, for an unchanged value (the change rule's
    /// `.action("unchanged")`) and for an arrangement without the level's shape.
    public static func of(_ change: BinaryGardensAction, arrangement: BinaryGardensArrangement, actionsLeft: Int,
                          level: BinaryGardensLevel) -> BinaryGardensPreview? {
        if case .run = change { return nil }
        guard BinaryGardensSky.isWellFormed(level, arrangement) else { return nil }
        let next: BinaryGardensArrangement
        do throws(BinaryGardensError) {
            next = try BinaryGardensSky.changed(level, arrangement, by: change)
        } catch {
            if error == .action("unchanged") { return nil }
            return BinaryGardensPreview(change: change, outcome: .refused(error))
        }
        guard actionsLeft > 0 else { return BinaryGardensPreview(change: change, outcome: .refused(.budget)) }
        return BinaryGardensPreview(change: change,
                                    outcome: .accepted(arrangement: next,
                                                       report: BinaryGardensSky.report(level, arrangement: next)))
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct BinaryGardensSceneSnapshot: Sendable, Equatable {
    /// The ticks of one cycle (and the entries of every per-tick list), 48.
    public static let cycle: Int = BinaryGardensSky.cycle

    /// The level's ring radii in distance units, ascending.
    public let ringRadii: [Int]
    /// The level's luminosity levels in units.
    public let luminosityLevels: [Int]
    /// The level's maximum tilt T_max, 0 … 6.
    public let maxTilt: Int
    /// The level's phase step g.
    public let phaseStep: Int
    /// The level's lethal tolerance E in ticks.
    public let lethalTolerance: Int
    /// The worlds, by world index.
    public let worlds: [BinaryGardensSceneWorld]
    /// The arrangement: both stars' rings, phases and luminosities and the tilt.
    public let arrangement: BinaryGardensArrangement
    /// Both stars' positions at ticks 1 … 48: `starPositions[tick − 1][star]`, at scale 2^20.
    public let starPositions: [[BinaryGardensPoint]]
    /// The shown tick, 1 … 48 (presentation only; never part of the digest).
    public let shownTick: Int
    /// The fit scale k = 0.95 / R, R the largest of the level's ring radii and world radii.
    public let fitScale: Double
    /// The failure: the play's on a failed play, otherwise the report's prediction (nil when a run would win).
    public let failure: BinaryGardensFailure?
    /// The stage.
    public let stage: BinaryGardensStage
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double
    /// The level's star speed ω in phase steps per tick, 1 … 3 (feature 504; presentation copy; 1 when unchecked).
    public let starSpeed: Int
    /// Each star's freedoms, star 1 first (feature 504; presentation copy; every control adjustable when unchecked).
    public let freedoms: [BinaryGardensStarFreedom]
    /// The previewed drag; nil from every initialiser (feature 504; presentation only; never in the digest).
    public private(set) var preview: BinaryGardensPreview? = nil
    /// The inspected world; nil from every initialiser (feature 504; presentation only; never in the digest).
    public private(set) var inspectedWorld: Int? = nil

    /// A snapshot of `play` with tick `shownTick` shown (clamped to 1 … 48), at presentation time `time` (a non-finite
    /// or negative time becomes 0). Copies the play's report; never holds the kernel.
    public init(play: BinaryGardensPlay, shownTick: Int, levelNumber: Int, time: Double) {
        let level: BinaryGardensLevel = play.level
        let report: BinaryGardensReport = play.report
        var worlds: [BinaryGardensSceneWorld] = []
        for (index, world) in level.worlds.enumerated() {
            let light: BinaryGardensWorldLight = report.worlds[index]
            var positions: [BinaryGardensPoint] = []
            for tick in report.worldPositions { positions.append(tick[index]) }
            worlds.append(BinaryGardensSceneWorld(radius: world.radius, phase: world.phase, speed: world.speed,
                                                  lethalLow: world.lethalLow, comfortLow: world.comfortLow,
                                                  comfortHigh: world.comfortHigh, lethalHigh: world.lethalHigh,
                                                  window: world.window, bloomLow: world.bloomLow,
                                                  bloomHigh: world.bloomHigh, positions: positions, flux: light.flux,
                                                  shares: light.shares, bands: light.bands,
                                                  longestLethalRun: light.longestLethalRun,
                                                  longestWindow: light.window, windowStart: light.windowStart,
                                                  integral: light.integral, bloom: light.bloom))
        }
        self.init(ringRadii: level.ringRadii, luminosityLevels: level.luminosityLevels, maxTilt: level.maxTilt,
                  phaseStep: level.phaseStep, lethalTolerance: level.lethalTolerance, worlds: worlds,
                  arrangement: play.arrangement, starPositions: report.starPositions, shownTick: shownTick,
                  failure: play.failure ?? report.failure, stage: play.stage, actionsLeft: play.actionsLeft,
                  budget: level.budget, levelNumber: levelNumber, time: time, starSpeed: level.starSpeed,
                  freedoms: level.stars.map { star in
                      BinaryGardensStarFreedom(ring: star.ringAdjustable, phase: star.phaseAdjustable,
                                               luminosity: star.luminosityAdjustable)
                  })
    }

    /// A snapshot of the given values, unchecked (presentation variants and tests: arrangements, failures and stages a
    /// play may not reach); the fit scale is computed from the radii, `shownTick` is clamped to 1 … 48 and `time` made
    /// finite and non-negative; the star speed defaults to 1 and the freedoms to every control adjustable (feature 504).
    init(ringRadii: [Int], luminosityLevels: [Int], maxTilt: Int, phaseStep: Int, lethalTolerance: Int,
         worlds: [BinaryGardensSceneWorld], arrangement: BinaryGardensArrangement,
         starPositions: [[BinaryGardensPoint]], shownTick: Int, failure: BinaryGardensFailure?,
         stage: BinaryGardensStage, actionsLeft: Int, budget: Int, levelNumber: Int, time: Double,
         starSpeed: Int = 1, freedoms: [BinaryGardensStarFreedom] = [.free, .free]) {
        self.ringRadii = ringRadii
        self.luminosityLevels = luminosityLevels
        self.maxTilt = maxTilt
        self.phaseStep = phaseStep
        self.lethalTolerance = lethalTolerance
        self.worlds = worlds
        self.arrangement = arrangement
        self.starPositions = starPositions
        self.shownTick = min(max(shownTick, 1), Self.cycle)
        self.fitScale = Self.fitScale(ringRadii: ringRadii, worldRadii: worlds.map(\.radius))
        self.failure = failure
        self.stage = stage
        self.actionsLeft = actionsLeft
        self.budget = budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
        self.starSpeed = starSpeed
        self.freedoms = freedoms
    }

    /// The fit scale k = 0.95 / R for R the largest of `ringRadii` and `worldRadii` (R at least 1).
    public static func fitScale(ringRadii: [Int], worldRadii: [Int]) -> Double {
        let largest: Int = max(ringRadii.max() ?? 1, worldRadii.max() ?? 1, 1)
        return 0.95 / Double(largest)
    }

    /// Whether the play is won (the won stage, or the result shown after a winning run).
    public var isWon: Bool { stage == .won || (stage == .result && failure == nil) }

    /// The index 0 … 47 of tick `tick` read cyclically (tick t > 48 is tick t − 48, tick 0 is tick 48).
    public static func tickIndex(_ tick: Int) -> Int { ((tick - 1) % cycle + cycle) % cycle }

    /// World `world`'s band at the shown tick (comfortable for a world the snapshot lacks).
    public func band(_ world: Int) -> BinaryGardensBand {
        guard worlds.indices.contains(world) else { return .comfortable }
        let bands: [BinaryGardensBand] = worlds[world].bands
        let index: Int = Self.tickIndex(shownTick)
        return index < bands.count ? bands[index] : .comfortable
    }

    /// Star `star`'s share of world `world`'s flux at the shown tick, in milliflux (0 when either is missing).
    public func share(_ world: Int, star: Int) -> Int {
        guard worlds.indices.contains(world) else { return 0 }
        let shares: [[Int]] = worlds[world].shares
        let index: Int = Self.tickIndex(shownTick)
        guard index < shares.count, shares[index].indices.contains(star) else { return 0 }
        return shares[index][star]
    }

    /// Star `star`'s position at tick `tick` (read cyclically), at scale 2^20; the origin when it is missing.
    public func starPoint(_ star: Int, tick: Int) -> BinaryGardensPoint {
        let index: Int = Self.tickIndex(tick)
        guard index < starPositions.count, starPositions[index].indices.contains(star) else {
            return BinaryGardensPoint(x: 0, y: 0, z: 0)
        }
        return starPositions[index][star]
    }

    /// World `world`'s position at tick `tick` (read cyclically), at scale 2^20; the origin when it is missing.
    public func worldPoint(_ world: Int, tick: Int) -> BinaryGardensPoint {
        guard worlds.indices.contains(world) else { return BinaryGardensPoint(x: 0, y: 0, z: 0) }
        let positions: [BinaryGardensPoint] = worlds[world].positions
        let index: Int = Self.tickIndex(tick)
        return index < positions.count ? positions[index] : BinaryGardensPoint(x: 0, y: 0, z: 0)
    }

    // MARK: Feature 504 — star steps, preview and inspection

    /// Star `star`'s freedoms (every control adjustable for a star the snapshot lacks).
    public func freedom(_ star: Int) -> BinaryGardensStarFreedom {
        freedoms.indices.contains(star) ? freedoms[star] : .free
    }

    /// The table step star `star` stands at at tick `tick`: (θ + ω · tick) mod 48 (`BinaryGardensSky.phase`), θ its
    /// phase in the arrangement (0 for a star the snapshot lacks); tick 48 gives θ.
    public func starStep(_ star: Int, tick: Int) -> Int {
        let phases: [Int] = arrangement.phases
        let theta: Int = phases.indices.contains(star) ? phases[star] : 0
        return BinaryGardensSky.phase(theta, speed: starSpeed, tick: tick)
    }

    /// This snapshot with `change` previewed in `level` (the snapshot's level): ``preview`` is
    /// ``BinaryGardensPreview/of(_:arrangement:actionsLeft:level:)`` of this snapshot's arrangement and actions left —
    /// the kernel's own judgement. A level whose rings, luminosity levels, maximum tilt, phase step, star speed or world
    /// count differ from the snapshot's, `.run` or an unchanged value gives this snapshot without a preview.
    /// Presentation only: nothing else changes.
    public func previewing(_ change: BinaryGardensAction, level: BinaryGardensLevel) -> BinaryGardensSceneSnapshot {
        var copy: BinaryGardensSceneSnapshot = self
        guard level.ringRadii == ringRadii, level.luminosityLevels == luminosityLevels, level.maxTilt == maxTilt,
              level.phaseStep == phaseStep, level.starSpeed == starSpeed, level.worlds.count == worlds.count else {
            copy.preview = nil
            return copy
        }
        copy.preview = BinaryGardensPreview.of(change, arrangement: arrangement, actionsLeft: actionsLeft, level: level)
        return copy
    }

    /// This snapshot without a preview (presentation only).
    public func clearingPreview() -> BinaryGardensSceneSnapshot {
        var copy: BinaryGardensSceneSnapshot = self
        copy.preview = nil
        return copy
    }

    /// This snapshot with world `world` inspected (nil, or a world the snapshot lacks, clears the inspection);
    /// presentation only.
    public func inspecting(_ world: Int?) -> BinaryGardensSceneSnapshot {
        var copy: BinaryGardensSceneSnapshot = self
        if let index = world, worlds.indices.contains(index) {
            copy.inspectedWorld = index
        } else {
            copy.inspectedWorld = nil
        }
        return copy
    }
}
