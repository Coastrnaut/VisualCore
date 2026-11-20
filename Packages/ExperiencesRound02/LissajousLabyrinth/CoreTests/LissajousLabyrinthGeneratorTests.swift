// LissajousLabyrinthGeneratorTests — feature 312 (R02-G02-02) T-R02G0202-004 (FR-R02G0202-001; clarification Q1). The
// band profiles, level ids, deterministic generation within band and budget (with the skipped candidates re-checked) and
// the refusal of a profile no candidate can meet. Test data uses explicit types and plain loops (CI type-check rule).
@testable import LissajousLabyrinthCore
import Testing
import VisualCoreSimulation

@Suite struct LissajousLabyrinthGeneratorTests {
    @Test func bandProfilesAndIDs() throws {
        let counts: [Int] = [2, 3, 4, 5, 6]
        let radii: [Int] = [512, 448, 384, 320, 256]
        let obstacles: [Int] = [2, 3, 4, 6, 8]
        let shortest: [ClosedRange<Int>] = [1...2, 2...2, 2...3, 3...3, 3...4]
        for band in 1...5 {
            let profile: LissajousLabyrinthBandProfile = try #require(LissajousLabyrinthBandProfile.of(band: band))
            #expect(profile.checkpoints == counts[band - 1] && profile.checkpointRadius == radii[band - 1])
            #expect(profile.obstacles == obstacles[band - 1] && profile.shortest == shortest[band - 1])
            #expect(profile.obstacleRadius == 256...512)
        }
        #expect(LissajousLabyrinthBandProfile.of(band: 0) == nil && LissajousLabyrinthBandProfile.of(band: 6) == nil)
        #expect(LissajousLabyrinthGenerator.levelID(1) == "lissajous-labyrinth-001")
        #expect(LissajousLabyrinthGenerator.levelID(100) == "lissajous-labyrinth-100")
    }

    /// One seeded entry per band: deterministic, within its band and budget, every skipped candidate rejected.
    @Test(arguments: [1, 2, 3, 4, 5])
    func generationIsDeterministicAndWithinBand(band: Int) throws {
        var random: SeededRandom = SeededRandom(seed: 2_312 + UInt64(band))
        let entry: LissajousLabyrinthManifestEntry = LissajousLabyrinthManifestEntry(
            number: band * 20 - 3, seed: random.next(), band: band, budget: band * 2 + 8)
        let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthGenerator.generate(entry)
        let again: LissajousLabyrinthGenerated = try LissajousLabyrinthGenerator.generate(entry)
        #expect(generated == again)
        let profile: LissajousLabyrinthBandProfile = try #require(LissajousLabyrinthBandProfile.of(band: band))
        let level: LissajousLabyrinthLevel = generated.level
        #expect(profile.shortest.contains(generated.solution.shortest))
        #expect(generated.solution.shortest <= entry.budget && level.allowance == entry.budget)
        #expect(level.checkpoints.count == profile.checkpoints && level.obstacles.count == profile.obstacles)
        #expect(level.id == LissajousLabyrinthGenerator.levelID(entry.number) && level.band == band)
        #expect(LissajousLabyrinthLap.verdict(level.start, level: level) != .won)
        #expect(LissajousLabyrinthLap.verdict(generated.solution.setting, level: level) == .won)
        #expect(generated.difficulty == LissajousLabyrinthDifficulty(level: level, solution: generated.solution))
        #expect(generated.difficulty.clearance > 0)
        for k in 0..<generated.skipped {
            if let candidate = LissajousLabyrinthGenerator.candidate(entry, profile: profile, index: k),
               let solution = LissajousLabyrinthSolver.solve(candidate) {
                #expect(!profile.shortest.contains(solution.shortest) || solution.shortest > entry.budget,
                        "candidate \(k) would have been accepted")
            }
        }
    }

    @Test func aProfileNoCandidateMeetsIsRefused() throws {
        let entry: LissajousLabyrinthManifestEntry = LissajousLabyrinthManifest.entries[0]
        let impossible: LissajousLabyrinthBandProfile = LissajousLabyrinthBandProfile(
            band: 1, checkpoints: 2, checkpointRadius: 512, obstacles: 0, obstacleRadius: 256...512, shortest: 9...9)
        #expect(throws: LissajousLabyrinthError.generation(1)) {
            try LissajousLabyrinthGenerator.generate(entry, profile: impossible)
        }
        let badBand: LissajousLabyrinthManifestEntry = LissajousLabyrinthManifestEntry(number: 7, seed: 1, band: 6,
                                                                                       budget: 9)
        #expect(throws: LissajousLabyrinthError.generation(7)) { try LissajousLabyrinthGenerator.generate(badBand) }
        #expect(LissajousLabyrinthError.generation(1).reasonCode == "r02-g02.generation")
        #expect(LissajousLabyrinthError.witness("x").reasonCode == "r02-g02.witness")
    }
}
