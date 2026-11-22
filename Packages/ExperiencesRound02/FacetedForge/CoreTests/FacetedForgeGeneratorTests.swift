// FacetedForgeGeneratorTests — feature 372 (R02-G08-02) T-R02G0802-004 (FR-R02G0802-001, 003, 005; clarifications Q1,
// Q3). Host checks of the generator: the manifest's shape, the band profiles and their clamping, level ids, candidate
// determinism, the generated levels' shape (id, tutorial, difficulty, budget, sliver, shares, target size, crystal by
// band), the solution's smallest cut count at the lower bound and its witness winning through the play, skipped
// candidates re-checked as not certified, difficulty fields consistent with the witness, and the refusal
// `.generation(n)` for an entry whose profile cannot succeed. Six sampled entries (tutorial levels 1 and 2 and the
// first of bands 2 … 5); explicit types, plain loops; the sample generated once per process and shared.
import Testing
import VisualCoreSimulation
@testable import FacetedForgeCore

@Suite("FacetedForgeGenerator")
struct FacetedForgeGeneratorTests {
    /// Entries 1 and 2 (tutorial, band 1) and the first entry of bands 2 … 5.
    static let sampled: [FacetedForgeManifestEntry] =
        [1, 2, 21, 41, 61, 81].map { FacetedForgeManifest.entries[$0 - 1] }

    /// The sampled entries generated once and shared by the tests (nil where generation threw).
    static let sampledResults: [FacetedForgeGenerated?] = sampled.map { try? FacetedForgeGenerator.generate($0) }

    /// The shared certified levels of the sample; a sampled entry that did not generate is recorded as an issue.
    static func generatedSample() -> [FacetedForgeGenerated] {
        var results: [FacetedForgeGenerated] = []
        for (offset, result) in sampledResults.enumerated() {
            if let result {
                results.append(result)
            } else {
                Issue.record("level \(sampled[offset].number) did not generate")
            }
        }
        return results
    }

    /// Whether the solver certifies `level` by the rules `generate` applies (clarification Q1).
    static func certified(_ level: FacetedForgeLevel) -> Bool {
        guard let solution = FacetedForgeSolver.solve(level) else { return false }
        if solution.smallest != FacetedForgeSolver.lowerBound(level) { return false }
        if solution.smallest > level.budget { return false }
        return FacetedForgeGenerator.wins(level, actions: solution.actions)
    }

    /// The (direction, sign) → depth map of `planes`.
    static func planeMap(_ planes: [FacetedForgeHalfSpace]) -> [Int: Int] {
        var map: [Int: Int] = [:]
        for plane in planes { map[plane.direction * 2 + (plane.sign > 0 ? 1 : 0)] = plane.depth }
        return map
    }

    /// The distinct directions of `planes`.
    static func directions(_ planes: [FacetedForgeHalfSpace]) -> Set<Int> {
        var set: Set<Int> = []
        for plane in planes { set.insert(plane.direction) }
        return set
    }

    /// The manifest has 100 entries numbered 1 … 100, 20 per band in order, budgets in the band's range.
    @Test func manifestShape() {
        let entries: [FacetedForgeManifestEntry] = FacetedForgeManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int: Int] = [:]
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            #expect(entry.band == offset / 20 + 1)
            let low: Int = 2 * entry.band + 6
            #expect(entry.budget >= low && entry.budget <= low + 3, "level \(entry.number) budget \(entry.budget)")
            perBand[entry.band, default: 0] += 1
        }
        for band in 1...5 { #expect(perBand[band] == 20) }
        #expect(FacetedForgeManifest.source.contains("round2.md"))
    }

    /// The five band profiles are exactly those of clarification Q1, and bands outside 1 … 5 clamp.
    @Test func bandProfiles() {
        let cuts: [ClosedRange<Int>] = [2...3, 3...4, 4...5, 5...6, 6...7]
        for band in 1...5 {
            let profile: FacetedForgeBandProfile = FacetedForgeBandProfile.of(band: band)
            #expect(profile.band == band)
            #expect(profile.cuts == cuts[band - 1])
            #expect(profile.directions == (band <= 2 ? Array(0...8) : Array(0...12)))
        }
        #expect(FacetedForgeBandProfile.of(band: 0) == FacetedForgeBandProfile.of(band: 1))
        #expect(FacetedForgeBandProfile.of(band: -3) == FacetedForgeBandProfile.of(band: 1))
        #expect(FacetedForgeBandProfile.of(band: 6) == FacetedForgeBandProfile.of(band: 5))
    }

    /// Level ids are `faceted-forge-NNN`, zero-padded to three digits; the constants are those of the design.
    @Test func levelIDFormatting() {
        #expect(FacetedForgeGenerator.levelID(1) == "faceted-forge-001")
        #expect(FacetedForgeGenerator.levelID(42) == "faceted-forge-042")
        #expect(FacetedForgeGenerator.levelID(100) == "faceted-forge-100")
        #expect(FacetedForgeGenerator.catalogID == "faceted-forge")
        #expect(FacetedForgeGenerator.maxCandidates == 256)
        #expect(FacetedForgeGenerator.sliver == FacetedForgeFraction(unchecked: 1, 64))
        #expect(FacetedForgeGenerator.smallestShare == FacetedForgeFraction(unchecked: 1, 32))
    }

    /// The same entry and index give the same candidate; different indices usually give different ones.
    @Test func candidateDeterminism() {
        for entry in [FacetedForgeManifest.entries[0], FacetedForgeManifest.entries[80]] {
            var fingerprints: Set<String> = []
            for index in 0..<48 {
                let first: FacetedForgeLevel? = FacetedForgeGenerator.candidate(entry, index: index)
                let second: FacetedForgeLevel? = FacetedForgeGenerator.candidate(entry, index: index)
                #expect(first == second)
                if let first { fingerprints.insert(first.fingerprint) }
            }
            #expect(fingerprints.count >= 2, "level \(entry.number): \(fingerprints.count) distinct candidates")
        }
    }

    /// Every generated level has the manifest's id, tutorial flag, difficulty, budget, the sliver 1/64, shares of at
    /// least 1/32 and a target whose cut count lies in the band's range.
    @Test func generatedShape() {
        let sample: [FacetedForgeGenerated] = Self.generatedSample()
        #expect(sample.count == Self.sampled.count)
        for generated in sample {
            let entry: FacetedForgeManifestEntry = generated.entry
            let level: FacetedForgeLevel = generated.level
            let profile: FacetedForgeBandProfile = FacetedForgeBandProfile.of(band: entry.band)
            #expect(level.id == FacetedForgeGenerator.levelID(entry.number))
            #expect(level.seed == entry.seed)
            #expect(level.tutorial == (entry.number <= 3))
            #expect(level.difficulty == entry.band)
            #expect(level.budget == entry.budget)
            #expect(level.sliver == FacetedForgeGenerator.sliver)
            #expect(profile.cuts.contains(level.target.count - 1), "level \(entry.number): \(level.target.count)")
            #expect(generated.skipped >= 0 && generated.skipped < FacetedForgeGenerator.maxCandidates)
            for piece in level.target {
                #expect(!(piece.share < FacetedForgeGenerator.smallestShare), "level \(entry.number) share")
            }
            #expect(level == FacetedForgeGenerator.candidate(entry, index: generated.skipped))
        }
    }

    /// The crystals follow clarification Q1: bands 1 … 2 boxes on the axes (band 1 a centred cube), band 3 a cube
    /// with one corner truncated, band 4 an octahedron on the body diagonals, band 5 a cube with two opposite corners
    /// truncated.
    @Test func crystalsByBand() {
        for generated in Self.generatedSample() {
            let planes: [FacetedForgeHalfSpace] = generated.level.planes
            let map: [Int: Int] = Self.planeMap(planes)
            let dirs: Set<Int> = Self.directions(planes)
            let number: Int = generated.entry.number
            switch generated.entry.band {
            case 1:
                #expect(planes.count == 6 && dirs == [0, 1, 2], "level \(number)")
                let a: Int = map[1] ?? 0
                #expect(a >= 3 && a <= 6, "level \(number)")
                for axis in 0..<3 { #expect(map[axis * 2 + 1] == a && map[axis * 2] == -a, "level \(number)") }
                #expect(generated.level.crystal.faceCount == 6)
            case 2:
                #expect(planes.count == 6 && dirs == [0, 1, 2], "level \(number)")
                for axis in 0..<3 {
                    let high: Int = map[axis * 2 + 1] ?? 0
                    let low: Int = map[axis * 2] ?? 0
                    #expect(high >= 2 && high <= 6 && -low >= 2 && -low <= 6, "level \(number)")
                }
                #expect(generated.level.crystal.faceCount == 6)
            case 3:
                #expect(planes.count == 7 && dirs == [0, 1, 2, 9], "level \(number)")
                let a: Int = map[1] ?? 0
                let b: Int = map[19] ?? 0
                #expect(a >= 4 && a <= 6 && b >= a + 1 && b <= 3 * a - 2 && map[18] == nil, "level \(number)")
                #expect(generated.level.crystal.faceCount == 7)
            case 4:
                #expect(planes.count == 8 && dirs == [9, 10, 11, 12], "level \(number)")
                let a: Int = map[19] ?? 0
                #expect(a >= 5 && a <= 6, "level \(number)")
                for direction in 9...12 {
                    #expect(map[direction * 2 + 1] == a && map[direction * 2] == -a, "level \(number)")
                }
                #expect(generated.level.crystal.faceCount == 8)
            default:
                #expect(planes.count == 8 && dirs == [0, 1, 2, 9], "level \(number)")
                let a: Int = map[1] ?? 0
                let b: Int = map[19] ?? 0
                #expect(a >= 5 && a <= 6 && b >= a + 1 && b <= 3 * a - 2 && map[18] == -b, "level \(number)")
                #expect(generated.level.crystal.faceCount == 8)
            }
        }
    }

    /// The solution's cut count is the lower bound, within the budget, and its witness wins through the play; bands
    /// 3 … 5 are certified for the right reason (the witness exists) whatever directions it uses.
    @Test func solutionWins() {
        for generated in Self.generatedSample() {
            let level: FacetedForgeLevel = generated.level
            let solution: FacetedForgeSolution = generated.solution
            #expect(solution.smallest == FacetedForgeSolver.lowerBound(level))
            #expect(solution.smallest == level.target.count - 1)
            #expect(solution.actions.count == solution.smallest)
            #expect(solution.smallest <= level.budget)
            #expect(solution.work > 0 && solution.work <= FacetedForgeSolver.workBound)
            #expect(FacetedForgeGenerator.wins(level, actions: solution.actions), "level \(generated.entry.number)")
            var short: [FacetedForgeAction] = solution.actions
            short.removeLast()
            #expect(!FacetedForgeGenerator.wins(level, actions: short), "level \(generated.entry.number)")
        }
    }

    /// Every candidate below `skipped` is refused or not certified by the solver.
    @Test func skippedRechecked() {
        for generated in Self.generatedSample() {
            for index in 0..<generated.skipped {
                guard let level = FacetedForgeGenerator.candidate(generated.entry, index: index) else { continue }
                #expect(!Self.certified(level), "level \(generated.entry.number) candidate \(index) qualifies")
            }
        }
    }

    /// The difficulty fields follow the witness and the level (clarification Q3).
    @Test func difficultyConsistent() {
        for generated in Self.generatedSample() {
            let difficulty: FacetedForgeDifficulty = generated.difficulty
            var used: Set<Int> = []
            var diagonals: Int = 0
            for action in generated.solution.actions {
                guard case let .cut(_, direction, _) = action else { continue }
                used.insert(direction)
                if direction >= 3 { diagonals += 1 }
            }
            #expect(difficulty.smallest == generated.solution.smallest)
            #expect(difficulty.pieces == difficulty.smallest + 1)
            #expect(difficulty.pieces == generated.level.target.count)
            #expect(difficulty.directions == used.count)
            #expect(difficulty.diagonals == diagonals)
            #expect(difficulty.crystalFaces == generated.level.crystal.faceCount)
            #expect(difficulty.work == generated.solution.work)
            #expect(difficulty.puzzleDifficulty == PuzzleDifficulty(shortest: difficulty.smallest,
                                                                    explored: difficulty.work))
        }
    }

    /// Generation is deterministic: a second run of a sampled entry gives the same result.
    @Test func generationDeterministic() throws {
        let entry: FacetedForgeManifestEntry = FacetedForgeManifest.entries[0]
        let again: FacetedForgeGenerated = try FacetedForgeGenerator.generate(entry)
        #expect(Self.sampledResults[0] == again)
    }

    /// An entry whose budget is below its band's cut range cannot succeed: `generate` refuses with `.generation(n)`.
    @Test func impossibleEntryRefused() {
        let entry: FacetedForgeManifestEntry = FacetedForgeManifestEntry(number: 81, seed: 0x6bcef1c658973e15, band: 5,
                                                                         budget: 1)
        var refused: FacetedForgeError?
        do {
            _ = try FacetedForgeGenerator.generate(entry)
        } catch {
            refused = error
        }
        #expect(refused == .generation(81))
    }
}
