// LissajousLabyrinthGenerator — feature 312 (R02-G02-02) T-R02G0202-004 (FR-R02G0202-001, 005; clarification Q1;
// research R4). Builds each catalog level deterministically from its manifest entry: candidate k draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))` the amplitudes and frequency c, a target winning
// setting, checkpoints on the target's path at spread ticks, obstacles on other settings' paths that the target lap
// clears and a start that changes some dials of the target. A candidate is kept only when the level is valid, the solver
// proves it solvable and its shortest solution lies in the band's range and the move budget. Pure integers; no clock.
import VisualCoreSimulation

/// The generation parameters of one band (clarification Q1).
public struct LissajousLabyrinthBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The number of checkpoints.
    public let checkpoints: Int
    /// The checkpoints' radius.
    public let checkpointRadius: Int
    /// The number of obstacles.
    public let obstacles: Int
    /// The obstacles' radius range.
    public let obstacleRadius: ClosedRange<Int>
    /// The shortest solutions accepted.
    public let shortest: ClosedRange<Int>

    /// A profile of the given values (tests use it to ask for an impossible band).
    public init(band: Int, checkpoints: Int, checkpointRadius: Int, obstacles: Int, obstacleRadius: ClosedRange<Int>,
                shortest: ClosedRange<Int>) {
        self.band = band
        self.checkpoints = checkpoints
        self.checkpointRadius = checkpointRadius
        self.obstacles = obstacles
        self.obstacleRadius = obstacleRadius
        self.shortest = shortest
    }

    /// The profile of `band`; nil outside 1 … 5. Bands 1 … 5: 2, 3, 4, 5, 6 checkpoints of radius 512, 448, 384, 320,
    /// 256; 2, 3, 4, 6, 8 obstacles of radius 256 … 512; shortest 1–2, 2, 2–3, 3, 3–4 actions.
    public static func of(band: Int) -> LissajousLabyrinthBandProfile? {
        guard (1...5).contains(band) else { return nil }
        let i = band - 1
        let counts = [2, 3, 4, 5, 6]
        let radii = [512, 448, 384, 320, 256]
        let obstacles = [2, 3, 4, 6, 8]
        let shortest: [ClosedRange<Int>] = [1...2, 2...2, 2...3, 3...3, 3...4]
        return LissajousLabyrinthBandProfile(band: band, checkpoints: counts[i], checkpointRadius: radii[i],
                                             obstacles: obstacles[i], obstacleRadius: 256...512,
                                             shortest: shortest[i])
    }
}

/// The seeded level generator of Lissajous Labyrinth.
public enum LissajousLabyrinthGenerator {
    /// The most candidates tried per level.
    public static let maxCandidates = 64
    /// The catalog id used for the digest.
    public static let catalogID = "lissajous-labyrinth"
    /// The levels shown with a tutorial.
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The level of `entry`.
    ///
    /// - Throws: `.generation(entry.number)` when the band is outside 1 … 5 or no candidate is accepted within
    ///   ``maxCandidates``.
    public static func generate(_ entry: LissajousLabyrinthManifestEntry)
        throws(LissajousLabyrinthError) -> LissajousLabyrinthGenerated {
        guard let profile = LissajousLabyrinthBandProfile.of(band: entry.band) else { throw .generation(entry.number) }
        return try generate(entry, profile: profile)
    }

    /// The level of `entry` under `profile`.
    ///
    /// - Throws: `.generation(entry.number)` when no candidate is accepted within ``maxCandidates``.
    public static func generate(_ entry: LissajousLabyrinthManifestEntry, profile: LissajousLabyrinthBandProfile)
        throws(LissajousLabyrinthError) -> LissajousLabyrinthGenerated {
        for k in 0..<maxCandidates {
            guard let level = candidate(entry, profile: profile, index: k),
                  let solution = LissajousLabyrinthSolver.solve(level),
                  profile.shortest.contains(solution.shortest),
                  solution.shortest <= entry.budget else { continue }
            return LissajousLabyrinthGenerated(entry: entry, level: level, solution: solution,
                                               difficulty: LissajousLabyrinthDifficulty(level: level, solution: solution),
                                               skipped: k)
        }
        throw .generation(entry.number)
    }

    /// The 100 catalog levels in manifest order.
    ///
    /// - Throws: the first `.generation(number)`.
    public static func catalog() throws(LissajousLabyrinthError) -> [LissajousLabyrinthGenerated] {
        var result: [LissajousLabyrinthGenerated] = []
        result.reserveCapacity(LissajousLabyrinthManifest.entries.count)
        for entry in LissajousLabyrinthManifest.entries {
            result.append(try generate(entry))
        }
        return result
    }

    /// The catalog digest: `PuzzleCatalog<LissajousLabyrinthRules>.digest(id: "lissajous-labyrinth", identities:)`
    /// over the level fingerprints in order.
    public static func catalogDigest(_ levels: [LissajousLabyrinthGenerated]) -> String {
        PuzzleCatalog<LissajousLabyrinthRules>.digest(id: catalogID, identities: levels.map(\.level.fingerprint))
    }

    /// The level id of manifest number `number`: `lissajous-labyrinth-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits = String(number)
        return "lissajous-labyrinth-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// A random valid setting (coprime frequencies).
    static func randomSetting(_ random: inout SeededRandom) -> LissajousLabyrinthDials {
        while true {
            let dials = LissajousLabyrinthDials(frequencyA: random.int(1...9), frequencyB: random.int(1...9),
                                                phaseA: random.int(0...15), phaseC: random.int(0...15))
            if dials.isValid { return dials }
        }
    }

    /// Whether any segment of the lap `points` (closing segment included) touches `ball`.
    static func lapTouches(_ points: [LissajousLabyrinthPoint], ball: LissajousLabyrinthBall) -> Bool {
        let count = points.count
        for n in 0..<count where LissajousLabyrinthLap.segmentTouches(points[n], points[n + 1 == count ? 0 : n + 1],
                                                                      ball: ball) {
            return true
        }
        return false
    }

    /// Candidate `index` of `entry` under `profile` (clarification Q1); nil when the kernel refuses it.
    static func candidate(_ entry: LissajousLabyrinthManifestEntry, profile: LissajousLabyrinthBandProfile,
                          index: Int) -> LissajousLabyrinthLevel? {
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let amplitudes = [random.int(2...4), random.int(2...4), random.int(2...4)]
        let frequencyC = random.int(1...9)
        let target = randomSetting(&random)
        // A placeholder level reads the target's samples through the kernel's own formula.
        guard let probe = try? LissajousLabyrinthLevel(
            id: levelID(entry.number), seed: entry.seed, band: entry.band, amplitudes: amplitudes,
            frequencyC: frequencyC, start: target,
            checkpoints: [LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 64)], obstacles: [],
            allowance: entry.budget) else { return nil }
        let points = LissajousLabyrinthLap.samples(target, level: probe)
        // Checkpoints: one per equal share of the lap, at a tick in the middle half of its share.
        let share = LissajousLabyrinthLap.ticks / profile.checkpoints
        var checkpoints: [LissajousLabyrinthBall] = []
        for i in 0..<profile.checkpoints {
            let tick = i * share + share / 4 + random.int(0...(share / 2 - 1))
            let p = points[tick]
            guard let ball = try? LissajousLabyrinthBall(x: p.x, y: p.y, z: p.z,
                                                         radius: profile.checkpointRadius) else { return nil }
            checkpoints.append(ball)
        }
        // Obstacles: on other settings' paths, kept only when the target lap clears them.
        var obstacles: [LissajousLabyrinthBall] = []
        var attempts = 0
        while obstacles.count < profile.obstacles && attempts < profile.obstacles * 8 {
            attempts += 1
            let other = randomSetting(&random)
            let tick = random.int(0...(LissajousLabyrinthLap.ticks - 1))
            let p = LissajousLabyrinthLap.position(tick: tick, dials: other, level: probe)
            guard let ball = try? LissajousLabyrinthBall(x: p.x, y: p.y, z: p.z,
                                                         radius: random.int(profile.obstacleRadius)),
                  !lapTouches(points, ball: ball) else { continue }
            obstacles.append(ball)
        }
        guard obstacles.count == profile.obstacles else { return nil }
        // Start: the target with `profile.shortest.upperBound` distinct dials changed, kept legal.
        var start = target
        var dials = LissajousLabyrinthDial.allCases
        for _ in 0..<min(profile.shortest.upperBound, dials.count) {
            let dial = dials.remove(at: random.int(0...(dials.count - 1)))
            let range = dial.range
            for _ in 0..<16 {
                var trial = start
                var value = random.int(range.lowerBound...(range.upperBound - 1))
                if value >= start[dial] { value += 1 }
                trial[dial] = value
                if trial.isValid {
                    start = trial
                    break
                }
            }
        }
        return try? LissajousLabyrinthLevel(id: levelID(entry.number), seed: entry.seed, band: entry.band,
                                            amplitudes: amplitudes, frequencyC: frequencyC, start: start,
                                            checkpoints: checkpoints, obstacles: obstacles,
                                            allowance: entry.budget,
                                            tutorial: tutorialLevels.contains(entry.number))
    }
}
