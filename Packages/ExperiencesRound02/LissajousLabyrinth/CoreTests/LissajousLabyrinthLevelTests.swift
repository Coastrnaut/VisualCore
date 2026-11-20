// LissajousLabyrinthLevelTests — feature 311 (R02-G02-01) T-R02G0201-002 (FR-R02G0201-001, 002, 007, 009;
// SC-R02G0201-001, 005). The pinned sine table, level refusals and codes, the stored form and the fixtures' safe setting.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
@testable import LissajousLabyrinthCore
import Testing
import VisualCoreSimulation

@Suite struct LissajousLabyrinthLevelTests {
    @Test func sineTableIsPinnedAndWithinOneUnitOfSine() {
        #expect(LissajousLabyrinthSine.tableDigest == "aa21b9ef1150ae4e0576f3100626994fc5f55c7cf6c50718da2312dd8cd98c79")
        for k in 0..<4_096 {
            let exact: Double = 1_024 * Foundation.sin(2 * Double.pi * Double(k) / 4_096)
            #expect(abs(Double(LissajousLabyrinthSine.sin(k)) - exact) <= 0.5 + 1e-9)
        }
        #expect(LissajousLabyrinthSine.sin(1_024) == 1_024)
        #expect(LissajousLabyrinthSine.sin(-1_024) == -1_024)
        #expect(LissajousLabyrinthSine.cos(0) == 1_024)
        #expect(LissajousLabyrinthSine.sin(4_096 + 7) == LissajousLabyrinthSine.sin(7))
    }

    @Test func invalidValuesAreRefusedWithCodes() throws {
        #expect(throws: LissajousLabyrinthError.level("centre")) { try LissajousLabyrinthBall(x: 5_001, y: 0, z: 0, radius: 64) }
        #expect(throws: LissajousLabyrinthError.level("radius")) { try LissajousLabyrinthBall(x: 0, y: 0, z: 0, radius: 63) }
        #expect(throws: LissajousLabyrinthError.level("radius")) { try LissajousLabyrinthBall(x: 0, y: 0, z: 0, radius: 1_025) }
        var random = SeededRandom(seed: 2_311)
        let f = LissajousLabyrinthFixture.next(&random)
        let l = f.level
        func make(id: String = "x", band: Int = 1, amplitudes: [Int]? = nil, frequencyC: Int? = nil,
                  start: LissajousLabyrinthDials? = nil, checkpoints: [LissajousLabyrinthBall]? = nil,
                  obstacles: [LissajousLabyrinthBall]? = nil, allowance: Int = 5) throws(LissajousLabyrinthError) {
            _ = try LissajousLabyrinthLevel(id: id, seed: 1, band: band, amplitudes: amplitudes ?? l.amplitudes,
                                            frequencyC: frequencyC ?? l.frequencyC, start: start ?? l.start,
                                            checkpoints: checkpoints ?? l.checkpoints, obstacles: obstacles ?? l.obstacles,
                                            allowance: allowance)
        }
        #expect(throws: LissajousLabyrinthError.level("id")) { try make(id: "Bad Id") }
        #expect(throws: LissajousLabyrinthError.level("band")) { try make(band: 6) }
        #expect(throws: LissajousLabyrinthError.level("amplitudes")) { try make(amplitudes: [1, 2]) }
        #expect(throws: LissajousLabyrinthError.level("amplitudes")) { try make(amplitudes: [1, 5, 2]) }
        #expect(throws: LissajousLabyrinthError.level("frequency-c")) { try make(frequencyC: 10) }
        let notCoprime = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 4, phaseA: 0, phaseC: 0)
        #expect(throws: LissajousLabyrinthError.level("start")) { try make(start: notCoprime) }
        let badPhase = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 16, phaseC: 0)
        #expect(throws: LissajousLabyrinthError.level("start")) { try make(start: badPhase) }
        #expect(throws: LissajousLabyrinthError.level("checkpoints")) { try make(checkpoints: []) }
        let seven: [LissajousLabyrinthBall] = Array(repeating: l.checkpoints[0], count: 7)
        #expect(throws: LissajousLabyrinthError.level("checkpoints")) { try make(checkpoints: seven) }
        let nine: [LissajousLabyrinthBall] = Array(repeating: try LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000,
                                                                                          radius: 64), count: 9)
        #expect(throws: LissajousLabyrinthError.level("obstacles")) { try make(obstacles: nine) }
        #expect(throws: LissajousLabyrinthError.level("allowance")) { try make(allowance: 0) }
        #expect(throws: LissajousLabyrinthError.level("allowance")) { try make(allowance: 65) }
        #expect(throws: LissajousLabyrinthError.level("won-at-start")) { try make(start: f.safe) }
        let codes: [String] = [LissajousLabyrinthError.level("x").reasonCode, LissajousLabyrinthError.move("x").reasonCode,
                               LissajousLabyrinthError.stage.reasonCode, LissajousLabyrinthError.stale.reasonCode,
                               LissajousLabyrinthError.allowance.reasonCode,
                               LissajousLabyrinthError.newerSchema(2).reasonCode,
                               LissajousLabyrinthError.malformed("x").reasonCode]
        #expect(codes == ["r02-g02.level", "r02-g02.move", "r02-g02.stage", "r02-g02.stale", "r02-g02.allowance",
                          "r02-g02.newer-schema", "r02-g02.malformed"])
    }

    @Test func fixturesWinWithTheirSafeSettingAndNotAtTheStart() {
        var random = SeededRandom(seed: 2_311)
        for _ in 0..<200 {
            let f = LissajousLabyrinthFixture.next(&random)
            #expect(LissajousLabyrinthLap.verdict(f.safe, level: f.level) == .won)
            #expect(LissajousLabyrinthLap.verdict(f.level.start, level: f.level) != .won)
            #expect(f.safe.isValid)
        }
    }

    @Test func storedFormRoundTripsAndRefusesDamage() throws {
        var random = SeededRandom(seed: 2_312)
        for _ in 0..<20 {
            let level = LissajousLabyrinthFixture.next(&random).level
            let data: Data = level.encoded()
            let decoded = try LissajousLabyrinthLevel.decode(data)
            #expect(decoded == level)
            #expect(decoded.encoded() == data)
            let viaCodable = try JSONDecoder().decode(LissajousLabyrinthLevel.self, from: data)
            #expect(viaCodable == level)
        }
        let level = LissajousLabyrinthFixture.next(&random).level
        let data: Data = level.encoded()
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schema"] = 2
        let newer: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: LissajousLabyrinthError.newerSchema(2)) { try LissajousLabyrinthLevel.decode(newer) }
        object["schema"] = 1
        object["allowance"] = level.allowance == 64 ? 63 : level.allowance + 1
        let edited: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: LissajousLabyrinthError.malformed("fingerprint")) { try LissajousLabyrinthLevel.decode(edited) }
        object["allowance"] = 0
        let invalid: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: LissajousLabyrinthError.malformed("r02-g02.level")) { try LissajousLabyrinthLevel.decode(invalid) }
        let truncated: Data = data.prefix(data.count / 2)
        #expect(throws: LissajousLabyrinthError.malformed("unreadable")) { try LissajousLabyrinthLevel.decode(truncated) }
        object["schema"] = 0
        let old: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: LissajousLabyrinthError.malformed("schema 0")) { try LissajousLabyrinthLevel.decode(old) }
    }
}
