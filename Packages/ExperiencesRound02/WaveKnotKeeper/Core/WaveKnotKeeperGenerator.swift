// WaveKnotKeeperGenerator — feature 322 (R02-G03-02) T-R02G0302-004 (FR-R02G0302-001, 003, 005; clarification Q1;
// research R1, R3). Builds each catalog level deterministically from its manifest entry: candidate k draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))` a solved rope (5 + band points at seeded angles of a
// fixed 32-direction integer table, angles sorted then `band` seeded neighbour swaps, radius 5 … 12, height −4 … 4),
// kept only when simple, in bounds and with a non-degenerate projection; its summary is the target. Gates (cubes of side
// 3 on seeded rope points), then a scramble walk of legal moves away from the solved rope (each step the first move, in
// seeded order, whose rope's summary differs from the solved rope's, else the first legal move; never back onto an
// earlier rope). The tension bound covers the walk plus 64 × (6 − band). A candidate is kept only when the level is
// valid, the solver proves its shortest solution within the band's range and the budget, and both counterexamples of the
// witness exist. Pure integers; no clock.
import VisualCoreSimulation

/// The generation parameters of one band (clarification Q1).
public struct WaveKnotKeeperBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The rope's control-point count.
    public let points: Int
    /// The number of crossing gates (cubes of side 3).
    public let gates: Int
    /// The length of the scramble walk from the solved rope.
    public let scramble: Int
    /// The shortest solutions accepted.
    public let shortest: ClosedRange<Int>

    /// A profile of the given values (tests use it to ask for an impossible band).
    public init(band: Int, points: Int, gates: Int, scramble: Int, shortest: ClosedRange<Int>) {
        self.band = band
        self.points = points
        self.gates = gates
        self.scramble = scramble
        self.shortest = shortest
    }

    /// The profile of `band`; nil outside 1 … 5. Bands 1 … 5: 6, 7, 8, 9, 10 points; 0, 0, 1, 1, 2 gates; scramble 1, 2,
    /// 2, 3, 4; shortest 1, 1–2, 1–2, 2, 2–3 moves.
    public static func of(band: Int) -> WaveKnotKeeperBandProfile? {
        guard (1...5).contains(band) else { return nil }
        let i = band - 1
        let gates = [0, 0, 1, 1, 2]
        let scramble = [1, 2, 2, 3, 4]
        let shortest: [ClosedRange<Int>] = [1...1, 1...2, 1...2, 2...2, 2...3]
        return WaveKnotKeeperBandProfile(band: band, points: 5 + band, gates: gates[i], scramble: scramble[i],
                                         shortest: shortest[i])
    }
}

/// A generated catalog level with its proof.
public struct WaveKnotKeeperGenerated: Sendable, Equatable {
    /// The manifest entry it was built from.
    public let entry: WaveKnotKeeperManifestEntry
    /// The level.
    public let level: WaveKnotKeeperLevel
    /// The solver's shortest solution.
    public let solution: WaveKnotKeeperSolution
    /// The difficulty metrics.
    public let difficulty: WaveKnotKeeperDifficulty
    /// The candidates skipped before this one (0 … 63).
    public let skipped: Int

    /// A generated level of the given values (not checked).
    public init(entry: WaveKnotKeeperManifestEntry, level: WaveKnotKeeperLevel, solution: WaveKnotKeeperSolution,
                difficulty: WaveKnotKeeperDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The seeded level generator of Wave Knot Keeper.
public enum WaveKnotKeeperGenerator {
    /// The most candidates tried per level.
    public static let maxCandidates = 64
    /// The catalog id used for the digest.
    public static let catalogID = "wave-knot-keeper"
    /// The levels shown with a tutorial.
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The 32 directions of the solved rope's angles, as integer cosine and sine × 1,000.
    static let directions: [(Int, Int)] = [
        (1000, 0), (981, 195), (924, 383), (831, 556), (707, 707), (556, 831), (383, 924), (195, 981), (0, 1000),
        (-195, 981), (-383, 924), (-556, 831), (-707, 707), (-831, 556), (-924, 383), (-981, 195), (-1000, 0),
        (-981, -195), (-924, -383), (-831, -556), (-707, -707), (-556, -831), (-383, -924), (-195, -981), (0, -1000),
        (195, -981), (383, -924), (556, -831), (707, -707), (831, -556), (924, -383), (981, -195),
    ]

    /// The level of `entry`.
    ///
    /// - Throws: `.generation(entry.number)` when the band is outside 1 … 5 or no candidate is accepted within
    ///   ``maxCandidates``.
    public static func generate(_ entry: WaveKnotKeeperManifestEntry) throws(WaveKnotKeeperError) -> WaveKnotKeeperGenerated {
        guard let profile = WaveKnotKeeperBandProfile.of(band: entry.band) else { throw .generation(entry.number) }
        return try generate(entry, profile: profile)
    }

    /// The level of `entry` under `profile`.
    ///
    /// - Throws: `.generation(entry.number)` when no candidate is accepted within ``maxCandidates``.
    public static func generate(_ entry: WaveKnotKeeperManifestEntry,
                                profile: WaveKnotKeeperBandProfile) throws(WaveKnotKeeperError) -> WaveKnotKeeperGenerated {
        for k in 0..<maxCandidates {
            guard let level = candidate(entry, profile: profile, index: k),
                  let solution = WaveKnotKeeperSolver.solve(level, depth: min(profile.shortest.upperBound,
                                                                               WaveKnotKeeperSolver.maximumDepth)),
                  profile.shortest.contains(solution.shortest),
                  solution.shortest <= entry.budget,
                  solution.crossing != nil,
                  nearMiss(level, solution: solution) != nil else { continue }
            return WaveKnotKeeperGenerated(entry: entry, level: level, solution: solution,
                                           difficulty: WaveKnotKeeperDifficulty(level: level, solution: solution),
                                           skipped: k)
        }
        throw .generation(entry.number)
    }

    /// The 100 catalog levels in manifest order.
    ///
    /// - Throws: the first `.generation(number)`.
    public static func catalog() throws(WaveKnotKeeperError) -> [WaveKnotKeeperGenerated] {
        var result: [WaveKnotKeeperGenerated] = []
        result.reserveCapacity(WaveKnotKeeperManifest.entries.count)
        for entry in WaveKnotKeeperManifest.entries {
            result.append(try generate(entry))
        }
        return result
    }

    /// The catalog digest: `PuzzleCatalog<WaveKnotKeeperRules>.digest(id: "wave-knot-keeper", identities:)` over the
    /// level fingerprints in order.
    public static func catalogDigest(_ levels: [WaveKnotKeeperGenerated]) -> String {
        PuzzleCatalog<WaveKnotKeeperRules>.digest(id: catalogID, identities: levels.map(\.level.fingerprint))
    }

    /// The level id of manifest number `number`: `wave-knot-keeper-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits = String(number)
        return "wave-knot-keeper-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The near miss of a solved level: the first legal move, in the rules' order, from the solution's winning rope
    /// whose rope does not win, with that rope; nil when every legal move still wins (clarification Q4).
    public static func nearMiss(_ level: WaveKnotKeeperLevel,
                                solution: WaveKnotKeeperSolution) -> (move: WaveKnotKeeperMove,
                                                                      points: [WaveKnotKeeperPoint])? {
        let rules = WaveKnotKeeperRules(level: level)
        for move in rules.moves(in: solution.final) {
            guard let next = rules.apply(move, to: solution.final) else { continue }
            if !level.wins(next) { return (move, next) }
        }
        return nil
    }

    /// The solved rope of candidate randomness `random` with `count` points and `swaps` neighbour swaps; nil when it is
    /// not simple, leaves the bounds, repeats a point or projects degenerately.
    static func solvedRope(_ random: inout SeededRandom, count: Int, swaps: Int) -> [WaveKnotKeeperPoint]? {
        var angles: [Int] = Array(0..<directions.count)
        random.shuffle(&angles)
        var chosen = Array(angles.prefix(count)).sorted()
        for _ in 0..<swaps {
            let i = random.int(0...(count - 1))
            chosen.swapAt(i, (i + 1) % count)
        }
        var points: [WaveKnotKeeperPoint] = []
        for angle in chosen {
            let radius = random.int(5...12)
            let (c, s) = directions[angle]
            points.append(WaveKnotKeeperPoint(x: (radius * c) / 1000, y: (radius * s) / 1000, z: random.int(-4...4)))
        }
        guard Set(points).count == points.count, points.allSatisfy(\.isInBounds),
              WaveKnotKeeperGeometry.isSimple(points),
              !WaveKnotKeeperGeometry.summary(points).degenerate else { return nil }
        return points
    }

    /// Candidate `index` of `entry` under `profile` (clarification Q1); nil when the kernel refuses it.
    static func candidate(_ entry: WaveKnotKeeperManifestEntry, profile: WaveKnotKeeperBandProfile,
                          index: Int) -> WaveKnotKeeperLevel? {
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        guard let solved = solvedRope(&random, count: profile.points, swaps: profile.band) else { return nil }
        let summary = WaveKnotKeeperGeometry.summary(solved)
        guard let target = try? WaveKnotKeeperTarget(crossings: summary.crossings, writhe: summary.writhe) else {
            return nil
        }
        var gates: [WaveKnotKeeperGate] = []
        for _ in 0..<profile.gates {
            let centre = solved[random.int(0...(solved.count - 1))]
            guard let gate = try? WaveKnotKeeperGate(
                min: WaveKnotKeeperPoint(x: centre.x - 1, y: centre.y - 1, z: centre.z - 1),
                max: WaveKnotKeeperPoint(x: centre.x + 1, y: centre.y + 1, z: centre.z + 1)) else { return nil }
            gates.append(gate)
        }
        // The walk runs on a level with the widest tension bound and a target the solved rope does not have (the kernel
        // refuses a start that already wins); the level's own bound then covers every rope on the walk.
        let other = summary.crossings == 0 ? (2, 0) : (0, 0)
        guard let walkTarget = try? WaveKnotKeeperTarget(crossings: other.0, writhe: other.1),
              let open = try? WaveKnotKeeperLevel(id: levelID(entry.number), seed: entry.seed, band: entry.band,
                                                  points: solved, gates: gates, target: walkTarget,
                                                  tensionBound: WaveKnotKeeperLevel.tensionBounds.upperBound,
                                                  allowance: entry.budget) else { return nil }
        let rules = WaveKnotKeeperRules(level: open)
        var rope = solved
        var visited: Set<[WaveKnotKeeperPoint]> = [solved]
        var tension = WaveKnotKeeperGeometry.tension(solved)
        for _ in 0..<profile.scramble {
            var moves = rules.moves(in: rope)
            random.shuffle(&moves)
            var chosen: [WaveKnotKeeperPoint]?
            var fallback: [WaveKnotKeeperPoint]?
            for move in moves {
                guard let next = rules.apply(move, to: rope), !visited.contains(next) else { continue }
                if fallback == nil { fallback = next }
                let nextSummary = WaveKnotKeeperGeometry.summary(next)
                if nextSummary.crossings != summary.crossings || nextSummary.writhe != summary.writhe
                    || nextSummary.degenerate {
                    chosen = next
                    break
                }
            }
            guard let step = chosen ?? fallback else { return nil }
            rope = step
            visited.insert(step)
            tension = max(tension, WaveKnotKeeperGeometry.tension(step))
        }
        let bound = min(WaveKnotKeeperLevel.tensionBounds.upperBound, tension + 64 * (6 - entry.band))
        return try? WaveKnotKeeperLevel(id: levelID(entry.number), seed: entry.seed, band: entry.band, points: rope,
                                        gates: gates, target: target, tensionBound: bound, allowance: entry.budget,
                                        tutorial: tutorialLevels.contains(entry.number))
    }
}
