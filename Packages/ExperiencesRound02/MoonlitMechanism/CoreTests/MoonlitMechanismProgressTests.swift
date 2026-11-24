// MoonlitMechanismProgressTests — feature 435 (R02-G14-05) T-R02G1405-003 (FR-R02G1405-001, 004, 005;
// SC-R02G1405-001, 004; clarifications Q2, Q3, Q4). The tutorial steps on levels 1 … 3 by scripted plays of their
// certified witnesses (`MoonlitMechanismExperienceCore.generated(number:)`, the actions of
// `docs/games/moonlit-mechanism/levels/00N.witness.json`: level 1 turn, lamp, run; levels 2 and 3 re-seat, lamp, run)
// through the real kernel (change → align → run → done, and a change that makes the set-up win moving change straight
// to run), an undo and redo detour that never moves a step back, a failed run ending the tutorial and a redo that
// restores a failed play ending it; 500 seeded (SeededRandom seed 2_435) flag walks that never move a step back; the
// star thresholds; the actions spent, undone records included; a 100-level progress script (frontier, best results, a
// better result replacing a worse one, daily and practice rules); every calendar day 2026-01-01 … 2036-12-31 mapping
// into 1 … 100, stably, and 100 consecutive days visiting every level once; negative day counts wrapped; impossible
// days nil, leap years included; Codable round trips. Test data uses explicit types and plain loops (CI type-check
// rule); each test well under 10 s. No clock: dates are inputs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MoonlitMechanismCore

@Suite struct MoonlitMechanismProgressTests {
    typealias Step = MoonlitMechanismTutorialStep
    typealias Progress = MoonlitMechanismProgress
    typealias Mode = MoonlitMechanismMode
    typealias Play = MoonlitMechanismPlay
    typealias Action = MoonlitMechanismAction
    typealias Core = MoonlitMechanismExperienceCore

    /// The seed of the seeded flag walks.
    static let seed: UInt64 = 2_435

    /// The witness actions of levels 1 … 3 as stored in `docs/games/moonlit-mechanism/levels/00N.witness.json`.
    static func storedWitness(_ number: Int) -> [Action] {
        switch number {
        case 1: [.turn(1), .lamp(-1), .run]
        case 2: [.reseat(2, 1), .lamp(1), .run]
        default: [.reseat(1, 1), .lamp(-1), .run]
        }
    }

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: Play) -> Bool { play.stage == .won || play.stage == .failed }

    /// The step after `action` was applied to `play` (which it mutates), from the play's own change and run report.
    static func step(_ step: Step, applying action: Action, to play: inout Play) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        return step.advanced(afterChange: Step.isChange(action), aligned: Step.isAligned(play), ended: ended(play))
    }

    /// The step after an undo or a redo: no accepted change, the current run report and the play's real end.
    static func stepAfterHistory(_ step: Step, _ play: Play) -> Step {
        step.advanced(afterChange: false, aligned: Step.isAligned(play), ended: ended(play))
    }

    /// Records a win in `progress` (outside `#expect`, which cannot mutate) and returns whether the result changed.
    static func record(_ progress: inout Progress, level: Int, actionsSpent: Int, certified: Int,
                       mode: Mode = .campaign) -> Bool {
        progress.record(level: level, actionsSpent: actionsSpent, certified: certified, mode: mode)
    }

    // MARK: Tutorial

    @Test func tutorialTextsAreClarificationQ2() {
        #expect(Step.change.text == "Drag a gear around (or use Turn − and +) to turn the handle, or double-tap a "
            + "gear (or use Re-seat) to shift it by a tooth: watch its shadow move on the paper")
        #expect(Step.align.text == "Drag the lamp up or down (or use Lamp − and +) to slide the shadows onto their "
            + "targets — a hint shows which change is next")
        #expect(Step.run.text == "Tap the lamp (or Run) to run the machine through every key frame; if it fails, undo")
        #expect(Step.done.text.isEmpty)
        #expect(Step.initial(tutorial: true) == .change && Step.initial(tutorial: false) == .done)
        for level in 1...100 {
            let expected: Step = level <= 3 ? .change : .done
            #expect(Step.initial(level: level) == expected)
        }
        for step in Step.allCases { #expect(step.dismissed() == .done) }
        #expect(Step.isChange(.turn(1)) && Step.isChange(.reseat(1, -1)) && Step.isChange(.lamp(1)))
        #expect(!Step.isChange(.run))
    }

    @Test func tutorialAdvancesInOrderNeverBack() {
        #expect(Step.change.advanced(afterChange: true, aligned: false, ended: false) == .align)
        #expect(Step.change.advanced(afterChange: true, aligned: true, ended: false) == .run)
        #expect(Step.change.advanced(afterChange: false, aligned: true, ended: false) == .change)
        #expect(Step.change.advanced(afterChange: false, aligned: false, ended: false) == .change)
        #expect(Step.align.advanced(afterChange: true, aligned: false, ended: false) == .align)
        #expect(Step.align.advanced(afterChange: false, aligned: true, ended: false) == .run)
        #expect(Step.run.advanced(afterChange: true, aligned: false, ended: false) == .run)
        #expect(Step.done.advanced(afterChange: true, aligned: true, ended: false) == .done)
        for step in Step.allCases {
            #expect(step.advanced(afterChange: false, aligned: false, ended: true) == .done)
            #expect(step.advanced(afterChange: true, aligned: true, ended: true) == .done)
        }
        let order: [Step] = [.change, .align, .run, .done]
        for (position, step) in order.enumerated() {
            for flags in 0..<8 {
                let next: Step = step.advanced(afterChange: flags & 1 != 0, aligned: flags & 2 != 0,
                                               ended: flags & 4 != 0)
                let nextPosition: Int = order.firstIndex(of: next) ?? -1
                #expect(nextPosition >= position)
            }
        }
    }

    @Test func seededFlagWalksNeverMoveBack() {
        let order: [Step] = [.change, .align, .run, .done]
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var reachedDone: Int = 0
        for _ in 0..<500 {
            var step: Step = .change
            for _ in 0..<12 {
                let flags: Int = random.int(0...7)
                let ended: Bool = flags & 4 != 0 && random.int(0...3) == 0
                let next: Step = step.advanced(afterChange: flags & 1 != 0, aligned: flags & 2 != 0, ended: ended)
                let before: Int = order.firstIndex(of: step) ?? -1
                let after: Int = order.firstIndex(of: next) ?? -1
                #expect(after >= before && after <= before + 2 || next == .done)
                step = next
            }
            if step == .done { reachedDone += 1 }
        }
        #expect(reachedDone > 0)
    }

    @Test func alignedIsTheRunReportWinning() throws {
        for number in 1...3 {
            let generated: MoonlitMechanismGenerated = try Core.generated(number: number)
            var play: Play = try Core.freshPlay(of: generated.level)
            #expect(!Step.isAligned(play))
            #expect(Step.isAligned(play) == Step.isAligned(report: play.report))
            for action in generated.actions where action != .run {
                try play.apply(action, expecting: play.fingerprint)
            }
            #expect(Step.isAligned(play) && play.report.outcome == .won)
            #expect(play.report.aligned)
        }
    }

    @Test func tutorialLevelsWitnessPlaysWalkTheSteps() throws {
        for number in 1...3 {
            let generated: MoonlitMechanismGenerated = try Core.generated(number: number)
            let level: MoonlitMechanismLevel = generated.level
            #expect(level.tutorial)
            let actions: [Action] = generated.actions
            #expect(actions == Self.storedWitness(number), "level \(number): \(actions)")
            #expect(actions.last == .run)
            var play: Play = try Core.freshPlay(of: level)
            var step: Step = Step.initial(tutorial: level.tutorial)
            #expect(step == .change)
            var seen: [Step] = [step]
            for (index, action) in actions.enumerated() {
                step = try Self.step(step, applying: action, to: &play)
                if index == actions.count - 1 {
                    #expect(play.stage == .won && step == .done)
                } else if Step.isAligned(play) {
                    #expect(step == .run)
                } else {
                    #expect(step == .align)
                }
                if seen.last != step { seen.append(step) }
            }
            // The witness is the least plan: its first change never wins alone, its last change does.
            #expect(seen == [.change, .align, .run, .done], "level \(number): \(seen)")
        }
    }

    @Test func aChangeThatWinsMovesChangeStraightToRun() throws {
        for number in 1...3 {
            let actions: [Action] = Self.storedWitness(number)
            var play: Play = try Core.freshPlay(of: try Core.level(number: number))
            // The first witness change applied outside the tutorial; the second wins the set-up at once.
            try play.apply(actions[0], expecting: play.fingerprint)
            let step: Step = try Self.step(.change, applying: actions[1], to: &play)
            #expect(Step.isAligned(play) && step == .run)
        }
    }

    @Test func tutorialDetourNeverMovesBack() throws {
        for number in 1...3 {
            let actions: [Action] = Self.storedWitness(number)
            var play: Play = try Core.freshPlay(of: try Core.level(number: number))
            var step: Step = .change
            // The first change, undone and redone: the step never falls back to change.
            step = try Self.step(step, applying: actions[0], to: &play)
            #expect(step == .align)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == .align)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == .align)
            // The second change wins the set-up: run; undoing it leaves run.
            step = try Self.step(step, applying: actions[1], to: &play)
            #expect(Step.isAligned(play) && step == .run)
            try play.undo()
            #expect(!Step.isAligned(play))
            step = Self.stepAfterHistory(step, play)
            #expect(step == .run)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == .run)
            step = try Self.step(step, applying: .run, to: &play)
            #expect(play.stage == .won && step == .done)
            // Records: two changes, two undos, two redos, the run — the undone ones were redone, not re-spent.
            #expect(Progress.actionsSpent(play) == actions.count)
        }
    }

    @Test func failedPlayEndsTheTutorialAndRedoOfAFailureEndsIt() throws {
        for number in 1...3 {
            var play: Play = try Core.freshPlay(of: try Core.level(number: number))
            // A run at the start does not win (a certified start never wins): the level ends, the tutorial is done.
            let step: Step = try Self.step(.change, applying: .run, to: &play)
            #expect(play.stage == .failed && step == .done)
            // An undo of the failed run lands before the end and never moves the step back.
            try play.undo()
            #expect(play.stage == .playing)
            #expect(Self.stepAfterHistory(step, play) == .done)
            // An undo alone never ends a running tutorial; a redo that restores the failed play ends it.
            #expect(Self.stepAfterHistory(.change, play) == .change)
            #expect(Self.stepAfterHistory(.align, play) == .align)
            try play.redo()
            #expect(play.stage == .failed)
            #expect(Self.stepAfterHistory(.change, play) == .done)
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
            #expect(Progress.stars(actionsSpent: certified + 2, certified: certified) == 2)
            #expect(Progress.stars(actionsSpent: certified + 3, certified: certified) == 1)
        }
    }

    @Test func actionsSpentCountsUndoneRecords() throws {
        for number in 1...3 {
            let actions: [Action] = Self.storedWitness(number)
            let certified: Int = actions.count
            var play: Play = try Core.freshPlay(of: try Core.level(number: number))
            #expect(Progress.actionsSpent(play) == 0)
            // A change undone and applied again counts twice.
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
            #expect(progress.best(level) == nil && progress.stars(of: level) == 0)
            #expect(Self.record(&progress, level: level, actionsSpent: certified + 4, certified: certified) == true)
            #expect(progress.solved[level] == Progress.Result(actionsSpent: certified + 4, stars: 1))
            #expect(progress.frontier == min(level + 1, 100))
            #expect(Self.record(&progress, level: level, actionsSpent: certified + 5, certified: certified) == false)
            #expect(progress.best(level) == certified + 4)
            #expect(Self.record(&progress, level: level, actionsSpent: certified + 2, certified: certified) == true)
            #expect(progress.stars(of: level) == 2)
            #expect(Self.record(&progress, level: level, actionsSpent: certified, certified: certified) == true)
            #expect(progress.solved[level] == Progress.Result(actionsSpent: certified, stars: 3))
            #expect(Self.record(&progress, level: level, actionsSpent: certified, certified: certified) == false)
            if level < 100 { #expect(progress.nextOpen(after: level) == level + 1) }
        }
        #expect(progress.frontier == 100 && progress.solved.count == 100)
        #expect(progress.nextOpen(after: 100) == nil)
        #expect(Self.record(&progress, level: 0, actionsSpent: 1, certified: 1) == false)
        #expect(Self.record(&progress, level: 101, actionsSpent: 1, certified: 1) == false)
        progress.open(through: 3)
        #expect(progress.frontier == 100)
        for level in 1...100 { #expect(Progress.band(of: level) == (level - 1) / 20 + 1) }
        #expect(Progress.band(of: 0) == 1 && Progress.band(of: 500) == 5)
    }

    @Test func modesRecordAndOpen() {
        var progress: Progress = Progress()
        #expect(Self.record(&progress, level: 1, actionsSpent: 1, certified: 3, mode: .practice) == false)
        #expect(progress.solved.isEmpty && progress.frontier == 1)
        #expect(Self.record(&progress, level: 42, actionsSpent: 4, certified: 3, mode: .daily(level: 42)) == true)
        #expect(progress.solved[42] == Progress.Result(actionsSpent: 4, stars: 2))
        #expect(progress.frontier == 1 && !progress.isOpen(42))
        #expect(Self.record(&progress, level: 1, actionsSpent: 2, certified: 2, mode: .campaign) == true)
        #expect(progress.frontier == 2)
        progress.open(through: 7)
        #expect(progress.frontier == 7)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 40)
        #expect(Mode.practice.budget(base: 9) == 40)
        #expect(Mode.campaign.budget(base: 9) == 9 && Mode.daily(level: 3).budget(base: 9) == 9)
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 1).awardsStars && !Mode.practice.awardsStars)
        #expect(Mode.campaign.opensLevels && !Mode.daily(level: 1).opensLevels && !Mode.practice.opensLevels)
    }

    // MARK: Daily level

    @Test func dailyLevelOverElevenYears() {
        #expect(Progress.dailyMultiplier == 97)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 2) == 98)
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 4)   // day −1: (−97 wrapped to 3) + 1
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
                    #expect(level == (dayIndex * 97) % 100 + 1)
                    counts[level] += 1
                    if dayIndex < 100 { window.append(level) }
                    dayIndex += 1
                }
            }
        }
        #expect(dayIndex == 4_018)
        #expect(window.count == 100 && Set(window).count == 100)
        for level in 1...100 { #expect(counts[level] >= 40) }
    }

    @Test func hundredConsecutiveDaysFromAnyStartVisitEveryLevelOnce() {
        var seen: Set<Int> = []
        var year: Int = 2031
        var month: Int = 11
        var day: Int = 15
        for _ in 0..<100 {
            if let level = Progress.dailyLevel(year: year, month: month, day: day) { seen.insert(level) }
            day += 1
            if day > Progress.daysIn(month: month, year: year) {
                day = 1
                month += 1
                if month > 12 {
                    month = 1
                    year += 1
                }
            }
        }
        #expect(seen.count == 100)
    }

    @Test func negativeDayCountsWrap() {
        var before: Set<Int> = []
        var dayCount: Int = -1
        let months: [(month: Int, first: Int, last: Int)] = [(12, 1, 31), (11, 1, 30), (10, 1, 31), (9, 24, 30)]
        for entry in months {
            var day: Int = entry.last
            while day >= entry.first {
                let level: Int? = Progress.dailyLevel(year: 2025, month: entry.month, day: day)
                let wrapped: Int = ((dayCount * 97) % 100 + 100) % 100 + 1
                #expect(level == wrapped)
                if let level { before.insert(level) }
                dayCount -= 1
                day -= 1
            }
        }
        #expect(before.count == 99)
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
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: -3) == nil)
        #expect(Progress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2032, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        // 2028-02-29 is day 789: the day after it continues the sequence.
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) == (789 * 97) % 100 + 1)
        #expect(Progress.dailyLevel(year: 2028, month: 3, day: 1) == (790 * 97) % 100 + 1)
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
        #expect(String(decoding: try encoder.encode(Mode.practice), as: UTF8.self) == "{\"mode\":\"practice\"}")
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"daily\"}", "{\"mode\":\"replay\",\"level\":1}"]
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
        var one: Progress = Progress()
        one.record(level: 1, actionsSpent: 4, certified: 3)
        #expect(String(decoding: try one.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":4,\"level\":1,\"stars\":2}]}")
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
