// NocturneGardenProgressTests — feature 385 (R02-G09-05) T-R02G0905-003 (FR-R02G0905-001, 004, 005; SC-R02G0905-001,
// 004; clarifications Q2, Q3, Q4). The tutorial on levels 1 … 3 driven by the certified solutions through a play from
// the opening state (the first accepted move → `shape`, the second → `finish`, the winning move ends the level →
// `done`), the steps seen in order and ending `done` at the win; dismissal; undo and redo never move the step back; the
// tutorial texts of clarification Q2 word for word. Moves made counted from real plays with move-and-undo detours
// (stars 3, 2 and 1). Progress scripted through 100 levels with seeded smallest move counts (seed 2,385; each campaign
// win opens the next; stars against the smallest move count; a better result replaces a worse one, a worse or equal
// one does not; daily records without opening, practice records nothing); the star thresholds; every day 2026-01-01 …
// 2036-12-31 maps into 1 … 100, stably, consecutive days differ by 71 mod 100 and every 100 consecutive days visit
// every level; days before 2026 wrap; impossible days refused; Codable round trips of the step, the mode and the
// progress. Explicit types, plain loops; each test < 10 s.
import Foundation
import Testing
import VisualCoreSimulation
@testable import NocturneGardenCore

@Suite struct NocturneGardenProgressTests {
    typealias Step = NocturneGardenTutorialStep
    typealias Mode = NocturneGardenMode
    typealias Progress = NocturneGardenProgress
    typealias Core = NocturneGardenExperienceCore

    /// The progression test seed.
    static let seed: UInt64 = 2_385

    // MARK: - Tutorial

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: NocturneGardenPlay) -> Bool {
        play.stage == .won || play.stage == .failed
    }

    /// Whether the latest record of `play` is a move (not an undo or redo).
    static func lastWasMove(_ play: NocturneGardenPlay) -> Bool {
        guard let kind = play.records.last?.kind else { return false }
        return kind != .undo && kind != .redo
    }

    /// The step after the latest record of `play`.
    static func next(_ step: Step, play: NocturneGardenPlay) -> Step {
        step.advanced(afterMove: lastWasMove(play), ended: ended(play))
    }

    /// The opening play of level `number` (playing, kernel tutorial dismissed).
    static func fresh(_ number: Int) throws -> NocturneGardenPlay {
        try Core.opening(number: number).play
    }

    /// The steps the tutorial must show for a winning sequence of `count` moves, by the rules of clarification Q2.
    static func expectedSteps(moves count: Int) -> [Step] {
        if count <= 1 { return [.plant, .done] }
        if count == 2 { return [.plant, .shape, .done] }
        return [.plant, .shape, .finish, .done]
    }

    @Test func tutorialFollowsCertifiedSolutionsOnLevelsOneToThree() throws {
        var lengths: [Int] = []
        for number in 1...3 {
            let generated: NocturneGardenGenerated = try Core.generated(number: number)
            #expect(generated.level.tutorial)
            var play: NocturneGardenPlay = try Self.fresh(number)
            #expect(play.stage == .playing)
            var step: Step = Step.initial(tutorial: generated.level.tutorial)
            #expect(step == .plant)
            #expect(Step.initial(level: number) == .plant)
            var seen: [Step] = [step]
            let actions: [NocturneGardenAction] = generated.solution.actions
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
                    #expect(play.stage == .playing, "level \(number) move \(index)")
                    #expect(next != .done)
                }
                if next != step { seen.append(next) }
                step = next
            }
            #expect(seen == Self.expectedSteps(moves: actions.count), "level \(number)")
            var order: Int = -1
            for shown in seen {
                let position: Int = Step.allCases.firstIndex(of: shown) ?? -1
                #expect(position > order)
                order = position
            }
            #expect(Progress.movesMade(play) == actions.count)
            lengths.append(actions.count)
        }
        print("NocturneGardenProgressTests solution lengths of levels 1 … 3: \(lengths)")
    }

    @Test func undoAndRedoNeverMoveTheStepBack() throws {
        var checked: Int = 0
        for number in 1...3 {
            let generated: NocturneGardenGenerated = try Core.generated(number: number)
            let actions: [NocturneGardenAction] = generated.solution.actions
            var play: NocturneGardenPlay = try Self.fresh(number)
            var step: Step = Step.initial(level: number)
            // Every move but the winning one, undone and redone after each: the step never moves back.
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
            #expect(step != .plant || actions.count == 1)
            // Undo and redo records are not moves: the moves made equal the move records.
            #expect(Progress.movesMade(play) == actions.count - 1)
        }
        for start in Step.allCases {
            #expect(start.advanced(afterMove: false, ended: false) == start)
        }
        print("NocturneGardenProgressTests undo/redo checks: \(checked)")
    }

    @Test func transitionTableTextsAndDismissal() {
        for start in Step.allCases {
            #expect(start.dismissed() == .done)
            #expect(start.advanced(afterMove: false, ended: true) == .done)
            #expect(start.advanced(afterMove: true, ended: true) == .done)
            #expect(start.advanced(afterMove: false, ended: false) == start)
        }
        #expect(Step.plant.advanced(afterMove: true, ended: false) == .shape)
        #expect(Step.shape.advanced(afterMove: true, ended: false) == .finish)
        #expect(Step.finish.advanced(afterMove: true, ended: false) == .finish)
        #expect(Step.done.advanced(afterMove: true, ended: false) == .done)
        #expect(Step.initial(tutorial: true) == .plant)
        #expect(Step.initial(tutorial: false) == .done)
        for level in 0...101 {
            #expect(Step.initial(level: level) == ((1...3).contains(level) ? Step.plant : Step.done))
        }
        #expect(Step.plant.text == "Tap a cell of the mist to plant a bloom there (or use the panel); its black shadow "
            + "falls on the mist — a hint shows where")
        #expect(Step.shape.text == "Drag a bloom to move it, pinch it to resize it, drag the lantern to lengthen every "
            + "shadow; match the gold outline without letting the shadow touch the coral cells")
        #expect(Step.finish.text == "Reach the required match before the moves run out")
        #expect(Step.done.text.isEmpty)
    }

    // MARK: - Moves made from real plays

    @Test func movesMadeCountsUndoneMovesAndGivesStars() throws {
        var progress: Progress = Progress()
        for number in 1...5 {
            let generated: NocturneGardenGenerated = try Core.generated(number: number)
            let actions: [NocturneGardenAction] = generated.solution.actions
            let smallest: Int = generated.solution.smallest
            guard let first = actions.first else {
                Issue.record("level \(number) has no solution moves")
                continue
            }
            // k detours of (first move, undo) before the certified solution: moves made = smallest + k.
            for detours in 0...4 {
                var play: NocturneGardenPlay = try Self.fresh(number)
                var made: Int = 0
                while made < detours {
                    try play.apply(first, expecting: play.fingerprint)
                    if play.stage == .won { break }
                    try play.undo()
                    made += 1
                }
                if play.stage == .won {
                    // A one-move level wins on its first move: no detour can be made with this move.
                    #expect(smallest == 1)
                    continue
                }
                for action in actions { try play.apply(action, expecting: play.fingerprint) }
                #expect(play.stage == .won, "level \(number) detours \(detours)")
                let moves: Int = Progress.movesMade(play)
                #expect(moves == smallest + detours)
                #expect(play.moves == smallest)
                let expected: Int = detours == 0 ? 3 : (detours <= 2 ? 2 : 1)
                #expect(Progress.stars(movesMade: moves, smallest: smallest) == expected)
                // Worse results never replace the best (detours rise), so only the first win stores.
                let changed: Bool = progress.record(level: number, movesMade: moves, smallest: smallest,
                                                    opensNext: true)
                #expect(changed == (detours == 0))
                #expect(progress.solved[number] == Progress.Result(movesMade: smallest, stars: 3))
            }
            #expect(progress.isOpen(number + 1))
        }
        #expect(progress.frontier == 6)
    }

    // MARK: - Progress

    @Test func starThresholds() {
        for smallest in 1...40 {
            for moves in 0...60 {
                let expected: Int = moves <= smallest ? 3 : (moves <= smallest + 2 ? 2 : 1)
                #expect(Progress.stars(movesMade: moves, smallest: smallest) == expected)
            }
        }
        #expect(Progress.stars(movesMade: 3, smallest: 3) == 3)
        #expect(Progress.stars(movesMade: 5, smallest: 3) == 2)
        #expect(Progress.stars(movesMade: 6, smallest: 3) == 1)
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
            // A first result of smallest + extra moves made: stars by the thresholds; the next level opens.
            let first: Int = smallest + extra
            let firstStars: Int = extra == 0 ? 3 : (extra <= 2 ? 2 : 1)
            let changed1: Bool = progress.record(level: level, movesMade: first, smallest: smallest, opensNext: true)
            #expect(changed1)
            #expect(progress.solved[level] == Progress.Result(movesMade: first, stars: firstStars))
            #expect(progress.frontier == min(level + 1, 100))
            // A worse and an equal result keep the stored one.
            let changed2: Bool = progress.record(level: level, movesMade: first + 1, smallest: smallest,
                                                 opensNext: true)
            #expect(!changed2)
            let changed3: Bool = progress.record(level: level, movesMade: first, smallest: smallest, opensNext: true)
            #expect(!changed3)
            #expect(progress.solved[level]?.movesMade == first)
            // A better result replaces it (every second level), down to the smallest → 3 stars.
            if level % 2 == 0 && extra > 0 {
                let changed4: Bool = progress.record(level: level, movesMade: smallest, smallest: smallest,
                                                     opensNext: true)
                #expect(changed4)
                #expect(progress.solved[level] == Progress.Result(movesMade: smallest, stars: 3))
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
        let changed5: Bool = progress.record(level: 0, movesMade: 1, smallest: 1, opensNext: true)
        #expect(!changed5)
        let changed6: Bool = progress.record(level: 101, movesMade: 1, smallest: 1, opensNext: true)
        #expect(!changed6)
        #expect(Progress.band(of: 0) == 1)
        #expect(Progress.band(of: 101) == 5)
        print("NocturneGardenProgressTests scripted stars over 100 levels: \(total)")
    }

    @Test func modesDailyAndPractice() {
        var progress: Progress = Progress()
        let changed1: Bool = progress.record(level: 1, movesMade: 1, smallest: 1, mode: .practice)
        #expect(!changed1)
        #expect(progress == Progress())
        let changed2: Bool = progress.record(level: 50, movesMade: 2, smallest: 1, mode: .daily(level: 50))
        #expect(changed2)
        #expect(progress.solved[50]?.stars == 2)
        #expect(progress.frontier == 1)
        #expect(!progress.isOpen(50))
        let changed3: Bool = progress.record(level: 60, movesMade: 4, smallest: 4, opensNext: false)
        #expect(changed3)
        #expect(progress.frontier == 1)
        let changed4: Bool = progress.record(level: 1, movesMade: 4, smallest: 4, mode: .campaign)
        #expect(changed4)
        #expect(progress.frontier == 2)
        progress.open(through: 30)
        #expect(progress.frontier == 30)
        progress.open(through: 10)
        #expect(progress.frontier == 30)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 40)
        #expect(Mode.practiceBudget == NocturneGardenLevel.budgets.upperBound)
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
        #expect(levels[1] == 72)
        var index: Int = 0
        while index < levels.count {
            #expect(levels[index] >= 1 && levels[index] <= 100)
            #expect(levels[index] == (index * 71) % 100 + 1)
            if index > 0 {
                #expect((levels[index] - levels[index - 1] + 100) % 100 == 71, "day \(index)")
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
        #expect(Progress.dailyMultiplier == 71)
    }

    @Test func negativeDayCountsWrap() {
        // 2025-12-31 is day −1 → (−71 mod 100) + 1 = 30; 2025-12-30 is day −2 → (−142 mod 100) + 1 = 59.
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 30)
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 30) == 59)
        // 2025 has 365 days: 2025-01-01 is day −365 → (−25,915 mod 100) + 1 = 86.
        #expect(Progress.dailyLevel(year: 2025, month: 1, day: 1) == 86)
        // Every day of 2016 … 2025 (counted back from 2025-12-31) follows the same formula on its negative day count.
        var days: Int = 0
        var year: Int = 2025
        while year >= 2016 {
            var month: Int = 12
            while month >= 1 {
                var day: Int = Progress.daysIn(month: month, year: year)
                while day >= 1 {
                    days -= 1
                    let wrapped: Int = ((days * 71) % 100 + 100) % 100 + 1
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
        progress.record(level: 1, movesMade: 6, smallest: 5, opensNext: true)
        progress.record(level: 2, movesMade: 19, smallest: 6, opensNext: true)
        progress.record(level: 70, movesMade: 9, smallest: 9, mode: .daily(level: 70))
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":3,\"solved\":[{\"level\":1,\"movesMade\":6,\"stars\":2},"
            + "{\"level\":2,\"movesMade\":19,\"stars\":1},{\"level\":70,\"movesMade\":9,\"stars\":3}]}")
        let bad: [String] = ["{\"frontier\":0,\"solved\":[]}", "{\"frontier\":101,\"solved\":[]}",
                             "{\"frontier\":1,\"solved\":[{\"movesMade\":1,\"level\":1,\"stars\":4}]}",
                             "{\"frontier\":1,\"solved\":[{\"movesMade\":1,\"level\":0,\"stars\":1}]}",
                             "{\"frontier\":1,\"solved\":[{\"movesMade\":-1,\"level\":1,\"stars\":1}]}",
                             "{\"frontier\":2,\"solved\":[{\"movesMade\":1,\"level\":1,\"stars\":3},"
                                + "{\"movesMade\":2,\"level\":1,\"stars\":3}]}"]
        for json in bad {
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(Progress.self, from: Data(json.utf8)) }
        }
        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
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
                                  "{\"mode\":\"daily\"}", "{\"mode\":\"replay\",\"level\":1}"]
        for json in badModes {
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(Mode.self, from: Data(json.utf8)) }
        }
        for step in Step.allCases {
            let encoded: Data = try JSONEncoder().encode([step])
            #expect(String(decoding: encoded, as: UTF8.self) == "[\"\(step.rawValue)\"]")
            #expect(try JSONDecoder().decode([Step].self, from: encoded) == [step])
        }
    }
}
