// CelestialEclipseLabLevelTests — feature 461 (R02-G17-01) T-R02G1701-002 (FR-R02G1701-001, 002, 009, 013;
// SC-R02G1701-001, 005). The level's rules (every range and rule refused by name: bodies, orbits, positions, radii, no
// movable body, a broken depth order, the horizon, the target's bodies, front and window, the phases, the budget,
// starting phases that already win), its words, and the stored form (round trip, damaged, edited, newer and older
// forms refused). Explicit types, plain loops.
import Foundation
import Testing
@testable import CelestialEclipseLabCore

@Suite struct CelestialEclipseLabLevelTests {
    /// A two-body orbit at depth `z`: four positions on a square of side 2 around (`cx`, `cy`).
    static func orbit(_ cx: Int, _ cy: Int, z: Int) -> [CelestialEclipseLabVector] {
        [CelestialEclipseLabVector(cx - 1, cy - 1, z), CelestialEclipseLabVector(cx + 1, cy - 1, z),
         CelestialEclipseLabVector(cx + 1, cy + 1, z), CelestialEclipseLabVector(cx - 1, cy + 1, z)]
    }

    /// A small valid level: body 0 (front, fixed, radius 2) at the origin, body 1 (back, radius 2) moving on a line
    /// x = −12, −9, …, 9 in eight ticks; the target is body 0 in front of body 1 inside ticks 2 … 5. With phases [0, 3]
    /// body 1 starts at x = −3, so the first eclipse comes at tick 0, outside the window: not won at load.
    static func sample(phases: [Int] = [0, 3], budget: Int = 3) throws -> CelestialEclipseLabLevel {
        let front = CelestialEclipseLabBody(orbit: orbit(0, 0, z: 10), radius: 2, fixed: true)
        var line: [CelestialEclipseLabVector] = []
        for k in 0..<8 { line.append(CelestialEclipseLabVector(-12 + 3 * k, 0, 0)) }
        let back = CelestialEclipseLabBody(orbit: line, radius: 2)
        return try CelestialEclipseLabLevel(
            id: "sample", seed: 0, difficulty: 1, bodies: [front, back], horizon: 8,
            target: [CelestialEclipseLabTarget(front: 0, back: 1, open: 2, close: 5)], phases: phases, budget: budget)
    }

    @Test func aValidLevelBuildsAndRoundTrips() throws {
        let level: CelestialEclipseLabLevel = try Self.sample()
        let data: Data = level.encoded()
        let decoded: CelestialEclipseLabLevel = try CelestialEclipseLabLevel.decode(data)
        #expect(decoded == level && decoded.fingerprint == level.fingerprint)
        let json: CelestialEclipseLabLevel = try JSONDecoder().decode(CelestialEclipseLabLevel.self, from: data)
        #expect(json == level)
        #expect(level.encoded() == data)
    }

    @Test func startingPhasesThatWinAreRefused() throws {
        // Phase 0 for body 1 starts it at x = −12; it first meets body 0 at tick 3 (x = −3 against (−1, 1): squared
        // distance 5 < 16), inside the window, with no other eclipse: a win at load.
        #expect(throws: CelestialEclipseLabError.level("already won")) { try Self.sample(phases: [0, 0]) }
    }

    @Test func everyRuleIsRefusedByName() throws {
        let level: CelestialEclipseLabLevel = try Self.sample()
        let front: CelestialEclipseLabBody = level.bodies[0]
        let back: CelestialEclipseLabBody = level.bodies[1]
        let target: [CelestialEclipseLabTarget] = level.target
        func build(id: String = "x", difficulty: Int = 1, bodies: [CelestialEclipseLabBody]? = nil, horizon: Int = 8,
                   target t: [CelestialEclipseLabTarget]? = nil, phases: [Int] = [0, 3], budget: Int = 3) throws {
            _ = try CelestialEclipseLabLevel(id: id, seed: 0, difficulty: difficulty, bodies: bodies ?? [front, back],
                                             horizon: horizon, target: t ?? target, phases: phases, budget: budget)
        }
        #expect(throws: CelestialEclipseLabError.level("id")) { try build(id: "Bad Id") }
        #expect(throws: CelestialEclipseLabError.level("difficulty")) { try build(difficulty: 6) }
        #expect(throws: CelestialEclipseLabError.level("bodies")) { try build(bodies: [back], phases: [0]) }
        let short = CelestialEclipseLabBody(orbit: Array(back.orbit.prefix(3)), radius: 2)
        #expect(throws: CelestialEclipseLabError.level("orbit")) { try build(bodies: [front, short], phases: [0, 0]) }
        var far: [CelestialEclipseLabVector] = back.orbit
        far[0] = CelestialEclipseLabVector(33, 0, 0)
        #expect(throws: CelestialEclipseLabError.level("position")) {
            try build(bodies: [front, CelestialEclipseLabBody(orbit: far, radius: 2)])
        }
        #expect(throws: CelestialEclipseLabError.level("radius")) {
            try build(bodies: [front, CelestialEclipseLabBody(orbit: back.orbit, radius: 9)])
        }
        let fixedBack = CelestialEclipseLabBody(orbit: back.orbit, radius: 2, fixed: true)
        #expect(throws: CelestialEclipseLabError.level("movable")) { try build(bodies: [front, fixedBack]) }
        let level0 = CelestialEclipseLabBody(orbit: Self.orbit(0, 0, z: 0), radius: 2, fixed: true)
        #expect(throws: CelestialEclipseLabError.level("depth order")) { try build(bodies: [level0, back]) }
        #expect(throws: CelestialEclipseLabError.level("horizon")) { try build(horizon: 7) }
        let same = [CelestialEclipseLabTarget(front: 1, back: 1, open: 0, close: 1)]
        #expect(throws: CelestialEclipseLabError.level("target bodies")) { try build(target: same) }
        let behind = [CelestialEclipseLabTarget(front: 1, back: 0, open: 0, close: 1)]
        #expect(throws: CelestialEclipseLabError.level("target front")) { try build(target: behind) }
        let late = [CelestialEclipseLabTarget(front: 0, back: 1, open: 2, close: 8)]
        #expect(throws: CelestialEclipseLabError.level("target window")) { try build(target: late) }
        #expect(throws: CelestialEclipseLabError.level("target")) { try build(target: []) }
        #expect(throws: CelestialEclipseLabError.level("phases")) { try build(phases: [0]) }
        #expect(throws: CelestialEclipseLabError.level("phase")) { try build(phases: [0, 8]) }
        #expect(throws: CelestialEclipseLabError.level("budget")) { try build(budget: 25) }
    }

    @Test func damagedEditedAndNewerFormsAreRefused() throws {
        let level: CelestialEclipseLabLevel = try Self.sample()
        let text: String = String(decoding: level.encoded(), as: UTF8.self)
        let edited: String = text.replacingOccurrences(of: "\"budget\":3", with: "\"budget\":4")
        #expect(edited != text)
        #expect(throws: CelestialEclipseLabError.malformed("fingerprint")) {
            try CelestialEclipseLabLevel.decode(Data(edited.utf8))
        }
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(throws: CelestialEclipseLabError.newerSchema(2)) {
            try CelestialEclipseLabLevel.decode(Data(newer.utf8))
        }
        let older: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")
        #expect(throws: CelestialEclipseLabError.malformed("schema 0")) {
            try CelestialEclipseLabLevel.decode(Data(older.utf8))
        }
        #expect(throws: CelestialEclipseLabError.malformed("unreadable")) {
            try CelestialEclipseLabLevel.decode(Data("{".utf8))
        }
        let broken: String = text.replacingOccurrences(of: "\"horizon\":8", with: "\"horizon\":7")
        #expect(throws: CelestialEclipseLabError.malformed("r02-g17.level")) {
            try CelestialEclipseLabLevel.decode(Data(broken.utf8))
        }
    }

    @Test func bodiesEclipsesAndProgressAreNamedInWords() throws {
        let level: CelestialEclipseLabLevel = try Self.sample()
        #expect(level.bodyName(1) == "body 1")
        #expect(level.eclipseName(front: 0, back: 1) == "body 0 in front of body 1")
        let interval = CelestialEclipseLabInterval(front: 0, back: 1, first: 7, last: 9, visibility: .total)
        #expect(level.intervalDescription(interval) == "body 0 in front of body 1 from tick 7 to tick 9, total")
        let words: String = level.progressDescription(timeline: level.startTimeline, actionsLeft: 3)
        #expect(words.hasPrefix("0 of 1 eclipses in order; next: body 0 in front of body 1 between tick 2 and tick 5"))
        #expect(words.hasSuffix("3 actions left"))
    }

    @Test func theFixturesAreValidAndTheirKnownPhasesWin() throws {
        let fixtures: [CelestialEclipseLabFixture] = CelestialEclipseLabFixture.all(count: 200)
        #expect(fixtures.count == 200)
        for fixture in fixtures {
            #expect(!fixture.level.startTimeline.wins, "\(fixture.level.id) starts unwon")
            #expect(CelestialEclipseLabSky.timeline(fixture.level, phases: fixture.winning).wins, "\(fixture.level.id)")
            #expect(fixture.actions.last == .run)
            #expect(fixture.actions.count - 1 <= fixture.level.budget)
        }
    }
}
