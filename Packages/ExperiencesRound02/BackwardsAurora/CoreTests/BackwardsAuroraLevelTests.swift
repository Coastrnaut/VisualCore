// BackwardsAuroraLevelTests — feature 391 (R02-G10-01) T-R02G1001-002 (FR-R02G1001-001, 002, 003, 009, 011, 013, 014;
// SC-R02G1001-001, 005; clarifications Q1, Q2, Q5). Levels and the exact wave: the reason codes, every range refusal,
// the stored form's round trip with its fingerprint, damaged, edited and newer forms refused, names in words,
// hand-computed bends, seams, palindromes and distances, and the 500 seeded fixtures valid with known reversals that
// restore the target, never tear and win only on the last one. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import BackwardsAuroraCore

struct BackwardsAuroraLevelTests {
    /// The straight target 0, 2, 4, … 22 (every bend 0).
    static let straight: [Int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
    /// The straight target with the section [2, 5] reversed.
    static let folded: [Int] = [0, 2, 10, 8, 6, 4, 12, 14, 16, 18, 20, 22]

    /// A valid level with the given overrides: the folded opening, the straight target, checkpoints 2 and 9.
    static func level(id: String = "aurora-one", difficulty: Int = 1, opening: [Int] = folded,
                      target: [Int] = straight, checkpoints: [Int] = [9, 2], bendLimit: Int = 4,
                      breakingLimit: Int = 40, shortest: Int = 2, longest: Int = 12,
                      budget: Int = 3) throws -> BackwardsAuroraLevel {
        try BackwardsAuroraLevel(id: id, seed: 9, difficulty: difficulty, opening: BackwardsAuroraWave(opening),
                                 target: BackwardsAuroraWave(target), checkpoints: checkpoints, bendLimit: bendLimit,
                                 breakingLimit: breakingLimit, shortest: shortest, longest: longest, budget: budget)
    }

    /// The reason codes are the stable `r02-g10.*` set.
    @Test func reasonCodesAreStable() {
        let errors: [BackwardsAuroraError] = [.level("x"), .action("x"), .noop, .stage, .stale, .newerSchema(2),
                                              .malformed("x")]
        let codes: [String] = errors.map(\.reasonCode)
        #expect(codes == ["r02-g10.level", "r02-g10.action", "r02-g10.noop", "r02-g10.stage", "r02-g10.stale",
                          "r02-g10.newer-schema", "r02-g10.malformed"])
    }

    /// Every range and rule is refused with its name.
    @Test func everyRangeIsRefusedByName() throws {
        #expect(throws: BackwardsAuroraError.level("length")) { try BackwardsAuroraWave(Array(repeating: 0, count: 11)) }
        #expect(throws: BackwardsAuroraError.level("length")) { try BackwardsAuroraWave(Array(repeating: 0, count: 33)) }
        #expect(throws: BackwardsAuroraError.level("samples")) { try BackwardsAuroraWave(Self.straight + [65]) }
        #expect(throws: BackwardsAuroraError.level("samples")) { try BackwardsAuroraWave(Self.straight + [-65]) }
        let extremes: BackwardsAuroraWave = try BackwardsAuroraWave(Array(repeating: -64, count: 16)
                                                                    + Array(repeating: 64, count: 16))
        #expect(extremes.count == 32)
        #expect(throws: BackwardsAuroraError.level("id")) { try Self.level(id: "Bad Id") }
        #expect(throws: BackwardsAuroraError.level("id")) { try Self.level(id: "") }
        #expect(throws: BackwardsAuroraError.level("difficulty")) { try Self.level(difficulty: 0) }
        #expect(throws: BackwardsAuroraError.level("difficulty")) { try Self.level(difficulty: 6) }
        #expect(throws: BackwardsAuroraError.level("target")) { try Self.level(target: Self.straight + [24]) }
        var other: [Int] = Self.straight
        other[11] = 23
        #expect(throws: BackwardsAuroraError.level("target")) { try Self.level(target: other) }
        #expect(throws: BackwardsAuroraError.level("checkpoints")) { try Self.level(checkpoints: [2]) }
        #expect(throws: BackwardsAuroraError.level("checkpoints")) { try Self.level(checkpoints: [2, 2]) }
        #expect(throws: BackwardsAuroraError.level("checkpoints")) { try Self.level(checkpoints: [2, 12]) }
        #expect(throws: BackwardsAuroraError.level("checkpoints")) { try Self.level(checkpoints: [-1, 2]) }
        #expect(throws: BackwardsAuroraError.level("checkpoints")) {
            try Self.level(checkpoints: [0, 1, 2, 3, 4, 5, 6, 7, 8])
        }
        #expect(throws: BackwardsAuroraError.level("bend")) { try Self.level(bendLimit: 0, breakingLimit: 10) }
        #expect(throws: BackwardsAuroraError.level("bend")) { try Self.level(bendLimit: 65, breakingLimit: 100) }
        #expect(throws: BackwardsAuroraError.level("breaking")) { try Self.level(bendLimit: 10, breakingLimit: 9) }
        #expect(throws: BackwardsAuroraError.level("breaking")) { try Self.level(breakingLimit: 129) }
        #expect(throws: BackwardsAuroraError.level("shortest")) { try Self.level(shortest: 1) }
        #expect(throws: BackwardsAuroraError.level("shortest")) { try Self.level(shortest: 13) }
        #expect(throws: BackwardsAuroraError.level("longest")) { try Self.level(shortest: 4, longest: 3) }
        #expect(throws: BackwardsAuroraError.level("longest")) { try Self.level(longest: 13) }
        #expect(throws: BackwardsAuroraError.level("budget")) { try Self.level(budget: 0) }
        #expect(throws: BackwardsAuroraError.level("budget")) { try Self.level(budget: 41) }
        #expect(throws: BackwardsAuroraError.level("solved")) { try Self.level(opening: Self.straight) }
        let edges: BackwardsAuroraLevel = try Self.level(checkpoints: [0, 1, 2, 3, 4, 5, 6, 7], bendLimit: 64,
                                                         breakingLimit: 128, shortest: 12, longest: 12, budget: 40)
        #expect(edges.checkpoints.count == 8)
        #expect(edges.sectionLengths == 12...12)
        // An opening wave whose checkpoints all match but which is too sharp is not solved.
        let sharp: BackwardsAuroraLevel = try Self.level(checkpoints: [0, 11])
        #expect(sharp.matched(sharp.opening) == [true, true])
        #expect(!sharp.wins(sharp.opening))
    }

    /// The stored form round-trips with its fingerprint; damaged, edited and newer forms are refused.
    @Test func theStoredFormRoundTripsAndRefusesDamage() throws {
        let level: BackwardsAuroraLevel = try Self.level()
        #expect(level.checkpoints == [2, 9])
        let data: Data = level.encoded()
        #expect(try BackwardsAuroraLevel.decode(data) == level)
        #expect(try JSONDecoder().decode(BackwardsAuroraLevel.self, from: data) == level)
        #expect(try Self.level(checkpoints: [2, 9]).fingerprint == level.fingerprint)
        #expect(try Self.level(budget: 4).fingerprint != level.fingerprint)
        let text: String = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema\":1"))
        #expect(text.contains("\"opening\":[0,2,10,8,6,4,12,14,16,18,20,22]"))
        // Damaged.
        #expect(throws: BackwardsAuroraError.malformed("unreadable")) {
            try BackwardsAuroraLevel.decode(Data("{".utf8))
        }
        #expect(throws: BackwardsAuroraError.malformed("unreadable")) {
            try BackwardsAuroraLevel.decode(Data(text.replacingOccurrences(of: "\"budget\":3,", with: "").utf8))
        }
        // Edited: a new value with the old fingerprint, or a value out of range.
        #expect(throws: BackwardsAuroraError.malformed("fingerprint")) {
            try BackwardsAuroraLevel.decode(Data(text.replacingOccurrences(of: "\"budget\":3", with: "\"budget\":4").utf8))
        }
        #expect(throws: BackwardsAuroraError.malformed("r02-g10.level")) {
            try BackwardsAuroraLevel.decode(Data(text.replacingOccurrences(of: "\"budget\":3", with: "\"budget\":0").utf8))
        }
        #expect(throws: BackwardsAuroraError.malformed("r02-g10.level")) {
            try BackwardsAuroraLevel.decode(Data(text.replacingOccurrences(of: "[0,2,10,8,6,4,", with: "[0,2,99,8,6,4,").utf8))
        }
        #expect(throws: BackwardsAuroraError.malformed("r02-g10.level")) {
            try BackwardsAuroraLevel.decode(Data(text.replacingOccurrences(of: "[0,2,10,8,6,4,", with: "[0,2,4,6,8,10,").utf8))
        }
        // Newer and older schemas.
        #expect(throws: BackwardsAuroraError.newerSchema(2)) {
            try BackwardsAuroraLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8))
        }
        #expect(throws: BackwardsAuroraError.malformed("schema 0")) {
            try BackwardsAuroraLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0").utf8))
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(BackwardsAuroraLevel.self,
                                     from: Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8))
        }
    }

    /// Bends, seams, palindromes and distances agree with hand computation.
    @Test func theWaveAgreesWithHandComputation() throws {
        let folded: BackwardsAuroraWave = try BackwardsAuroraWave(Self.folded)
        let straight: BackwardsAuroraWave = try BackwardsAuroraWave(Self.straight)
        #expect(folded.interior == 1...10)
        #expect(folded.bends == [6, -10, 0, 0, 10, -6, 0, 0, 0, 0])
        #expect(folded.worstBend == 10)
        #expect(folded.isSmooth(limit: 10))
        #expect(!folded.isSmooth(limit: 9))
        #expect(straight.bends == Array(repeating: 0, count: 10))
        #expect(folded.reversed(start: 2, end: 5) == straight)
        #expect(straight.reversed(start: 2, end: 5) == folded)
        #expect(BackwardsAuroraWave.seams(start: 2, end: 5, count: 12) == [1, 2, 5, 6])
        #expect(BackwardsAuroraWave.seams(start: 0, end: 11, count: 12) == [])
        #expect(BackwardsAuroraWave.seams(start: 0, end: 3, count: 12) == [3, 4])
        #expect(BackwardsAuroraWave.seams(start: 1, end: 2, count: 12) == [1, 2, 3])
        #expect(BackwardsAuroraWave.seams(start: 9, end: 11, count: 12) == [8, 9])
        #expect(folded.distance(to: straight) == (numerator: 16, denominator: 132))
        #expect(straight.distance(to: straight) == (numerator: 0, denominator: 132))
        let zero: BackwardsAuroraWave = try BackwardsAuroraWave(Array(repeating: 0, count: 12))
        #expect(zero.distance(to: zero) == (numerator: 0, denominator: 1))
        let mirrored: BackwardsAuroraWave = try BackwardsAuroraWave([1, 5, 7, 5, 1, 0, 0, 3, 3, 9, 9, 9])
        #expect(mirrored.isPalindrome(start: 0, end: 4))
        #expect(mirrored.isPalindrome(start: 5, end: 6))
        #expect(mirrored.isPalindrome(start: 9, end: 11))
        #expect(!mirrored.isPalindrome(start: 0, end: 3))
        #expect(!mirrored.isPalindrome(start: 6, end: 7))
    }

    /// Samples, checkpoints, bends, reversals and the level are named in words.
    @Test func everythingIsNamedInWords() throws {
        let level: BackwardsAuroraLevel = try Self.level()
        let wave: BackwardsAuroraWave = level.opening
        #expect(level.sampleName(2, wave: wave) == "sample at position 2: height 10")
        #expect(level.checkpointName(0, wave: wave) == "checkpoint 1 at position 2: height 10, target 4, not matched")
        #expect(level.checkpointName(1, wave: wave) == "checkpoint 2 at position 9: height 18, target 18, matched")
        #expect(level.bendName(2, wave: wave) == "bend at position 2: 10 of limit 4")
        #expect(level.bendDescription(wave) == "worst bend 10 of limit 4, too sharp")
        #expect(level.bendDescription(level.target) == "worst bend 0 of limit 4, smooth")
        #expect(BackwardsAuroraLevel.reversalsText(1) == "1 reversal left")
        #expect(BackwardsAuroraLevel.reversalsText(0) == "0 reversals left")
        #expect(level.targetDescription() == "12 samples; 2 checkpoints at positions 2, 9; bend limit 4, "
                + "breaking limit 40; sections of 2 to 12 samples; 3 reversals")
        #expect(level.matched(wave) == [false, true])
        #expect(level.wins(level.target))
        #expect(!level.wins(wave))
    }

    /// The 500 seeded fixtures are valid levels whose known reversals restore the target without tearing and win only
    /// on the last one.
    @Test func theFixturesWinOnlyOnTheirLastKnownReversal() throws {
        let fixtures: [BackwardsAuroraFixture] = BackwardsAuroraFixtures.fixtures(500)
        var reversals: Int = 0
        for fixture in fixtures {
            let level: BackwardsAuroraLevel = fixture.level
            #expect(!level.wins(level.opening))
            #expect(level.budget >= fixture.sections.count)
            #expect(level.bendLimit >= level.target.worstBend)
            var wave: BackwardsAuroraWave = level.opening
            for (index, section) in fixture.sections.enumerated() {
                #expect(level.sectionLengths.contains(section.end - section.start + 1))
                #expect(!wave.isPalindrome(start: section.start, end: section.end))
                wave = wave.reversed(start: section.start, end: section.end)
                #expect(wave == fixture.waves[index])
                for k in BackwardsAuroraWave.seams(start: section.start, end: section.end, count: wave.count) {
                    #expect(abs(wave.bend(at: k)) <= level.breakingLimit)
                }
                #expect(level.wins(wave) == (index == fixture.sections.count - 1))
                reversals += 1
            }
            #expect(wave == level.target)
            #expect(try BackwardsAuroraLevel.decode(level.encoded()) == level)
        }
        #expect(reversals >= 500)
        #expect(Set(fixtures.map(\.level.fingerprint)).count == 500)
    }
}
