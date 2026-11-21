// ColorfallCanyonsGeneratorTests — feature 342 (R02-G05-02) T-R02G0502-004 (FR-R02G0502-001; clarification Q1). Host
// checks of the generator: the band profiles and their clamping, determinism of candidates and of generation, the
// generated levels' ranges, the planted plan as a winning proof, the difficulty fields, skipped candidates re-checked as
// not qualifying, the refusal when no candidate can qualify, the order-sensitive catalog digest and the generator's own
// shuffle. Short runs on sampled entries; bands 4 and 5 are sampled once each because one level can take seconds.
import Testing
import VisualCoreSimulation
@testable import ColorfallCanyonsCore

@Suite struct ColorfallCanyonsGeneratorTests {
    /// The first entry of every band and a second entry of bands 1 and 2.
    static let sampled: [ColorfallCanyonsManifestEntry] = [1, 7, 21, 28, 41, 61, 81].map {
        ColorfallCanyonsManifest.entries[$0 - 1]
    }

    /// Whether candidate `index` of `entry` would be kept by the rules of clarification Q1.
    static func qualifies(_ entry: ColorfallCanyonsManifestEntry, index: Int) -> Bool {
        let profile: ColorfallCanyonsBandProfile = ColorfallCanyonsBandProfile.of(band: entry.band)
        guard let (level, planted) = ColorfallCanyonsGenerator.candidate(entry, index: index) else { return false }
        guard ColorfallCanyonsSolver.run(level, edits: planted)?.verdict == .won,
              let unedited = ColorfallCanyonsSolver.run(level, edits: []), unedited.verdict != .won else { return false }
        guard let solution = ColorfallCanyonsSolver.solve(level, depth: profile.smallest.upperBound) else { return false }
        return profile.smallest.contains(solution.smallest)
    }

    @Test func bandProfilesFollowClarificationQ1AndClamp() {
        let expected: [ColorfallCanyonsBandProfile] = [
            ColorfallCanyonsBandProfile(columns: 6, rows: 5, springs: 1, depressions: 3, smallest: 1...2),
            ColorfallCanyonsBandProfile(columns: 6, rows: 5, springs: 2, depressions: 4, smallest: 2...3),
            ColorfallCanyonsBandProfile(columns: 7, rows: 5, springs: 2, depressions: 5, smallest: 3...3),
            ColorfallCanyonsBandProfile(columns: 8, rows: 6, springs: 3, depressions: 8, smallest: 3...3),
            ColorfallCanyonsBandProfile(columns: 8, rows: 6, springs: 3, depressions: 8, smallest: 3...3),
        ]
        for band in 1...5 { #expect(ColorfallCanyonsBandProfile.of(band: band) == expected[band - 1]) }
        #expect(ColorfallCanyonsBandProfile.of(band: 0) == expected[0])
        #expect(ColorfallCanyonsBandProfile.of(band: -3) == expected[0])
        #expect(ColorfallCanyonsBandProfile.of(band: 6) == expected[4])
        #expect(ColorfallCanyonsBandProfile.of(band: 99) == expected[4])
        #expect(ColorfallCanyonsGenerator.maximumCandidates == 512)
        #expect(ColorfallCanyonsGenerator.tutorialLevels == 1...3)
    }

    @Test func candidatesAreDeterministic() {
        for entry in ColorfallCanyonsManifest.entries where entry.number % 20 == 1 || entry.number % 20 == 10 {
            var fingerprints: [String] = []
            for index in 0..<3 {
                let a = ColorfallCanyonsGenerator.candidate(entry, index: index)
                let b = ColorfallCanyonsGenerator.candidate(entry, index: index)
                #expect(a?.level == b?.level)
                #expect(a?.planted == b?.planted)
                #expect((a == nil) == (b == nil))
                if let a { fingerprints.append(a.level.fingerprint) }
            }
            // Different candidate indices draw different terrain.
            #expect(Set(fingerprints).count == fingerprints.count)
        }
    }

    @Test func generationIsDeterministic() throws {
        for entry in [ColorfallCanyonsManifest.entries[0], ColorfallCanyonsManifest.entries[24]] {
            let a: ColorfallCanyonsGenerated = try ColorfallCanyonsGenerator.generate(entry)
            let b: ColorfallCanyonsGenerated = try ColorfallCanyonsGenerator.generate(entry)
            #expect(a == b)
        }
    }

    @Test func generatedLevelsMeetTheirBand() throws {
        for entry in Self.sampled {
            let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsGenerator.generate(entry)
            let level: ColorfallCanyonsLevel = generated.level
            let profile: ColorfallCanyonsBandProfile = ColorfallCanyonsBandProfile.of(band: entry.band)
            #expect(generated.entry == entry)
            #expect(level.columns == profile.columns && level.rows == profile.rows)
            #expect(level.springs.count == profile.springs)
            #expect(level.budget == entry.budget && level.difficulty == entry.band && level.seed == entry.seed)
            let number: String = entry.number < 10 ? "00\(entry.number)" : entry.number < 100 ? "0\(entry.number)"
                : "\(entry.number)"
            #expect(level.id == "colorfall-canyons-\(number)")
            #expect(level.tutorial == (1...3).contains(entry.number))
            #expect((60...120).contains(level.tickLimit))
            #expect((3...6).contains(level.flowRate))
            for spring in level.springs {
                #expect((1...3).contains(spring.release) && (8...24).contains(spring.supply) && spring.open)
                #expect(spring.cell < 2 * level.columns && level.grounds[spring.cell] == .open)
            }
            #expect(Set(level.springs.map(\.color)).count == level.springs.count)
            #expect(!level.basins.isEmpty && level.basins.count >= min(profile.springs, 2))
            #expect(Set(level.basins.map(\.cell)).count == level.basins.count)
            // Basins sit where the planted routing pools: an open cell without a lower non-rock neighbour.
            var carved: [Int] = level.heights
            for edit in generated.planted {
                guard case .carve(let cell) = edit else {
                    Issue.record("planted edit \(edit) is not a carve")
                    continue
                }
                carved[cell] -= 1
            }
            let routing: [Int?] = ColorfallCanyonsSolver.routing(level, heights: carved)
            for basin in level.basins {
                #expect(level.grounds[basin.cell] == .open)
                #expect(routing[basin.cell] == nil, "basin \(basin.cell) of level \(entry.number) does not pool")
                #expect([50, 100, 150].contains(basin.tolerance))
                #expect(basin.toleratedWrong == 0)
                #expect(basin.capacity >= basin.fill && basin.fill >= 1)
                #expect(basin.shares.reduce(0, +) == 1_000)
            }
            #expect(level.grounds.contains(.drain))
            #expect(level.grounds[(level.rows - 1) * level.columns..<level.cellCount].contains(.drain))
        }
    }

    @Test func thePlantedPlanWinsAndTheDifficultyIsTheSolversResult() throws {
        for entry in Self.sampled {
            let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsGenerator.generate(entry)
            let level: ColorfallCanyonsLevel = generated.level
            let profile: ColorfallCanyonsBandProfile = ColorfallCanyonsBandProfile.of(band: entry.band)
            #expect(ColorfallCanyonsSolver.run(level, edits: generated.planted)?.verdict == .won)
            #expect(ColorfallCanyonsSolver.run(level, edits: [])?.verdict != .won)
            #expect(profile.smallest.contains(generated.solution.smallest))
            #expect(generated.solution.smallest <= generated.planted.count)
            #expect(ColorfallCanyonsSolver.run(level, edits: generated.solution.edits)?.verdict == .won)
            let difficulty: ColorfallCanyonsDifficulty = generated.difficulty
            #expect(difficulty.smallest == generated.solution.smallest)
            #expect(difficulty.work == generated.solution.work)
            #expect(difficulty.winTick == generated.solution.winTick)
            #expect(difficulty.springs == level.springs.count)
            #expect(difficulty.basins == level.basins.count)
            #expect(difficulty.protectedBasins == level.basins.filter(\.isProtected).count)
            #expect(difficulty.carvableCells
                == (0..<level.cellCount).filter { level.isCarvable($0, heights: level.heights) }.count)
        }
    }

    @Test func skippedCandidatesDoNotQualify() throws {
        for entry in [1, 2, 7, 21, 22].map({ ColorfallCanyonsManifest.entries[$0 - 1] }) {
            let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsGenerator.generate(entry)
            for index in 0..<generated.skipped {
                #expect(!Self.qualifies(entry, index: index), "entry \(entry.number) skipped qualifying \(index)")
            }
            #expect(Self.qualifies(entry, index: generated.skipped))
            let kept = ColorfallCanyonsGenerator.candidate(entry, index: generated.skipped)
            #expect(kept?.level == generated.level && kept?.planted == generated.planted)
        }
    }

    @Test func anEntryNoCandidateCanMeetIsRefusedByNumber() {
        // A budget of 0 is outside the level's budget range, so every candidate is refused by the level's rules.
        let entry = ColorfallCanyonsManifestEntry(number: 7, seed: ColorfallCanyonsManifest.entries[6].seed, band: 1,
                                                  budget: 0)
        #expect(ColorfallCanyonsGenerator.candidate(entry, index: 0) == nil)
        #expect(throws: ColorfallCanyonsError.generation(7)) {
            try ColorfallCanyonsGenerator.generate(entry)
        }
        #expect(ColorfallCanyonsError.generation(7).reasonCode == "r02-g05.generation")
        #expect(ColorfallCanyonsError.witness("x").reasonCode == "r02-g05.witness")
    }

    @Test func theCatalogDigestIsOrderSensitive() throws {
        let levels: [ColorfallCanyonsLevel] = try [0, 1, 20].map {
            try ColorfallCanyonsGenerator.generate(ColorfallCanyonsManifest.entries[$0]).level
        }
        let digest: String = ColorfallCanyonsGenerator.catalogDigest(levels)
        #expect(digest == PuzzleCatalog<ColorfallCanyonsRules>.digest(id: "colorfall-canyons",
                                                                       identities: levels.map(\.fingerprint)))
        #expect(ColorfallCanyonsGenerator.catalogID == "colorfall-canyons")
        #expect(digest == ColorfallCanyonsGenerator.catalogDigest(levels))
        #expect(digest != ColorfallCanyonsGenerator.catalogDigest(levels.reversed()))
        #expect(digest != ColorfallCanyonsGenerator.catalogDigest(Array(levels.prefix(2))))
    }

    @Test func theShuffleIsADeterministicPermutation() {
        for seed: UInt64 in [0, 1, 342, 0xc65b_c117_d84e_fa83] {
            let original: [Int] = Array(0..<17)
            var a: [Int] = original
            var b: [Int] = original
            var first = SeededRandom(seed: seed)
            var second = SeededRandom(seed: seed)
            ColorfallCanyonsGenerator.shuffle(&a, &first)
            ColorfallCanyonsGenerator.shuffle(&b, &second)
            #expect(a == b)
            #expect(a.sorted() == original)
        }
        var random = SeededRandom(seed: 9)
        var single: [Int] = [5]
        ColorfallCanyonsGenerator.shuffle(&single, &random)
        var empty: [Int] = []
        ColorfallCanyonsGenerator.shuffle(&empty, &random)
        #expect(single == [5] && empty.isEmpty)
        var c: [Int] = Array(0..<17)
        var d: [Int] = Array(0..<17)
        var r1 = SeededRandom(seed: 1)
        var r2 = SeededRandom(seed: 2)
        ColorfallCanyonsGenerator.shuffle(&c, &r1)
        ColorfallCanyonsGenerator.shuffle(&d, &r2)
        #expect(c != d)
    }
}
