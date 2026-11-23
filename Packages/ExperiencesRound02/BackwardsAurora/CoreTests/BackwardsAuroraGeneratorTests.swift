// BackwardsAuroraGeneratorTests — feature 392 (R02-G10-02) T-R02G1002-004 (FR-R02G1002-001, 003; SC-R02G1002-001,
// 003). Host checks of the generator: the five band profiles equal clarification Q1, the breaking limit per band, the
// level ids, candidate and generation determinism, every one of the 100 manifest entries generated and checked (id,
// band, budget, tutorial, wave length, bend limit at the target's worst bend, a smooth target, sections separated and
// within the band's lengths, β = 4k = 4 · solution.smallest, k within the band's range and the budget, band + 1
// checkpoints inside reversed sections where opening and target differ, the breaking limit, a winning witness and the
// difficulty metrics recomputed), skipped candidates re-checked as unqualified on a sample, and the internal `place`
// and `accepts` on hand cases. All 100 entries are generated once per process and shared. Explicit types, plain loops,
// short runs.
import Testing
import VisualCoreSimulation
@testable import BackwardsAuroraCore

@Suite("BackwardsAuroraGenerator")
struct BackwardsAuroraGeneratorTests {
    /// Every manifest entry generated once and shared by the tests (nil where generation threw).
    static let allResults: [BackwardsAuroraGenerated?] =
        BackwardsAuroraManifest.entries.map { try? BackwardsAuroraGenerator.generate($0) }

    /// The entries sampled for the skipped re-check and generation determinism.
    static let sampledNumbers: [Int] = [1, 2, 4, 21, 22, 41, 42, 61, 62, 81, 82, 100]

    /// Whether `level` fails one of the conditions `generate` requires of a candidate.
    static func unqualified(_ level: BackwardsAuroraLevel?, profile: BackwardsAuroraBandProfile) -> Bool {
        guard let level else { return true }
        let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
        if !profile.reversals.contains(bound.smallest) || bound.smallest > level.budget { return true }
        guard let solution: BackwardsAuroraSolution = BackwardsAuroraSolver.solve(level) else { return true }
        return solution.smallest != bound.smallest
    }

    /// The sections of a witness as (start, end), sorted by start.
    static func sections(_ actions: [BackwardsAuroraAction]) -> [(start: Int, end: Int)] {
        var result: [(start: Int, end: Int)] = []
        for action in actions {
            switch action {
            case let .reverse(start, end): result.append((start: start, end: end))
            }
        }
        result.sort { $0.start < $1.start }
        return result
    }

    /// Checks every generated level of `band` against clarification Q1.
    static func checkBand(_ band: Int) {
        let profile: BackwardsAuroraBandProfile = .of(band: band)
        var checked: Int = 0
        for (offset, entry) in BackwardsAuroraManifest.entries.enumerated() where entry.band == band {
            guard let generated: BackwardsAuroraGenerated = allResults[offset] else {
                Issue.record("level \(entry.number) did not generate")
                continue
            }
            checked += 1
            let level: BackwardsAuroraLevel = generated.level
            let n: Int = entry.number
            #expect(generated.entry == entry)
            #expect(level.id == BackwardsAuroraGenerator.levelID(n))
            #expect(level.seed == entry.seed)
            #expect(level.difficulty == band, "level \(n)")
            #expect(level.budget == entry.budget, "level \(n)")
            #expect(level.tutorial == (n <= 3), "level \(n)")
            #expect(profile.lengths.contains(level.count), "level \(n) length \(level.count)")
            #expect(level.shortest == BackwardsAuroraLevel.minimumSection)
            #expect(level.longest == level.count)
            #expect(level.bendLimit == max(1, level.target.worstBend), "level \(n)")
            #expect(level.target.isSmooth(limit: level.bendLimit), "level \(n)")
            #expect(level.breakingLimit == profile.breakingLimit(bendLimit: level.bendLimit), "level \(n)")

            let solution: BackwardsAuroraSolution = generated.solution
            let k: Int = solution.smallest
            #expect(solution.actions.count == k)
            #expect(profile.reversals.contains(k), "level \(n) k \(k)")
            #expect(k <= level.budget, "level \(n)")
            let bad: Int = BackwardsAuroraSolver.badBends(level.opening, limit: level.bendLimit)
            #expect(bad == 4 * k, "level \(n) β \(bad) k \(k)")
            #expect(generated.bound == BackwardsAuroraBound(badBends: bad))
            #expect(generated.bound.smallest == k)
            #expect(BackwardsAuroraSolver.wins(level, actions: solution.actions), "level \(n) witness does not win")
            #expect(generated.skipped >= 0 && generated.skipped < BackwardsAuroraGenerator.maxCandidates)

            let parts: [(start: Int, end: Int)] = sections(solution.actions)
            if let first = parts.first, let last = parts.last {
                #expect(first.start >= 2, "level \(n) first start \(first.start)")
                #expect(last.end <= level.count - 3, "level \(n) last end \(last.end)")
            }
            for (index, part) in parts.enumerated() {
                let length: Int = part.end - part.start + 1
                #expect(profile.sectionLengths.contains(length), "level \(n) section length \(length)")
                if index > 0 {
                    #expect(part.start >= parts[index - 1].end + 3, "level \(n) sections \(parts[index - 1]) \(part)")
                }
            }

            #expect(level.checkpoints.count == band + 1, "level \(n)")
            #expect(level.checkpoints.count == profile.checkpoints)
            for checkpoint in level.checkpoints {
                #expect(level.opening.samples[checkpoint] != level.target.samples[checkpoint],
                        "level \(n) checkpoint \(checkpoint)")
                var inside: Bool = false
                for part in parts where checkpoint >= part.start && checkpoint <= part.end { inside = true }
                #expect(inside, "level \(n) checkpoint \(checkpoint) outside the reversed sections")
            }

            var reversed: Int = 0
            var longest: Int = 0
            for part in parts {
                reversed += part.end - part.start + 1
                longest = max(longest, part.end - part.start + 1)
            }
            let expected: BackwardsAuroraDifficulty =
                BackwardsAuroraDifficulty(smallest: k, length: level.count, checkpoints: band + 1,
                                          reversedSamples: reversed, longestSection: longest, badBends: bad,
                                          bendLimit: level.bendLimit,
                                          breakingMargin: level.breakingLimit - level.bendLimit, work: solution.work)
            #expect(generated.difficulty == expected, "level \(n)")
        }
        #expect(checked == 20)
    }

    /// The band profiles equal clarification Q1 (clamped outside 1 … 5).
    @Test func bandProfiles() {
        let expected: [BackwardsAuroraBandProfile] = [
            BackwardsAuroraBandProfile(band: 1, lengths: 14...16, reversals: 2...3, sectionLengths: 2...4,
                                       checkpoints: 2, breakingMargin: nil),
            BackwardsAuroraBandProfile(band: 2, lengths: 18...22, reversals: 3...4, sectionLengths: 2...5,
                                       checkpoints: 3, breakingMargin: nil),
            BackwardsAuroraBandProfile(band: 3, lengths: 22...26, reversals: 4...5, sectionLengths: 2...6,
                                       checkpoints: 4, breakingMargin: 48),
            BackwardsAuroraBandProfile(band: 4, lengths: 26...30, reversals: 5...6, sectionLengths: 2...6,
                                       checkpoints: 5, breakingMargin: 32),
            BackwardsAuroraBandProfile(band: 5, lengths: 30...32, reversals: 6...7, sectionLengths: 2...6,
                                       checkpoints: 6, breakingMargin: 16),
        ]
        for band in 1...5 {
            let profile: BackwardsAuroraBandProfile = .of(band: band)
            #expect(profile == expected[band - 1], "band \(band)")
            #expect(profile.lengths.lowerBound >= 4 * profile.reversals.upperBound + 2, "band \(band) N ≥ 4k + 2")
        }
        #expect(BackwardsAuroraBandProfile.of(band: 0) == expected[0])
        #expect(BackwardsAuroraBandProfile.of(band: 9) == expected[4])
        #expect(BackwardsAuroraGenerator.maxCandidates == 256)
        #expect(BackwardsAuroraGenerator.placements == 16)
    }

    /// The breaking limit is 128 in bands 1 … 2 and min(128, L + margin) in bands 3 … 5.
    @Test func breakingLimits() {
        for limit in [1, 10, 64] {
            #expect(BackwardsAuroraBandProfile.of(band: 1).breakingLimit(bendLimit: limit) == 128)
            #expect(BackwardsAuroraBandProfile.of(band: 2).breakingLimit(bendLimit: limit) == 128)
        }
        #expect(BackwardsAuroraBandProfile.of(band: 3).breakingLimit(bendLimit: 10) == 58)
        #expect(BackwardsAuroraBandProfile.of(band: 3).breakingLimit(bendLimit: 64) == 112)
        #expect(BackwardsAuroraBandProfile.of(band: 4).breakingLimit(bendLimit: 10) == 42)
        #expect(BackwardsAuroraBandProfile.of(band: 4).breakingLimit(bendLimit: 100) == 128)
        #expect(BackwardsAuroraBandProfile.of(band: 5).breakingLimit(bendLimit: 10) == 26)
        #expect(BackwardsAuroraBandProfile.of(band: 5).breakingLimit(bendLimit: 120) == 128)
    }

    /// Level ids are `backwards-aurora-NNN`.
    @Test func levelIDs() {
        #expect(BackwardsAuroraGenerator.levelID(1) == "backwards-aurora-001")
        #expect(BackwardsAuroraGenerator.levelID(42) == "backwards-aurora-042")
        #expect(BackwardsAuroraGenerator.levelID(100) == "backwards-aurora-100")
        #expect(BackwardsAuroraGenerator.catalogID == "backwards-aurora")
    }

    /// `candidate(_:index:)` gives equal results twice for the first candidates of every band.
    @Test func candidateDeterminism() {
        for number in [1, 21, 41, 61, 81] {
            let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[number - 1]
            for index in 0..<8 {
                let a: BackwardsAuroraLevel? = BackwardsAuroraGenerator.candidate(entry, index: index)
                let b: BackwardsAuroraLevel? = BackwardsAuroraGenerator.candidate(entry, index: index)
                #expect(a == b, "level \(number) candidate \(index)")
            }
        }
    }

    /// `generate` gives equal results twice on the sampled entries, equal to the shared generation.
    @Test func generationDeterminism() throws {
        for number in Self.sampledNumbers {
            let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[number - 1]
            let a: BackwardsAuroraGenerated = try BackwardsAuroraGenerator.generate(entry)
            let b: BackwardsAuroraGenerated = try BackwardsAuroraGenerator.generate(entry)
            #expect(a == b, "level \(number)")
            #expect(Self.allResults[number - 1] == a, "level \(number)")
        }
    }

    /// Every band-1 level meets clarification Q1.
    @Test func band1Levels() { Self.checkBand(1) }

    /// Every band-2 level meets clarification Q1.
    @Test func band2Levels() { Self.checkBand(2) }

    /// Every band-3 level meets clarification Q1.
    @Test func band3Levels() { Self.checkBand(3) }

    /// Every band-4 level meets clarification Q1.
    @Test func band4Levels() { Self.checkBand(4) }

    /// Every band-5 level meets clarification Q1.
    @Test func band5Levels() { Self.checkBand(5) }

    /// All 100 levels generate with distinct fingerprints, and the catalog digest is stable and order-sensitive.
    @Test func catalog() {
        var levels: [BackwardsAuroraLevel] = []
        for result in Self.allResults {
            if let result { levels.append(result.level) }
        }
        #expect(levels.count == 100)
        var fingerprints: Set<String> = []
        for level in levels { fingerprints.insert(level.fingerprint) }
        #expect(fingerprints.count == 100)
        let digest: String = BackwardsAuroraGenerator.catalogDigest(levels)
        #expect(digest == BackwardsAuroraGenerator.catalogDigest(levels))
        #expect(digest != BackwardsAuroraGenerator.catalogDigest(Array(levels.reversed())))
    }

    /// Every candidate before the kept one is nil or not certified, on the sampled entries.
    @Test func skippedRechecked() {
        for number in Self.sampledNumbers {
            guard let generated: BackwardsAuroraGenerated = Self.allResults[number - 1] else {
                Issue.record("level \(number) did not generate")
                continue
            }
            let entry: BackwardsAuroraManifestEntry = generated.entry
            let profile: BackwardsAuroraBandProfile = .of(band: entry.band)
            for index in 0..<generated.skipped {
                let level: BackwardsAuroraLevel? = BackwardsAuroraGenerator.candidate(entry, index: index)
                #expect(Self.unqualified(level, profile: profile), "level \(number) candidate \(index) qualified")
            }
            let kept: BackwardsAuroraLevel? = BackwardsAuroraGenerator.candidate(entry, index: generated.skipped)
            #expect(kept == generated.level, "level \(number)")
            #expect(!Self.unqualified(kept, profile: profile), "level \(number)")
        }
    }

    /// `place` keeps sections separated, within the lengths and inside 2 … N − 3, on seeded draws of every band.
    @Test func placementShape() {
        for band in 1...5 {
            let profile: BackwardsAuroraBandProfile = .of(band: band)
            var random = SeededRandom(seed: UInt64(3_920 + band))
            for count in profile.lengths {
                for k in profile.reversals {
                    for _ in 0..<20 {
                        let parts: [(start: Int, end: Int)] =
                            BackwardsAuroraGenerator.place(count: count, k: k, lengths: profile.sectionLengths,
                                                           random: &random)
                        #expect(parts.count == k)
                        guard let first = parts.first, let last = parts.last else { continue }
                        #expect(first.start >= 2, "band \(band) N \(count) k \(k)")
                        #expect(last.end <= count - 3, "band \(band) N \(count) k \(k) last \(last.end)")
                        for (index, part) in parts.enumerated() {
                            #expect(profile.sectionLengths.contains(part.end - part.start + 1))
                            if index > 0 { #expect(part.start >= parts[index - 1].end + 3) }
                        }
                    }
                }
            }
        }
    }

    /// A straight sloped target accepts length-2 sections when the slope exceeds L (seam bends ±s and ±3s), and
    /// rejects them otherwise.
    @Test func acceptsSlopedTarget() throws {
        for slope in 1...3 {
            var samples: [Int] = []
            for i in 0..<16 { samples.append(slope * i - 24) }
            let target: BackwardsAuroraWave = try BackwardsAuroraWave(samples)
            #expect(target.worstBend == 0)
            let parts: [(start: Int, end: Int)] = [(start: 2, end: 3), (start: 6, end: 7), (start: 11, end: 12)]
            for limit in 1...3 {
                let accepted: Bool = BackwardsAuroraGenerator.accepts(parts, target: target, bendLimit: limit)
                #expect(accepted == (slope >= limit + 1), "slope \(slope) L \(limit)")
            }
            let alone: BackwardsAuroraWave = target.reversed(start: 6, end: 7)
            #expect(alone.bend(at: 5) == slope)
            #expect(alone.bend(at: 6) == -3 * slope)
            #expect(alone.bend(at: 7) == 3 * slope)
            #expect(alone.bend(at: 8) == -slope)
        }
    }

    /// A flat section is a palindrome and rejected; a section ending past N − 3 is rejected.
    @Test func acceptsRejectsFlatAndEdge() throws {
        var samples: [Int] = []
        for i in 0..<16 { samples.append(3 * i - 24) }
        samples[7] = samples[6]
        samples[8] = samples[6]
        let target: BackwardsAuroraWave = try BackwardsAuroraWave(samples)
        #expect(target.isPalindrome(start: 6, end: 8))
        let limit: Int = 1
        #expect(!BackwardsAuroraGenerator.accepts([(start: 6, end: 8)], target: target, bendLimit: limit))
        #expect(!BackwardsAuroraGenerator.accepts([(start: 2, end: 3), (start: 6, end: 8)], target: target,
                                                  bendLimit: limit))
        #expect(BackwardsAuroraGenerator.accepts([(start: 2, end: 3)], target: target, bendLimit: limit))
        #expect(BackwardsAuroraGenerator.accepts([(start: 12, end: 13)], target: target, bendLimit: limit))
        #expect(!BackwardsAuroraGenerator.accepts([(start: 13, end: 14)], target: target, bendLimit: limit))
    }
}
