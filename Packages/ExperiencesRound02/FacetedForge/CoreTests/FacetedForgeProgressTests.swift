// FacetedForgeProgressTests — feature 375 (R02-G08-05) T-R02G0805-003 (FR-R02G0805-001, 004, 005; SC-R02G0805-001,
// 004; clarifications Q2, Q3, Q4). The tutorial on levels 1 … 3 driven by the certified solutions through the play (the
// first accepted cut → `match`, the second → `finish`, the winning cut ends the level → `done`), the steps seen in
// order and ending `done` at the win; dismissal; undo and redo never move the step back; the tutorial texts of
// clarification Q2 word for word. Cuts made counted from real plays with cut-and-undo detours (stars 3, 2 and 1).
// Progress scripted through 100 levels (each campaign win opens the next; stars against the smallest cut count; a
// better result replaces a worse one, a worse or equal one does not; daily records without opening, practice records
// nothing); the star thresholds; every day 2026-01-01 … 2036-12-31 maps into 1 … 100, stably, consecutive days differ
// by 67 mod 100 and every 100 consecutive days visit every level; days before 2026 wrap; impossible days refused;
// Codable round trips of the step, the mode and the progress. Explicit types, plain loops; each test < 10 s.
import Foundation
import Testing
@testable import FacetedForgeCore

@Suite struct FacetedForgeProgressTests {
    typealias Step = FacetedForgeTutorialStep
    typealias Mode = FacetedForgeMode
    typealias Progress = FacetedForgeProgress
    typealias Core = FacetedForgeExperienceCore

    // MARK: - Tutorial

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: FacetedForgePlay) -> Bool {
        play.stage == .won || play.stage == .failed
    }

    /// The step after the latest record of `play`.
    static func next(_ step: Step, play: FacetedForgePlay) -> Step {
        step.advanced(afterCut: play.records.last?.kind == .cut, ended: ended(play))
    }

    /// A fresh playing play of `level` (replay of no records: begun, kernel tutorial dismissed).
    static func fresh(_ level: FacetedForgeLevel) throws -> FacetedForgePlay {
        try FacetedForgePlay.replay(level: level, records: [])
    }

    /// The steps the tutorial must show for a winning sequence of `count` cuts, by the rules of clarification Q2.
    static func expectedSteps(cuts count: Int) -> [Step] {
        if count <= 1 { return [.aim, .done] }
        if count == 2 { return [.aim, .match, .done] }
        return [.aim, .match, .finish, .done]
    }

    @Test func tutorialFollowsCertifiedSolutionsOnLevelsOneToThree() throws {
        var lengths: [Int] = []
        for number in 1...3 {
            let generated: FacetedForgeGenerated = try Core.generated(number: number)
            let level: FacetedForgeLevel = generated.level
            #expect(level.tutorial)
            var play: FacetedForgePlay = try Self.fresh(level)
            #expect(play.stage == .playing)
            var step: Step = Step.initial(tutorial: level.tutorial)
            #expect(step == .aim)
            #expect(Step.initial(level: number) == .aim)
            var seen: [Step] = [step]
            let actions: [FacetedForgeAction] = generated.solution.actions
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
                    #expect(play.stage == .playing, "level \(number) cut \(index)")
                    #expect(next != .done)
                }
                if next != step { seen.append(next) }
                step = next
            }
            #expect(seen == Self.expectedSteps(cuts: actions.count), "level \(number)")
            var order: Int = -1
            for shown in seen {
                let position: Int = Step.allCases.firstIndex(of: shown) ?? -1
                #expect(position > order)
                order = position
            }
            #expect(Progress.cutsMade(play) == actions.count)
            lengths.append(actions.count)
        }
        print("FacetedForgeProgressTests solution lengths of levels 1 … 3: \(lengths)")
    }

    @Test func undoAndRedoNeverMoveTheStepBack() throws {
        var checked: Int = 0
        for number in 1...3 {
            let generated: FacetedForgeGenerated = try Core.generated(number: number)
            let actions: [FacetedForgeAction] = generated.solution.actions
            var play: FacetedForgePlay = try Self.fresh(generated.level)
            var step: Step = Step.initial(tutorial: generated.level.tutorial)
            // Every cut but the winning one, undone and redone after each: the step never moves back.
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
            #expect(step != .aim || actions.count == 1)
        }
        for start in Step.allCases {
            #expect(start.advanced(afterCut: false, ended: false) == start)
        }
        print("FacetedForgeProgressTests undo/redo checks: \(checked)")
    }

    @Test func transitionTableTextsAndDismissal() {
        for start in Step.allCases {
            #expect(start.dismissed() == .done)
            #expect(start.advanced(afterCut: false, ended: true) == .done)
            #expect(start.advanced(afterCut: true, ended: true) == .done)
            #expect(start.advanced(afterCut: false, ended: false) == start)
        }
        #expect(Step.aim.advanced(afterCut: true, ended: false) == .match)
        #expect(Step.match.advanced(afterCut: true, ended: false) == .finish)
        #expect(Step.finish.advanced(afterCut: true, ended: false) == .finish)
        #expect(Step.done.advanced(afterCut: true, ended: false) == .done)
        #expect(Step.initial(tutorial: true) == .aim)
        #expect(Step.initial(tutorial: false) == .done)
        for level in 0...101 {
            #expect(Step.initial(level: level) == ((1...3).contains(level) ? Step.aim : Step.done))
        }
        #expect(Step.aim.text == "Choose a piece and aim the ruby plane — drag its rim to tilt it, drag inside it to "
            + "slide it, or use the panel — then tap the plane (or Cut) to split the piece; a hint shows where")
        #expect(Step.match.text == "Each cut adds one piece: match the target's shares and face counts exactly; a "
            + "piece thinner than 1/64 of the crystal ends the play")
        #expect(Step.finish.text == "Match every target piece before the cuts run out")
        #expect(Step.done.text.isEmpty)
    }

    // MARK: - Cuts made from real plays

    @Test func cutsMadeCountsUndoneCutsAndGivesStars() throws {
        var progress: Progress = Progress()
        for number in 1...5 {
            let generated: FacetedForgeGenerated = try Core.generated(number: number)
            let actions: [FacetedForgeAction] = generated.solution.actions
            let smallest: Int = generated.solution.smallest
            guard let first = actions.first else {
                Issue.record("level \(number) has no solution cuts")
                continue
            }
            // k detours of (first cut, undo) before the certified solution: cuts made = smallest + k.
            for detours in 0...4 {
                var play: FacetedForgePlay = try Self.fresh(generated.level)
                var made: Int = 0
                while made < detours {
                    try play.apply(first, expecting: play.fingerprint)
                    if play.stage == .won { break }
                    try play.undo()
                    made += 1
                }
                if play.stage == .won {
                    // A one-cut level wins on its first cut: no detour can be made with this cut.
                    #expect(smallest == 1)
                    continue
                }
                for action in actions { try play.apply(action, expecting: play.fingerprint) }
                #expect(play.stage == .won, "level \(number) detours \(detours)")
                let cuts: Int = Progress.cutsMade(play)
                #expect(cuts == smallest + detours)
                #expect(play.cuts == smallest)
                let expected: Int = detours == 0 ? 3 : (detours <= 2 ? 2 : 1)
                #expect(Progress.stars(cutsMade: cuts, smallest: smallest) == expected)
                // Worse results never replace the best (detours rise), so only the first win stores.
                let changed: Bool = progress.record(level: number, cutsMade: cuts, smallest: smallest)
                #expect(changed == (detours == 0))
                #expect(progress.solved[number] == Progress.Result(cutsMade: smallest, stars: 3))
            }
            #expect(progress.isOpen(number + 1))
        }
        #expect(progress.frontier == 6)
    }

    // MARK: - Progress

    @Test func starThresholds() {
        for smallest in 1...20 {
            for cuts in 0...40 {
                let expected: Int = cuts <= smallest ? 3 : (cuts <= smallest + 2 ? 2 : 1)
                #expect(Progress.stars(cutsMade: cuts, smallest: smallest) == expected)
            }
        }
        #expect(Progress.stars(cutsMade: 3, smallest: 3) == 3)
        #expect(Progress.stars(cutsMade: 5, smallest: 3) == 2)
        #expect(Progress.stars(cutsMade: 6, smallest: 3) == 1)
    }

    @Test func scriptedProgressThroughOneHundredLevels() {
        var progress: Progress = Progress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1))
        #expect(!progress.isOpen(2))
        #expect(!progress.isOpen(0))
        #expect(progress.nextOpen(after: 1) == nil)
        for level in 1...100 {
            let smallest: Int = (level - 1) % 7 + 1
            #expect(progress.isOpen(level))
            #expect(!progress.isOpen(level + 1) || level == 100)
            // A first, worse result: smallest + 3 cuts made (cut-and-undo detours) → 1 star.
            let changed1: Bool = progress.record(level: level, cutsMade: smallest + 3, smallest: smallest)
            #expect(changed1)
            #expect(progress.solved[level] == Progress.Result(cutsMade: smallest + 3, stars: 1))
            #expect(progress.frontier == min(level + 1, 100))
            // A worse and an equal result keep the stored one.
            let changed2: Bool = progress.record(level: level, cutsMade: smallest + 5, smallest: smallest)
            #expect(!changed2)
            let changed3: Bool = progress.record(level: level, cutsMade: smallest + 3, smallest: smallest)
            #expect(!changed3)
            // Better results replace it: smallest + 2 → 2 stars, then smallest → 3.
            let changed4: Bool = progress.record(level: level, cutsMade: smallest + 2, smallest: smallest)
            #expect(changed4)
            #expect(progress.solved[level] == Progress.Result(cutsMade: smallest + 2, stars: 2))
            let changed5: Bool = progress.record(level: level, cutsMade: smallest, smallest: smallest)
            #expect(changed5)
            #expect(progress.solved[level] == Progress.Result(cutsMade: smallest, stars: 3))
            let changed6: Bool = progress.record(level: level, cutsMade: smallest + 1, smallest: smallest)
            #expect(!changed6)
            #expect(progress.solved[level]?.cutsMade == smallest)
            if level < 100 {
                #expect(progress.nextOpen(after: level) == level + 1)
            }
            #expect(Progress.band(of: level) == (level - 1) / 20 + 1)
        }
        #expect(progress.frontier == 100)
        #expect(progress.nextOpen(after: 100) == nil)
        #expect(progress.solved.count == 100)
        var stars: Int = 0
        for result in progress.solved.values { stars += result.stars }
        #expect(stars == 300)
        let changed7: Bool = progress.record(level: 0, cutsMade: 1, smallest: 1)
        #expect(!changed7)
        let changed8: Bool = progress.record(level: 101, cutsMade: 1, smallest: 1)
        #expect(!changed8)
        #expect(Progress.band(of: 0) == 1)
        #expect(Progress.band(of: 101) == 5)
    }

    @Test func modesDailyAndPractice() {
        var progress: Progress = Progress()
        let changed1: Bool = progress.record(level: 1, cutsMade: 1, smallest: 1, mode: .practice)
        #expect(!changed1)
        #expect(progress == Progress())
        let changed2: Bool = progress.record(level: 50, cutsMade: 2, smallest: 1, mode: .daily(level: 50))
        #expect(changed2)
        #expect(progress.solved[50]?.stars == 2)
        #expect(progress.frontier == 1)
        #expect(!progress.isOpen(50))
        progress.open(through: 30)
        #expect(progress.frontier == 30)
        progress.open(through: 10)
        #expect(progress.frontier == 30)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 20)
        #expect(Mode.practiceBudget == FacetedForgeLevel.budgets.upperBound)
        #expect(Mode.practice.budget(base: 9) == 20)
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
        #expect(levels[1] == 68)
        var index: Int = 0
        while index < levels.count {
            #expect(levels[index] >= 1 && levels[index] <= 100)
            #expect(levels[index] == (index * 67) % 100 + 1)
            if index > 0 {
                #expect((levels[index] - levels[index - 1] + 100) % 100 == 67, "day \(index)")
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
        // Negative day counts wrap: 2025-12-31 is day −1 → (−67 mod 100) + 1 = 34; 2025-12-30 is day −2 → 67.
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 34)
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 30) == 67)
        // 2025 has 365 days: 2025-01-01 is day −365 → (−365 × 67 mod 100) + 1 = (−24455 mod 100) + 1 = 46.
        #expect(Progress.dailyLevel(year: 2025, month: 1, day: 1) == 46)
        #expect(Progress.dailyLevel(year: 1, month: 1, day: 1) != nil)
        #expect(Progress.dailyLevel(year: 9999, month: 12, day: 31) != nil)
        #expect(Progress.dailyMultiplier == 67)
    }

    @Test func impossibleDaysAreRefused() {
        #expect(Progress.dailyLevel(year: 2027, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 32) == nil)
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
        progress.record(level: 1, cutsMade: 6, smallest: 5)
        progress.record(level: 2, cutsMade: 19, smallest: 6)
        progress.record(level: 70, cutsMade: 9, smallest: 9, mode: .daily(level: 70))
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":3,\"solved\":[{\"cutsMade\":6,\"level\":1,\"stars\":2},"
            + "{\"cutsMade\":19,\"level\":2,\"stars\":1},{\"cutsMade\":9,\"level\":70,\"stars\":3}]}")
        let bad: [String] = ["{\"frontier\":0,\"solved\":[]}", "{\"frontier\":101,\"solved\":[]}",
                             "{\"frontier\":1,\"solved\":[{\"cutsMade\":1,\"level\":1,\"stars\":4}]}",
                             "{\"frontier\":1,\"solved\":[{\"cutsMade\":1,\"level\":0,\"stars\":1}]}",
                             "{\"frontier\":1,\"solved\":[{\"cutsMade\":-1,\"level\":1,\"stars\":1}]}",
                             "{\"frontier\":2,\"solved\":[{\"cutsMade\":1,\"level\":1,\"stars\":3},"
                                + "{\"cutsMade\":2,\"level\":1,\"stars\":3}]}"]
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
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"daily\"}", "{\"mode\":\"rewind\",\"level\":1}"]
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
