// VoxelOrigamiGenerator — feature 442 (R02-G15-02) T-R02G1502-004 (FR-R02G1502-001, 005; SC-R02G1502-001, 003, 004;
// clarification Q1). The constructive level generator of Voxel Origami. Candidate c of a manifest entry draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the cube count by band; the tree
// (each non-root cube's parent a drawn lower index and its rest direction one of the six units, the whole tree redrawn
// up to 50 times until the rest pose is collision-free, else no candidate); the solution's quarter turns (one per hinge,
// 0 … 3; a colliding solution pose gives no candidate); the orientations by the entry's emphasis; the target (the
// solution's cells under a drawn rotation of that group and a drawn shift of −3 … 3 per axis, sorted); then a scramble
// of the solution by band (clear random turns: a drawn hinge 1 … n − 1 and step ±1 the kernel accepts, at most eight
// draws per wanted turn) gives the start. Budget = the manifest's; ids `voxel-origami-NNN`; tutorial on levels 1 … 3;
// difficulty = band. `generate` keeps the first candidate whose start does not match and whose minimal plan lies in
// its band's range within the solver's work bound; at most 256 candidates, then `generation(n)`. The ranges were
// measured by a prototype of this generator on the real kernel before they were written down. Modelled on
// `MoonlitMechanismGenerator` (feature 432).
import VisualCoreSimulation

/// The values of one band (clarification Q1).
public struct VoxelOrigamiBandProfile: Sendable, Equatable {
    /// The cube counts.
    public let cubes: ClosedRange<Int>
    /// The scramble lengths (clear turns).
    public let scramble: ClosedRange<Int>
    /// The accepted minimal plan sizes (turns).
    public let planRange: ClosedRange<Int>

    /// The profile of `band` (1 … 5; others clamp).
    public static func of(band: Int) -> VoxelOrigamiBandProfile {
        switch band {
        case ...1: VoxelOrigamiBandProfile(cubes: 5...6, scramble: 2...4, planRange: 1...2)
        case 2: VoxelOrigamiBandProfile(cubes: 6...7, scramble: 4...6, planRange: 2...3)
        case 3: VoxelOrigamiBandProfile(cubes: 7...8, scramble: 6...9, planRange: 3...4)
        case 4: VoxelOrigamiBandProfile(cubes: 8...9, scramble: 8...12, planRange: 4...5)
        default: VoxelOrigamiBandProfile(cubes: 9...10, scramble: 10...14, planRange: 5...6)
        }
    }
}

/// A certified catalog level with its plan, difficulty and the candidates skipped before it.
public struct VoxelOrigamiGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: VoxelOrigamiManifestEntry
    /// The level.
    public let level: VoxelOrigamiLevel
    /// The minimal plan.
    public let plan: VoxelOrigamiPlan
    /// The difficulty metrics.
    public let difficulty: VoxelOrigamiDifficulty
    /// The index of the accepted candidate (the candidates skipped before it).
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: VoxelOrigamiManifestEntry, level: VoxelOrigamiLevel, plan: VoxelOrigamiPlan,
                difficulty: VoxelOrigamiDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The constructive generator of Voxel Origami (see the file header).
public enum VoxelOrigamiGenerator {
    /// The catalog id of the digest.
    public static let catalogID: String = "voxel-origami"
    /// The most candidates tried per entry.
    public static let maxCandidates: Int = 256
    /// The most tree draws per candidate.
    public static let maxTreeDraws: Int = 50
    /// The most draws per wanted scramble turn.
    public static let drawsPerScrambleTurn: Int = 8

    /// `voxel-origami-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "voxel-origami-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// Candidate `index` of `entry`, or nil when its draws do not give a valid level (a tree without a collision-free
    /// rest pose within the draw bound, a colliding solution, no clear scramble turn, a start that already matches).
    public static func candidate(_ entry: VoxelOrigamiManifestEntry, index: Int) -> VoxelOrigamiLevel? {
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let profile: VoxelOrigamiBandProfile = .of(band: entry.band)
        let count: Int = random.int(profile.cubes)
        var tree: [VoxelOrigamiCube]? = nil
        for _ in 0..<maxTreeDraws {
            var cubes: [VoxelOrigamiCube] = [.root]
            for cube in 1..<count {
                let parent: Int = random.int(0...(cube - 1))
                let direction: VoxelOrigamiVector = VoxelOrigamiVector.units[random.int(0...5)]
                cubes.append(VoxelOrigamiCube(parent: parent, direction: direction, startTurn: 0))
            }
            if VoxelOrigamiLattice.pose(cubes, turns: Array(repeating: 0, count: count)).isCollisionFree {
                tree = cubes
                break
            }
        }
        guard let rest = tree else { return nil }
        var solution: [Int] = [0]
        for _ in 1..<count { solution.append(random.int(0...3)) }
        let solved: VoxelOrigamiPose = VoxelOrigamiLattice.pose(rest, turns: solution)
        guard solved.isCollisionFree else { return nil }
        let orientations: VoxelOrigamiOrientations = entry.orientations
        let group: [VoxelOrigamiRotation] = orientations.group
        let rotation: VoxelOrigamiRotation = group[random.int(0...(group.count - 1))]
        let shift = VoxelOrigamiVector(random.int(-3...3), random.int(-3...3), random.int(-3...3))
        let target: [VoxelOrigamiVector] = solved.cells.map { rotation.applied(to: $0) + shift }.sorted()
        let wanted: Int = random.int(profile.scramble)
        var turns: [Int] = solution
        var done: Int = 0
        var draws: Int = 0
        while done < wanted, draws < wanted * drawsPerScrambleTurn {
            draws += 1
            let hinge: Int = random.int(1...(count - 1))
            let step: Int = random.int(0...1) == 0 ? -1 : 1
            let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(rest, turns: turns)
            guard !VoxelOrigamiLattice.swinging(rest, pose: pose, hinge: hinge).isEmpty,
                  VoxelOrigamiLattice.check(rest, turns: turns, hinge: hinge, step: step) == nil else { continue }
            turns = VoxelOrigamiLattice.turned(turns, hinge: hinge, step: step)
            done += 1
        }
        guard done > 0 else { return nil }
        var cubes: [VoxelOrigamiCube] = []
        for (position, cube) in rest.enumerated() {
            cubes.append(VoxelOrigamiCube(parent: cube.parent, direction: cube.direction,
                                          startTurn: position == 0 ? 0 : turns[position]))
        }
        return try? VoxelOrigamiLevel(id: levelID(entry.number), seed: entry.seed, difficulty: entry.band,
                                      cubes: cubes, target: target, orientations: orientations,
                                      budget: entry.budget, tutorial: entry.number <= 3)
    }

    /// The certified level of `entry`: the first candidate whose minimal plan lies in its band's range (and within the
    /// budget) within the solver's work bound.
    ///
    /// - Throws: `.generation(number)` when none of the first ``maxCandidates`` candidates qualifies.
    public static func generate(_ entry: VoxelOrigamiManifestEntry) throws(VoxelOrigamiError) -> VoxelOrigamiGenerated {
        let range: ClosedRange<Int> = VoxelOrigamiBandProfile.of(band: entry.band).planRange
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index) else { continue }
            guard let plan = VoxelOrigamiSolver.plan(level, maxTurns: range.upperBound),
                  range.contains(plan.size), plan.size <= entry.budget else { continue }
            return VoxelOrigamiGenerated(entry: entry, level: level, plan: plan,
                                         difficulty: VoxelOrigamiDifficulty(level: level, plan: plan),
                                         skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest of `levels` (their fingerprints, in order).
    public static func catalogDigest(_ levels: [VoxelOrigamiLevel]) -> String {
        PuzzleCatalog<VoxelOrigamiRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
