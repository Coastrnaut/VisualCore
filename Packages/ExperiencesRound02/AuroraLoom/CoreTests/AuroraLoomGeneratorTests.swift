// AuroraLoomGeneratorTests — feature 302 (R02-G01-02) T-R02G0102-004 (FR-R02G0102-001, 006; SC-R02G0102-001, 003;
// clarification Q1). Determinism, band ranges, the move budget, the skipped count and the refusal of an entry no
// candidate can meet. Test data uses explicit types and plain loops (CI type-check rule).
@testable import AuroraLoomCore
import Testing
import VisualCoreSimulation

@Suite struct AuroraLoomGeneratorTests {
    @Test func bandProfilesMatchTheClarification() throws {
        let omegas: [Int] = [16, 32, 64, 128, 256]
        let tolerances: [Int] = [160, 96, 64, 40, 24]
        for band in 1...5 {
            let profile = try #require(AuroraLoomBandProfile.of(band: band))
            #expect(profile.omega == omegas[band - 1])
            #expect(profile.tolerance == tolerances[band - 1])
            #expect(profile.shortest == band...(band + 1))
            #expect(profile.tolerance < 256)
        }
        #expect(AuroraLoomBandProfile.of(band: 0) == nil)
        #expect(AuroraLoomBandProfile.of(band: 6) == nil)
    }

    @Test func levelIDsAreZeroPadded() {
        #expect(AuroraLoomGenerator.levelID(1) == "aurora-loom-001")
        #expect(AuroraLoomGenerator.levelID(42) == "aurora-loom-042")
        #expect(AuroraLoomGenerator.levelID(100) == "aurora-loom-100")
    }

    @Test func seededEntriesGenerateDeterministicallyWithinTheirBand() throws {
        var random = SeededRandom(seed: 2_302)
        for i in 0..<40 {
            let band: Int = i % 5 + 1
            let entry = AuroraLoomManifestEntry(number: i % 100 + 1, seed: random.next(), band: band,
                                                budget: random.int((band + 1)...19))
            let first = try AuroraLoomGenerator.generate(entry)
            let second = try AuroraLoomGenerator.generate(entry)
            #expect(first == second)
            let profile = try #require(AuroraLoomBandProfile.of(band: band))
            #expect(profile.shortest.contains(first.solution.shortest))
            #expect(first.solution.shortest <= entry.budget)
            #expect(first.level.allowance == entry.budget)
            #expect(first.level.omega == profile.omega)
            #expect(first.level.tolerance == profile.tolerance)
            #expect(first.level.tutorial == (1...3).contains(entry.number))
            #expect(first.level.id == AuroraLoomGenerator.levelID(entry.number))
            #expect((0..<AuroraLoomGenerator.maxCandidates).contains(first.skipped))
            #expect(!AuroraLoomHarmony.wins(first.level.startSteps, level: first.level))
            #expect(AuroraLoomHarmony.wins(first.solution.setting, level: first.level))
            #expect(first.difficulty == AuroraLoomDifficulty(level: first.level, solution: first.solution))
            // The skipped candidates were really refused: each earlier one is invalid or outside the band.
            for k in 0..<first.skipped {
                if let level = AuroraLoomGenerator.candidate(entry, profile: profile, index: k),
                   let solution = AuroraLoomSolver.solve(level) {
                    #expect(!profile.shortest.contains(solution.shortest) || solution.shortest > entry.budget)
                }
            }
        }
    }

    @Test func anEntryNoCandidateCanMeetIsRefused() throws {
        let entry = AuroraLoomManifestEntry(number: 7, seed: 2_302, band: 1, budget: 9)
        // A shortest range no level can reach (at most six controls change).
        let impossible = AuroraLoomBandProfile(band: 1, omega: 16, tolerance: 160, shortest: 7...8)
        #expect(throws: AuroraLoomError.generation(7)) { try AuroraLoomGenerator.generate(entry, profile: impossible) }
        #expect(AuroraLoomError.generation(7).reasonCode == "r02-g01.generation")
        let outside = AuroraLoomManifestEntry(number: 9, seed: 1, band: 6, budget: 9)
        #expect(throws: AuroraLoomError.generation(9)) { try AuroraLoomGenerator.generate(outside) }
        // A budget below every shortest solution of the band.
        let tight = AuroraLoomManifestEntry(number: 11, seed: 2_302, band: 5, budget: 4)
        #expect(throws: AuroraLoomError.generation(11)) { try AuroraLoomGenerator.generate(tight) }
    }
}
