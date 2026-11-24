// VoxelOrigamiProgressTests — feature 445 (R02-G15-05) T-R02G1505-003 (FR-R02G1505-001, 004, 005; SC-R02G1505-001,
// 004; clarifications Q2, Q3, Q4). The tutorial steps on levels 1 … 3 by scripted plays of their certified witnesses
// (`VoxelOrigamiExperienceCore.generated(number:).plan.turns`, the actions of
// `docs/games/voxel-origami/levels/00N.witness.json`: levels 1 and 3 two turns, level 2 one) applied to the opening
// play through the real kernel (turn → compare → done on the winning turn; turn → done on
// level 2), an undo and redo detour that never moves a step back, a failed play
// ending the tutorial and a redo that restores a failed play ending it; 500 seeded (SeededRandom seed 2_445) flag walks
// that never move a step back; the star thresholds; the actions spent, undone records included; a 100-level progress
// script (frontier, best results, a worse replay not replacing a better one, daily and practice rules); every calendar
// day 2026-01-01 … 2036-12-31 mapping into 1 … 100, stably, and 100 consecutive days visiting every level once;
// negative day counts wrapped; impossible days nil, leap years included; Codable round trips. Test data uses explicit
// types and plain loops (CI type-check rule); each test well under 3 s. No clock: dates are inputs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

@Suite struct VoxelOrigamiProgressTests {
    typealias Step = VoxelOrigamiTutorialStep
    typealias Progress = VoxelOrigamiProgress
    typealias Mode = VoxelOrigamiMode
    typealias Play = VoxelOrigamiPlay
    typealias Action = VoxelOrigamiAction
    typealias Core = VoxelOrigamiExperienceCore

    /// The seed of the seeded flag walks.
    static let seed: UInt64 = 2_445

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: Play) -> Bool { play.stage == .won || play.stage == .failed }

    /// The step after `action` was applied to `play` (which it mutates): an accepted turn and the play's real end.
    static func step(_ step: Step, applying action: Action, to play: inout Play) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        return step.advanced(afterTurn: true, ended: ended(play))
    }

    /// The step after an undo or a redo: no accepted turn and the play's real end.
    static func stepAfterHistory(_ step: Step, _ play: Play) -> Step {
        step.advanced(afterTurn: false, ended: ended(play))
    }

    /// The opening play of level `number` and its certified turns.
    static func opening(_ number: Int) throws -> (play: Play, turns: [Action]) {
        let play: Play = try Core.opening(number: number).play
        let turns: [Action] = try Core.generated(number: number).plan.turns
        return (play, turns)
    }

    /// The inverse of turn `action` (the same hinge, the opposite step).
    static func inverse(_ action: Action) -> Action {
        switch action {
        case .turn(let hinge, let step): .turn(hinge, -step)
        }
    }

    /// Records a win in `progress` (outside `#expect`, which cannot mutate) and returns whether the result changed.
    static func record(_ progress: inout Progress, level: Int, actionsSpent: Int, certified: Int,
                       mode: Mode = .campaign) -> Bool {
        progress.record(level: level, actionsSpent: actionsSpent, certified: certified, mode: mode)
    }

    // MARK: Tutorial

    @Test func tutorialTextsAreClarificationQ2() {
        #expect(Step.turn.text == "Tap a cube to choose its hinge, then drag the cube (or use Turn − and +) to turn "
            + "the hinge a quarter turn: every cube beyond it swings")
        #expect(Step.compare.text == "Orbit with two fingers to see every side and compare the chain with the "
            + "turquoise target — a hint shows which turn is next")
        #expect(Step.recover.text == "If a turn would hit another cube the level fails: undo and choose another "
            + "hinge or way")
        #expect(Step.done.text.isEmpty)
        #expect(Step.initial(tutorial: true) == .turn && Step.initial(tutorial: false) == .done)
        for level in 1...100 {
            let expected: Step = level <= 3 ? .turn : .done
            #expect(Step.initial(level: level) == expected)
        }
        for step in Step.allCases { #expect(step.dismissed() == .done) }
    }

    @Test func tutorialAdvancesInOrderNeverBack() {
        #expect(Step.turn.advanced(afterTurn: true, ended: false) == .compare)
        #expect(Step.turn.advanced(afterTurn: false, ended: false) == .turn)
        #expect(Step.compare.advanced(afterTurn: true, ended: false) == .recover)
        #expect(Step.compare.advanced(afterTurn: false, ended: false) == .compare)
        #expect(Step.recover.advanced(afterTurn: true, ended: false) == .recover)
        #expect(Step.recover.advanced(afterTurn: false, ended: false) == .recover)
        #expect(Step.done.advanced(afterTurn: true, ended: false) == .done)
        #expect(Step.done.advanced(afterTurn: false, ended: false) == .done)
        for step in Step.allCases {
            #expect(step.advanced(afterTurn: false, ended: true) == .done)
            #expect(step.advanced(afterTurn: true, ended: true) == .done)
        }
    }

    @Test func seededFlagWalksNeverMoveBack() {
        let order: [Step] = [.turn, .compare, .recover, .done]
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var reachedDone: Int = 0
        var reachedRecover: Int = 0
        for _ in 0..<500 {
            var step: Step = .turn
            for _ in 0..<12 {
                let afterTurn: Bool = random.int(0...1) == 1
                let ended: Bool = random.int(0...7) == 0
                let next: Step = step.advanced(afterTurn: afterTurn, ended: ended)
                let before: Int = order.firstIndex(of: step) ?? -1
                let after: Int = order.firstIndex(of: next) ?? -1
                #expect(after >= before)
                #expect(after <= before + 1 || next == .done)
                if next == .recover { reachedRecover += 1 }
                step = next
            }
            if step == .done { reachedDone += 1 }
        }
        #expect(reachedDone > 0 && reachedRecover > 0)
    }

    @Test func tutorialLevelsWitnessPlaysWalkTheSteps() throws {
        for number in 1...3 {
            let opening: (play: Play, turns: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            #expect(play.level.tutorial)
            #expect(!opening.turns.isEmpty)
            var step: Step = Step.initial(level: number)
            #expect(step == .turn)
            for (index, action) in opening.turns.enumerated() {
                step = try Self.step(step, applying: action, to: &play)
                let last: Bool = index == opening.turns.count - 1
                if last {
                    #expect(play.stage == .won)
                    #expect(step == .done)
                } else {
                    #expect(play.stage == .playing)
                    let expected: Step = index == 0 ? .compare : .recover
                    #expect(step == expected)
                }
            }
            #expect(Progress.actionsSpent(play) == opening.turns.count)
            let stars: Int = Progress.stars(actionsSpent: Progress.actionsSpent(play),
                                            certified: opening.turns.count)
            #expect(stars == 3)
        }
    }

    @Test func tutorialDetourNeverMovesBack() throws {
        for number in 1...3 {
            let opening: (play: Play, turns: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            var step: Step = .turn
            // A detour: the witness's first hinge turned the other way, undone, redone and undone again.
            step = try Self.step(step, applying: Self.inverse(opening.turns[0]), to: &play)
            #expect(play.stage == .playing && step == .compare)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .compare)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .compare)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .compare)
            for (index, action) in opening.turns.enumerated() {
                step = try Self.step(step, applying: action, to: &play)
                let expected: Step = index == opening.turns.count - 1 ? .done : .recover
                #expect(step == expected)
            }
            #expect(play.stage == .won && step == .done)
            // Every accepted turn record counts, the undone one included; the redo spends nothing new.
            #expect(Progress.actionsSpent(play) == opening.turns.count + 1)
            #expect(play.actionsSpent == opening.turns.count)
        }
    }

    @Test func failedPlayEndsTheTutorialAndRedoOfAFailureEndsIt() throws {
        let opening: (play: Play, turns: [Action]) = try Self.opening(1)
        var play: Play = opening.play
        // Turning the witness's first hinge back and forth never matches (the minimal plan has two or more turns), so
        // the play fails at the latest when the budget is spent.
        let forth: Action = Self.inverse(opening.turns[0])
        let back: Action = opening.turns[0]
        var step: Step = .turn
        var count: Int = 0
        while !Self.ended(play) && count < 40 {
            let action: Action = count % 2 == 0 ? forth : back
            step = try Self.step(step, applying: action, to: &play)
            count += 1
            if !Self.ended(play) {
                let expected: Step = count == 1 ? .compare : .recover
                #expect(step == expected)
            }
        }
        #expect(play.stage == .failed)
        #expect(step == .done)
        // An undo lands before the end: a fresh tutorial at `recover` stays there.
        try play.undo()
        var replayed: Step = Self.stepAfterHistory(.recover, play)
        #expect(play.stage == .playing && replayed == .recover)
        // A redo that restores the failed play ends it.
        try play.redo()
        replayed = Self.stepAfterHistory(replayed, play)
        #expect(play.stage == .failed && replayed == .done)
        #expect(Progress.actionsSpent(play) == count)
    }

    // MARK: Stars and actions

    @Test func starThresholds() {
        for certified in 1...6 {
            for spent in 1...12 {
                let expected: Int = spent <= certified ? 3 : (spent <= certified + 2 ? 2 : 1)
                #expect(Progress.stars(actionsSpent: spent, certified: certified) == expected)
            }
            #expect(Progress.stars(actionsSpent: certified, certified: certified) == 3)
            #expect(Progress.stars(actionsSpent: certified + 1, certified: certified) == 2)
            #expect(Progress.stars(actionsSpent: certified + 2, certified: certified) == 2)
            #expect(Progress.stars(actionsSpent: certified + 3, certified: certified) == 1)
        }
    }

    @Test func actionsSpentCountsUndoneRecords() throws {
        let opening: (play: Play, turns: [Action]) = try Self.opening(1)
        var play: Play = opening.play
        #expect(opening.turns.count == 2)
        #expect(Progress.actionsSpent(play) == 0)
        try play.apply(opening.turns[0], expecting: play.fingerprint)
        try play.undo()
        try play.apply(opening.turns[0], expecting: play.fingerprint)
        #expect(play.actionsSpent == 1)
        #expect(Progress.actionsSpent(play) == 2)
        for index in 1..<opening.turns.count {
            try play.apply(opening.turns[index], expecting: play.fingerprint)
        }
        #expect(play.stage == .won)
        let spent: Int = Progress.actionsSpent(play)
        #expect(spent == opening.turns.count + 1)
        #expect(Progress.stars(actionsSpent: spent, certified: opening.turns.count) == 2)
    }

    // MARK: Progress

    @Test func hundredLevelScript() {
        var progress: Progress = Progress()
        #expect(progress.frontier == 1 && progress.isOpen(1) && !progress.isOpen(2) && !progress.isOpen(0))
        #expect(progress.best(1) == nil && progress.stars(of: 1) == 0)
        #expect(progress.nextOpen(after: 1) == nil)
        for level in 1...100 {
            #expect(progress.isOpen(level))
            let certified: Int = level % 6 + 1
            let spent: Int = certified + level % 4
            let changed: Bool = Self.record(&progress, level: level, actionsSpent: spent, certified: certified)
            #expect(changed)
            #expect(progress.best(level) == spent)
            #expect(progress.stars(of: level) == Progress.stars(actionsSpent: spent, certified: certified))
            #expect(progress.frontier == min(level + 1, 100))
        }
        #expect(progress.frontier == 100 && progress.solved.count == 100)
        // A worse or equal replay keeps the better result; a better one replaces it.
        for level in 1...100 {
            let certified: Int = level % 6 + 1
            let spent: Int = certified + level % 4
            #expect(!Self.record(&progress, level: level, actionsSpent: spent + 1, certified: certified))
            #expect(!Self.record(&progress, level: level, actionsSpent: spent, certified: certified))
            #expect(progress.best(level) == spent)
            if spent > certified {
                #expect(Self.record(&progress, level: level, actionsSpent: certified, certified: certified))
                #expect(progress.best(level) == certified && progress.stars(of: level) == 3)
            }
        }
        #expect(progress.frontier == 100)
        #expect(!Self.record(&progress, level: 0, actionsSpent: 1, certified: 1))
        #expect(!Self.record(&progress, level: 101, actionsSpent: 1, certified: 1))
        #expect(Progress.band(of: 1) == 1 && Progress.band(of: 20) == 1 && Progress.band(of: 21) == 2)
        #expect(Progress.band(of: 100) == 5 && Progress.band(of: 0) == 1 && Progress.band(of: 200) == 5)
    }

    @Test func modesRecordAndOpen() {
        var progress: Progress = Progress()
        #expect(!Self.record(&progress, level: 1, actionsSpent: 2, certified: 2, mode: .practice))
        #expect(progress.best(1) == nil && progress.frontier == 1)
        #expect(Self.record(&progress, level: 50, actionsSpent: 4, certified: 3, mode: .daily(level: 50)))
        #expect(progress.best(50) == 4 && progress.stars(of: 50) == 2 && progress.frontier == 1)
        #expect(Self.record(&progress, level: 1, actionsSpent: 2, certified: 2, mode: .campaign))
        #expect(progress.frontier == 2 && progress.nextOpen(after: 1) == 2)
        progress.open(through: 7)
        #expect(progress.frontier == 7)
        progress.open(through: 3)
        #expect(progress.frontier == 7)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 40 && Mode.practiceBudget == VoxelOrigamiLevel.budgets.upperBound)
        #expect(Mode.practice.budget(base: 9) == 40 && Mode.campaign.budget(base: 9) == 9)
        #expect(Mode.daily(level: 3).budget(base: 11) == 11)
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 1).awardsStars && !Mode.practice.awardsStars)
        #expect(Mode.campaign.opensLevels && !Mode.daily(level: 1).opensLevels && !Mode.practice.opensLevels)
    }

    // MARK: Daily level

    @Test func dailyLevelOverElevenYears() {
        var days: Int = 0
        var counts: [Int] = [Int](repeating: 0, count: 101)
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...Progress.daysIn(month: month, year: year) {
                    let level: Int? = Progress.dailyLevel(year: year, month: month, day: day)
                    #expect(level != nil)
                    let value: Int = level ?? 0
                    #expect(value >= 1 && value <= 100)
                    #expect(Progress.dailyLevel(year: year, month: month, day: day) == level)
                    #expect(Progress.daysFromEpoch(year: year, month: month, day: day) == days)
                    #expect(value == (days * 31) % 100 + 1)
                    counts[min(max(value, 0), 100)] += 1
                    days += 1
                }
            }
        }
        #expect(days == 4_018)
        for level in 1...100 { #expect(counts[level] >= 40) }
        #expect(Progress.dailyMultiplier == 31)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 2) == 32)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 1) == 62)
        #expect(Progress.dailyLevel(year: 2027, month: 1, day: 1) == 16)
        #expect(Progress.dailyLevel(year: 2036, month: 12, day: 31) == 28)
    }

    @Test func hundredConsecutiveDaysVisitEveryLevelOnce() {
        let starts: [(Int, Int, Int)] = [(2026, 1, 1), (2026, 11, 24), (2028, 2, 10), (2031, 12, 1)]
        for start in starts {
            var year: Int = start.0
            var month: Int = start.1
            var day: Int = start.2
            var seen: Set<Int> = []
            for _ in 0..<100 {
                seen.insert(Progress.dailyLevel(year: year, month: month, day: day) ?? 0)
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
            #expect(seen.count == 100 && !seen.contains(0))
        }
    }

    @Test func negativeDayCountsWrap() {
        #expect(Progress.daysFromEpoch(year: 2025, month: 12, day: 31) == -1)
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 70)
        #expect(Progress.dailyLevel(year: 2025, month: 1, day: 1) == 86)
        #expect(Progress.daysFromEpoch(year: 2025, month: 1, day: 1) == -365)
        for year in [1, 1600, 1900, 2000, 2024] {
            for month in [1, 2, 7, 12] {
                let level: Int = Progress.dailyLevel(year: year, month: month, day: 28) ?? 0
                let days: Int = Progress.daysFromEpoch(year: year, month: month, day: 28) ?? 0
                #expect(days < 0)
                #expect(level >= 1 && level <= 100)
                #expect(level == ((days * 31) % 100 + 100) % 100 + 1)
            }
        }
    }

    @Test func impossibleDaysAreNilAndLeapYears() {
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2025, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2024, month: 4, day: 31) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 32) == nil)
        #expect(Progress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2024, month: 2, day: 29) != nil)
        #expect(Progress.daysIn(month: 2, year: 2028) == 29 && Progress.daysIn(month: 2, year: 2026) == 28)
        #expect(Progress.daysIn(month: 11, year: 2026) == 30 && Progress.daysIn(month: 12, year: 2026) == 31)
    }

    // MARK: Codable

    @Test func codableRoundTrips() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder: JSONDecoder = JSONDecoder()
        var progress: Progress = Progress()
        progress.record(level: 3, actionsSpent: 5, certified: 3, opensNext: false)
        progress.record(level: 1, actionsSpent: 2, certified: 2)
        progress.open(through: 4)
        let data: Data = try progress.encoded()
        let decoded: Progress = try decoder.decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":4,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,\"trace\":[],"
            + "\"verified\":false},{\"actionsSpent\":5,\"level\":3,\"stars\":2,\"trace\":[],\"verified\":false}]}")
        let empty: Progress = try decoder.decode(Progress.self, from: try Progress().encoded())
        #expect(empty == Progress())
        let bad: [String] = ["{\"frontier\":0,\"solved\":[]}", "{\"frontier\":101,\"solved\":[]}",
                             "{\"frontier\":1,\"solved\":[{\"actionsSpent\":1,\"level\":0,\"stars\":3}]}",
                             "{\"frontier\":1,\"solved\":[{\"actionsSpent\":1,\"level\":1,\"stars\":4}]}",
                             "{\"frontier\":1,\"solved\":[{\"actionsSpent\":-1,\"level\":1,\"stars\":3}]}",
                             "{\"frontier\":2,\"solved\":[{\"actionsSpent\":1,\"level\":1,\"stars\":3},"
                                + "{\"actionsSpent\":1,\"level\":1,\"stars\":3}]}"]
        for json in bad {
            #expect(throws: DecodingError.self) { try decoder.decode(Progress.self, from: Data(json.utf8)) }
        }
        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
        for mode in modes {
            let modeData: Data = try encoder.encode(mode)
            #expect(try decoder.decode(Mode.self, from: modeData) == mode)
        }
        #expect(String(decoding: try encoder.encode(Mode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        #expect(String(decoding: try encoder.encode(Mode.campaign), as: UTF8.self) == "{\"mode\":\"campaign\"}")
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"daily\"}", "{\"mode\":\"replay\"}"]
        for json in badModes {
            #expect(throws: DecodingError.self) { try decoder.decode(Mode.self, from: Data(json.utf8)) }
        }
        for step in Step.allCases {
            let stepData: Data = try encoder.encode([step])
            #expect(try decoder.decode([Step].self, from: stepData) == [step])
            #expect(String(decoding: stepData, as: UTF8.self) == "[\"" + step.rawValue + "\"]")
        }
    }
}
