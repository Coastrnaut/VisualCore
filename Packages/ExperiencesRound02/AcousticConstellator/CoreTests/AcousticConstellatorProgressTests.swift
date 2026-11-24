// AcousticConstellatorProgressTests — feature 425 (R02-G13-05) T-R02G1305-003 (FR-R02G1305-001, 004, 005;
// SC-R02G1305-001, 004; clarifications Q2, Q3, Q4). The tutorial steps on levels 1 … 3 by scripted plays of their
// certified witnesses (`AcousticConstellatorExperienceCore.generated(number:)`) through the real kernel (link →
// complete or straight to listen → done), an undo and redo detour that never moves a step back, a failed listen ending
// the tutorial and a redo that restores a failed play ending it; the star thresholds; the actions spent, undone records
// included; a 100-level progress script (frontier, best results, a better result replacing a worse one, daily and
// practice rules); every calendar day 2026-01-01 … 2036-12-31 mapping into 1 … 100, stably, and 100 consecutive days
// visiting every level once; negative day counts wrapped; impossible days nil, leap years included; Codable round
// trips. Test data uses explicit types and plain loops (CI type-check rule). No clock: dates are inputs.
@testable import AcousticConstellatorCore
import Foundation
import Testing

@Suite struct AcousticConstellatorProgressTests {
    typealias Step = AcousticConstellatorTutorialStep
    typealias Progress = AcousticConstellatorProgress
    typealias Mode = AcousticConstellatorMode
    typealias Play = AcousticConstellatorPlay
    typealias Action = AcousticConstellatorAction
    typealias Core = AcousticConstellatorExperienceCore

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: Play) -> Bool { play.stage == .won || play.stage == .failed }

    /// The step after `action` was applied to `play` (which it mutates), from the play's own change.
    static func step(_ step: Step, applying action: Action, to play: inout Play) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        var afterLink: Bool = false
        if case .link = action { afterLink = true }
        return step.advanced(afterLink: afterLink, complete: Step.isComplete(play), ended: ended(play))
    }

    /// The step after an undo or a redo: no accepted link, the current completeness and the play's real end.
    static func stepAfterHistory(_ step: Step, _ play: Play) -> Step {
        step.advanced(afterLink: false, complete: Step.isComplete(play), ended: ended(play))
    }

    /// Records a win in `progress` (outside `#expect`, which cannot mutate) and returns whether the result changed.
    static func record(_ progress: inout Progress, level: Int, actionsSpent: Int, certified: Int,
                       mode: Mode = .campaign) -> Bool {
        progress.record(level: level, actionsSpent: actionsSpent, certified: certified, mode: mode)
    }

    // MARK: Tutorial

    @Test func tutorialTextsAreClarificationQ2() {
        #expect(Step.link.text == "Drag from one star to another (or use the panel's star, partner and Link) to link "
            + "a pair the dashed plum guides show")
        #expect(Step.complete.text == "Link every guided pair; linked stars pull each other's phases, and a link "
            + "stretched too far snaps — tap a star to nudge its phase, and a hint shows which")
        #expect(Step.listen.text == "Tap the coherence gauge (or Listen) to hear whether the stars hold together for "
            + "the hold; if they fall apart, undo")
        #expect(Step.done.text.isEmpty)
        #expect(Step.initial(tutorial: true) == .link && Step.initial(tutorial: false) == .done)
        for level in 1...100 {
            let expected: Step = level <= 3 ? .link : .done
            #expect(Step.initial(level: level) == expected)
        }
        for step in Step.allCases { #expect(step.dismissed() == .done) }
    }

    @Test func tutorialAdvancesInOrderNeverBack() {
        #expect(Step.link.advanced(afterLink: true, complete: false, ended: false) == .complete)
        #expect(Step.link.advanced(afterLink: true, complete: true, ended: false) == .listen)
        #expect(Step.link.advanced(afterLink: false, complete: true, ended: false) == .link)
        #expect(Step.link.advanced(afterLink: false, complete: false, ended: false) == .link)
        #expect(Step.complete.advanced(afterLink: true, complete: false, ended: false) == .complete)
        #expect(Step.complete.advanced(afterLink: false, complete: true, ended: false) == .listen)
        #expect(Step.listen.advanced(afterLink: true, complete: false, ended: false) == .listen)
        #expect(Step.done.advanced(afterLink: true, complete: true, ended: false) == .done)
        for step in Step.allCases {
            #expect(step.advanced(afterLink: false, complete: false, ended: true) == .done)
            #expect(step.advanced(afterLink: true, complete: true, ended: true) == .done)
        }
        let order: [Step] = [.link, .complete, .listen, .done]
        for (position, step) in order.enumerated() {
            for flags in 0..<8 {
                let next: Step = step.advanced(afterLink: flags & 1 != 0, complete: flags & 2 != 0,
                                               ended: flags & 4 != 0)
                let nextPosition: Int = order.firstIndex(of: next) ?? -1
                #expect(nextPosition >= position)
            }
        }
    }

    @Test func completenessIsTheSymbolPairsInTheLinks() {
        let symbol: [AcousticConstellatorLink] = [.between(0, 1), .between(1, 2)]
        #expect(!Step.isComplete(symbol: symbol, links: []))
        #expect(!Step.isComplete(symbol: symbol, links: [.between(0, 1)]))
        #expect(Step.isComplete(symbol: symbol, links: [.between(0, 1), .between(1, 2)]))
        #expect(Step.isComplete(symbol: symbol, links: [.between(0, 1), .between(0, 2), .between(1, 2)]))
    }

    @Test func tutorialLevelsWitnessPlaysWalkTheSteps() throws {
        for number in 1...3 {
            let generated: AcousticConstellatorGenerated = try Core.generated(number: number)
            let level: AcousticConstellatorLevel = generated.level
            #expect(level.tutorial)
            var play: Play = try Core.freshPlay(of: level)
            #expect(!Step.isComplete(play))
            var step: Step = Step.initial(tutorial: level.tutorial)
            #expect(step == .link)
            var seen: [Step] = [step]
            let actions: [Action] = generated.actions
            #expect(actions.last == .listen)
            for (index, action) in actions.enumerated() {
                let before: Step = step
                step = try Self.step(step, applying: action, to: &play)
                if index == actions.count - 1 {
                    #expect(play.stage == .won && step == .done)
                } else if Step.isComplete(play) {
                    #expect(step == .listen)
                } else {
                    #expect(step == .complete)
                    #expect(before != .link || index == 0)
                }
                if seen.last != step { seen.append(step) }
            }
            // The witness links every missing symbol pair first, so the first link leads to complete, or straight on
            // to listen when the symbol had one pair missing.
            let ok: Bool = seen == [.link, .complete, .listen, .done] || seen == [.link, .listen, .done]
            #expect(ok, "level \(number): \(seen)")
        }
    }

    @Test func tutorialDetourNeverMovesBack() throws {
        for number in 1...3 {
            let generated: AcousticConstellatorGenerated = try Core.generated(number: number)
            let actions: [Action] = generated.actions
            var play: Play = try Core.freshPlay(of: generated.level)
            var step: Step = .link
            // The first link, undone and redone: the step never falls back to link.
            step = try Self.step(step, applying: actions[0], to: &play)
            let afterFirst: Step = step
            #expect(afterFirst == .complete || afterFirst == .listen)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == afterFirst)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == afterFirst)
            // The remaining moves complete the symbol: listen; undoing the last link leaves listen.
            for action in actions.dropFirst() where action != .listen {
                step = try Self.step(step, applying: action, to: &play)
            }
            #expect(Step.isComplete(play) && step == .listen)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == .listen)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(step == .listen)
            step = try Self.step(step, applying: .listen, to: &play)
            #expect(play.stage == .won && step == .done)
            // Records: the moves, two undos and two redos, the listen — the undone ones were redone, not re-spent.
            #expect(Progress.actionsSpent(play) == actions.count)
        }
    }

    @Test func failedPlayEndsTheTutorialAndRedoOfAFailureEndsIt() throws {
        for number in 1...3 {
            let generated: AcousticConstellatorGenerated = try Core.generated(number: number)
            var play: Play = try Core.freshPlay(of: generated.level)
            // A listen at the start finds a symbol pair missing: the level ends and the tutorial is done.
            let step: Step = try Self.step(.link, applying: .listen, to: &play)
            #expect(play.stage == .failed && step == .done)
            // An undo of the failed listen lands before the end and never moves the step back.
            try play.undo()
            #expect(play.stage == .playing)
            #expect(Self.stepAfterHistory(step, play) == .done)
            // An undo alone never ends a running tutorial; a redo that restores the failed play ends it.
            #expect(Self.stepAfterHistory(.link, play) == .link)
            try play.redo()
            #expect(play.stage == .failed)
            #expect(Self.stepAfterHistory(.link, play) == .done)
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
            let generated: AcousticConstellatorGenerated = try Core.generated(number: number)
            let actions: [Action] = generated.actions
            let certified: Int = actions.count
            var play: Play = try Core.freshPlay(of: generated.level)
            #expect(Progress.actionsSpent(play) == 0)
            // A link undone and applied again counts twice.
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
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 2) == 90)
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 12)   // day −1: (−89 wrapped to 11) + 1
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
                    #expect(level == (dayIndex * 89) % 100 + 1)
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
        // Starting on 2031-07-15 (crossing a year end and a leap day is not needed for the sequence; it is day based).
        var seen: Set<Int> = []
        var year: Int = 2031
        var month: Int = 7
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
                let wrapped: Int = ((dayCount * 89) % 100 + 100) % 100 + 1
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
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) == (789 * 89) % 100 + 1)
        #expect(Progress.dailyLevel(year: 2028, month: 3, day: 1) == (790 * 89) % 100 + 1)
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
