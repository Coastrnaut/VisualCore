// BinaryGardensSky — feature 501 (R02-G21-01) T-R02G2101-002 (FR-R02G2101-002, 003, 004, 005, 014; SC-R02G2101-003,
// 004; clarifications Q1 … Q4). The exact sky of Binary Gardens: two stars and 1 … 5 garden worlds on analytic circular
// orbits quantized to 48 phase steps (7.5° each), sampled once per tick, so every body is back at its start after the
// 48-tick cycle. Angles come from a fixed integer cosine table at scale 1024 (the quarter wave C[0 … 12] = 1024, 1015,
// 989, 946, 887, 812, 724, 623, 512, 392, 265, 134, 0, the rest by symmetry; S[k] = C[(k + 36) mod 48]); positions are
// integers at scale 2^20 — a world at radius a and phase ψ is at (a·C[ψ]·1024, a·S[ψ]·1024, 0), a star at ring radius ρ,
// phase θ and tilt τ at (ρ·C[θ]·1024, ρ·S[θ]·C[τ], ρ·S[θ]·S[τ]); squared distances at scale 2^40. Star i gives world j
// ⌊1000·Lᵢ·2^40 / max(D, r_min²·2^40)⌋ milliflux (one truncating division per star, at most 64 000), and a world's flux
// at a tick is the sum of its two stars' shares. Every tick is classed lethal low (F < λ_lo), dim, comfortable
// (c_lo ≤ F ≤ c_hi), bright or lethal high (F > λ_hi); the integral is the sum of the flux over ticks 1 … 48; the longest
// lethal run and the longest comfortable window are read cyclically (tick 48 followed by tick 1, at most 48). The judge
// walks ticks 1 … 48 + E (a tick t > 48 repeats tick t − 48) and fails `frozen` or `scorched` at the first tick a
// world's consecutive lethal ticks exceed the tolerance E (worlds ascending within a tick, a mixed run named by the band
// of the exceeding tick); otherwise, worlds ascending, `unstable` (window shorter than W) before `wilted` (I < B_lo) or
// `bleached` (I > B_hi); otherwise the level is won. The stars keep the minimum separation σ when their squared
// separation at every tick 0 … 47 is at least σ²·2^40. Integers only; no clock is read and no trigonometry runs.

/// A star of a level: its starting ring, phase and luminosity and which of them the player may adjust.
public struct BinaryGardensStar: Sendable, Hashable, Codable {
    /// The starting ring, an index into the level's ring radii.
    public let ring: Int
    /// The starting phase θ, 0 … 47.
    public let phase: Int
    /// The starting luminosity, an index into the level's luminosity levels.
    public let luminosity: Int
    /// Whether the player may move the star to another ring.
    public let ringAdjustable: Bool
    /// Whether the player may shift the star's phase.
    public let phaseAdjustable: Bool
    /// Whether the player may change the star's luminosity.
    public let luminosityAdjustable: Bool

    /// A star of the given values (checked by ``BinaryGardensLevel``).
    public init(ring: Int, phase: Int, luminosity: Int, ringAdjustable: Bool, phaseAdjustable: Bool,
                luminosityAdjustable: Bool) {
        self.ring = ring
        self.phase = phase
        self.luminosity = luminosity
        self.ringAdjustable = ringAdjustable
        self.phaseAdjustable = phaseAdjustable
        self.luminosityAdjustable = luminosityAdjustable
    }
}

/// A garden world: its fixed orbit in the base plane, its four flux bounds, its required window and its bloom band.
public struct BinaryGardensWorld: Sendable, Hashable, Codable {
    /// The orbit radius a in distance units, 1 … 60.
    public let radius: Int
    /// The starting phase ψ, 0 … 47.
    public let phase: Int
    /// The speed ν in phase steps per tick, −4 … 4 (negative is retrograde, 0 a world held still).
    public let speed: Int
    /// The lethal low bound λ_lo in milliflux: a flux strictly below it is lethal.
    public let lethalLow: Int
    /// The comfortable low bound c_lo in milliflux (inside the comfortable band).
    public let comfortLow: Int
    /// The comfortable high bound c_hi in milliflux (inside the comfortable band).
    public let comfortHigh: Int
    /// The lethal high bound λ_hi in milliflux: a flux strictly above it is lethal.
    public let lethalHigh: Int
    /// The required comfortable window W in ticks, 1 … 48.
    public let window: Int
    /// The lowest integrated flux B_lo inside the bloom band.
    public let bloomLow: Int
    /// The highest integrated flux B_hi inside the bloom band.
    public let bloomHigh: Int

    /// A world of the given values (checked by ``BinaryGardensLevel``).
    public init(radius: Int, phase: Int, speed: Int, lethalLow: Int, comfortLow: Int, comfortHigh: Int,
                lethalHigh: Int, window: Int, bloomLow: Int, bloomHigh: Int) {
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
    }
}

/// An arrangement: both stars' rings, phases and luminosities (two entries each, star 1 first) and the orbit tilt.
public struct BinaryGardensArrangement: Sendable, Hashable, Codable {
    /// Each star's ring, an index into the level's ring radii.
    public let rings: [Int]
    /// Each star's phase θ, 0 … 47.
    public let phases: [Int]
    /// Each star's luminosity, an index into the level's luminosity levels.
    public let luminosities: [Int]
    /// The orbit-plane tilt τ in phase steps, 0 … T_max.
    public let tilt: Int

    /// The arrangement of the given values (checked by ``BinaryGardensLevel`` and the play).
    public init(rings: [Int], phases: [Int], luminosities: [Int], tilt: Int) {
        self.rings = rings
        self.phases = phases
        self.luminosities = luminosities
        self.tilt = tilt
    }
}

/// A point in space at scale 2^20 (one distance unit is 1 048 576).
public struct BinaryGardensPoint: Sendable, Hashable, Codable {
    /// The x coordinate.
    public let x: Int
    /// The y coordinate.
    public let y: Int
    /// The z coordinate (0 for every world: worlds orbit in the base plane).
    public let z: Int

    /// The point (x, y, z).
    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// The band of one tick's flux against a world's four bounds.
public enum BinaryGardensBand: String, Sendable, Codable, CaseIterable {
    /// F < λ_lo.
    case lethalLow
    /// λ_lo ≤ F < c_lo.
    case dim
    /// c_lo ≤ F ≤ c_hi.
    case comfortable
    /// c_hi < F ≤ λ_hi.
    case bright
    /// F > λ_hi.
    case lethalHigh

    /// Whether the band is lethal (low or high).
    public var isLethal: Bool { self == .lethalLow || self == .lethalHigh }

    /// The band in words: "lethal low", "dim", "comfortable", "bright" or "lethal high".
    public var words: String {
        switch self {
        case .lethalLow: "lethal low"
        case .dim: "dim"
        case .comfortable: "comfortable"
        case .bright: "bright"
        case .lethalHigh: "lethal high"
        }
    }
}

/// Where a world's integrated flux lies against its bloom band.
public enum BinaryGardensBloom: String, Sendable, Codable {
    /// I < B_lo.
    case below
    /// B_lo ≤ I ≤ B_hi.
    case inside
    /// I > B_hi.
    case above
}

/// Why a run of the cycle failed. Worlds are 0-based; a tick is the walk tick 1 … 48 + E.
public enum BinaryGardensFailure: Sendable, Hashable, Codable {
    /// World `world`'s lethal run exceeded the tolerance at walk tick `tick`, a lethal-low tick.
    case frozen(world: Int, tick: Int)
    /// World `world`'s lethal run exceeded the tolerance at walk tick `tick`, a lethal-high tick.
    case scorched(world: Int, tick: Int)
    /// World `world`'s longest cyclic comfortable window, `window` ticks, is shorter than `required`.
    case unstable(world: Int, window: Int, required: Int)
    /// World `world`'s integrated flux `integral` is below its bloom band `low` … `high`.
    case wilted(world: Int, integral: Int, low: Int, high: Int)
    /// World `world`'s integrated flux `integral` is above its bloom band `low` … `high`.
    case bleached(world: Int, integral: Int, low: Int, high: Int)

    /// The failure's code: `frozen`, `scorched`, `unstable`, `wilted` or `bleached`.
    public var code: String {
        switch self {
        case .frozen: "frozen"
        case .scorched: "scorched"
        case .unstable: "unstable"
        case .wilted: "wilted"
        case .bleached: "bleached"
        }
    }

    /// The world the failure names (0-based).
    public var world: Int {
        switch self {
        case .frozen(let world, _), .scorched(let world, _): world
        case .unstable(let world, _, _): world
        case .wilted(let world, _, _, _), .bleached(let world, _, _, _): world
        }
    }
}

/// The light one world receives over one cycle: the per-world part of the truth metric (FR-R02G2101-014).
public struct BinaryGardensWorldLight: Sendable, Equatable {
    /// The flux at ticks 1 … 48 (index 0 is tick 1), in milliflux: the sum of the two stars' shares.
    public let flux: [Int]
    /// Each star's share at ticks 1 … 48: `shares[tick − 1][star]`.
    public let shares: [[Int]]
    /// The band of ticks 1 … 48.
    public let bands: [BinaryGardensBand]
    /// The longest run of consecutive lethal ticks, read cyclically, at most 48.
    public let longestLethalRun: Int
    /// The longest run of consecutive comfortable ticks, read cyclically, at most 48.
    public let window: Int
    /// The start tick (1 … 48) of ``window``: the smallest start among equal longest runs, tick 1 when all 48 ticks are
    /// comfortable, 0 when no tick is comfortable.
    public let windowStart: Int
    /// The integrated flux I, the sum of ``flux`` over ticks 1 … 48 (the mean flux is I / 48, kept exact as I).
    public let integral: Int
    /// Where ``integral`` lies against the bloom band.
    public let bloom: BinaryGardensBloom

    /// A world light of the given values.
    public init(flux: [Int], shares: [[Int]], bands: [BinaryGardensBand], longestLethalRun: Int, window: Int,
                windowStart: Int, integral: Int, bloom: BinaryGardensBloom) {
        self.flux = flux
        self.shares = shares
        self.bands = bands
        self.longestLethalRun = longestLethalRun
        self.window = window
        self.windowStart = windowStart
        self.integral = integral
        self.bloom = bloom
    }
}

/// The exact light report of one arrangement: the truth metric (FR-R02G2101-014). It describes; the judge's result is
/// `failure`, and a play ends only on `run`.
public struct BinaryGardensReport: Sendable, Equatable {
    /// Each star's position at ticks 1 … 48: `starPositions[tick − 1][star]`.
    public let starPositions: [[BinaryGardensPoint]]
    /// Each world's position at ticks 1 … 48: `worldPositions[tick − 1][world]`.
    public let worldPositions: [[BinaryGardensPoint]]
    /// The light of every world, by world index.
    public let worlds: [BinaryGardensWorldLight]
    /// The smallest squared star separation over ticks 0 … 47, at scale 2^40.
    public let minimumSeparationSquared: Int
    /// The earliest tick 0 … 47 at which ``minimumSeparationSquared`` occurs (tick 0 is the configuration of tick 48).
    public let minimumSeparationTick: Int
    /// The judge's first failure, or nil when running would win.
    public let failure: BinaryGardensFailure?

    /// A report of the given values.
    public init(starPositions: [[BinaryGardensPoint]], worldPositions: [[BinaryGardensPoint]],
                worlds: [BinaryGardensWorldLight], minimumSeparationSquared: Int, minimumSeparationTick: Int,
                failure: BinaryGardensFailure?) {
        self.starPositions = starPositions
        self.worldPositions = worldPositions
        self.worlds = worlds
        self.minimumSeparationSquared = minimumSeparationSquared
        self.minimumSeparationTick = minimumSeparationTick
        self.failure = failure
    }

    /// Whether running the cycle would win.
    public var wins: Bool { failure == nil }
}

/// A player action: move a star to a ring, shift its phase, set its luminosity, tilt the orbit plane, or run the cycle.
/// Stars are 0-based (star 1 in words is `star: 0`).
public enum BinaryGardensAction: Sendable, Hashable, Codable {
    /// Move star `star` to ring `index`; spends one action ("adjust orbit").
    case ring(star: Int, index: Int)
    /// Shift star `star` to phase `step`, 0 … 47; spends one action ("phase twin stars").
    case phase(star: Int, step: Int)
    /// Set star `star`'s luminosity to level `index`; spends one action ("set luminosity").
    case luminosity(star: Int, index: Int)
    /// Tilt the orbit plane to `step`, 0 … T_max; spends one action.
    case tilt(step: Int)
    /// Run the cycle ("commit light window"); spends nothing and ends the level.
    case run
}

/// The exact two-star sky: the cosine table, positions, distances, milliflux, bands, the light report and the judge.
public enum BinaryGardensSky {
    /// The phase steps (and ticks) of one cycle.
    public static let cycle: Int = 48
    /// The scale of the cosine table.
    public static let tableScale: Int = 1024
    /// The scale of a position: 2^20.
    public static let positionScale: Int = 1 << 20
    /// The scale of a squared distance: 2^40.
    public static let squaredScale: Int = 1 << 40
    /// The milliflux of one flux unit (one luminosity unit at one distance unit).
    public static let millifluxPerUnit: Int = 1000

    /// The cosine of every phase step k (7.5°·k) at scale 1024: the nearest integer to 1024·cos(7.5°·k), literal data
    /// built from the quarter wave C[0 … 12] by C[k] = −C[24 − k] (13 … 24), −C[k − 24] (25 … 36), C[48 − k] (37 … 47).
    public static let cosine: [Int] = [
        1024, 1015, 989, 946, 887, 812, 724, 623, 512, 392, 265, 134,
        0, -134, -265, -392, -512, -623, -724, -812, -887, -946, -989, -1015,
        -1024, -1015, -989, -946, -887, -812, -724, -623, -512, -392, -265, -134,
        0, 134, 265, 392, 512, 623, 724, 812, 887, 946, 989, 1015,
    ]

    /// The sine of phase step `step` at scale 1024: `cosine[(step + 36) mod 48]` (any integer step).
    public static func sine(_ step: Int) -> Int { cosine[wrap(step + 36)] }

    /// `value` mod 48, non-negative.
    static func wrap(_ value: Int) -> Int { ((value % cycle) + cycle) % cycle }

    /// The phase at `tick` of a body starting at phase `start` and moving `speed` steps per tick: the non-negative
    /// (start + speed·tick) mod 48.
    public static func phase(_ start: Int, speed: Int, tick: Int) -> Int { wrap(start + speed * tick) }

    /// A star on a ring of radius `radius` at phase `phase` in the orbit plane tilted by `tilt` steps about the x axis:
    /// (ρ·C[θ]·1024, ρ·S[θ]·C[τ], ρ·S[θ]·S[τ]).
    public static func starPosition(radius: Int, phase: Int, tilt: Int) -> BinaryGardensPoint {
        let c: Int = cosine[wrap(phase)]
        let s: Int = sine(phase)
        return BinaryGardensPoint(x: radius * c * tableScale, y: radius * s * cosine[wrap(tilt)],
                                  z: radius * s * sine(tilt))
    }

    /// A world on an orbit of radius `radius` at phase `phase` in the base plane: (a·C[ψ]·1024, a·S[ψ]·1024, 0).
    public static func worldPosition(radius: Int, phase: Int) -> BinaryGardensPoint {
        BinaryGardensPoint(x: radius * cosine[wrap(phase)] * tableScale, y: radius * sine(phase) * tableScale, z: 0)
    }

    /// The exact squared distance between `a` and `b`, at scale 2^40.
    public static func squaredDistance(_ a: BinaryGardensPoint, _ b: BinaryGardensPoint) -> Int {
        let dx: Int = a.x - b.x
        let dy: Int = a.y - b.y
        let dz: Int = a.z - b.z
        return dx * dx + dy * dy + dz * dz
    }

    /// The share in milliflux of a star of luminosity `luminosity` (units, 1 … 64) at squared distance
    /// `squaredDistance` (scale 2^40) with clamp radius `clampRadius` (1 … 8 units):
    /// ⌊1000·L·2^40 / max(D, r_min²·2^40)⌋, at most 64 000.
    public static func flux(luminosity: Int, squaredDistance: Int, clampRadius: Int) -> Int {
        let clamp: Int = clampRadius * clampRadius * squaredScale
        return millifluxPerUnit * luminosity * squaredScale / max(squaredDistance, clamp)
    }

    /// The band of flux `flux` against `world`'s four bounds.
    public static func band(_ flux: Int, of world: BinaryGardensWorld) -> BinaryGardensBand {
        if flux < world.lethalLow { return .lethalLow }
        if flux < world.comfortLow { return .dim }
        if flux <= world.comfortHigh { return .comfortable }
        if flux <= world.lethalHigh { return .bright }
        return .lethalHigh
    }

    /// Whether `arrangement` has the level's shape: two entries per star array, every index in range and a tilt of
    /// 0 … T_max.
    static func isWellFormed(_ level: BinaryGardensLevel, _ arrangement: BinaryGardensArrangement) -> Bool {
        guard arrangement.rings.count == 2, arrangement.phases.count == 2,
              arrangement.luminosities.count == 2 else { return false }
        for star in 0..<2 {
            guard level.ringRadii.indices.contains(arrangement.rings[star]),
                  (0..<cycle).contains(arrangement.phases[star]),
                  level.luminosityLevels.indices.contains(arrangement.luminosities[star]) else { return false }
        }
        return (0...level.maxTilt).contains(arrangement.tilt)
    }

    /// Both stars' positions at `tick`.
    static func starPositions(_ level: BinaryGardensLevel, _ arrangement: BinaryGardensArrangement,
                              tick: Int) -> [BinaryGardensPoint] {
        var points: [BinaryGardensPoint] = []
        for star in 0..<2 {
            let radius: Int = level.ringRadii[arrangement.rings[star]]
            let phase: Int = phase(arrangement.phases[star], speed: level.starSpeed, tick: tick)
            points.append(starPosition(radius: radius, phase: phase, tilt: arrangement.tilt))
        }
        return points
    }

    /// The smallest squared star separation over ticks 0 … 47 and the earliest tick at which it occurs (a well-formed
    /// arrangement).
    static func minimumSeparation(_ level: BinaryGardensLevel,
                                  _ arrangement: BinaryGardensArrangement) -> (squared: Int, tick: Int) {
        var best: Int = Int.max
        var bestTick: Int = 0
        for tick in 0..<cycle {
            let points: [BinaryGardensPoint] = starPositions(level, arrangement, tick: tick)
            let d: Int = squaredDistance(points[0], points[1])
            if d < best {
                best = d
                bestTick = tick
            }
        }
        return (best, bestTick)
    }

    /// Whether the stars of `arrangement` keep the level's minimum separation σ: their squared separation at every tick
    /// 0 … 47 is at least σ²·2^40 (exactly σ is allowed; σ = 0 always holds). False for an arrangement without the
    /// level's shape.
    public static func keepsSeparation(_ level: BinaryGardensLevel, arrangement: BinaryGardensArrangement) -> Bool {
        guard isWellFormed(level, arrangement) else { return false }
        let limit: Int = level.minimumSeparation * level.minimumSeparation * squaredScale
        for tick in 0..<cycle {
            let points: [BinaryGardensPoint] = starPositions(level, arrangement, tick: tick)
            if squaredDistance(points[0], points[1]) < limit { return false }
        }
        return true
    }

    /// The longest run of `true` in `values` read cyclically (the last followed by the first), at most
    /// `values.count`, with its start index: the smallest start among equal longest runs, 0 when every value is true,
    /// nil when none is.
    static func longestCyclicRun(_ values: [Bool]) -> (length: Int, start: Int?) {
        let count: Int = values.count
        guard let breakIndex = values.firstIndex(of: false) else { return (count, count > 0 ? 0 : nil) }
        var bestLength: Int = 0
        var bestStart: Int?
        var length: Int = 0
        var start: Int = 0
        for offset in 1...count {
            let index: Int = (breakIndex + offset) % count
            if values[index] {
                if length == 0 { start = index }
                length += 1
                if length > bestLength || (length == bestLength && start < (bestStart ?? Int.max)) {
                    bestLength = length
                    bestStart = start
                }
            } else {
                length = 0
            }
        }
        return (bestLength, bestStart)
    }

    /// The light of `world` from the stars' shares at ticks 1 … 48 (`shares[tick − 1][star]`): flux, bands, the
    /// longest cyclic lethal run, the longest cyclic comfortable window with its start tick, the integral and the bloom.
    static func light(shares: [[Int]], world: BinaryGardensWorld) -> BinaryGardensWorldLight {
        var flux: [Int] = []
        var bands: [BinaryGardensBand] = []
        var integral: Int = 0
        for tickShares in shares {
            var total: Int = 0
            for share in tickShares { total += share }
            flux.append(total)
            bands.append(band(total, of: world))
            integral += total
        }
        let lethal: (length: Int, start: Int?) = longestCyclicRun(bands.map { $0.isLethal })
        let comfortable: (length: Int, start: Int?) = longestCyclicRun(bands.map { $0 == .comfortable })
        let bloom: BinaryGardensBloom = integral < world.bloomLow ? .below
            : (integral > world.bloomHigh ? .above : .inside)
        return BinaryGardensWorldLight(flux: flux, shares: shares, bands: bands, longestLethalRun: lethal.length,
                                       window: comfortable.length, windowStart: comfortable.start.map { $0 + 1 } ?? 0,
                                       integral: integral, bloom: bloom)
    }

    /// The judge of the worlds' lights under lethal tolerance `tolerance`: the lethal walk over ticks 1 … 48 + E (a
    /// tick t > 48 repeats tick t − 48; worlds ascending within a tick; a lethal tick extends a world's run, any other
    /// tick ends it; the first run longer than E fails `frozen` on a lethal-low tick or `scorched` on a lethal-high
    /// tick, naming the world and the walk tick); then, worlds ascending, `unstable` (window shorter than W) before
    /// `wilted` (I < B_lo) or `bleached` (I > B_hi); nil when the level is won.
    static func judge(worlds: [BinaryGardensWorld], tolerance: Int,
                      lights: [BinaryGardensWorldLight]) -> BinaryGardensFailure? {
        var runs: [Int] = Array(repeating: 0, count: lights.count)
        for tick in 1...(cycle + tolerance) {
            let index: Int = (tick - 1) % cycle
            for world in lights.indices {
                let band: BinaryGardensBand = lights[world].bands[index]
                if band.isLethal {
                    runs[world] += 1
                    if runs[world] > tolerance {
                        return band == .lethalLow ? .frozen(world: world, tick: tick)
                            : .scorched(world: world, tick: tick)
                    }
                } else {
                    runs[world] = 0
                }
            }
        }
        for world in lights.indices {
            let light: BinaryGardensWorldLight = lights[world]
            let rules: BinaryGardensWorld = worlds[world]
            if light.window < rules.window {
                return .unstable(world: world, window: light.window, required: rules.window)
            }
            if light.integral < rules.bloomLow {
                return .wilted(world: world, integral: light.integral, low: rules.bloomLow, high: rules.bloomHigh)
            }
            if light.integral > rules.bloomHigh {
                return .bleached(world: world, integral: light.integral, low: rules.bloomLow, high: rules.bloomHigh)
            }
        }
        return nil
    }

    /// The exact light report of `arrangement` in `level` (a well-formed arrangement): every body's position at ticks
    /// 1 … 48, every world's flux with each star's share, bands, runs, window and integral, the minimum star separation
    /// over ticks 0 … 47 and the judge's first failure.
    public static func report(_ level: BinaryGardensLevel,
                              arrangement: BinaryGardensArrangement) -> BinaryGardensReport {
        let luminosities: [Int] = arrangement.luminosities.map { level.luminosityLevels[$0] }
        var starPositions: [[BinaryGardensPoint]] = []
        var worldPositions: [[BinaryGardensPoint]] = []
        starPositions.reserveCapacity(cycle)
        worldPositions.reserveCapacity(cycle)
        var shares: [[[Int]]] = Array(repeating: [], count: level.worlds.count)
        for tick in 1...cycle {
            let stars: [BinaryGardensPoint] = Self.starPositions(level, arrangement, tick: tick)
            var worlds: [BinaryGardensPoint] = []
            for (index, world) in level.worlds.enumerated() {
                let point: BinaryGardensPoint = worldPosition(radius: world.radius,
                                                              phase: phase(world.phase, speed: world.speed, tick: tick))
                worlds.append(point)
                var tickShares: [Int] = []
                for star in 0..<2 {
                    tickShares.append(flux(luminosity: luminosities[star],
                                           squaredDistance: squaredDistance(stars[star], point),
                                           clampRadius: level.clampRadius))
                }
                shares[index].append(tickShares)
            }
            starPositions.append(stars)
            worldPositions.append(worlds)
        }
        var lights: [BinaryGardensWorldLight] = []
        for (index, world) in level.worlds.enumerated() { lights.append(light(shares: shares[index], world: world)) }
        let separation: (squared: Int, tick: Int) = minimumSeparation(level, arrangement)
        let failure: BinaryGardensFailure? = judge(worlds: level.worlds, tolerance: level.lethalTolerance,
                                                   lights: lights)
        return BinaryGardensReport(starPositions: starPositions, worldPositions: worldPositions, worlds: lights,
                                   minimumSeparationSquared: separation.squared,
                                   minimumSeparationTick: separation.tick, failure: failure)
    }

    /// The largest integer r with r² ≤ `value` (0 for a value ≤ 0), by integer Newton steps.
    static func integerSquareRoot(_ value: Int) -> Int {
        guard value > 0 else { return 0 }
        var x: Int = value
        var y: Int = (x + 1) / 2
        while y < x {
            x = y
            y = (x + value / x) / 2
        }
        return x
    }

    /// The arrangement `action` asks for from `arrangement` in `level`, checked against the ranges, the adjustable
    /// flags, the current value and the minimum separation (the run returns `arrangement`).
    ///
    /// - Throws: `.action("star out of range")` (outside 0 … 1), `.action("ring out of range")`,
    ///   `.action("phase out of range")` (outside 0 … 47), `.action("luminosity out of range")`,
    ///   `.action("tilt out of range")` (outside 0 … T_max), `.action("locked")` (the control is not adjustable; the tilt
    ///   when T_max = 0), `.action("unchanged")` or `.action("separation")` (the new arrangement breaks the minimum
    ///   separation at a tick of 0 … 47), checked in this order.
    static func changed(_ level: BinaryGardensLevel, _ arrangement: BinaryGardensArrangement,
                        by action: BinaryGardensAction) throws(BinaryGardensError) -> BinaryGardensArrangement {
        var rings: [Int] = arrangement.rings
        var phases: [Int] = arrangement.phases
        var luminosities: [Int] = arrangement.luminosities
        var tilt: Int = arrangement.tilt
        switch action {
        case .ring(let star, let index):
            guard (0..<2).contains(star) else { throw .action("star out of range") }
            guard level.ringRadii.indices.contains(index) else { throw .action("ring out of range") }
            guard level.stars[star].ringAdjustable else { throw .action("locked") }
            guard rings[star] != index else { throw .action("unchanged") }
            rings[star] = index
        case .phase(let star, let step):
            guard (0..<2).contains(star) else { throw .action("star out of range") }
            guard (0..<cycle).contains(step) else { throw .action("phase out of range") }
            guard level.stars[star].phaseAdjustable else { throw .action("locked") }
            guard phases[star] != step else { throw .action("unchanged") }
            phases[star] = step
        case .luminosity(let star, let index):
            guard (0..<2).contains(star) else { throw .action("star out of range") }
            guard level.luminosityLevels.indices.contains(index) else { throw .action("luminosity out of range") }
            guard level.stars[star].luminosityAdjustable else { throw .action("locked") }
            guard luminosities[star] != index else { throw .action("unchanged") }
            luminosities[star] = index
        case .tilt(let step):
            guard (0...level.maxTilt).contains(step) else { throw .action("tilt out of range") }
            guard level.maxTilt > 0 else { throw .action("locked") }
            guard tilt != step else { throw .action("unchanged") }
            tilt = step
        case .run:
            return arrangement
        }
        let next = BinaryGardensArrangement(rings: rings, phases: phases, luminosities: luminosities, tilt: tilt)
        guard keepsSeparation(level, arrangement: next) else { throw .action("separation") }
        return next
    }
}
