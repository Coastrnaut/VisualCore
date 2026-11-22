// AmethystEscapeProgressTests — feature 365 (R02-G07-05) T-R02G0705-003 (FR-R02G0705-001, 004, 005; SC-R02G0705-001,
// 004; clarifications Q2, Q3, Q4). The tutorial on levels 1 … 3 driven by the certified solutions through the play (the
// first accepted move → `advance`, the next accepted advance → `escape`, the winning advance ends the level → `done`),
// the steps seen in order and ending `done` at the win; dismissal; undo and redo never move the step back; the tutorial
// texts of clarification Q2 word for word. Progress scripted through 100 levels (each campaign win opens the next; stars
// against the smallest move count; a better result replaces a worse one, a worse or equal one does not; daily records
// without opening, practice records nothing); the star thresholds; every date 2026-01-01 … 2036-12-31 maps into
// 1 … 100, stably, and every 100 consecutive days visit every level; impossible dates refused; Codable round trips of
// the step, the mode and the progress. Explicit types, plain loops; each test < 3 s.
import Foundation
import Testing
@testable import AmethystEscapeCore

@Suite struct AmethystEscapeProgressTests {
    typealias Step = AmethystEscapeTutorialStep
    typealias Mode = AmethystEscapeMode
    typealias Progress = AmethystEscapeProgress
    typealias Core = AmethystEscapeExperienceCore

    // MARK: - Tutorial

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: AmethystEscapePlay) -> Bool {
        play.stage == .won || play.stage == .failed
    }

    /// Applies `action` to `play` and returns the tutorial step after it.
    static func advance(_ step: Step, play: inout AmethystEscapePlay, action: AmethystEscapeAction) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        return step.advanced(after: play.records.last?.kind, ended: ended(play))
    }

    /// The steps the tutorial must show for a winning action sequence `actions`, by the rules of clarification Q2.
    static func expectedSteps(for actions: [AmethystEscapeAction]) -> [Step] {
        if actions.count <= 1 { return [.turn, .done] }
        var laterAdvance: Bool = false
        for index in 1..<(actions.count - 1) where actions[index] == .advance { laterAdvance = true }
        return laterAdvance ? [.turn, .advance, .escape, .done] : [.turn, .advance, .done]
    }

    @Test func tutorialFollowsCertifiedSolutionsOnLevelsOneToThree() throws {
        var lengths: [Int] = []
        for number in 1...3 {
            let generated: AmethystEscapeGenerated = try Core.generated(number: number)
            let level: AmethystEscapeLevel = generated.level
            #expect(level.tutorial)
            var play: AmethystEscapePlay = try Core.freshPlay(of: level)
            var step: Step = Step.initial(level: number)
            #expect(step == .turn)
            var seen: [Step] = [step]
            let actions: [AmethystEscapeAction] = generated.solution.actions
            #expect(actions.count == generated.solution.smallest)
            var index: Int = 0
            for action in actions {
                index += 1
                let next: Step = try Self.advance(step, play: &play, action: action)
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
            #expect(seen == Self.expectedSteps(for: actions), "level \(number)")
            #expect(seen.first == .turn && seen.last == .done)
            // The steps were seen in their declared order, none skipped backwards.
            var order: Int = -1
            for shown in seen {
                let position: Int = Step.allCases.firstIndex(of: shown) ?? -1
                #expect(position > order)
                order = position
            }
            lengths.append(actions.count)
        }
        print("AmethystEscapeProgressTests solution lengths of levels 1 … 3: \(lengths)")
    }

    @Test func undoAndRedoNeverMoveTheStepBack() throws {
        var checked: Int = 0
        for number in 1...3 {
            let generated: AmethystEscapeGenerated = try Core.generated(number: number)
            let actions: [AmethystEscapeAction] = generated.solution.actions
            var play: AmethystEscapePlay = try Core.freshPlay(of: generated.level)
            var step: Step = Step.initial(level: number)
            // Every move but the winning one, undone and redone after each: the step never moves back.
            for action in actions.dropLast() {
                step = try Self.advance(step, play: &play, action: action)
                let before: Step = step
                try play.undo()
                #expect(play.records.last?.kind == .undo)
                step = step.advanced(after: play.records.last?.kind, ended: Self.ended(play))
                #expect(step == before)
                try play.redo()
                #expect(play.records.last?.kind == .redo)
                step = step.advanced(after: play.records.last?.kind, ended: Self.ended(play))
                #expect(step == before)
                checked += 1
            }
            #expect(step != .turn || actions.count == 1)
        }
        for start in Step.allCases {
            #expect(start.advanced(after: .undo, ended: false) == start)
            #expect(start.advanced(after: .redo, ended: false) == start)
        }
        #expect(checked >= 1)
    }

    @Test func transitionTableAndDismissal() {
        let all: [AmethystEscapeRecordKind] = [.rotate, .advance, .undo, .redo]
        for start in Step.allCases {
            #expect(start.dismissed() == .done)
            #expect(start.advanced(after: nil, ended: true) == .done)
            #expect(start.advanced(after: nil, ended: false) == start)
            for kind in all {
                #expect(start.advanced(after: kind, ended: true) == .done)
                var expected: Step = start
                if start == .turn && (kind == .rotate || kind == .advance) { expected = .advance }
                if start == .advance && kind == .advance { expected = .escape }
                #expect(start.advanced(after: kind, ended: false) == expected, "\(start) \(kind)")
            }
        }
        for level in 0...101 {
            #expect(Step.initial(level: level) == ((1...3).contains(level) ? Step.turn : Step.done))
        }
        #expect(Step.turn.text == "Drag a shell round the centre (or use Turn − and +) to line an opening up with the "
            + "pearl, or roll the pearl when its way is open; a hint shows which")
        #expect(Step.advance.text == "Tap the pearl (or Advance) to roll it one pocket: out through an opening, else "
            + "clockwise until a wall stops it")
        #expect(Step.escape.text == "Lead the pearl out through the exit gap of the outer shell before the moves run "
            + "out; dark wedges with a cross end the play")
        #expect(Step.done.text.isEmpty)
    }

    // MARK: - Progress

    @Test func starThresholds() {
        for smallest in 1...20 {
            for moves in 0...60 {
                let expected: Int = moves <= smallest ? 3 : (moves <= smallest + 2 ? 2 : 1)
                #expect(Progress.stars(moves: moves, smallest: smallest) == expected)
            }
        }
        #expect(Progress.stars(moves: 3, smallest: 3) == 3)
        #expect(Progress.stars(moves: 5, smallest: 3) == 2)
        #expect(Progress.stars(moves: 6, smallest: 3) == 1)
    }

    @Test func scriptedProgressThroughOneHundredLevels() {
        var progress: Progress = Progress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1))
        #expect(!progress.isOpen(2))
        #expect(!progress.isOpen(0))
        #expect(progress.nextOpen(after: 1) == nil)
        for level in 1...100 {
            let smallest: Int = (level - 1) % 7 + 2
            #expect(progress.isOpen(level))
            #expect(!progress.isOpen(level + 1) || level == 100)
            // A first, worse result: smallest + 3 moves → 1 star.
            let changed1: Bool = progress.record(level: level, moves: smallest + 3, smallest: smallest)
            #expect(changed1)
            #expect(progress.solved[level] == Progress.Result(bestMoves: smallest + 3, stars: 1))
            #expect(progress.frontier == min(level + 1, 100))
            // A worse and an equal result keep the stored one.
            let changed2: Bool = progress.record(level: level, moves: smallest + 5, smallest: smallest)
            #expect(!changed2)
            let changed3: Bool = progress.record(level: level, moves: smallest + 3, smallest: smallest)
            #expect(!changed3)
            // Better results replace it: 2 stars, then 3.
            let changed4: Bool = progress.record(level: level, moves: smallest + 1, smallest: smallest)
            #expect(changed4)
            #expect(progress.solved[level]?.stars == 2)
            let changed5: Bool = progress.record(level: level, moves: smallest, smallest: smallest)
            #expect(changed5)
            #expect(progress.solved[level] == Progress.Result(bestMoves: smallest, stars: 3))
            let changed6: Bool = progress.record(level: level, moves: smallest + 2, smallest: smallest)
            #expect(!changed6)
            #expect(progress.solved[level]?.bestMoves == smallest)
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
        let changed7: Bool = progress.record(level: 0, moves: 1, smallest: 1)
        #expect(!changed7)
        let changed8: Bool = progress.record(level: 101, moves: 1, smallest: 1)
        #expect(!changed8)
        #expect(Progress.band(of: 0) == 1)
        #expect(Progress.band(of: 101) == 5)
    }

    @Test func modesDailyAndPractice() {
        var progress: Progress = Progress()
        let changed9: Bool = progress.record(level: 1, moves: 1, smallest: 1, mode: .practice)
        #expect(!changed9)
        #expect(progress == Progress())
        let changed10: Bool = progress.record(level: 50, moves: 2, smallest: 1, mode: .daily(level: 50))
        #expect(changed10)
        #expect(progress.solved[50]?.stars == 2)
        #expect(progress.frontier == 1)
        #expect(!progress.isOpen(50))
        progress.open(through: 30)
        #expect(progress.frontier == 30)
        progress.open(through: 10)
        #expect(progress.frontier == 30)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 60)
        #expect(Mode.practiceBudget == AmethystEscapeLevel.budgets.upperBound)
        #expect(Mode.practice.budget(base: 9) == 60)
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

    @Test func everyDateOfElevenYearsMapsIntoTheLevels() {
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
        #expect(levels[1] == 62)
        var index: Int = 0
        while index < levels.count {
            #expect(levels[index] >= 1 && levels[index] <= 100)
            #expect(levels[index] == (index * 61) % 100 + 1)
            index += 1
        }
        var start: Int = 0
        while start + 100 <= levels.count {
            var visited: Set<Int> = []
            for offset in 0..<100 { visited.insert(levels[start + offset]) }
            #expect(visited.count == 100, "window from day \(start)")
            start += 1
        }
        // Negative day counts wrap: 2025-12-31 is day −1 → (−61 mod 100) + 1 = 40.
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 40)
        #expect(Progress.dailyLevel(year: 1, month: 1, day: 1) != nil)
        #expect(Progress.dailyLevel(year: 9999, month: 12, day: 31) != nil)
        #expect(Progress.dailyMultiplier == 61)
    }

    @Test func impossibleDatesAreRefused() {
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 32) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(Progress.dailyLevel(year: 2027, month: 2, day: 29) == nil)
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
        progress.record(level: 1, moves: 6, smallest: 5)
        progress.record(level: 2, moves: 19, smallest: 6)
        progress.record(level: 70, moves: 9, smallest: 9, mode: .daily(level: 70))
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":3,\"solved\":[{\"bestMoves\":6,\"level\":1,\"stars\":2},"
            + "{\"bestMoves\":19,\"level\":2,\"stars\":1},{\"bestMoves\":9,\"level\":70,\"stars\":3}]}")
        let bad: [String] = ["{\"frontier\":0,\"solved\":[]}", "{\"frontier\":101,\"solved\":[]}",
                             "{\"frontier\":1,\"solved\":[{\"bestMoves\":1,\"level\":1,\"stars\":4}]}",
                             "{\"frontier\":1,\"solved\":[{\"bestMoves\":1,\"level\":0,\"stars\":1}]}",
                             "{\"frontier\":1,\"solved\":[{\"bestMoves\":-1,\"level\":1,\"stars\":1}]}",
                             "{\"frontier\":2,\"solved\":[{\"bestMoves\":1,\"level\":1,\"stars\":3},"
                                + "{\"bestMoves\":2,\"level\":1,\"stars\":3}]}"]
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
