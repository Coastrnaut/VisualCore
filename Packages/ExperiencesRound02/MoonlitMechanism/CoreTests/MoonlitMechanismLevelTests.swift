// MoonlitMechanismLevelTests — feature 431 (R02-G14-01) T-R02G1401-002 (FR-R02G1401-001, 009, 011, 013;
// SC-R02G1401-001, 005; clarifications Q1, Q3, Q4, Q5). The level's ranges and structural refusals, its stored form and
// names, and the fixtures: 200 seeded levels whose known actions win on the run and whose start does not.
import Foundation
import Testing
@testable import MoonlitMechanismCore

@Suite struct MoonlitMechanismLevelTests {
    /// A small valid level: two gears of 6 and 12 teeth.
    static func gear(teeth: Int, phase: Int = 0, parent: Int? = nil, alignment: Int = 0, depth: Int = 1,
                     centre: MoonlitMechanismCell = MoonlitMechanismCell(column: 4, row: 3)) -> MoonlitMechanismGear {
        var blades: [Bool] = Array(repeating: false, count: teeth)
        blades[0] = true
        var slots: [[MoonlitMechanismCell]] = []
        for k in 0..<teeth { slots.append([MoonlitMechanismCell(column: k % 3, row: 1)]) }
        return MoonlitMechanismGear(teeth: teeth, phase: phase, blades: blades, depth: depth, centre: centre,
                                    parent: parent, alignment: alignment, slots: slots)
    }

    static func level(gears: [MoonlitMechanismGear]? = nil, width: Int = 10, rows: Int = 8, lampHeights: Int = 3,
                      startingHeight: Int = 0, keyFrames: [MoonlitMechanismKeyFrame]? = nil, forbidden: [Int] = [],
                      allowance: Int = 0, budget: Int = 5) throws(MoonlitMechanismError) -> MoonlitMechanismLevel {
        let g: [MoonlitMechanismGear] = gears ?? [gear(teeth: 6), gear(teeth: 12, parent: 0)]
        let f: [MoonlitMechanismKeyFrame] = keyFrames ?? [MoonlitMechanismKeyFrame(turns: 0, target: [44], required: true),
                                                          MoonlitMechanismKeyFrame(turns: 2, target: [45], required: false)]
        return try MoonlitMechanismLevel(id: "small", seed: 1, difficulty: 1, gears: g, width: width, rows: rows,
                                         lampHeights: lampHeights, startingHeight: startingHeight, keyFrames: f,
                                         forbidden: forbidden, allowance: allowance, budget: budget)
    }

    static func refusal(_ make: () throws(MoonlitMechanismError) -> MoonlitMechanismLevel) -> String? {
        do {
            _ = try make()
            return nil
        } catch {
            if case .level(let name) = error { return name }
            return error.reasonCode
        }
    }

    @Test func reasonCodesAreStable() {
        let codes: [String] = [MoonlitMechanismError.level("x").reasonCode, MoonlitMechanismError.action("x").reasonCode,
                               MoonlitMechanismError.stage.reasonCode, MoonlitMechanismError.stale.reasonCode,
                               MoonlitMechanismError.newerSchema(2).reasonCode,
                               MoonlitMechanismError.malformed("x").reasonCode]
        #expect(codes == ["r02-g14.level", "r02-g14.action", "r02-g14.stage", "r02-g14.stale", "r02-g14.newer-schema",
                          "r02-g14.malformed"])
    }

    @Test func aSmallLevelIsAccepted() throws {
        let level = try Self.level()
        #expect(level.gears.count == 2)
        #expect(level.fingerprint.count == 64)
    }

    @Test func rangesAreRefusedByName() {
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(gears: [Self.gear(teeth: 6)]) } == "gears")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(gears: [Self.gear(teeth: 5), Self.gear(teeth: 10, parent: 0)]) } == "teeth")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(gears: [Self.gear(teeth: 6, phase: 6), Self.gear(teeth: 12, parent: 0)]) } == "phase")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(gears: [Self.gear(teeth: 6, depth: 4), Self.gear(teeth: 12, parent: 0)]) } == "depth")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(gears: [Self.gear(teeth: 6), Self.gear(teeth: 7, parent: 0)]) } == "mesh")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(gears: [Self.gear(teeth: 6), Self.gear(teeth: 12, parent: 0, alignment: 6)]) } == "mesh")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(gears: [Self.gear(teeth: 6, parent: 0), Self.gear(teeth: 12, parent: 0)]) } == "gears")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(gears: [Self.gear(teeth: 6), Self.gear(teeth: 12, parent: 1)]) } == "gears")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(width: 7) } == "wall")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(rows: 17) } == "wall")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(lampHeights: 1) } == "lamp")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(startingHeight: 3) } == "lamp")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(allowance: 5) } == "allowance")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(budget: 0) } == "budget")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(budget: 41) } == "budget")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(forbidden: [44]) } == "forbidden")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(forbidden: [5, 3]) } == "forbidden")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(forbidden: Array(0..<13)) } == "forbidden")
    }

    @Test func keyFramesAreChecked() {
        let one = MoonlitMechanismKeyFrame(turns: 0, target: [1], required: true)
        #expect(Self.refusal { () throws(MoonlitMechanismError) in try Self.level(keyFrames: [one]) } == "keyFrames")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(keyFrames: [one, MoonlitMechanismKeyFrame(turns: 0, target: [2], required: true)]) } == "keyFrames")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(keyFrames: [MoonlitMechanismKeyFrame(turns: 0, target: [1], required: false),
                                       MoonlitMechanismKeyFrame(turns: 1, target: [2], required: false)]) } == "keyFrames")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(keyFrames: [one, MoonlitMechanismKeyFrame(turns: 1, target: [], required: true)]) } == "keyFrames")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(keyFrames: [one, MoonlitMechanismKeyFrame(turns: 1, target: [80], required: true)]) } == "keyFrames")
        #expect(Self.refusal { () throws(MoonlitMechanismError) in
            try Self.level(keyFrames: [one, MoonlitMechanismKeyFrame(turns: 401, target: [2], required: true)]) } == "keyFrames")
    }

    @Test func theStoredFormRoundTripsAndRefusesDamage() throws {
        let level = try Self.level()
        let data = level.encoded()
        #expect(try MoonlitMechanismLevel.decode(data) == level)
        let decoded = try JSONDecoder().decode(MoonlitMechanismLevel.self, from: data)
        #expect(decoded == level)
        var text = String(decoding: data, as: UTF8.self)
        text = text.replacingOccurrences(of: "\"budget\":5", with: "\"budget\":6")
        #expect(throws: MoonlitMechanismError.malformed("fingerprint")) { try MoonlitMechanismLevel.decode(Data(text.utf8)) }
        let newer = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(throws: MoonlitMechanismError.newerSchema(2)) { try MoonlitMechanismLevel.decode(Data(newer.utf8)) }
        #expect(throws: MoonlitMechanismError.malformed("unreadable")) { try MoonlitMechanismLevel.decode(Data("{".utf8)) }
        let ranged = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"allowance\":0", with: "\"allowance\":9")
        #expect(throws: MoonlitMechanismError.malformed("r02-g14.level")) { try MoonlitMechanismLevel.decode(Data(ranged.utf8)) }
    }

    @Test func namesAreInWords() throws {
        let level = try Self.level()
        #expect(level.gearName(1, phase: 5) == "gear 1, 12 teeth, phase 5")
        #expect(level.lampName(1) == "lamp height 1 of 3")
        let report = level.run(phases: level.startingPhases, height: 0)
        let text = level.progressDescription(report: report, actionsLeft: 1)
        #expect(text.hasPrefix("aligned; key frame 0: "))
        #expect(text.hasSuffix("; 1 action left"))
    }

    @Test func fixturesWinByTheirKnownActionsAndNotBare() {
        let fixtures = MoonlitMechanismFixture.all(count: 200)
        #expect(fixtures.count == 200)
        for fixture in fixtures {
            let level = fixture.level
            #expect(level.run(phases: level.startingPhases, height: level.startingHeight).outcome != .won)
            var phases: [Int] = level.startingPhases
            var height: Int = level.startingHeight
            for action in fixture.actions.dropLast() {
                guard let next = MoonlitMechanismFixture.apply(action, gears: level.gears, phases: phases,
                                                               height: height, lampHeights: level.lampHeights) else {
                    Issue.record("\(level.id): a known action is refused")
                    break
                }
                (phases, height) = next
            }
            #expect(fixture.actions.last == .run)
            #expect(fixture.actions.count <= level.budget)
            #expect(level.run(phases: phases, height: height).outcome == .won, "\(level.id)")
        }
    }
}
