// HueCompassLevelTests — feature 331 (R02-G04-01) T-R02G0401-002 (FR-R02G0401-001, 008, 010; SC-R02G0401-005;
// clarifications Q1, Q3, Q5). Host checks of the level: every range refusal with its name, the start rule (never
// already within the bearing tolerance), bands, clues and acceptance on a hand-made level, the stored form (exact round
// trip, fingerprint, sorted keys) and the refusal of damaged, edited and newer stored forms; the reason codes. Fixtures
// seed 2_331. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import HueCompassCore

@Suite struct HueCompassLevelTests {
    static func level(offset: Int = 0, fog: [Int] = Array(repeating: 1, count: 96), target: Int = 10, start: Int = 50,
                      bearingTolerance: Int = 1, bandTolerance: Int = 0, allowance: Int = 6, id: String = "hand",
                      band: Int = 1) throws -> HueCompassLevel {
        try HueCompassLevel(id: id, seed: 2_331, band: band, offset: offset, fog: fog, target: target, start: start,
                            bearingTolerance: bearingTolerance, bandTolerance: bandTolerance, allowance: allowance)
    }

    @Test func aValidLevelAndItsRangeRefusals() throws {
        let level: HueCompassLevel = try Self.level()
        #expect(level.fingerprint.count == 64 && level.target == 10 && level.start == 50)
        #expect(throws: HueCompassError.level("id")) { try Self.level(id: "Hand") }
        #expect(throws: HueCompassError.level("band")) { try Self.level(band: 0) }
        #expect(throws: HueCompassError.level("offset")) { try Self.level(offset: 24) }
        #expect(throws: HueCompassError.level("fog")) { try Self.level(fog: Array(repeating: 1, count: 95)) }
        var dense: [Int] = Array(repeating: 1, count: 96)
        dense[7] = 10
        #expect(throws: HueCompassError.level("fog")) { try Self.level(fog: dense) }
        #expect(throws: HueCompassError.level("target")) { try Self.level(target: 96) }
        #expect(throws: HueCompassError.level("start")) { try Self.level(start: -1) }
        #expect(throws: HueCompassError.level("bearing-tolerance")) { try Self.level(bearingTolerance: 5) }
        #expect(throws: HueCompassError.level("band-tolerance")) { try Self.level(bandTolerance: 3) }
        #expect(throws: HueCompassError.level("allowance")) { try Self.level(allowance: 1) }
        #expect(throws: HueCompassError.level("allowance")) { try Self.level(allowance: 25) }
    }

    @Test func theStartIsNeverAlreadyWithinTheBearingTolerance() throws {
        #expect(throws: HueCompassError.level("solved-at-start")) { try Self.level(target: 10, start: 11) }
        #expect(throws: HueCompassError.level("solved-at-start")) { try Self.level(target: 0, start: 95) }
        #expect(throws: HueCompassError.level("solved-at-start")) { try Self.level(target: 10, start: 10) }
        #expect(try Self.level(target: 10, start: 12).start == 12)
        #expect(try Self.level(target: 0, start: 94, bearingTolerance: 1).start == 94)
    }

    @Test func bandsCluesAndAcceptanceOnAHandMadeLevel() throws {
        var fog: [Int] = Array(repeating: 0, count: 96)
        for k in 0..<96 { fog[k] = k % 10 }
        let level: HueCompassLevel = try Self.level(offset: 5, fog: fog, target: 10, start: 50, bearingTolerance: 2,
                                                    bandTolerance: 1)
        #expect(level.targetBand == (10 / 4 + 5) % 24)
        #expect(level.band(of: 95) == (23 + 5) % 24)
        let atTarget: HueCompassClue = level.clue(at: 10)
        #expect(atTarget.hueGap == 0 && atTarget.depth == 0)
        let neighbour: HueCompassClue = level.clue(at: 11)
        #expect(neighbour.depth == 0)
        let near: HueCompassClue = level.clue(at: 14)
        #expect(near.depth == fog[11] + fog[12] + fog[13] && near.hueGap == 1)
        let wrapped: HueCompassClue = level.clue(at: 94)
        var wrappedDepth: Int = 0
        for k in [95, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9] { wrappedDepth += fog[k] }
        #expect(wrapped.depth == wrappedDepth)
        // Opposite bearings: the counter-clockwise arc from the probe, 59 … 95 then 0 … 9.
        let opposite: HueCompassClue = level.clue(at: 58)
        var oppositeDepth: Int = 0
        for k in 59..<96 { oppositeDepth += fog[k] }
        for k in 0..<10 { oppositeDepth += fog[k] }
        #expect(opposite.depth == oppositeDepth && opposite.hueGap == 12)
        #expect(level.accepts(bearing: 12, band: level.targetBand + 1))
        #expect(!level.accepts(bearing: 13, band: level.targetBand))
        #expect(!level.accepts(bearing: 10, band: level.targetBand + 2))
        #expect(level.accepts(bearing: 8, band: level.targetBand - 1))
    }

    @Test func storedLevelsRoundTripExactly() throws {
        for index in 0..<40 {
            let level: HueCompassLevel = HueCompassFixtures.fixture(index, tutorial: index % 2 == 0).level
            let data: Data = level.encoded()
            let back: HueCompassLevel = try HueCompassLevel.decode(data)
            #expect(back == level && back.encoded() == data)
            let viaCodable: HueCompassLevel = try JSONDecoder().decode(HueCompassLevel.self, from: data)
            #expect(viaCodable == level)
            let text: String = String(decoding: data, as: UTF8.self)
            #expect(text.hasPrefix("{\"allowance\":") && text.contains("\"fingerprint\":\"\(level.fingerprint)\""))
        }
    }

    @Test func damagedEditedAndNewerFormsAreRefused() throws {
        let level: HueCompassLevel = HueCompassFixtures.fixture(3).level
        let text: String = String(decoding: level.encoded(), as: UTF8.self)
        #expect(throws: HueCompassError.malformed("unreadable")) { try HueCompassLevel.decode(Data("{".utf8)) }
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(throws: HueCompassError.newerSchema(2)) { try HueCompassLevel.decode(Data(newer.utf8)) }
        let older: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")
        #expect(throws: HueCompassError.malformed("schema 0")) { try HueCompassLevel.decode(Data(older.utf8)) }
        let edited: String = text.replacingOccurrences(of: "\"target\":\(level.target)",
                                                       with: "\"target\":\((level.target + 48) % 96)")
        #expect(throws: HueCompassError.malformed("fingerprint")) { try HueCompassLevel.decode(Data(edited.utf8)) }
        let broken: String = text.replacingOccurrences(of: "\"offset\":\(level.offset)", with: "\"offset\":30")
        #expect(throws: HueCompassError.malformed("r02-g04.level")) { try HueCompassLevel.decode(Data(broken.utf8)) }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(HueCompassLevel.self, from: Data(edited.utf8)) }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(HueCompassLevel.self, from: Data(newer.utf8)) }
    }

    @Test func reasonCodesAreStable() {
        let codes: [String] = [HueCompassError.level("x"), .action("range"), .stage, .stale, .allowance,
                               .newerSchema(2), .malformed("x")].map(\.reasonCode)
        #expect(codes == ["r02-g04.level", "r02-g04.action", "r02-g04.stage", "r02-g04.stale", "r02-g04.allowance",
                          "r02-g04.newer-schema", "r02-g04.malformed"])
    }

    @Test func everyFixtureIsValidAndItsSolutionSelectsAnAcceptedPair() {
        for index in 0..<500 {
            let fixture: HueCompassFixture = HueCompassFixtures.fixture(index)
            guard case .select(let bearing, let band) = fixture.solution.last else {
                Issue.record("fixture \(index) does not end with a selection")
                continue
            }
            #expect(fixture.level.accepts(bearing: bearing, band: band))
            #expect(fixture.solution.count <= 3)
        }
    }
}
