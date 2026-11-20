// AuroraLoomLevelTests — feature 301 (R02-G01-01) T-R02G0101-002 (FR-R02G0101-001, 007, 009; SC-R02G0101-005;
// clarifications Q1, Q2, Q5). Level refusals and reason codes; a start that already wins is refused; the period; the
// stored form round-trips byte for byte; damaged, newer and edited forms are refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreSimulation

@Suite struct AuroraLoomLevelTests {
    static func ribbons(_ omega: Int = 64) -> [AuroraLoomRibbon] {
        [try! AuroraLoomRibbon(wave: 1, phase: 2, omega: omega), try! AuroraLoomRibbon(wave: 3, phase: 4, omega: omega),
         try! AuroraLoomRibbon(wave: 5, phase: 6, omega: omega)]
    }

    static func gates() -> [AuroraLoomGate] {
        [try! AuroraLoomGate(position: 2, target: 2_000), try! AuroraLoomGate(position: 5, target: 100),
         try! AuroraLoomGate(position: 9, target: 3_000), try! AuroraLoomGate(position: 14, target: 700)]
    }

    static func level(id: String = "lvl-1", band: Int = 1, ribbons: [AuroraLoomRibbon] = ribbons(),
                      gates: [AuroraLoomGate] = gates(), omega: Int = 64, tolerance: Int = 32,
                      allowance: Int = 9) throws(AuroraLoomError) -> AuroraLoomLevel {
        try AuroraLoomLevel(id: id, seed: 2_301, band: band, ribbons: ribbons, gates: gates, omega: omega,
                            tolerance: tolerance, allowance: allowance)
    }

    @Test func refusalsAndCodes() throws {
        #expect(throws: AuroraLoomError.level("wave")) { try AuroraLoomRibbon(wave: 16, phase: 0, omega: 1) }
        #expect(throws: AuroraLoomError.level("phase")) { try AuroraLoomRibbon(wave: 0, phase: -1, omega: 1) }
        #expect(throws: AuroraLoomError.level("omega")) { try AuroraLoomRibbon(wave: 0, phase: 0, omega: 257) }
        #expect(throws: AuroraLoomError.level("position")) { try AuroraLoomGate(position: 0, target: 0) }
        #expect(throws: AuroraLoomError.level("position")) { try AuroraLoomGate(position: 16, target: 0) }
        #expect(throws: AuroraLoomError.level("target")) { try AuroraLoomGate(position: 1, target: 4_096) }
        #expect(throws: AuroraLoomError.level("id")) { try Self.level(id: "Bad Id") }
        #expect(throws: AuroraLoomError.level("band")) { try Self.level(band: 6) }
        #expect(throws: AuroraLoomError.level("ribbons")) { try Self.level(ribbons: Array(Self.ribbons().prefix(2))) }
        #expect(throws: AuroraLoomError.level("gates")) { try Self.level(gates: Array(Self.gates().prefix(3))) }
        var same: [AuroraLoomGate] = Self.gates()
        same[3] = try AuroraLoomGate(position: 2, target: 5)
        #expect(throws: AuroraLoomError.level("positions")) { try Self.level(gates: same) }
        #expect(throws: AuroraLoomError.level("omega")) { try Self.level(omega: 48) }
        #expect(throws: AuroraLoomError.level("omega")) { try Self.level(omega: 512) }
        #expect(throws: AuroraLoomError.level("tolerance")) { try Self.level(tolerance: 0) }
        #expect(throws: AuroraLoomError.level("tolerance")) { try Self.level(tolerance: 513) }
        #expect(throws: AuroraLoomError.level("allowance")) { try Self.level(allowance: 65) }
        let codes: [(AuroraLoomError, String)] = [
            (.level("x"), "r02-g01.level"), (.move("x"), "r02-g01.move"), (.stage, "r02-g01.stage"),
            (.stale, "r02-g01.stale"), (.allowance, "r02-g01.allowance"), (.newerSchema(2), "r02-g01.newer-schema"),
            (.malformed("x"), "r02-g01.malformed"),
        ]
        for (error, code) in codes { #expect(error.reasonCode == code) }
    }

    @Test func aStartThatAlreadyWinsIsRefused() throws {
        // All ribbons at (wave 2, phase 3) and targets built from them: the start wins.
        var ribbons: [AuroraLoomRibbon] = []
        for _ in 0..<3 { ribbons.append(try AuroraLoomRibbon(wave: 2, phase: 3, omega: 32)) }
        var gates: [AuroraLoomGate] = []
        let positions: [Int] = [1, 4, 7, 11]
        for p in positions { gates.append(try AuroraLoomGate(position: p, target: (2 * p * 16 + 3 * 256) % 4_096)) }
        #expect(throws: AuroraLoomError.level("start")) {
            try Self.level(ribbons: ribbons, gates: gates, omega: 32)
        }
    }

    @Test func periodAndFixtures() throws {
        let level = try Self.level(omega: 64)
        #expect(level.period == 64)
        #expect(try Self.level(omega: 1).period == 4_096)
        #expect(level.fingerprint.count == 64)
        var random = SeededRandom(seed: 2_301)
        for _ in 0..<200 {
            let fixture = AuroraLoomFixture.next(&random)
            #expect(AuroraLoomHarmony.wins(fixture.winning, level: fixture.level))
            #expect(!AuroraLoomHarmony.wins(fixture.level.startSteps, level: fixture.level))
        }
    }

    @Test func storedFormRoundTripsAndRefusesDamage() throws {
        var random = SeededRandom(seed: 2_301)
        for _ in 0..<50 {
            let level = AuroraLoomFixture.next(&random).level
            let data = level.encoded()
            let back = try AuroraLoomLevel.decode(data)
            #expect(back == level)
            #expect(back.encoded() == data)
            #expect(try JSONDecoder().decode(AuroraLoomLevel.self, from: data) == level)
        }
        let level = try Self.level()
        let text = String(decoding: level.encoded(), as: UTF8.self)
        #expect(throws: AuroraLoomError.newerSchema(2)) {
            try AuroraLoomLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8))
        }
        #expect(throws: AuroraLoomError.malformed("schema 0")) {
            try AuroraLoomLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0").utf8))
        }
        #expect(throws: AuroraLoomError.malformed("unreadable")) { try AuroraLoomLevel.decode(Data("nope".utf8)) }
        #expect(throws: AuroraLoomError.malformed("unreadable")) {
            try AuroraLoomLevel.decode(Data(text.replacingOccurrences(of: "\"band\":1,", with: "").utf8))
        }
        #expect(throws: AuroraLoomError.malformed("r02-g01.level")) {
            try AuroraLoomLevel.decode(Data(text.replacingOccurrences(of: "\"tolerance\":32", with: "\"tolerance\":0").utf8))
        }
        // An edited value with the old fingerprint.
        #expect(throws: AuroraLoomError.malformed("fingerprint")) {
            try AuroraLoomLevel.decode(Data(text.replacingOccurrences(of: "\"allowance\":9", with: "\"allowance\":10").utf8))
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AuroraLoomLevel.self,
                                     from: Data(text.replacingOccurrences(of: "\"allowance\":9", with: "\"allowance\":10").utf8))
        }
    }
}
