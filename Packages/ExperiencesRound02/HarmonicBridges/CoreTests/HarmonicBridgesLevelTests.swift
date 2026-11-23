// HarmonicBridgesLevelTests — feature 411 (R02-G12-01) T-R02G1201-002 (FR-R02G1201-001, 002, 003, 005, 009, 011, 013,
// 014; SC-R02G1201-001, 003, 004, 005; clarifications Q1, Q2, Q4, Q5). Levels and the exact resonance: the reason codes,
// every range refusal, the swing table against 4 sin²(nπk/6), hand resonance cases (mode 1 alone, modes 2 and 3, a
// mode above 5, the threshold met exactly and one quarter short), reachability and the broken-string rule on the hand
// level, names in words, the stored form's round trip with damaged, edited and newer forms refused, and the 500 seeded
// fixtures valid (starting pegs do not win, winning pegs win). Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import HarmonicBridgesCore

struct HarmonicBridgesLevelTests {
    static let twoIslands: [HarmonicBridgesIsland] = [HarmonicBridgesIsland(x: 0, y: 0),
                                                      HarmonicBridgesIsland(x: 15, y: 9)]
    static let oneString: [HarmonicBridgesString] = [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)]
    static let oneStep: [[HarmonicBridgesTone]] = [[HarmonicBridgesTone(frequency: 1, strength: 1)]]

    /// A valid two-island level with the given overrides.
    static func level(id: String = "bridge-one", difficulty: Int = 1, islands: [HarmonicBridgesIsland] = twoIslands,
                      strings: [HarmonicBridgesString] = oneString, start: Int = 0, goal: Int = 1,
                      steps: [[HarmonicBridgesTone]] = oneStep, threshold: Int = 1,
                      budget: Int = 5) throws -> HarmonicBridgesLevel {
        try HarmonicBridgesLevel(id: id, seed: 9, difficulty: difficulty, islands: islands, strings: strings,
                                 start: start, goal: goal, steps: steps, threshold: threshold, budget: budget)
    }

    static func string(_ a: Int, _ b: Int, length: Int = 1, peg: Int = 1) -> HarmonicBridgesString {
        HarmonicBridgesString(a: a, b: b, length: length, peg: peg)
    }

    static func tone(_ frequency: Int, _ strength: Int = 1) -> HarmonicBridgesTone {
        HarmonicBridgesTone(frequency: frequency, strength: strength)
    }

    /// The reason codes are the stable `r02-g12.*` set.
    @Test func reasonCodesAreStable() {
        let errors: [HarmonicBridgesError] = [.level("x"), .action("x"), .noop, .stage, .stale, .newerSchema(2),
                                              .malformed("x")]
        var codes: [String] = []
        for error in errors { codes.append(error.reasonCode) }
        #expect(codes == ["r02-g12.level", "r02-g12.action", "r02-g12.noop", "r02-g12.stage", "r02-g12.stale",
                          "r02-g12.newer-schema", "r02-g12.malformed"])
    }

    /// Every range and rule is refused with its name; the boundaries themselves are accepted.
    @Test func everyRangeIsRefusedByName() throws {
        #expect(throws: HarmonicBridgesError.level("id")) { try Self.level(id: "Bridge") }
        #expect(throws: HarmonicBridgesError.level("id")) { try Self.level(id: "bridge--one") }
        #expect(throws: HarmonicBridgesError.level("difficulty")) { try Self.level(difficulty: 0) }
        #expect(throws: HarmonicBridgesError.level("difficulty")) { try Self.level(difficulty: 6) }
        let one: [HarmonicBridgesIsland] = [HarmonicBridgesIsland(x: 0, y: 0)]
        #expect(throws: HarmonicBridgesError.level("islands")) { try Self.level(islands: one) }
        var nine: [HarmonicBridgesIsland] = []
        for x in 0..<9 { nine.append(HarmonicBridgesIsland(x: x, y: 0)) }
        #expect(throws: HarmonicBridgesError.level("islands")) { try Self.level(islands: nine) }
        let wide: [HarmonicBridgesIsland] = [HarmonicBridgesIsland(x: 16, y: 0), HarmonicBridgesIsland(x: 0, y: 0)]
        #expect(throws: HarmonicBridgesError.level("islands")) { try Self.level(islands: wide) }
        let tall: [HarmonicBridgesIsland] = [HarmonicBridgesIsland(x: 0, y: 10), HarmonicBridgesIsland(x: 0, y: 0)]
        #expect(throws: HarmonicBridgesError.level("islands")) { try Self.level(islands: tall) }
        let negative: [HarmonicBridgesIsland] = [HarmonicBridgesIsland(x: -1, y: 0), HarmonicBridgesIsland(x: 0, y: 0)]
        #expect(throws: HarmonicBridgesError.level("islands")) { try Self.level(islands: negative) }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: []) }
        var eight: [HarmonicBridgesIsland] = []
        for x in 0..<8 { eight.append(HarmonicBridgesIsland(x: x, y: 0)) }
        var thirteen: [HarmonicBridgesString] = []
        for a in 0..<7 {
            for b in (a + 1)..<8 where thirteen.count < 13 { thirteen.append(Self.string(a, b)) }
        }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(islands: eight, strings: thirteen) }
        let twelve: [HarmonicBridgesString] = Array(thirteen.prefix(12))
        #expect(try Self.level(islands: eight, strings: twelve).strings.count == 12)
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: [Self.string(1, 0)]) }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: [Self.string(0, 0)]) }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: [Self.string(0, 2)]) }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: [Self.string(-1, 1)]) }
        #expect(throws: HarmonicBridgesError.level("strings")) {
            try Self.level(strings: [Self.string(0, 1), Self.string(0, 1, length: 2)])
        }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: [Self.string(0, 1, length: 0)]) }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: [Self.string(0, 1, length: 7)]) }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: [Self.string(0, 1, peg: 0)]) }
        #expect(throws: HarmonicBridgesError.level("strings")) { try Self.level(strings: [Self.string(0, 1, peg: 13)]) }
        #expect(throws: HarmonicBridgesError.level("start")) { try Self.level(start: 2) }
        #expect(throws: HarmonicBridgesError.level("start")) { try Self.level(start: -1) }
        #expect(throws: HarmonicBridgesError.level("goal")) { try Self.level(goal: 0) }
        #expect(throws: HarmonicBridgesError.level("goal")) { try Self.level(goal: 2) }
        #expect(throws: HarmonicBridgesError.level("steps")) { try Self.level(steps: []) }
        let fiveSteps: [[HarmonicBridgesTone]] = [[Self.tone(1)], [Self.tone(1)], [Self.tone(1)], [Self.tone(1)],
                                                  [Self.tone(1)]]
        #expect(throws: HarmonicBridgesError.level("steps")) { try Self.level(steps: fiveSteps) }
        #expect(try Self.level(steps: Array(fiveSteps.prefix(4))).steps.count == 4)
        #expect(throws: HarmonicBridgesError.level("steps")) { try Self.level(steps: [[]]) }
        let fourTones: [[HarmonicBridgesTone]] = [[Self.tone(1), Self.tone(2), Self.tone(3), Self.tone(4)]]
        #expect(throws: HarmonicBridgesError.level("steps")) { try Self.level(steps: fourTones) }
        #expect(throws: HarmonicBridgesError.level("tones")) { try Self.level(steps: [[Self.tone(0)]]) }
        #expect(throws: HarmonicBridgesError.level("tones")) { try Self.level(steps: [[Self.tone(73)]]) }
        #expect(throws: HarmonicBridgesError.level("tones")) { try Self.level(steps: [[Self.tone(5, 0)]]) }
        #expect(throws: HarmonicBridgesError.level("tones")) { try Self.level(steps: [[Self.tone(5, 4)]]) }
        #expect(throws: HarmonicBridgesError.level("tones")) { try Self.level(steps: [[Self.tone(5, 1), Self.tone(5, 2)]]) }
        // The same frequency in two different steps is allowed.
        #expect(try Self.level(steps: [[Self.tone(5)], [Self.tone(5)]]).steps.count == 2)
        #expect(throws: HarmonicBridgesError.level("threshold")) { try Self.level(threshold: 0) }
        #expect(throws: HarmonicBridgesError.level("threshold")) { try Self.level(threshold: 13) }
        #expect(throws: HarmonicBridgesError.level("budget")) { try Self.level(budget: 0) }
        #expect(throws: HarmonicBridgesError.level("budget")) { try Self.level(budget: 61) }
        let edge: HarmonicBridgesLevel = try Self.level(strings: [Self.string(0, 1, length: 6, peg: 12)],
                                                        steps: [[Self.tone(72, 3)]], threshold: 12, budget: 60)
        #expect(edge.budget == 60 && edge.threshold == 12)
    }

    /// The swing table equals 4 sin²(nπk/6) rounded, for n and k in 1 … 5; outside it is 0.
    @Test func swingTableMatchesTheSineLaw() {
        for n in 1...HarmonicBridgesSwing.maxMode {
            for k in 1...HarmonicBridgesSwing.samples {
                let s: Double = sin(Double(n) * Double.pi * Double(k) / 6)
                let expected: Int = Int((4 * s * s).rounded())
                #expect(HarmonicBridgesSwing.quarter(mode: n, sample: k) == expected, "n \(n), k \(k)")
                #expect(abs(4 * s * s - Double(expected)) < 1e-9, "the squared sine is a whole number of quarters")
            }
        }
        #expect(HarmonicBridgesSwing.samples == 5 && HarmonicBridgesSwing.maxMode == 5)
        #expect(HarmonicBridgesSwing.quarter(mode: 6, sample: 1) == 0)
        #expect(HarmonicBridgesSwing.quarter(mode: 1, sample: 0) == 0)
        #expect(HarmonicBridgesSwing.quarter(mode: 1, sample: 6) == 0)
    }

    /// Hand resonance cases: mode 1 alone; modes 2 and 3 together; strengths weigh; a mode above 5 does not resonate;
    /// the threshold met exactly is a bridge and one quarter short is not.
    @Test func handResonanceCases() {
        #expect(HarmonicBridgesSwing.swing(modes: [(mode: 1, strength: 1)]) == [1, 3, 4, 3, 1])
        #expect(HarmonicBridgesSwing.swing(modes: [(mode: 2, strength: 1), (mode: 3, strength: 1)]) == [7, 3, 4, 3, 7])
        #expect(HarmonicBridgesSwing.swing(modes: [(mode: 1, strength: 3)]) == [3, 9, 12, 9, 3])
        #expect(HarmonicBridgesSwing.swing(modes: []) == [0, 0, 0, 0, 0])
        // A string of length 2 at peg 4: F 2 is mode 1, F 4 mode 2, F 10 mode 5, F 12 would be mode 6, F 3 no mode.
        let s: HarmonicBridgesString = Self.string(0, 1, length: 2, peg: 4)
        #expect(s.mode(of: Self.tone(2), peg: 4) == 1)
        #expect(s.mode(of: Self.tone(4), peg: 4) == 2)
        #expect(s.mode(of: Self.tone(10), peg: 4) == 5)
        #expect(s.mode(of: Self.tone(12), peg: 4) == nil)
        #expect(s.mode(of: Self.tone(3), peg: 4) == nil)
        #expect(s.mode(of: Self.tone(72), peg: 12) == nil)
        #expect(s.mode(of: Self.tone(6), peg: 12) == 1)
        #expect(s.mode(of: Self.tone(2), peg: 0) == nil)
        // Length 6 at peg 1: F 1 would be mode 6, so nothing resonates.
        #expect(Self.string(0, 1, length: 6, peg: 1).mode(of: Self.tone(1), peg: 1) == nil)
        // Modes 2 and 3 at peg 4 of length 2 (tones 4 and 6): swing 7 3 4 3 7, minimum 3.
        let tones: [HarmonicBridgesTone] = [Self.tone(4), Self.tone(6)]
        let exact = HarmonicBridgesResonance(string: s, index: 0, step: 0, tones: tones, peg: 4, threshold: 3)
        #expect(exact.modes == [2, 3])
        #expect(exact.swing == [7, 3, 4, 3, 7])
        #expect(exact.bridge)
        let short = HarmonicBridgesResonance(string: s, index: 0, step: 0, tones: tones, peg: 4, threshold: 4)
        #expect(short.bridge == false)
        let single = HarmonicBridgesResonance(string: s, index: 0, step: 0, tones: [Self.tone(2)], peg: 4,
                                              threshold: 1)
        #expect(single.swing == [1, 3, 4, 3, 1] && single.bridge)
        let above = HarmonicBridgesResonance(string: s, index: 0, step: 0, tones: [Self.tone(12, 3)], peg: 4,
                                             threshold: 1)
        #expect(above.modes == [nil] && above.swing == [0, 0, 0, 0, 0] && above.bridge == false)
    }

    /// Reachability and the broken-string rule on the hand level (see `HarmonicBridgesFixtures.handLevel`).
    @Test func reachabilityAndBrokenStringOnTheHandLevel() {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        let report: HarmonicBridgesReport = level.report(pegs: level.startingPegs)
        #expect(report.swings[0][0] == [2, 6, 8, 6, 2])
        #expect(report.swings[0][1] == [2, 6, 8, 6, 2])
        #expect(report.swings[0][2] == [6, 6, 0, 6, 6])
        #expect(report.swings[0][3] == [0, 0, 0, 0, 0])
        #expect(report.swings[1][2] == [5, 3, 8, 3, 5])
        #expect(report.bridges == [[true, true, false, false], [false, false, true, false]])
        #expect(report.reached == [[true, true, false, true], [true, false, true, false]])
        #expect(report.goalReachedInEveryStep == false)
        #expect(level.firstBreak(report) == HarmonicBridgesBreak(step: 1, string: 0))
        #expect(report.bridgeCounts == [2, 1])
        // Tuning string 3 to peg 1 joins island 2 to the goal in step 1 and wins.
        let won: HarmonicBridgesReport = level.report(pegs: [2, 4, 3, 1])
        #expect(won.swings[1][3] == [5, 3, 8, 3, 5])
        #expect(won.swings[0][3] == [6, 6, 0, 6, 6])
        #expect(won.reached[1] == [true, false, true, true])
        #expect(won.goalReachedInEveryStep)
        #expect(level.firstBreak(won) == nil)
        // Threshold 4: string 2's minimum 3 is one quarter short, so step 1 reaches only the start; strings 0 and 1
        // (minimum 2) are not bridges either, so step 0 breaks first, at string 0 (lowest index across the cut).
        let strict: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel(threshold: 3)
        #expect(strict.report(pegs: strict.startingPegs).bridges[1] == [false, false, true, false])
        let shortLevel: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel(threshold: 4)
        let shortReport: HarmonicBridgesReport = shortLevel.report(pegs: shortLevel.startingPegs)
        #expect(shortReport.bridges[1] == [false, false, false, false])
        #expect(shortReport.reached[1] == [true, false, false, false])
        #expect(shortReport.reached[0] == [true, false, false, false])
        #expect(shortLevel.firstBreak(shortReport) == HarmonicBridgesBreak(step: 0, string: 0))
        // Step 0 broken first: pegs that silence string 1 break step 0 at string 1 (island 1 reached, island 3 not).
        let early: HarmonicBridgesReport = level.report(pegs: [2, 5, 3, 5])
        #expect(early.reached[0] == [true, true, false, false])
        #expect(level.firstBreak(early) == HarmonicBridgesBreak(step: 0, string: 1))
    }

    /// A goal no string touches: the break names no string; the reachable set is found breadth-first in index order.
    @Test func breakWithoutACrossingString() throws {
        let islands: [HarmonicBridgesIsland] = [HarmonicBridgesIsland(x: 0, y: 0), HarmonicBridgesIsland(x: 1, y: 0),
                                                HarmonicBridgesIsland(x: 2, y: 0)]
        let level: HarmonicBridgesLevel = try Self.level(islands: islands, strings: [Self.string(0, 1)], goal: 2)
        let report: HarmonicBridgesReport = level.report(pegs: [1])
        #expect(report.bridges == [[true]])
        #expect(report.reached == [[true, true, false]])
        #expect(level.firstBreak(report) == HarmonicBridgesBreak(step: 0, string: nil))
        let ring: [Bool] = HarmonicBridgesReport.reachable(
            strings: [Self.string(0, 2), Self.string(1, 2), Self.string(0, 1)], bridges: [true, false, false],
            islandCount: 3, start: 1)
        #expect(ring == [false, true, false])
    }

    /// Strings, resonances and progress in words (FR-R02G1201-013).
    @Test func namesAreWords() {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        #expect(level.stringName(1, peg: 4) == "string 1, island 1 to island 3, peg 4")
        let locked: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel(lockedLast: true)
        #expect(locked.stringName(3, peg: 5) == "string 3, island 2 to island 3, peg 5, locked")
        #expect(level.resonanceDescription(2, pegs: level.startingPegs)
                == "step 0: mode 2, swing 6 6 0 6 6, not a bridge; step 1: modes 1 and 3, swing 5 3 8 3 5, a bridge")
        #expect(level.resonanceDescription(3, pegs: level.startingPegs)
                == "step 0: no modes, swing 0 0 0 0 0, not a bridge; step 1: no modes, swing 0 0 0 0 0, not a bridge")
        let report: HarmonicBridgesReport = level.report(pegs: level.startingPegs)
        #expect(level.progressDescription(report: report, actionsLeft: 6)
                == "step 0: 2 bridges, goal reached; step 1: 1 bridge, goal not reached; 6 actions left")
        #expect(level.progressDescription(report: report, actionsLeft: 1).hasSuffix("; 1 action left"))
        #expect(HarmonicBridgesLevel.modesText([1, 2, 3]) == "modes 1, 2 and 3")
    }

    /// The stored form round-trips with its fingerprint; damaged, edited and newer forms are refused.
    @Test func storedFormRoundTripsAndRefusesDamage() throws {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        let data: Data = level.encoded()
        #expect(try HarmonicBridgesLevel.decode(data) == level)
        let text: String = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"budget\":6,\"difficulty\":1,\"fingerprint\":"))
        #expect(text.contains("\"islands\":[[1,5],[5,2],[5,8],[10,5]]"))
        #expect(text.contains("\"strings\":[[0,1,1,2,false],[1,3,2,4,false],[0,2,3,3,false],[2,3,1,5,false]]"))
        #expect(text.contains("\"steps\":[[[2,2]],[[1,1],[3,1]]]"))
        #expect(level.fingerprint.count == 64)
        let decoded: HarmonicBridgesLevel = try JSONDecoder().decode(HarmonicBridgesLevel.self, from: data)
        #expect(decoded == level)
        #expect(throws: HarmonicBridgesError.malformed("unreadable")) { try HarmonicBridgesLevel.decode(Data("{".utf8)) }
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(throws: HarmonicBridgesError.newerSchema(2)) { try HarmonicBridgesLevel.decode(Data(newer.utf8)) }
        let older: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")
        #expect(throws: HarmonicBridgesError.malformed("schema 0")) { try HarmonicBridgesLevel.decode(Data(older.utf8)) }
        let edited: String = text.replacingOccurrences(of: "\"budget\":6", with: "\"budget\":7")
        #expect(throws: HarmonicBridgesError.malformed("fingerprint")) {
            try HarmonicBridgesLevel.decode(Data(edited.utf8))
        }
        let retuned: String = text.replacingOccurrences(of: "[2,3,1,5,false]", with: "[2,3,1,1,false]")
        #expect(throws: HarmonicBridgesError.malformed("fingerprint")) {
            try HarmonicBridgesLevel.decode(Data(retuned.utf8))
        }
        let broken: String = text.replacingOccurrences(of: "\"threshold\":2", with: "\"threshold\":13")
        #expect(throws: HarmonicBridgesError.malformed("r02-g12.level")) {
            try HarmonicBridgesLevel.decode(Data(broken.utf8))
        }
        let sameGoal: String = text.replacingOccurrences(of: "\"goal\":3", with: "\"goal\":0")
        #expect(throws: HarmonicBridgesError.malformed("r02-g12.level")) {
            try HarmonicBridgesLevel.decode(Data(sameGoal.utf8))
        }
        let repeatedTone: String = text.replacingOccurrences(of: "[[1,1],[3,1]]", with: "[[1,1],[1,2]]")
        #expect(throws: HarmonicBridgesError.malformed("r02-g12.level")) {
            try HarmonicBridgesLevel.decode(Data(repeatedTone.utf8))
        }
        let missing: String = text.replacingOccurrences(of: ",\"tutorial\":false", with: "")
        #expect(throws: HarmonicBridgesError.malformed("unreadable")) {
            try HarmonicBridgesLevel.decode(Data(missing.utf8))
        }
        let shortString: String = text.replacingOccurrences(of: "[2,3,1,5,false]", with: "[2,3,1,5]")
        #expect(throws: HarmonicBridgesError.malformed("unreadable")) {
            try HarmonicBridgesLevel.decode(Data(shortString.utf8))
        }
        let edits: [String] = [newer, edited, broken]
        for edit in edits {
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(HarmonicBridgesLevel.self, from: Data(edit.utf8)) }
        }
    }

    /// The 500 seeded fixtures are valid levels: the starting pegs do not reach the goal in every step, the known
    /// tunings touch only unlocked strings with new pegs in range, the winning pegs reach the goal in every step with
    /// the path strings bridges in every step, the known actions fit the budget, and each round-trips.
    @Test func fixturesAreValid() throws {
        let fixtures: [HarmonicBridgesFixture] = HarmonicBridgesFixtures.fixtures(500)
        var steps: Set<Int> = []
        var withLocks: Int = 0
        for fixture in fixtures {
            let level: HarmonicBridgesLevel = fixture.level
            let starting: HarmonicBridgesReport = level.report(pegs: level.startingPegs)
            #expect(starting.goalReachedInEveryStep == false, "fixture \(level.seed) is solved at load")
            #expect(level.firstBreak(starting) != nil)
            #expect(fixture.winningActions.isEmpty == false)
            var pegs: [Int] = level.startingPegs
            for action in fixture.winningActions {
                #expect(level.strings[action.string].locked == false)
                #expect(HarmonicBridgesLevel.pegs.contains(action.peg))
                #expect(pegs[action.string] != action.peg)
                pegs[action.string] = action.peg
            }
            #expect(pegs == fixture.winningPegs)
            let won: HarmonicBridgesReport = level.report(pegs: pegs)
            #expect(won.goalReachedInEveryStep, "fixture \(level.seed) is not won by its known actions")
            #expect(level.firstBreak(won) == nil)
            for stepBridges in won.bridges {
                for index in fixture.path { #expect(stepBridges[index]) }
            }
            #expect(fixture.winningActions.count + 1 <= level.budget)
            #expect(try HarmonicBridgesLevel.decode(level.encoded()) == level)
            steps.insert(level.steps.count)
            for string in level.strings where string.locked { withLocks += 1 }
        }
        #expect(steps == [1, 2, 3, 4])
        #expect(withLocks > 0)
    }
}
