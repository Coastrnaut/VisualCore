// AmethystEscapeGeneratorTests — feature 362 (R02-G07-02) T-R02G0702-004 (FR-R02G0702-001, 003; clarification Q1).
// Host checks of the generator: the band profiles and their clamping, determinism of candidates and of generation, the
// generated levels' shape (sectors, shells, id, tutorial, difficulty, budget), the solution's smallest move count within
// the band and the budget, the witness winning through the play where advances alone do not escape, skipped candidates
// re-checked as rejected for a stated reason, consistent difficulty fields, the refusal `.generation(n)` when no
// candidate can qualify, and the manifest's shape. Four sampled entries of every band; explicit types, plain loops;
// the sample generated once and shared; each test under 3 s.
import Testing
import VisualCoreSimulation
@testable import AmethystEscapeCore

@Suite("AmethystEscapeGenerator")
struct AmethystEscapeGeneratorTests {
    /// Four entries of bands 1 … 4 (including the three tutorial levels) and two of band 5, whose proofs cost the
    /// most (a debug build spends about 0.6 s on each band-5 level).
    static let sampled: [AmethystEscapeManifestEntry] = [1, 2, 3, 20, 21, 24, 33, 40, 41, 44, 52, 60, 61, 64, 72, 80,
                                                         84, 92].map { AmethystEscapeManifest.entries[$0 - 1] }

    /// The sampled entries generated once and shared by the tests (nil where generation threw).
    static let sampledResults: [AmethystEscapeGenerated?] = sampled.map { try? AmethystEscapeGenerator.generate($0) }

    /// Why candidate `index` of `entry` is rejected by the rules of clarification Q1, or nil when it qualifies.
    static func rejection(_ entry: AmethystEscapeManifestEntry, index: Int) -> String? {
        let profile: AmethystEscapeBandProfile = AmethystEscapeBandProfile.of(band: entry.band)
        guard let level = AmethystEscapeGenerator.candidate(entry, index: index) else { return "candidate-nil" }
        if AmethystEscapeSolver.escapesByAdvancing(level) { return "escapes-by-advancing" }
        guard let solution = AmethystEscapeSolver.solve(level) else { return "unsolvable" }
        if !profile.smallest.contains(solution.smallest) { return "smallest-out-of-range" }
        if solution.smallest > level.budget { return "over-budget" }
        if !AmethystEscapeGenerator.wins(level, actions: solution.actions) { return "witness-does-not-win" }
        return nil
    }

    /// The shared certified levels of the sample; a sampled entry that did not generate is recorded as an issue.
    static func generatedSample() -> [AmethystEscapeGenerated] {
        var results: [AmethystEscapeGenerated] = []
        for (offset, result) in sampledResults.enumerated() {
            if let result {
                results.append(result)
            } else {
                Issue.record("level \(sampled[offset].number) did not generate")
            }
        }
        return results
    }

    /// The five band profiles are exactly those of clarification Q1, and bands outside 1 … 5 clamp.
    @Test func bandProfiles() {
        #expect(AmethystEscapeBandProfile.of(band: 1) == AmethystEscapeBandProfile(sectors: 6, shells: 2, smallest: 3...4))
        #expect(AmethystEscapeBandProfile.of(band: 2) == AmethystEscapeBandProfile(sectors: 6, shells: 3, smallest: 5...6))
        #expect(AmethystEscapeBandProfile.of(band: 3) == AmethystEscapeBandProfile(sectors: 8, shells: 3, smallest: 7...8))
        #expect(AmethystEscapeBandProfile.of(band: 4) == AmethystEscapeBandProfile(sectors: 8, shells: 4, smallest: 9...10))
        #expect(AmethystEscapeBandProfile.of(band: 5)
            == AmethystEscapeBandProfile(sectors: 10, shells: 4, smallest: 11...12))
        #expect(AmethystEscapeBandProfile.of(band: 0) == AmethystEscapeBandProfile.of(band: 1))
        #expect(AmethystEscapeBandProfile.of(band: -3) == AmethystEscapeBandProfile.of(band: 1))
        #expect(AmethystEscapeBandProfile.of(band: 6) == AmethystEscapeBandProfile.of(band: 5))
        #expect(AmethystEscapeBandProfile.of(band: 99) == AmethystEscapeBandProfile.of(band: 5))
    }

    /// Level ids are `amethyst-escape-NNN`, zero-padded to three digits.
    @Test func levelIDFormatting() {
        #expect(AmethystEscapeGenerator.levelID(1) == "amethyst-escape-001")
        #expect(AmethystEscapeGenerator.levelID(42) == "amethyst-escape-042")
        #expect(AmethystEscapeGenerator.levelID(100) == "amethyst-escape-100")
        #expect(AmethystEscapeGenerator.catalogID == "amethyst-escape")
        #expect(AmethystEscapeGenerator.maxCandidates == 512)
    }

    /// The manifest has 100 entries numbered 1 … 100, 20 per band in order, and budgets 8 … 19 (band b: 2b+6 … 2b+9).
    @Test func manifestShape() {
        let entries: [AmethystEscapeManifestEntry] = AmethystEscapeManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int: Int] = [:]
        var minBudget: Int = Int.max
        var maxBudget: Int = Int.min
        var seeds: Set<UInt64> = []
        for (offset, entry) in entries.enumerated() {
            #expect(entry.number == offset + 1)
            #expect(entry.band == offset / 20 + 1)
            let low: Int = 2 * entry.band + 6
            #expect((low...(low + 3)).contains(entry.budget), "level \(entry.number) budget \(entry.budget)")
            perBand[entry.band, default: 0] += 1
            minBudget = min(minBudget, entry.budget)
            maxBudget = max(maxBudget, entry.budget)
            seeds.insert(entry.seed)
        }
        for band in 1...5 { #expect(perBand[band] == 20) }
        #expect(minBudget == 8)
        #expect(maxBudget == 19)
        #expect(seeds.count == 100)
    }

    /// Candidates and generation are deterministic: the same entry and index give equal results twice (candidates on
    /// the whole sample, generation regenerated on one entry of every band against the shared results).
    @Test func determinism() throws {
        for entry in Self.sampled {
            for index in 0..<4 {
                let first: AmethystEscapeLevel? = AmethystEscapeGenerator.candidate(entry, index: index)
                let second: AmethystEscapeLevel? = AmethystEscapeGenerator.candidate(entry, index: index)
                #expect(first == second, "level \(entry.number) candidate \(index)")
            }
        }
        for (offset, entry) in Self.sampled.enumerated() where offset % 4 == 0 {
            let again: AmethystEscapeGenerated = try AmethystEscapeGenerator.generate(entry)
            #expect(Self.sampledResults[offset] == again, "level \(entry.number)")
            #expect(Self.sampledResults[offset]?.level.fingerprint == again.level.fingerprint)
        }
    }

    /// Generated levels have the band's sectors and shells, the manifest id, seed, budget and difficulty, the tutorial
    /// only on levels 1 … 3, and a smallest move count within the band's range and the budget.
    @Test func generatedShape() {
        for result in Self.generatedSample() {
            let entry: AmethystEscapeManifestEntry = result.entry
            let profile: AmethystEscapeBandProfile = AmethystEscapeBandProfile.of(band: entry.band)
            let level: AmethystEscapeLevel = result.level
            #expect(result.entry == entry)
            #expect(level.sectors == profile.sectors, "level \(entry.number)")
            #expect(level.shells.count == profile.shells, "level \(entry.number)")
            #expect(level.id == AmethystEscapeGenerator.levelID(entry.number))
            #expect(level.seed == entry.seed)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (entry.number <= 3), "level \(entry.number)")
            #expect(profile.smallest.contains(result.solution.smallest), "level \(entry.number)")
            #expect(result.solution.smallest <= level.budget, "level \(entry.number)")
            #expect(result.solution.actions.count == result.solution.smallest)
            #expect(result.solution.actions.last == .advance)
            #expect((0..<AmethystEscapeGenerator.maxCandidates).contains(result.skipped))
            #expect(AmethystEscapeGenerator.candidate(entry, index: result.skipped) == level)
        }
    }

    /// The certified solution wins through the play, while advances alone do not escape.
    @Test func witnessWinsAdvancesAloneDoNot() {
        for result in Self.generatedSample() {
            let entry: AmethystEscapeManifestEntry = result.entry
            let level: AmethystEscapeLevel = result.level
            #expect(AmethystEscapeGenerator.wins(level, actions: result.solution.actions), "level \(entry.number)")
            #expect(!AmethystEscapeSolver.escapesByAdvancing(level), "level \(entry.number)")
            let advances: [AmethystEscapeAction] = Array(repeating: .advance, count: level.budget)
            #expect(!AmethystEscapeGenerator.wins(level, actions: advances), "level \(entry.number)")
            let shortened: [AmethystEscapeAction] = Array(result.solution.actions.dropLast())
            #expect(!AmethystEscapeGenerator.wins(level, actions: shortened), "level \(entry.number)")
        }
    }

    /// Every candidate index below `skipped` is rejected for a stated reason, and the kept one qualifies.
    @Test func skippedCandidatesRechecked() {
        var reasons: Set<String> = []
        for result in Self.generatedSample() {
            let entry: AmethystEscapeManifestEntry = result.entry
            for index in 0..<result.skipped {
                let reason: String? = Self.rejection(entry, index: index)
                #expect(reason != nil, "level \(entry.number) candidate \(index) qualifies but was skipped")
                if let reason { reasons.insert(reason) }
            }
            #expect(Self.rejection(entry, index: result.skipped) == nil, "level \(entry.number)")
        }
        #expect(!reasons.contains("witness-does-not-win"))
    }

    /// The difficulty fields agree with the level and the solution: turns + advances = smallest, explored = work.
    @Test func difficultyConsistent() {
        for result in Self.generatedSample() {
            let entry: AmethystEscapeManifestEntry = result.entry
            let difficulty: AmethystEscapeDifficulty = result.difficulty
            var turns: Int = 0
            var advances: Int = 0
            for action in result.solution.actions {
                switch action {
                case .rotate: turns += 1
                case .advance: advances += 1
                }
            }
            #expect(difficulty.smallest == result.solution.smallest)
            #expect(difficulty.turns == turns)
            #expect(difficulty.advances == advances)
            #expect(difficulty.turns + difficulty.advances == difficulty.smallest)
            #expect(difficulty.explored == result.solution.work)
            #expect(difficulty.shells == result.level.shells.count)
            #expect(difficulty.sectors == result.level.sectors)
            #expect(difficulty == AmethystEscapeDifficulty(level: result.level, solution: result.solution))
            #expect(difficulty.puzzleDifficulty.shortest == difficulty.smallest)
        }
    }

    /// An entry whose budget is below its band's smallest range cannot qualify and throws `.generation(number)`.
    @Test func impossibleEntryThrows() {
        let entry: AmethystEscapeManifestEntry = AmethystEscapeManifestEntry(number: 7, seed: 0x0123_4567_89ab_cdef,
                                                                              band: 1, budget: 2)
        #expect(throws: AmethystEscapeError.generation(7)) {
            try AmethystEscapeGenerator.generate(entry)
        }
        #expect(AmethystEscapeError.generation(7).reasonCode == "r02-g07.generation")
    }
}
