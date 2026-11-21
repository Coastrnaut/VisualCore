// WaveKnotKeeperGeneratorTests — feature 322 (R02-G03-02) T-R02G0302-004 (FR-R02G0302-001; clarification Q1 and its
// amendment). The band profiles, level ids, deterministic generation within band and budget (with the skipped candidates
// re-checked), the tension bound covering the scramble walk and the refusal of a profile no candidate can meet. Test data
// uses explicit types and plain loops (CI type-check rule).
@testable import WaveKnotKeeperCore
import Testing
import VisualCoreSimulation

@Suite struct WaveKnotKeeperGeneratorTests {
    @Test func bandProfilesAndIDs() throws {
        let gates: [Int] = [0, 0, 1, 1, 2]
        let scramble: [Int] = [1, 2, 2, 3, 4]
        let shortest: [ClosedRange<Int>] = [1...1, 1...2, 1...2, 2...2, 2...3]
        for band in 1...5 {
            let profile: WaveKnotKeeperBandProfile = try #require(WaveKnotKeeperBandProfile.of(band: band))
            #expect(profile.points == 5 + band && profile.gates == gates[band - 1])
            #expect(profile.scramble == scramble[band - 1] && profile.shortest == shortest[band - 1])
        }
        #expect(WaveKnotKeeperBandProfile.of(band: 0) == nil && WaveKnotKeeperBandProfile.of(band: 6) == nil)
        #expect(WaveKnotKeeperGenerator.levelID(1) == "wave-knot-keeper-001")
        #expect(WaveKnotKeeperGenerator.levelID(100) == "wave-knot-keeper-100")
    }

    /// One seeded entry per band: deterministic, within its band and budget, every skipped candidate rejected.
    @Test(arguments: [1, 2, 3, 4, 5])
    func generationIsDeterministicAndWithinBand(band: Int) throws {
        var random: SeededRandom = SeededRandom(seed: 2_322 + UInt64(band))
        let entry: WaveKnotKeeperManifestEntry = WaveKnotKeeperManifestEntry(
            number: band * 20 - 3, seed: random.next(), band: band, budget: band * 2 + 8)
        let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperGenerator.generate(entry)
        let again: WaveKnotKeeperGenerated = try WaveKnotKeeperGenerator.generate(entry)
        #expect(generated == again)
        let profile: WaveKnotKeeperBandProfile = try #require(WaveKnotKeeperBandProfile.of(band: band))
        let level: WaveKnotKeeperLevel = generated.level
        #expect(profile.shortest.contains(generated.solution.shortest))
        #expect(generated.solution.shortest <= entry.budget && level.allowance == entry.budget)
        #expect(level.points.count == profile.points && level.gates.count == profile.gates)
        #expect(level.id == WaveKnotKeeperGenerator.levelID(entry.number) && level.band == band)
        #expect(!level.wins(level.points))
        #expect(level.wins(generated.solution.final))
        #expect(generated.solution.crossing != nil)
        #expect(WaveKnotKeeperGenerator.nearMiss(level, solution: generated.solution) != nil)
        #expect(generated.difficulty == WaveKnotKeeperDifficulty(level: level, solution: generated.solution))
        // The tension bound covers the start and every rope of the witness.
        let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: level)
        var rope: [WaveKnotKeeperPoint] = level.points
        #expect(WaveKnotKeeperGeometry.tension(rope) <= level.tensionBound)
        for move in generated.solution.moves {
            rope = try #require(rules.apply(move, to: rope))
            #expect(WaveKnotKeeperGeometry.tension(rope) <= level.tensionBound)
        }
        for k in 0..<generated.skipped {
            guard let candidate = WaveKnotKeeperGenerator.candidate(entry, profile: profile, index: k) else { continue }
            guard let solution = WaveKnotKeeperSolver.solve(candidate, depth: profile.shortest.upperBound) else {
                continue
            }
            let accepted: Bool = profile.shortest.contains(solution.shortest) && solution.shortest <= entry.budget
                && solution.crossing != nil && WaveKnotKeeperGenerator.nearMiss(candidate, solution: solution) != nil
            #expect(!accepted, "candidate \(k) would have been accepted")
        }
    }

    @Test func aProfileNoCandidateMeetsIsRefused() throws {
        let entry: WaveKnotKeeperManifestEntry = WaveKnotKeeperManifest.entries[0]
        // A one-step scramble never ends three moves from every winning rope.
        let impossible: WaveKnotKeeperBandProfile = WaveKnotKeeperBandProfile(band: 1, points: 6, gates: 0, scramble: 1,
                                                                              shortest: 3...3)
        #expect(throws: WaveKnotKeeperError.generation(1)) {
            try WaveKnotKeeperGenerator.generate(entry, profile: impossible)
        }
        let badBand: WaveKnotKeeperManifestEntry = WaveKnotKeeperManifestEntry(number: 7, seed: 1, band: 6, budget: 9)
        #expect(throws: WaveKnotKeeperError.generation(7)) { try WaveKnotKeeperGenerator.generate(badBand) }
        #expect(WaveKnotKeeperError.generation(1).reasonCode == "r02-g03.generation")
        #expect(WaveKnotKeeperError.witness("x").reasonCode == "r02-g03.witness")
    }
}
