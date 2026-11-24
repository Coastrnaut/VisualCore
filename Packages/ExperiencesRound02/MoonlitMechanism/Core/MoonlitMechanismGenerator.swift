// MoonlitMechanismGenerator — feature 432 (R02-G14-02) T-R02G1402-004 (FR-R02G1402-001, 005; SC-R02G1402-001, 003,
// 004; clarification Q1; research R4). The constructive level generator of Moonlit Mechanism. Candidate c of a manifest
// entry draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order:
//   1. the wall: W 12 … 16, H 9 … 12;
//   2. the gear count and the lamp heights by band (see `MoonlitMechanismBandProfile`);
//   3. for each gear: its parent (a drawn lower index; none for the driver) and its tooth count from (6, 8, 9, 10, 12,
//      14, 15, 16, 18, 20), redrawn until its divisor with the parent is at least 2;
//   4. the solution set-up: a phase per gear, then a lamp height;
//   5. for each gear: a blade pattern (each bit solid with chance 1 in 3, bit 0 solid, the last bit open), a depth
//      1 … 3, a centre (column 3 … W − 4, row 2 … H − 5) and a slot table (slot k points the compass direction
//      ⌊8k / T⌋, a ray of 2 … 3 cells starting one cell out); the alignment values are the solution's sums;
//   6. the key frames by band: first turns 0 … 2, then gaps 1 … 4; each target is the solution's cast at that key frame
//      (an empty cast discards the candidate); key frame 0 is required and each later one is required with chance 3
//      in 4;
//   7. 2 … 6 forbidden cells drawn from the cells no solution key frame covers; the allowance is 0;
//   8. a scramble of the solution by band: random turns, re-seats (never the driver) and lamp steps the play accepts
//      (a drawn step that would leave the lamp range is drawn again, at most 50 draws), which gives the start.
// Budget = the manifest's; ids `moonlit-mechanism-NNN`; a tutorial on levels 1 … 3; difficulty = band. A candidate whose
// start already wins, or that the solver does not certify with a minimal plan in its band's range within its work
// bound, is skipped; after 256 candidates the entry is refused (`generation(n)`). The catalog digest is
// `PuzzleCatalog<MoonlitMechanismRules>.digest(id: "moonlit-mechanism", identities:)` over the levels' fingerprints in
// manifest order. Nothing here reads a clock.
import Foundation
import VisualCoreSimulation

/// A band's generation profile: the gear counts, the lamp heights, the key frames, the scramble lengths and the range
/// of minimal plans a certified level of the band needs.
public struct MoonlitMechanismBandProfile: Sendable, Equatable {
    /// The gear counts.
    public let gears: ClosedRange<Int>
    /// The lamp heights.
    public let lampHeights: ClosedRange<Int>
    /// The key-frame counts.
    public let keyFrames: ClosedRange<Int>
    /// The scramble lengths.
    public let scramble: ClosedRange<Int>
    /// The minimal plan sizes (actions before the run) a certified level of the band has.
    public let planRange: ClosedRange<Int>

    /// A profile of the given values.
    public init(gears: ClosedRange<Int>, lampHeights: ClosedRange<Int>, keyFrames: ClosedRange<Int>,
                scramble: ClosedRange<Int>, planRange: ClosedRange<Int>) {
        self.gears = gears
        self.lampHeights = lampHeights
        self.keyFrames = keyFrames
        self.scramble = scramble
        self.planRange = planRange
    }

    /// The profile of `band` (1 … 5; others clamp to the nearest band).
    public static func of(band: Int) -> MoonlitMechanismBandProfile {
        switch min(max(band, 1), 5) {
        case 1: MoonlitMechanismBandProfile(gears: 2...3, lampHeights: 2...3, keyFrames: 2...2, scramble: 2...3,
                                            planRange: 1...2)
        case 2: MoonlitMechanismBandProfile(gears: 3...3, lampHeights: 3...3, keyFrames: 2...3, scramble: 3...4,
                                            planRange: 2...3)
        case 3: MoonlitMechanismBandProfile(gears: 3...4, lampHeights: 3...4, keyFrames: 3...3, scramble: 4...6,
                                            planRange: 3...4)
        case 4: MoonlitMechanismBandProfile(gears: 4...4, lampHeights: 4...4, keyFrames: 3...4, scramble: 5...7,
                                            planRange: 4...5)
        default: MoonlitMechanismBandProfile(gears: 4...5, lampHeights: 4...5, keyFrames: 4...5, scramble: 7...9,
                                             planRange: 5...6)
        }
    }
}

/// A certified catalog level: its manifest entry, the level, its minimal plan, its difficulty and the index of the
/// accepted candidate (the candidates skipped before it).
public struct MoonlitMechanismGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: MoonlitMechanismManifestEntry
    /// The level.
    public let level: MoonlitMechanismLevel
    /// The minimal plan.
    public let plan: MoonlitMechanismPlan
    /// The difficulty metrics.
    public let difficulty: MoonlitMechanismDifficulty
    /// The candidates skipped before the accepted one (its index).
    public let skipped: Int

    /// A certified level of the given values.
    public init(entry: MoonlitMechanismManifestEntry, level: MoonlitMechanismLevel, plan: MoonlitMechanismPlan,
                difficulty: MoonlitMechanismDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The witness actions of the plan (turns, re-seats, lamp steps, then the run).
    public var actions: [MoonlitMechanismAction] { MoonlitMechanismSolver.actions(plan) }
}

/// The constructive generator of Moonlit Mechanism's catalog levels (see the file header).
public enum MoonlitMechanismGenerator {
    /// The catalog id of the digest.
    public static let catalogID: String = "moonlit-mechanism"
    /// The candidates tried per manifest entry before it is refused.
    public static let maxCandidates: Int = 256
    /// The tooth counts a gear is drawn from.
    public static let toothChoices: [Int] = [6, 8, 9, 10, 12, 14, 15, 16, 18, 20]
    /// The eight compass directions (column, row), rows downward, starting east and turning clockwise.
    public static let compass: [MoonlitMechanismCell] = [
        MoonlitMechanismCell(column: 1, row: 0), MoonlitMechanismCell(column: 1, row: 1),
        MoonlitMechanismCell(column: 0, row: 1), MoonlitMechanismCell(column: -1, row: 1),
        MoonlitMechanismCell(column: -1, row: 0), MoonlitMechanismCell(column: -1, row: -1),
        MoonlitMechanismCell(column: 0, row: -1), MoonlitMechanismCell(column: 1, row: -1),
    ]

    /// The level id of manifest number `number`: `moonlit-mechanism-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "moonlit-mechanism-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// Candidate `index` of `entry` (see the file header), or nil when the draw discards it (an empty key-frame cast,
    /// a scramble that found no accepted action, or a value the level refuses).
    public static func candidate(_ entry: MoonlitMechanismManifestEntry, index: Int) -> MoonlitMechanismLevel? {
        let profile: MoonlitMechanismBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let width: Int = Int.random(in: 12...16, using: &random)
        let rows: Int = Int.random(in: 9...12, using: &random)
        let count: Int = Int.random(in: profile.gears, using: &random)
        let lampHeights: Int = Int.random(in: profile.lampHeights, using: &random)
        var teeth: [Int] = []
        var parents: [Int?] = []
        for gear in 0..<count {
            let parent: Int? = gear == 0 ? nil : Int.random(in: 0..<gear, using: &random)
            parents.append(parent)
            var tooth: Int = toothChoices[Int.random(in: 0..<toothChoices.count, using: &random)]
            if let parent {
                while MoonlitMechanismTrain.gcd(tooth, teeth[parent]) < 2 {
                    tooth = toothChoices[Int.random(in: 0..<toothChoices.count, using: &random)]
                }
            }
            teeth.append(tooth)
        }
        var solution: [Int] = []
        for tooth in teeth { solution.append(Int.random(in: 0..<tooth, using: &random)) }
        let solutionHeight: Int = Int.random(in: 0..<lampHeights, using: &random)
        var gears: [MoonlitMechanismGear] = []
        for gear in 0..<count {
            let tooth: Int = teeth[gear]
            var blades: [Bool] = []
            for _ in 0..<tooth { blades.append(Int.random(in: 0..<3, using: &random) == 0) }
            blades[0] = true
            blades[tooth - 1] = false
            let depth: Int = Int.random(in: 1...3, using: &random)
            let centre = MoonlitMechanismCell(column: Int.random(in: 3...(width - 4), using: &random),
                                              row: Int.random(in: 2...(rows - 5), using: &random))
            var slots: [[MoonlitMechanismCell]] = []
            for slot in 0..<tooth {
                let direction: MoonlitMechanismCell = compass[(8 * slot) / tooth]
                let length: Int = Int.random(in: 2...3, using: &random)
                var ray: [MoonlitMechanismCell] = []
                for step in 1...length {
                    ray.append(MoonlitMechanismCell(column: direction.column * step, row: direction.row * step))
                }
                slots.append(ray)
            }
            var alignment: Int = 0
            if let parent = parents[gear] {
                alignment = MoonlitMechanismTrain.mod(solution[parent] + solution[gear],
                                                      MoonlitMechanismTrain.gcd(teeth[parent], tooth))
            }
            gears.append(MoonlitMechanismGear(teeth: tooth, phase: solution[gear], blades: blades, depth: depth,
                                              centre: centre, parent: parents[gear], alignment: alignment,
                                              slots: slots))
        }
        let frameCount: Int = Int.random(in: profile.keyFrames, using: &random)
        var frames: [MoonlitMechanismKeyFrame] = []
        var turns: Int = Int.random(in: 0...2, using: &random)
        var covered: Set<Int> = []
        for frame in 0..<frameCount {
            let at: [Int] = MoonlitMechanismTrain.turned(gears, phases: solution, by: turns)
            let cells: [Int] = MoonlitMechanismTrain.cast(gears, phases: at, height: solutionHeight, width: width,
                                                          rows: rows)
            guard !cells.isEmpty else { return nil }
            covered.formUnion(cells)
            let required: Bool = frame == 0 || Int.random(in: 0..<4, using: &random) != 0
            frames.append(MoonlitMechanismKeyFrame(turns: turns, target: cells, required: required))
            turns += Int.random(in: 1...4, using: &random)
        }
        var free: [Int] = []
        for cell in 0..<(width * rows) where !covered.contains(cell) { free.append(cell) }
        var forbidden: [Int] = []
        let forbiddenCount: Int = min(free.count, Int.random(in: 2...6, using: &random))
        for _ in 0..<forbiddenCount {
            forbidden.append(free.remove(at: Int.random(in: 0..<free.count, using: &random)))
        }
        forbidden.sort()
        var phases: [Int] = solution
        var height: Int = solutionHeight
        let scramble: Int = Int.random(in: profile.scramble, using: &random)
        var done: Int = 0
        var draws: Int = 0
        while done < scramble, draws < 50 {
            draws += 1
            let kind: Int = Int.random(in: 0..<3, using: &random)
            let step: Int = Bool.random(using: &random) ? 1 : -1
            switch kind {
            case 0:
                phases = MoonlitMechanismTrain.turned(gears, phases: phases, by: step)
            case 1:
                let gear: Int = Int.random(in: 1..<count, using: &random)
                phases[gear] = MoonlitMechanismTrain.mod(phases[gear] + step, teeth[gear])
            default:
                guard height + step >= 0, height + step < lampHeights else { continue }
                height += step
            }
            done += 1
        }
        guard done > 0 else { return nil }
        var start: [MoonlitMechanismGear] = []
        for (gear, value) in gears.enumerated() {
            start.append(MoonlitMechanismGear(teeth: value.teeth, phase: phases[gear], blades: value.blades,
                                              depth: value.depth, centre: value.centre, parent: value.parent,
                                              alignment: value.alignment, slots: value.slots))
        }
        return try? MoonlitMechanismLevel(id: levelID(entry.number), seed: entry.seed, difficulty: entry.band,
                                          gears: start, width: width, rows: rows, lampHeights: lampHeights,
                                          startingHeight: height, keyFrames: frames, forbidden: forbidden,
                                          allowance: 0, budget: entry.budget, tutorial: entry.number <= 3)
    }

    /// The certified level of `entry`: the first candidate whose start does not win and whose minimal plan lies in its
    /// band's range (and below the budget) within the solver's work bound.
    ///
    /// - Throws: `.generation(number)` when none of the first ``maxCandidates`` candidates qualifies.
    public static func generate(_ entry: MoonlitMechanismManifestEntry) throws(MoonlitMechanismError)
        -> MoonlitMechanismGenerated {
        let range: ClosedRange<Int> = MoonlitMechanismBandProfile.of(band: entry.band).planRange
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index) else { continue }
            guard level.run(phases: level.startingPhases, height: level.startingHeight).outcome != .won else {
                continue
            }
            guard let plan = MoonlitMechanismSolver.plan(level, maxActions: range.upperBound),
                  range.contains(plan.size), plan.size <= entry.budget - 1 else { continue }
            return MoonlitMechanismGenerated(entry: entry, level: level, plan: plan,
                                             difficulty: MoonlitMechanismDifficulty(level: level, plan: plan),
                                             skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest of `levels` (their fingerprints, in order).
    public static func catalogDigest(_ levels: [MoonlitMechanismLevel]) -> String {
        PuzzleCatalog<MoonlitMechanismRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
