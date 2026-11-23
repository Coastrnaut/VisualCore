// HarmonicBridgesProgressTests — feature 415 (R02-G12-05) T-R02G1205-003 (FR-R02G1205-001, 004, 005; SC-R02G1205-001,
// 004; clarifications Q2, Q3, Q4). The tutorial steps on levels 1 … 3 by scripted plays of their stored certified
// witnesses through the real kernel (level 1's single tuning bridges every step and goes straight on to `test`; levels
// 2 and 3 walk tune → bridge → test → done), a detour of undo and redo that never moves a step back, and a failed play
// ending the tutorial; the star thresholds; the actions spent, undone records included; a 100-level progress script
// (frontier, best results, a better result replacing a worse one, daily and practice rules); every calendar day
// 2026-01-01 … 2036-12-31 mapping into 1 … 100, stably, and 100 consecutive days visiting every level; negative day
// counts wrapped; impossible days refused, leap years included; Codable round trips.
// Test data uses explicit types and plain loops (CI type-check rule). No clock: dates are inputs.
@testable import HarmonicBridgesCore
import Foundation
import Testing

/// The stored witness directory, `docs/games/harmonic-bridges/levels`, from this file's path.
private let progressWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/harmonic-bridges/levels", isDirectory: true)

@Suite struct HarmonicBridgesProgressTests {
    typealias Step = HarmonicBridgesTutorialStep
    typealias Progress = HarmonicBridgesProgress
    typealias Mode = HarmonicBridgesMode
    typealias Play = HarmonicBridgesPlay
    typealias Action = HarmonicBridgesAction
    typealias Core = HarmonicBridgesExperienceCore

    /// The stored certified witness of level `number`, read with the plain decoder.
    static func storedWitness(_ number: Int) throws -> HarmonicBridgesWitness {
        let name: String = String(HarmonicBridgesGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: progressWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(HarmonicBridgesWitness.self, from: data)
    }

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: Play) -> Bool { play.stage == .won || play.stage == .failed }

    /// The step after `action` was applied to `play` (which it mutates), from the play's own change.
    static func step(_ step: Step, applying action: Action, to play: inout Play) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        var afterTune: Bool = false
        if case .tune = action { afterTune = true }
        return step.advanced(afterTune: afterTune, bridged: play.report.goalReachedInEveryStep, ended: ended(play))
    }

    /// The step after an undo or a redo: no accepted action, the current bridging.
    static func stepAfterHistory(_ step: Step, _ play: Play) -> Step {
        step.advanced(afterTune: false, bridged: play.report.goalReachedInEveryStep, ended: false)
    }

    /// Records a win in `progress` (outside `#expect`, which cannot mutate) and returns whether the result changed.
    static func record(_ progress: inout Progress, level: Int, actionsSpent: Int, certified: Int,
                       mode: Mode = .campaign) -> Bool {
        progress.record(level: level, actionsSpent: actionsSpent, certified: certified, mode: mode)
    }

    // MARK: Tutorial

    @Test func tutorialTextsAreClarificationQ2() {
        #expect(Step.tune.text == "Drag a string's peg up or down (or use the panel's peg steppers and Tune) — when "
            + "one of its harmonics matches a tone of the step it swings and its samples fill")
        #expect(Step.bridge.text == "A string whose five samples all fill becomes a cyan bridge: bridge a path from "
            + "the start to the violet goal in every step — a hint shows which string")
        #expect(Step.test.text == "Tap the goal or a step pip to test the crossing; if a step breaks, undo it")
        #expect(Step.done.text.isEmpty)
        #expect(Step.initial(tutorial: true) == .tune && Step.initial(tutorial: false) == .done)
        for level in 1...100 {
            let expected: Step = level <= 3 ? .tune : .done
            #expect(Step.initial(level: level) == expected)
        }
        for step in Step.allCases { #expect(step.dismissed() == .done) }
    }

    @Test func tutorialAdvancesInOrderNeverBack() {
        // tune: only an accepted tuning moves it — to bridge, or straight to test when it already bridges.
        #expect(Step.tune.advanced(afterTune: true, bridged: false, ended: false) == .bridge)
        #expect(Step.tune.advanced(afterTune: true, bridged: true, ended: false) == .test)
        #expect(Step.tune.advanced(afterTune: false, bridged: true, ended: false) == .tune)
        #expect(Step.tune.advanced(afterTune: false, bridged: false, ended: false) == .tune)
        // bridge: moves when bridged; a further unbridging tuning leaves it.
        #expect(Step.bridge.advanced(afterTune: true, bridged: false, ended: false) == .bridge)
        #expect(Step.bridge.advanced(afterTune: false, bridged: true, ended: false) == .test)
        #expect(Step.bridge.advanced(afterTune: true, bridged: true, ended: false) == .test)
        // test lasts until the end, even unbridged; done is final.
        #expect(Step.test.advanced(afterTune: true, bridged: false, ended: false) == .test)
        #expect(Step.done.advanced(afterTune: true, bridged: true, ended: false) == .done)
        // The end of the level moves every step to done.
        for step in Step.allCases {
            #expect(step.advanced(afterTune: false, bridged: false, ended: true) == .done)
            #expect(step.advanced(afterTune: true, bridged: true, ended: true) == .done)
        }
        // Never back: every step's successor is at or after it.
        let order: [Step] = [.tune, .bridge, .test, .done]
        for (position, step) in order.enumerated() {
            for flags in 0..<8 {
                let next: Step = step.advanced(afterTune: flags & 1 != 0, bridged: flags & 2 != 0,
                                               ended: flags & 4 != 0)
                let nextPosition: Int = order.firstIndex(of: next) ?? -1
                #expect(nextPosition >= position)
            }
        }
    }

    @Test func tutorialLevelsWitnessPlaysWalkTheSteps() throws {
        var straightToTest: Int = 0
        for number in 1...3 {
            let witness: HarmonicBridgesWitness = try Self.storedWitness(number)
            let level: HarmonicBridgesLevel = witness.level
            #expect(level.tutorial)
            var play: Play = try Core.freshPlay(of: level)
            #expect(!play.report.goalReachedInEveryStep)
            var step: Step = Step.initial(tutorial: level.tutorial)
            #expect(step == .tune)
            var seen: [Step] = [step]
            let tunings: Int = witness.actions.count - 1
            for (index, action) in witness.actions.enumerated() {
                step = try Self.step(step, applying: action, to: &play)
                // Check the step after each action: the last tuning bridges every step, the test ends the level.
                if index == witness.actions.count - 1 {
                    #expect(step == .done)
                } else if index == tunings - 1 {
                    #expect(play.report.goalReachedInEveryStep)
                    #expect(step == .test)
                } else {
                    #expect(step == .bridge)
                }
                if seen.last != step { seen.append(step) }
            }
            #expect(play.stage == .won)
            if tunings == 1 {
                // A single tuning that already bridges every step goes straight on to test.
                #expect(seen == [.tune, .test, .done], "level \(number): \(seen)")
                straightToTest += 1
            } else {
                #expect(seen == [.tune, .bridge, .test, .done], "level \(number): \(seen)")
            }
        }
        // Level 1's witness is one tuning and the test: the straight-to-test case occurs.
        #expect(straightToTest >= 1)
    }

    @Test func tutorialDetourNeverMovesBack() throws {
        for number in 2...3 {
            let witness: HarmonicBridgesWitness = try Self.storedWitness(number)
            let actions: [Action] = witness.actions
            #expect(actions.count == 3)
            var play: Play = try Core.freshPlay(of: witness.level)
            var step: Step = .tune
            // The first tuning, undone and redone: bridge throughout.
            step = try Self.step(step, applying: actions[0], to: &play)
            #expect(step == .bridge)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == .bridge)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == .bridge)
            // The second tuning bridges every step; its undo unbridges, and test stays.
            step = try Self.step(step, applying: actions[1], to: &play)
            #expect(step == .test)
            try play.undo()
            #expect(!play.report.goalReachedInEveryStep)
            step = Self.stepAfterHistory(step, play)
            #expect(step == .test)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == .test)
            step = try Self.step(step, applying: actions[2], to: &play)
            #expect(play.stage == .won && step == .done)
            // Records: tune, undo, redo, tune, undo, redo, test — three accepted actions, the certified count.
            #expect(Progress.actionsSpent(play) == actions.count)
        }
    }

    @Test func failedPlayEndsTheTutorial() throws {
        for number in 1...3 {
            let witness: HarmonicBridgesWitness = try Self.storedWitness(number)
            var play: Play = try Core.freshPlay(of: witness.level)
            // A test at the starting pegs breaks: the level ends and the tutorial is done.
            let step: Step = try Self.step(.tune, applying: .test, to: &play)
            #expect(play.stage == .failed)
            #expect(step == .done)
            // An undo of the failed test never moves the step back.
            try play.undo()
            #expect(Self.stepAfterHistory(step, play) == .done)
        }
    }

    // MARK: Stars and actions spent

    @Test func starThresholds() {
        for certified in 1...8 {
            for spent in 0...(certified + 6) {
                let stars: Int = Progress.stars(actionsSpent: spent, certified: certified)
                let expected: Int = spent <= certified ? 3 : (spent <= certified + 2 ? 2 : 1)
                #expect(stars == expected)
            }
            #expect(Progress.stars(actionsSpent: certified, certified: certified) == 3)
            #expect(Progress.stars(actionsSpent: certified + 1, certified: certified) == 2)
            #expect(Progress.stars(actionsSpent: certified + 2, certified: certified) == 2)
            #expect(Progress.stars(actionsSpent: certified + 3, certified: certified) == 1)
        }
    }

    @Test func witnessActionsAreTheCertifiedCount() throws {
        for number in 1...3 {
            let witness: HarmonicBridgesWitness = try Self.storedWitness(number)
            var play: Play = try Core.freshPlay(of: witness.level)
            #expect(Progress.actionsSpent(play) == 0)
            for action in witness.actions { try play.apply(action, expecting: play.fingerprint) }
            let spent: Int = Progress.actionsSpent(play)
            #expect(spent == witness.actions.count)
            #expect(spent == play.actionsSpent)
            #expect(Progress.stars(actionsSpent: spent, certified: witness.actions.count) == 3)
        }
    }

    @Test func actionsSpentCountsUndoneRecords() throws {
        let witness: HarmonicBridgesWitness = try Self.storedWitness(2)
        let actions: [Action] = witness.actions
        let certified: Int = actions.count
        var play: Play = try Core.freshPlay(of: witness.level)
        // A tuning undone and applied again counts twice.
        try play.apply(actions[0], expecting: play.fingerprint)
        try play.undo()
        #expect(play.actionsSpent == 0)
        #expect(Progress.actionsSpent(play) == 1)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        #expect(play.actionsSpent == certified)
        #expect(Progress.actionsSpent(play) == certified + 1)
        #expect(Progress.stars(actionsSpent: Progress.actionsSpent(play), certified: certified) == 2)
    }

    // MARK: Progress

    @Test func hundredLevelScript() {
        var progress: Progress = Progress()
        #expect(progress.frontier == 1 && progress.solved.isEmpty)
        #expect(progress.isOpen(1) && !progress.isOpen(2) && !progress.isOpen(0) && !progress.isOpen(101))
        #expect(progress.nextOpen(after: 1) == nil)
        for level in 1...100 {
            #expect(progress.isOpen(level))
            #expect(!progress.isOpen(level + 1) || level == 100)
            let certified: Int = level % 6 + 2
            // A first, poor win: 1 star; it opens the next level.
            #expect(Self.record(&progress, level: level, actionsSpent: certified + 4, certified: certified) == true)
            #expect(progress.solved[level] == Progress.Result(actionsSpent: certified + 4, stars: 1))
            #expect(progress.frontier == min(level + 1, 100))
            // A worse result keeps the stored one.
            #expect(Self.record(&progress, level: level, actionsSpent: certified + 5, certified: certified) == false)
            #expect(progress.solved[level]?.actionsSpent == certified + 4)
            // A better result replaces it: 2 stars, then 3.
            #expect(Self.record(&progress, level: level, actionsSpent: certified + 2, certified: certified) == true)
            #expect(progress.solved[level]?.stars == 2)
            #expect(Self.record(&progress, level: level, actionsSpent: certified, certified: certified) == true)
            #expect(progress.solved[level] == Progress.Result(actionsSpent: certified, stars: 3))
            // An equal result keeps it.
            #expect(Self.record(&progress, level: level, actionsSpent: certified, certified: certified) == false)
            if level < 100 { #expect(progress.nextOpen(after: level) == level + 1) }
        }
        #expect(progress.frontier == 100 && progress.solved.count == 100)
        #expect(progress.nextOpen(after: 100) == nil)
        // Levels outside 1 … 100 are ignored; the frontier never falls.
        #expect(Self.record(&progress, level: 0, actionsSpent: 1, certified: 1) == false)
        #expect(Self.record(&progress, level: 101, actionsSpent: 1, certified: 1) == false)
        progress.open(through: 3)
        #expect(progress.frontier == 100)
        // Bands of 20.
        for level in 1...100 { #expect(Progress.band(of: level) == (level - 1) / 20 + 1) }
        #expect(Progress.band(of: 0) == 1 && Progress.band(of: 500) == 5)
    }

    @Test func modesRecordAndOpen() {
        var progress: Progress = Progress()
        // Practice records nothing and opens nothing.
        #expect(Self.record(&progress, level: 1, actionsSpent: 1, certified: 3, mode: .practice) == false)
        #expect(progress.solved.isEmpty && progress.frontier == 1)
        // A daily win on a locked level records its result without opening anything.
        #expect(Self.record(&progress, level: 42, actionsSpent: 4, certified: 3, mode: .daily(level: 42)) == true)
        #expect(progress.solved[42] == Progress.Result(actionsSpent: 4, stars: 2))
        #expect(progress.frontier == 1 && !progress.isOpen(42))
        // A campaign win opens the next level.
        #expect(Self.record(&progress, level: 1, actionsSpent: 2, certified: 2, mode: .campaign) == true)
        #expect(progress.frontier == 2)
        // open(through:) raises the frontier, clamped, never lowers it.
        progress.open(through: 7)
        #expect(progress.frontier == 7)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        // Budgets and flags.
        #expect(Mode.practiceBudget == 60)
        #expect(Mode.practice.budget(base: 9) == 60)
        #expect(Mode.campaign.budget(base: 9) == 9 && Mode.daily(level: 3).budget(base: 9) == 9)
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 1).awardsStars && !Mode.practice.awardsStars)
        #expect(Mode.campaign.opensLevels && !Mode.daily(level: 1).opensLevels && !Mode.practice.opensLevels)
    }

    // MARK: Daily level

    @Test func dailyLevelOverElevenYears() {
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 2) == 84)
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 18)   // day −1: (−83 wrapped to 17) + 1
        var counts: [Int] = Array(repeating: 0, count: 101)
        var window: [Int] = []
        var dayIndex: Int = 0
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...Progress.daysIn(month: month, year: year) {
                    guard let level = Progress.dailyLevel(year: year, month: month, day: day) else {
                        Issue.record("\(year)-\(month)-\(day) has no daily level")
                        continue
                    }
                    #expect(level >= 1 && level <= 100)
                    #expect(Progress.dailyLevel(year: year, month: month, day: day) == level)
                    #expect(level == (dayIndex * 83) % 100 + 1)
                    counts[level] += 1
                    if dayIndex < 100 { window.append(level) }
                    dayIndex += 1
                }
            }
        }
        #expect(dayIndex == 4_018)
        // 100 consecutive days visit every level once.
        #expect(Set(window).count == 100)
        for level in 1...100 { #expect(counts[level] >= 40) }
    }

    @Test func negativeDayCountsWrap() {
        // 99 days 2025-09-24 … 2025-12-31 (day counts −99 … −1) give 99 distinct levels in 1 … 100.
        var before: Set<Int> = []
        var dayCount: Int = -1
        let months: [(month: Int, first: Int, last: Int)] = [(12, 1, 31), (11, 1, 30), (10, 1, 31), (9, 24, 30)]
        for entry in months {
            var day: Int = entry.last
            while day >= entry.first {
                let level: Int? = Progress.dailyLevel(year: 2025, month: entry.month, day: day)
                let wrapped: Int = ((dayCount * 83) % 100 + 100) % 100 + 1
                #expect(level == wrapped)
                if let level { before.insert(level) }
                dayCount -= 1
                day -= 1
            }
        }
        #expect(before.count == 99)
        // The earliest accepted day is in range.
        let early: Int? = Progress.dailyLevel(year: 1, month: 1, day: 1)
        #expect(early != nil && (early ?? 0) >= 1 && (early ?? 0) <= 100)
        let late: Int? = Progress.dailyLevel(year: 9999, month: 12, day: 31)
        #expect(late != nil && (late ?? 0) >= 1 && (late ?? 0) <= 100)
    }

    @Test func impossibleDaysAreNilAndLeapYears() {
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 32) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: -1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        // Leap years: 2028 and 2032 (every fourth year), 2000 (divisible by 400); 2100 is a century, not leap.
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2032, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        // 2028-02-29 is day 789: the day after it continues the sequence.
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) == (789 * 83) % 100 + 1)
        #expect(Progress.dailyLevel(year: 2028, month: 3, day: 1) == (790 * 83) % 100 + 1)
    }

    // MARK: Codable

    @Test func codableRoundTrips() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder: JSONDecoder = JSONDecoder()
        for step in Step.allCases {
            let data: Data = try encoder.encode(step)
            #expect(try decoder.decode(Step.self, from: data) == step)
            #expect(String(decoding: data, as: UTF8.self) == "\"" + step.rawValue + "\"")
        }
        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
        for mode in modes {
            let data: Data = try encoder.encode(mode)
            #expect(try decoder.decode(Mode.self, from: data) == mode)
        }
        #expect(String(decoding: try encoder.encode(Mode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        #expect(String(decoding: try encoder.encode(Mode.campaign), as: UTF8.self) == "{\"mode\":\"campaign\"}")
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"daily\"}", "{\"mode\":\"replay\"}"]
        for text in badModes {
            #expect(throws: DecodingError.self) { try decoder.decode(Mode.self, from: Data(text.utf8)) }
        }
        var progress: Progress = Progress()
        for level in 1...30 {
            progress.record(level: level, actionsSpent: level % 7 + 2, certified: 3)
        }
        progress.record(level: 77, actionsSpent: 9, certified: 3, mode: .daily(level: 77))
        let data: Data = try progress.encoded()
        let decoded: Progress = try decoder.decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        #expect(String(decoding: try Progress().encoded(), as: UTF8.self) == "{\"frontier\":1,\"solved\":[]}")
        let badProgress: [String] = ["{\"frontier\":0,\"solved\":[]}",
                                     "{\"frontier\":101,\"solved\":[]}",
                                     "{\"frontier\":1,\"solved\":[{\"level\":0,\"actionsSpent\":1,\"stars\":3}]}",
                                     "{\"frontier\":1,\"solved\":[{\"level\":1,\"actionsSpent\":1,\"stars\":4}]}",
                                     "{\"frontier\":1,\"solved\":[{\"level\":1,\"actionsSpent\":-1,\"stars\":3}]}",
                                     "{\"frontier\":2,\"solved\":[{\"level\":1,\"actionsSpent\":1,\"stars\":3},"
                                         + "{\"level\":1,\"actionsSpent\":2,\"stars\":3}]}"]
        for text in badProgress {
            #expect(throws: DecodingError.self) { try decoder.decode(Progress.self, from: Data(text.utf8)) }
        }
    }
}
