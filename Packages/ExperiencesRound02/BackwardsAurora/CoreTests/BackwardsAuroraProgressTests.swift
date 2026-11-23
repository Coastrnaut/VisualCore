// BackwardsAuroraProgressTests — feature 395 (R02-G10-05) T-R02G1005-003 (FR-R02G1005-001, 004, 005; SC-R02G1005-001,
// 004; clarifications Q2, Q3, Q4). The tutorial on levels 1 … 3 driven by the certified solutions through a play from
// the opening state (the first accepted reversal → `reverse`, the second → `finish`, the winning reversal ends the level
// → `done`), the steps seen in order and ending `done` at the win; a failed level ends the tutorial and undo does not
// bring it back; dismissal; undo and redo never move the step back; the tutorial texts of clarification Q2 word for
// word. Reversals made counted from real plays with reverse-and-undo detours (stars 3, 2 and 1). Progress scripted
// through 100 levels with seeded smallest reversal counts (seed 2,395; each campaign win opens the next; stars against
// the smallest reversal count; a better result replaces a worse one, a worse or equal one does not; daily records
// without opening, practice records nothing); the star thresholds; every day 2026-01-01 … 2036-12-31 maps into
// 1 … 100, stably, consecutive days differ by 73 mod 100 and every 100 consecutive days visit every level; days before
// 2026 wrap; impossible days refused; Codable round trips of the step, the mode and the progress. Explicit types, plain
// loops; each test < 10 s.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BackwardsAuroraCore

@Suite struct BackwardsAuroraProgressTests {
    typealias Step = BackwardsAuroraTutorialStep
    typealias Mode = BackwardsAuroraMode
    typealias Progress = BackwardsAuroraProgress
    typealias Core = BackwardsAuroraExperienceCore
    typealias Play = BackwardsAuroraPlay
    typealias Action = BackwardsAuroraAction

    /// The progression test seed.
    static let seed: UInt64 = 2_395

    // MARK: - Tutorial

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: Play) -> Bool {
        play.stage == .won || play.stage == .failed
    }

    /// Whether the latest record of `play` is a reversal (not an undo or redo).
    static func lastWasReversal(_ play: Play) -> Bool {
        play.records.last?.kind == .reverse
    }

    /// The step after the latest record of `play`.
    static func next(_ step: Step, play: Play) -> Step {
        step.advanced(afterReversal: lastWasReversal(play), ended: ended(play))
    }

    /// The opening play of level `number` (playing, kernel tutorial dismissed).
    static func fresh(_ number: Int) throws -> Play {
        try Core.opening(number: number).play
    }

    /// The steps the tutorial must show for a winning sequence of `count` reversals, by the rules of clarification Q2.
    static func expectedSteps(reversals count: Int) -> [Step] {
        if count <= 1 { return [.mark, .done] }
        if count == 2 { return [.mark, .reverse, .done] }
        return [.mark, .reverse, .finish, .done]
    }

    @Test func tutorialFollowsCertifiedSolutionsOnLevelsOneToThree() throws {
        var lengths: [Int] = []
        for number in 1...3 {
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            #expect(generated.level.tutorial)
            var play: Play = try Self.fresh(number)
            #expect(play.stage == .playing)
            var step: Step = Step.initial(tutorial: generated.level.tutorial)
            #expect(step == .mark)
            #expect(Step.initial(level: number) == .mark)
            var seen: [Step] = [step]
            let actions: [Action] = generated.solution.actions
            #expect(actions.count == generated.solution.smallest)
            var index: Int = 0
            for action in actions {
                index += 1
                try play.apply(action, expecting: play.fingerprint)
                let next: Step = Self.next(step, play: play)
                if index == actions.count {
                    #expect(play.stage == .won, "level \(number)")
                    #expect(next == .done)
                } else {
                    #expect(play.stage == .playing, "level \(number) reversal \(index)")
                    #expect(next != .done)
                    #expect(next == (index == 1 ? Step.reverse : Step.finish))
                }
                if next != step { seen.append(next) }
                step = next
            }
            #expect(seen == Self.expectedSteps(reversals: actions.count), "level \(number)")
            var order: Int = -1
            for shown in seen {
                let position: Int = Step.allCases.firstIndex(of: shown) ?? -1
                #expect(position > order)
                order = position
            }
            #expect(Progress.reversalsMade(play) == actions.count)
            lengths.append(actions.count)
            // A detour (the first certified reversal, then undo) before the solution: the detour's reversal was
            // accepted, so the step reaches `reverse`, then `finish` on the next reversal, and `done` at the win.
            var detoured: Play = try Self.fresh(number)
            var shown: Step = Step.initial(level: number)
            var detourSeen: [Step] = [shown]
            guard let first = actions.first, actions.count >= 2 else { continue }
            try detoured.apply(first, expecting: detoured.fingerprint)
            shown = Self.next(shown, play: detoured)
            detourSeen.append(shown)
            try detoured.undo()
            shown = Self.next(shown, play: detoured)
            #expect(shown == .reverse)
            for action in actions {
                try detoured.apply(action, expecting: detoured.fingerprint)
                let next: Step = Self.next(shown, play: detoured)
                if next != shown { detourSeen.append(next) }
                shown = next
            }
            #expect(detoured.stage == .won)
            #expect(detourSeen == [.mark, .reverse, .finish, .done], "level \(number) with a detour")
        }
        // Level 4 onwards carries no tutorial.
        let fourth: BackwardsAuroraGenerated = try Core.generated(number: 4)
        #expect(!fourth.level.tutorial)
        #expect(Step.initial(tutorial: fourth.level.tutorial) == .done)
        print("BackwardsAuroraProgressTests solution lengths of levels 1 … 3: \(lengths)")
    }

    @Test func undoAndRedoNeverMoveTheStepBack() throws {
        var checked: Int = 0
        for number in 1...3 {
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            let actions: [Action] = generated.solution.actions
            var play: Play = try Self.fresh(number)
            var step: Step = Step.initial(level: number)
            // Every reversal but the winning one, undone and redone after each: the step never moves back.
            for action in actions.dropLast() {
                try play.apply(action, expecting: play.fingerprint)
                step = Self.next(step, play: play)
                let before: Step = step
                try play.undo()
                #expect(play.records.last?.kind == .undo)
                step = Self.next(step, play: play)
                #expect(step == before)
                try play.redo()
                #expect(play.records.last?.kind == .redo)
                step = Self.next(step, play: play)
                #expect(step == before)
                checked += 1
            }
            #expect(step != .mark || actions.count == 1)
            // Undo and redo records are not reversals: the reversals made equal the reversal records.
            #expect(Progress.reversalsMade(play) == actions.count - 1)
            // Undoing every reversal back to the opening wave leaves the step where it is.
            let reached: Step = step
            while play.canUndo {
                try play.undo()
                step = Self.next(step, play: play)
                #expect(step == reached)
            }
            #expect(play.spent == 0)
        }
        for start in Step.allCases {
            #expect(start.advanced(afterReversal: false, ended: false) == start)
        }
        print("BackwardsAuroraProgressTests undo/redo checks: \(checked)")
    }

    @Test func aFailedLevelEndsTheTutorialAndUndoKeepsItEnded() throws {
        for number in 1...3 {
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            guard generated.solution.smallest >= 2, let first = generated.solution.actions.first else { continue }
            var play: Play = try Self.fresh(number)
            var step: Step = Step.initial(level: number)
            // The first certified reversal applied again and again toggles its section: the play never wins (the
            // smallest count is at least 2) and ends by a tear or the budget.
            var guardCount: Int = 0
            while !Self.ended(play) && guardCount < 64 {
                try play.apply(first, expecting: play.fingerprint)
                step = Self.next(step, play: play)
                guardCount += 1
            }
            #expect(play.stage == .failed, "level \(number)")
            #expect(step == .done)
            try play.undo()
            #expect(play.stage == .playing)
            step = Self.next(step, play: play)
            #expect(step == .done)
        }
    }

    @Test func transitionTableTextsAndDismissal() {
        for start in Step.allCases {
            #expect(start.dismissed() == .done)
            #expect(start.advanced(afterReversal: false, ended: true) == .done)
            #expect(start.advanced(afterReversal: true, ended: true) == .done)
            #expect(start.advanced(afterReversal: false, ended: false) == start)
        }
        #expect(Step.mark.advanced(afterReversal: true, ended: false) == .reverse)
        #expect(Step.reverse.advanced(afterReversal: true, ended: false) == .finish)
        #expect(Step.finish.advanced(afterReversal: true, ended: false) == .finish)
        #expect(Step.done.advanced(afterReversal: true, ended: false) == .done)
        #expect(Step.initial(tutorial: true) == .mark)
        #expect(Step.initial(tutorial: false) == .done)
        for level in 0...101 {
            #expect(Step.initial(level: level) == ((1...3).contains(level) ? Step.mark : Step.done))
        }
        #expect(Step.mark.text
            == "Tap two samples to mark the ends of a section (or use the panel) — a hint shows which")
        #expect(Step.reverse.text == "Swipe along the section to reverse it, or hold it first to preview; keep every "
            + "bend within the limit and never tear the aurora")
        #expect(Step.finish.text == "Bring every checkpoint to its true height before the reversals run out")
        #expect(Step.done.text.isEmpty)
    }

    // MARK: - Reversals made from real plays

    @Test func reversalsMadeCountsUndoneReversalsAndGivesStars() throws {
        var progress: Progress = Progress()
        for number in 1...5 {
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            let actions: [Action] = generated.solution.actions
            let smallest: Int = generated.solution.smallest
            guard let first = actions.first else {
                Issue.record("level \(number) has no solution reversals")
                continue
            }
            // k detours of (first reversal, undo) before the certified solution: reversals made = smallest + k.
            for detours in 0...4 {
                var play: Play = try Self.fresh(number)
                var made: Int = 0
                while made < detours {
                    try play.apply(first, expecting: play.fingerprint)
                    if play.stage == .won { break }
                    try play.undo()
                    made += 1
                }
                if play.stage == .won {
                    // A one-reversal level wins on its first reversal: no detour can be made with it.
                    #expect(smallest == 1)
                    continue
                }
                for action in actions { try play.apply(action, expecting: play.fingerprint) }
                #expect(play.stage == .won, "level \(number) detours \(detours)")
                let reversals: Int = Progress.reversalsMade(play)
                #expect(reversals == smallest + detours)
                #expect(play.spent == smallest)
                let expected: Int = detours == 0 ? 3 : (detours <= 2 ? 2 : 1)
                #expect(Progress.stars(reversalsMade: reversals, smallest: smallest) == expected)
                // Worse results never replace the best (detours rise), so only the first win stores.
                let changed: Bool = progress.record(level: number, reversalsMade: reversals, smallest: smallest)
                #expect(changed == (detours == 0))
                #expect(progress.solved[number] == Progress.Result(reversalsMade: smallest, stars: 3))
            }
            #expect(progress.isOpen(number + 1))
        }
        #expect(progress.frontier == 6)
    }

    // MARK: - Progress

    @Test func starThresholds() {
        for smallest in 1...40 {
            for reversals in 0...60 {
                let expected: Int = reversals <= smallest ? 3 : (reversals <= smallest + 2 ? 2 : 1)
                #expect(Progress.stars(reversalsMade: reversals, smallest: smallest) == expected)
            }
        }
        #expect(Progress.stars(reversalsMade: 3, smallest: 3) == 3)
        #expect(Progress.stars(reversalsMade: 5, smallest: 3) == 2)
        #expect(Progress.stars(reversalsMade: 6, smallest: 3) == 1)
    }

    @Test func scriptedProgressThroughOneHundredLevels() {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var progress: Progress = Progress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1))
        #expect(!progress.isOpen(2))
        #expect(!progress.isOpen(0))
        #expect(progress.nextOpen(after: 1) == nil)
        var stars: Int = 0
        for level in 1...100 {
            let smallest: Int = random.int(1...12)
            let extra: Int = random.int(0...5)
            #expect(progress.isOpen(level))
            #expect(!progress.isOpen(level + 1) || level == 100)
            // A first result of smallest + extra reversals made: stars by the thresholds; the next level opens.
            let first: Int = smallest + extra
            let firstStars: Int = extra == 0 ? 3 : (extra <= 2 ? 2 : 1)
            let changed1: Bool = progress.record(level: level, reversalsMade: first, smallest: smallest)
            #expect(changed1)
            #expect(progress.solved[level] == Progress.Result(reversalsMade: first, stars: firstStars))
            #expect(progress.frontier == min(level + 1, 100))
            // A worse and an equal result keep the stored one.
            let changed2: Bool = progress.record(level: level, reversalsMade: first + 1, smallest: smallest)
            #expect(!changed2)
            let changed3: Bool = progress.record(level: level, reversalsMade: first, smallest: smallest)
            #expect(!changed3)
            #expect(progress.solved[level]?.reversalsMade == first)
            // A better result replaces it (every second level), down to the smallest → 3 stars.
            if level % 2 == 0 && extra > 0 {
                let changed4: Bool = progress.record(level: level, reversalsMade: smallest, smallest: smallest)
                #expect(changed4)
                #expect(progress.solved[level] == Progress.Result(reversalsMade: smallest, stars: 3))
            }
            stars += progress.solved[level]?.stars ?? 0
            if level < 100 {
                #expect(progress.nextOpen(after: level) == level + 1)
            }
            #expect(Progress.band(of: level) == (level - 1) / 20 + 1)
        }
        #expect(progress.frontier == 100)
        #expect(progress.nextOpen(after: 100) == nil)
        #expect(progress.solved.count == 100)
        var total: Int = 0
        for result in progress.solved.values {
            #expect(result.stars >= 1 && result.stars <= 3)
            total += result.stars
        }
        #expect(total == stars)
        let changed5: Bool = progress.record(level: 0, reversalsMade: 1, smallest: 1)
        #expect(!changed5)
        let changed6: Bool = progress.record(level: 101, reversalsMade: 1, smallest: 1)
        #expect(!changed6)
        #expect(Progress.band(of: 0) == 1)
        #expect(Progress.band(of: 101) == 5)
        print("BackwardsAuroraProgressTests scripted stars over 100 levels: \(total)")
    }

    @Test func modesDailyAndPractice() {
        var progress: Progress = Progress()
        let changed1: Bool = progress.record(level: 1, reversalsMade: 1, smallest: 1, mode: .practice)
        #expect(!changed1)
        #expect(progress == Progress())
        let changed2: Bool = progress.record(level: 50, reversalsMade: 2, smallest: 1, mode: .daily(level: 50))
        #expect(changed2)
        #expect(progress.solved[50]?.stars == 2)
        #expect(progress.frontier == 1)
        #expect(!progress.isOpen(50))
        let changed3: Bool = progress.record(level: 60, reversalsMade: 4, smallest: 4, opensNext: false)
        #expect(changed3)
        #expect(progress.frontier == 1)
        let changed4: Bool = progress.record(level: 1, reversalsMade: 4, smallest: 4, mode: .campaign)
        #expect(changed4)
        #expect(progress.frontier == 2)
        progress.open(through: 30)
        #expect(progress.frontier == 30)
        progress.open(through: 10)
        #expect(progress.frontier == 30)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 40)
        #expect(Mode.practiceBudget == BackwardsAuroraLevel.budgets.upperBound)
        #expect(Mode.practice.budget(base: 9) == 40)
        #expect(Mode.campaign.budget(base: 9) == 9)
        #expect(Mode.daily(level: 7).budget(base: 9) == 9)
        #expect(Mode.campaign.opensLevels)
        #expect(!Mode.daily(level: 7).opensLevels)
        #expect(!Mode.practice.opensLevels)
        #expect(!Mode.practice.awardsStars)
        #expect(Mode.campaign.awardsStars)
        #expect(Mode.daily(level: 7).awardsStars)
    }

    // MARK: - Daily level

    @Test func everyDayOfElevenYearsMapsIntoTheLevels() {
        var levels: [Int] = []
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...Progress.daysIn(month: month, year: year) {
                    let level: Int? = Progress.dailyLevel(year: year, month: month, day: day)
                    #expect(level != nil)
                    #expect(Progress.dailyLevel(year: year, month: month, day: day) == level)
                    levels.append(level ?? 0)
                }
            }
        }
        #expect(levels.count == 4_018)
        #expect(levels[0] == 1)
        #expect(levels[1] == 74)
        var index: Int = 0
        while index < levels.count {
            #expect(levels[index] >= 1 && levels[index] <= 100)
            #expect(levels[index] == (index * 73) % 100 + 1)
            if index > 0 {
                #expect((levels[index] - levels[index - 1] + 100) % 100 == 73, "day \(index)")
            }
            index += 1
        }
        var start: Int = 0
        while start + 100 <= levels.count {
            var visited: Set<Int> = []
            for offset in 0..<100 { visited.insert(levels[start + offset]) }
            #expect(visited.count == 100, "window from day \(start)")
            start += 1
        }
        #expect(Progress.dailyMultiplier == 73)
        // 73 differs from the other round-two games' multipliers.
        let others: [Int] = [37, 41, 43, 47, 53, 59, 61, 67, 71]
        #expect(!others.contains(Progress.dailyMultiplier))
    }

    @Test func negativeDayCountsWrap() {
        // 2025-12-31 is day −1 → (−73 mod 100) + 1 = 28; 2025-12-30 is day −2 → (−146 mod 100) + 1 = 55.
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 28)
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 30) == 55)
        // 2025 has 365 days: 2025-01-01 is day −365 → (−26,645 mod 100) + 1 = 56.
        #expect(Progress.dailyLevel(year: 2025, month: 1, day: 1) == 56)
        // Every day of 2016 … 2025 (counted back from 2025-12-31) follows the same formula on its negative day count.
        var days: Int = 0
        var year: Int = 2025
        while year >= 2016 {
            var month: Int = 12
            while month >= 1 {
                var day: Int = Progress.daysIn(month: month, year: year)
                while day >= 1 {
                    days -= 1
                    let wrapped: Int = ((days * 73) % 100 + 100) % 100 + 1
                    let level: Int? = Progress.dailyLevel(year: year, month: month, day: day)
                    #expect(level == wrapped, "\(year)-\(month)-\(day)")
                    #expect(Progress.dailyLevel(year: year, month: month, day: day) == level)
                    day -= 1
                }
                month -= 1
            }
            year -= 1
        }
        #expect(days == -3_653)
        #expect(Progress.dailyLevel(year: 1, month: 1, day: 1) != nil)
        #expect(Progress.dailyLevel(year: 9999, month: 12, day: 31) != nil)
    }

    @Test func impossibleDaysAreRefused() {
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(Progress.dailyLevel(year: 2027, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 32) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: -1) == nil)
        #expect(Progress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
        #expect(Progress.dailyYears == 1...9999)
    }

    // MARK: - Codable

    @Test func codableRoundTrips() throws {
        var progress: Progress = Progress()
        progress.record(level: 1, reversalsMade: 6, smallest: 5)
        progress.record(level: 2, reversalsMade: 19, smallest: 6)
        progress.record(level: 70, reversalsMade: 9, smallest: 9, mode: .daily(level: 70))
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        // Feature 397: every result also writes its trace and whether it is verified (untraced here).
        #expect(text == "{\"frontier\":3,\"solved\":[{\"level\":1,\"reversalsMade\":6,\"stars\":2,\"trace\":[],"
            + "\"verified\":false},{\"level\":2,\"reversalsMade\":19,\"stars\":1,\"trace\":[],\"verified\":false},"
            + "{\"level\":70,\"reversalsMade\":9,\"stars\":3,\"trace\":[],\"verified\":false}]}")
        let empty: Progress = try JSONDecoder().decode(Progress.self, from: try Progress().encoded())
        #expect(empty == Progress())
        let bad: [String] = ["{\"frontier\":0,\"solved\":[]}", "{\"frontier\":101,\"solved\":[]}",
                             "{\"frontier\":1,\"solved\":[{\"reversalsMade\":1,\"level\":1,\"stars\":4}]}",
                             "{\"frontier\":1,\"solved\":[{\"reversalsMade\":1,\"level\":1,\"stars\":0}]}",
                             "{\"frontier\":1,\"solved\":[{\"reversalsMade\":1,\"level\":0,\"stars\":1}]}",
                             "{\"frontier\":1,\"solved\":[{\"reversalsMade\":1,\"level\":101,\"stars\":1}]}",
                             "{\"frontier\":1,\"solved\":[{\"reversalsMade\":-1,\"level\":1,\"stars\":1}]}",
                             "{\"frontier\":2,\"solved\":[{\"reversalsMade\":1,\"level\":1,\"stars\":3},"
                                + "{\"reversalsMade\":2,\"level\":1,\"stars\":3}]}",
                             "{\"frontier\":1}"]
        for json in bad {
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(Progress.self, from: Data(json.utf8)) }
        }
        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100), .replay(level: 1),
                             .replay(level: 100)]
        for mode in modes {
            let encoded: Data = try JSONEncoder().encode(mode)
            #expect(try JSONDecoder().decode(Mode.self, from: encoded) == mode)
        }
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(String(decoding: try encoder.encode(Mode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        #expect(String(decoding: try encoder.encode(Mode.practice), as: UTF8.self) == "{\"mode\":\"practice\"}")
        #expect(String(decoding: try encoder.encode(Mode.campaign), as: UTF8.self) == "{\"mode\":\"campaign\"}")
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"daily\"}", "{\"mode\":\"replay\",\"level\":0}",
                                  "{\"mode\":\"replay\",\"level\":101}", "{\"mode\":\"replay\"}", "{}"]
        for json in badModes {
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(Mode.self, from: Data(json.utf8)) }
        }
        for step in Step.allCases {
            let encoded: Data = try JSONEncoder().encode([step])
            #expect(String(decoding: encoded, as: UTF8.self) == "[\"\(step.rawValue)\"]")
            #expect(try JSONDecoder().decode([Step].self, from: encoded) == [step])
        }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([Step].self, from: Data("[\"plant\"]".utf8)) }
    }
}
