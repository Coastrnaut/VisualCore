// VoxelOrigamiGeneratorTests — feature 442 (R02-G15-02) T-R02G1502-004 (FR-R02G1502-001, 003, 005; SC-R02G1502-001,
// 003, 004; clarifications Q1, Q3). Host checks of the constructive level generator: the manifest (100 entries in
// order, 20 per band, budgets within the band's archived values, 20 per control emphasis, distinct seeds); the
// orientations by emphasis; the five band profiles of clarification Q1 and the clamp of out-of-range bands; the level
// ids and the bounds; candidate and generation determinism; the drawing order of clarification Q1 re-implemented
// independently here (cube count, tree with up to 50 redraws, solution turns, orientations, target rotation and shift,
// scramble with at most eight draws per wanted turn) and compared with `candidate` on 60 (entry, index) pairs spread over
// the five bands; every candidate's ids, tutorial flag, difficulty and budget; the filters of `generate` on sampled
// entries of every band (a minimal plan in the band's range and within the budget, `skipped` equal to the first
// qualifying candidate found by walking the candidates here, fewer than 256 skipped, a witness that wins through the
// play, difficulty metrics equal to a recount); the refusal `.generation(number)` on entries no candidate can satisfy;
// and the catalog digest's determinism and order sensitivity. Generating all 100 entries takes about 16 s in a debug
// build, so no test generates the whole catalog: the generated levels are sampled, four per band. Explicit types, plain
// loops, short runs.
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

@Suite("VoxelOrigamiGenerator")
struct VoxelOrigamiGeneratorTests {
    /// The manifest numbers sampled for the independent re-draw: four per band.
    static let redrawNumbers: [Int] = [1, 7, 14, 20, 21, 29, 35, 40, 41, 48, 55, 60, 61, 67, 74, 80, 81, 89, 95, 100]

    /// The candidate indices re-drawn per sampled entry (20 × 3 = 60 pairs).
    static let redrawIndices: [Int] = [0, 5, 17]

    /// The manifest numbers whose levels are generated and checked, four per band (index band − 1).
    static let generatedNumbers: [[Int]] = [[1, 2, 5, 12], [22, 25, 31, 38], [42, 45, 53, 59], [62, 65, 70, 77],
                                            [82, 85, 90, 97]]

    /// The archived moves budgets by band (index band − 1).
    static let budgetRanges: [ClosedRange<Int>] = [8...11, 10...13, 12...15, 14...17, 16...19]

    /// The five control emphases of the archived table.
    static let emphases: [String] = ["inspect collision", "lock shape", "fold hinge", "select voxel", "rotate assembly"]

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> VoxelOrigamiManifestEntry {
        VoxelOrigamiManifest.entries[number - 1]
    }

    /// The values of a candidate re-drawn independently of the generator.
    struct Drawn: Equatable {
        let cubes: [VoxelOrigamiCube]
        let target: [VoxelOrigamiVector]
        let orientations: VoxelOrigamiOrientations
    }

    /// Candidate `index` of `entry` drawn independently in the order of clarification Q1; nil where the draws discard
    /// it (no collision-free rest within 50 tree draws, a colliding solution, no clear scramble turn, or a start that
    /// already matches the target).
    static func redraw(_ entry: VoxelOrigamiManifestEntry, index: Int) -> Drawn? {
        let cubeRanges: [ClosedRange<Int>] = [5...6, 6...7, 7...8, 8...9, 9...10]
        let scrambleRanges: [ClosedRange<Int>] = [2...4, 4...6, 6...9, 8...12, 10...14]
        let band: Int = min(5, max(1, entry.band))
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        // 1. The cube count.
        let count: Int = random.int(cubeRanges[band - 1])
        // 2. The tree, redrawn up to 50 times until the rest pose is collision-free.
        var rest: [VoxelOrigamiCube] = []
        var found: Bool = false
        var attempt: Int = 0
        while attempt < 50, !found {
            attempt += 1
            var cubes: [VoxelOrigamiCube] = [VoxelOrigamiCube(parent: nil, direction: VoxelOrigamiVector(0, 0, 0))]
            var cube: Int = 1
            while cube < count {
                let parent: Int = random.int(0...(cube - 1))
                let unit: Int = random.int(0...5)
                cubes.append(VoxelOrigamiCube(parent: parent, direction: VoxelOrigamiVector.units[unit], startTurn: 0))
                cube += 1
            }
            var zeros: [Int] = []
            for _ in 0..<count { zeros.append(0) }
            let cells: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(cubes, turns: zeros).cells
            if Set(cells).count == count {
                rest = cubes
                found = true
            }
        }
        if !found { return nil }
        // 3. The solution's quarter turns, one per hinge.
        var solution: [Int] = [0]
        var hinge: Int = 1
        while hinge < count {
            solution.append(random.int(0...3))
            hinge += 1
        }
        let solved: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(rest, turns: solution).cells
        if Set(solved).count != count { return nil }
        // 4. The orientations by emphasis.
        var orientations: VoxelOrigamiOrientations = .upright
        if entry.emphasis == "rotate assembly" { orientations = .any }
        if entry.emphasis == "lock shape" { orientations = .fixed }
        // 5. The target: a drawn rotation of the group and a drawn shift of −3 … 3 per axis, sorted.
        let group: [VoxelOrigamiRotation] = orientations.group
        let rotation: VoxelOrigamiRotation = group[random.int(0...(group.count - 1))]
        let dx: Int = random.int(-3...3)
        let dy: Int = random.int(-3...3)
        let dz: Int = random.int(-3...3)
        var target: [VoxelOrigamiVector] = []
        for cell in solved {
            let turned: VoxelOrigamiVector = rotation.applied(to: cell)
            target.append(VoxelOrigamiVector(turned.x + dx, turned.y + dy, turned.z + dz))
        }
        target.sort()
        // 6. The scramble: clear random turns, at most eight draws per wanted turn.
        let wanted: Int = random.int(scrambleRanges[band - 1])
        var turns: [Int] = solution
        var done: Int = 0
        var draws: Int = 0
        while done < wanted, draws < wanted * 8 {
            draws += 1
            let drawnHinge: Int = random.int(1...(count - 1))
            let step: Int = random.int(0...1) == 0 ? -1 : 1
            let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(rest, turns: turns)
            if VoxelOrigamiLattice.swinging(rest, pose: pose, hinge: drawnHinge).isEmpty { continue }
            if VoxelOrigamiLattice.check(rest, turns: turns, hinge: drawnHinge, step: step) != nil { continue }
            turns[drawnHinge] = (turns[drawnHinge] + step + 4) % 4
            done += 1
        }
        if done == 0 { return nil }
        var cubes: [VoxelOrigamiCube] = []
        var position: Int = 0
        while position < count {
            let cube: VoxelOrigamiCube = rest[position]
            cubes.append(VoxelOrigamiCube(parent: cube.parent, direction: cube.direction,
                                          startTurn: position == 0 ? 0 : turns[position]))
            position += 1
        }
        // A start that already matches the target (in the group) is no level.
        let start: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(cubes, turns: turns).cells
        if VoxelOrigamiLattice.canonical(start, group: group) == VoxelOrigamiLattice.canonical(target, group: group) {
            return nil
        }
        return Drawn(cubes: cubes, target: target, orientations: orientations)
    }

    /// The index of the first candidate of `entry` that qualifies, walked here independently of `generate`.
    static func firstQualifying(_ entry: VoxelOrigamiManifestEntry) -> Int? {
        let range: ClosedRange<Int> = VoxelOrigamiBandProfile.of(band: entry.band).planRange
        for index in 0..<VoxelOrigamiGenerator.maxCandidates {
            guard let level = VoxelOrigamiGenerator.candidate(entry, index: index) else { continue }
            guard let plan = VoxelOrigamiSolver.plan(level, maxTurns: range.upperBound) else { continue }
            if range.contains(plan.size), plan.size <= entry.budget { return index }
        }
        return nil
    }

    /// Checks the generated levels of the sampled entries of `band`.
    static func checkGenerated(band: Int) throws {
        let range: ClosedRange<Int> = VoxelOrigamiBandProfile.of(band: band).planRange
        for number in generatedNumbers[band - 1] {
            let entry: VoxelOrigamiManifestEntry = Self.entry(number)
            let generated: VoxelOrigamiGenerated = try VoxelOrigamiGenerator.generate(entry)
            let level: VoxelOrigamiLevel = generated.level
            #expect(generated.entry == entry)
            #expect(level.id == VoxelOrigamiGenerator.levelID(number))
            #expect(level.difficulty == band)
            #expect(level.budget == entry.budget)
            #expect(level.tutorial == (number <= 3))
            #expect(level.orientations == entry.orientations)
            #expect(VoxelOrigamiBandProfile.of(band: band).cubes.contains(level.cubes.count))
            #expect(range.contains(generated.plan.size))
            #expect(generated.plan.size <= entry.budget)
            #expect(generated.skipped >= 0)
            #expect(generated.skipped < VoxelOrigamiGenerator.maxCandidates)
            #expect(generated.skipped == firstQualifying(entry))
            #expect(VoxelOrigamiGenerator.candidate(entry, index: generated.skipped) == level)
            #expect(!level.report(turns: level.startTurns).matched)
            #expect(VoxelOrigamiSolver.matches(level, actions: generated.plan.turns))
            // The difficulty recounted here.
            var turnable: Int = 0
            for hinge in 1..<level.cubes.count {
                let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(level.cubes, turns: level.startTurns)
                if !VoxelOrigamiLattice.swinging(level.cubes, pose: pose, hinge: hinge).isEmpty { turnable += 1 }
            }
            var searched: Int = 0
            for states in generated.plan.statesByDepth { searched += states }
            let difficulty: VoxelOrigamiDifficulty = generated.difficulty
            #expect(difficulty.turns == generated.plan.size)
            #expect(difficulty.cubes == level.cubes.count)
            #expect(difficulty.turnableHinges == turnable)
            #expect(difficulty.orientations == level.orientations)
            #expect(difficulty.statesSearched == searched)
            #expect(difficulty.work == generated.plan.work)
        }
    }

    @Test("the manifest holds 100 entries in order, 20 per band and emphasis, budgets within the band values")
    func manifest() {
        let entries: [VoxelOrigamiManifestEntry] = VoxelOrigamiManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int] = [0, 0, 0, 0, 0]
        var perEmphasis: [String: Int] = [:]
        var seeds: Set<UInt64> = []
        for (position, entry) in entries.enumerated() {
            #expect(entry.number == position + 1)
            #expect(entry.band == position / 20 + 1)
            #expect((1...5).contains(entry.band))
            if (1...5).contains(entry.band) {
                perBand[entry.band - 1] += 1
                #expect(Self.budgetRanges[entry.band - 1].contains(entry.budget))
            }
            #expect(Self.emphases.contains(entry.emphasis))
            perEmphasis[entry.emphasis, default: 0] += 1
            seeds.insert(entry.seed)
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        for emphasis in Self.emphases { #expect(perEmphasis[emphasis] == 20) }
        #expect(seeds.count == 100)
        #expect(!VoxelOrigamiManifest.source.isEmpty)
        #expect(!VoxelOrigamiManifest.provenance.isEmpty)
    }

    @Test("orientations follow the emphasis: rotate assembly any, lock shape fixed, the others upright")
    func orientationsByEmphasis() {
        for entry in VoxelOrigamiManifest.entries {
            var expected: VoxelOrigamiOrientations = .upright
            if entry.emphasis == "rotate assembly" { expected = .any }
            if entry.emphasis == "lock shape" { expected = .fixed }
            #expect(entry.orientations == expected)
        }
        let other = VoxelOrigamiManifestEntry(number: 1, seed: 1, band: 1, budget: 8, emphasis: "something else")
        #expect(other.orientations == .upright)
    }

    @Test("the band profiles equal clarification Q1 and out-of-range bands clamp")
    func bandProfiles() {
        let cubes: [ClosedRange<Int>] = [5...6, 6...7, 7...8, 8...9, 9...10]
        let scrambles: [ClosedRange<Int>] = [2...4, 4...6, 6...9, 8...12, 10...14]
        let plans: [ClosedRange<Int>] = [1...2, 2...3, 3...4, 4...5, 5...6]
        for band in 1...5 {
            let profile: VoxelOrigamiBandProfile = .of(band: band)
            #expect(profile.cubes == cubes[band - 1])
            #expect(profile.scramble == scrambles[band - 1])
            #expect(profile.planRange == plans[band - 1])
        }
        #expect(VoxelOrigamiBandProfile.of(band: 0) == .of(band: 1))
        #expect(VoxelOrigamiBandProfile.of(band: -3) == .of(band: 1))
        #expect(VoxelOrigamiBandProfile.of(band: 6) == .of(band: 5))
        #expect(VoxelOrigamiBandProfile.of(band: 99) == .of(band: 5))
    }

    @Test("the level ids, the bounds and the catalog id")
    func constants() {
        #expect(VoxelOrigamiGenerator.levelID(1) == "voxel-origami-001")
        #expect(VoxelOrigamiGenerator.levelID(42) == "voxel-origami-042")
        #expect(VoxelOrigamiGenerator.levelID(100) == "voxel-origami-100")
        #expect(VoxelOrigamiGenerator.maxCandidates == 256)
        #expect(VoxelOrigamiGenerator.maxTreeDraws == 50)
        #expect(VoxelOrigamiGenerator.drawsPerScrambleTurn == 8)
        #expect(VoxelOrigamiGenerator.catalogID == "voxel-origami")
    }

    @Test("candidates and generation are deterministic and different indices differ")
    func determinism() throws {
        for number in [1, 21, 41, 61, 81] {
            let entry: VoxelOrigamiManifestEntry = Self.entry(number)
            var levels: [VoxelOrigamiLevel] = []
            for index in 0..<8 {
                let first: VoxelOrigamiLevel? = VoxelOrigamiGenerator.candidate(entry, index: index)
                let second: VoxelOrigamiLevel? = VoxelOrigamiGenerator.candidate(entry, index: index)
                #expect(first == second)
                if let first { levels.append(first) }
            }
            #expect(levels.count >= 2)
            var fingerprints: Set<String> = []
            for level in levels { fingerprints.insert(level.fingerprint) }
            #expect(fingerprints.count == levels.count)
        }
        for number in [3, 44] {
            let first: VoxelOrigamiGenerated = try VoxelOrigamiGenerator.generate(Self.entry(number))
            let second: VoxelOrigamiGenerated = try VoxelOrigamiGenerator.generate(Self.entry(number))
            #expect(first == second)
        }
    }

    @Test("the drawing order of clarification Q1 re-implemented independently equals candidate(_:index:)")
    func drawingOrder() {
        var compared: Int = 0
        var levels: Int = 0
        for number in Self.redrawNumbers {
            let entry: VoxelOrigamiManifestEntry = Self.entry(number)
            for index in Self.redrawIndices {
                let drawn: Drawn? = Self.redraw(entry, index: index)
                let level: VoxelOrigamiLevel? = VoxelOrigamiGenerator.candidate(entry, index: index)
                compared += 1
                #expect((drawn == nil) == (level == nil), "entry \(number) candidate \(index)")
                guard let drawn, let level else { continue }
                levels += 1
                #expect(level.cubes == drawn.cubes, "entry \(number) candidate \(index)")
                #expect(level.target == drawn.target, "entry \(number) candidate \(index)")
                #expect(level.orientations == drawn.orientations)
                #expect(level.seed == entry.seed)
            }
        }
        #expect(compared == 60)
        #expect(levels >= 30)
    }

    @Test("every candidate carries its id, tutorial flag, band difficulty, band cube count and the manifest budget")
    func candidateValues() {
        for number in Self.redrawNumbers {
            let entry: VoxelOrigamiManifestEntry = Self.entry(number)
            let profile: VoxelOrigamiBandProfile = .of(band: entry.band)
            for index in 0..<6 {
                guard let level = VoxelOrigamiGenerator.candidate(entry, index: index) else { continue }
                #expect(level.id == VoxelOrigamiGenerator.levelID(number))
                #expect(level.tutorial == (number <= 3))
                #expect(level.difficulty == entry.band)
                #expect(level.budget == entry.budget)
                #expect(level.orientations == entry.orientations)
                #expect(profile.cubes.contains(level.cubes.count))
                #expect(level.target.count == level.cubes.count)
                #expect(!level.report(turns: level.startTurns).matched)
            }
        }
    }

    @Test("band 1 sampled levels: plan in range and budget, skipped, witness and difficulty")
    func generatedBand1() throws {
        try Self.checkGenerated(band: 1)
    }

    @Test("band 2 sampled levels: plan in range and budget, skipped, witness and difficulty")
    func generatedBand2() throws {
        try Self.checkGenerated(band: 2)
    }

    @Test("band 3 sampled levels: plan in range and budget, skipped, witness and difficulty")
    func generatedBand3() throws {
        try Self.checkGenerated(band: 3)
    }

    @Test("band 4 sampled levels: plan in range and budget, skipped, witness and difficulty")
    func generatedBand4() throws {
        try Self.checkGenerated(band: 4)
    }

    @Test("band 5 sampled levels: plan in range and budget, skipped, witness and difficulty")
    func generatedBand5() throws {
        try Self.checkGenerated(band: 5)
    }

    @Test("an entry no candidate can satisfy is refused with generation(number)")
    func refusal() {
        let base: VoxelOrigamiManifestEntry = Self.entry(27)
        // Band 2 accepts only plans of 2 … 3 turns; a budget of 1 admits none, so all 256 candidates are skipped by the
        // budget filter.
        let tight = VoxelOrigamiManifestEntry(number: base.number, seed: base.seed, band: base.band, budget: 1,
                                              emphasis: base.emphasis)
        var thrown: VoxelOrigamiError? = nil
        do {
            _ = try VoxelOrigamiGenerator.generate(tight)
        } catch {
            thrown = error
        }
        #expect(thrown == .generation(27))
        #expect(thrown?.reasonCode == "r02-g15.generation")
        // A budget of 0 is outside the level's range, so no candidate is a level at all.
        let invalid = VoxelOrigamiManifestEntry(number: 9, seed: base.seed, band: 1, budget: 0, emphasis: base.emphasis)
        var second: VoxelOrigamiError? = nil
        do {
            _ = try VoxelOrigamiGenerator.generate(invalid)
        } catch {
            second = error
        }
        #expect(second == .generation(9))
        #expect(VoxelOrigamiError.generation(5).reasonCode == "r02-g15.generation")
    }

    @Test("the catalog digest is deterministic and order-sensitive")
    func catalogDigest() throws {
        var levels: [VoxelOrigamiLevel] = []
        for number in [1, 21, 41] {
            // The first candidate that is a level.
            for index in 0..<16 {
                if let level = VoxelOrigamiGenerator.candidate(Self.entry(number), index: index) {
                    levels.append(level)
                    break
                }
            }
        }
        try #require(levels.count == 3)
        let digest: String = VoxelOrigamiGenerator.catalogDigest(levels)
        #expect(!digest.isEmpty)
        #expect(digest == VoxelOrigamiGenerator.catalogDigest(levels))
        var swapped: [VoxelOrigamiLevel] = levels
        swapped.swapAt(0, 2)
        #expect(digest != VoxelOrigamiGenerator.catalogDigest(swapped))
        #expect(digest != VoxelOrigamiGenerator.catalogDigest(Array(levels.prefix(2))))
    }
}
