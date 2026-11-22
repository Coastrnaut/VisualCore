// ChronoConstellatorProgressTests — feature 355 (R02-G06-05) T-R02G0605-003 (FR-R02G0605-001, 004, 005;
// SC-R02G0605-001, 004; clarifications Q2, Q3, Q4). The tutorial on levels 1 … 3 driven by the certified solutions
// through the play (phase changes keep `shift` until the last one makes the timeline win, so the plan is a run →
// `replay`; a one-tick step → `align`; the winning step ends the level → `done`), every step seen in order; dismissal;
// undo and redo never move the step back; the tutorial texts of clarification Q2. Progress scripted through 100 levels
// (each campaign win opens the next; stars against the smallest edit count; a better result replaces a worse one, a
// worse or equal one does not; daily records without opening, practice records nothing); the star thresholds; every
// date 2026-01-01 … 2036-12-31 maps into 1 … 100 and every 100 consecutive days visit every level; impossible dates
// refused; Codable round trips of the step, the mode and the progress. Explicit types, plain loops; each test < 3 s.
import Foundation
import Testing
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorProgressTests {
    typealias Step = ChronoConstellatorTutorialStep
    typealias Mode = ChronoConstellatorMode
    typealias Progress = ChronoConstellatorProgress
    typealias Core = ChronoConstellatorExperienceCore

    // MARK: - Tutorial

    /// Whether `play` has ended (won or failed).
    static func ended(_ play: ChronoConstellatorPlay) -> Bool {
        play.stage == .won || play.stage == .failed
    }

    /// Applies `action` to `play` and returns the tutorial step after it.
    static func advance(_ step: Step, play: inout ChronoConstellatorPlay,
                        action: ChronoConstellatorAction) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        let kind: ChronoConstellatorRecordKind? = play.records.last?.kind
        let planIsRun: Bool = ChronoConstellatorGenerator.winTick(play.level, timeline: play.timeline) != nil
        return step.advanced(after: kind, planIsRun: planIsRun, ended: ended(play))
    }

    @Test func tutorialFollowsCertifiedSolutionsOnLevelsOneToThree() throws {
        var winTicks: [Int] = []
        for number in 1...3 {
            let generated: ChronoConstellatorGenerated = try Core.generated(number: number)
            let level: ChronoConstellatorLevel = generated.level
            #expect(level.tutorial)
            var play: ChronoConstellatorPlay = try Core.freshPlay(of: level)
            var step: Step = Step.initial(level: number)
            #expect(step == .shift)
            var seen: [Step] = [step]
            let changes: [ChronoConstellatorAction] = ChronoConstellatorWitness.phaseChanges(
                for: generated.solution, level: level)
            #expect(changes.count == generated.difficulty.smallest)
            var index: Int = 0
            for action in changes {
                index += 1
                let next: Step = try Self.advance(step, play: &play, action: action)
                // Only the last change makes the timeline win (fewer than the smallest edit count never wins).
                #expect(next == (index == changes.count ? Step.replay : Step.shift), "level \(number) change \(index)")
                if next != step { seen.append(next) }
                step = next
            }
            let winTick: Int? = ChronoConstellatorGenerator.winTick(level, timeline: play.timeline)
            #expect(winTick != nil)
            let firstWin: Int = winTick ?? 0
            if firstWin > 1 {
                // A one-tick step that does not end the level shows `align`; the rest of the replay wins → `done`.
                let stepped: Step = try Self.advance(step, play: &play, action: .step(1))
                if stepped != step { seen.append(stepped) }
                step = stepped
                #expect(step == .align)
                #expect(play.stage == .playing)
                let last: Step = try Self.advance(step, play: &play, action: .step(level.tickLimit - 1))
                if last != step { seen.append(last) }
                #expect(seen == [Step.shift, Step.replay, Step.align, Step.done], "level \(number)")
            } else {
                // The timeline wins on tick 1, so the first accepted step ends the level: `replay` → `done` (the end
                // of the level overrides the step's own advance to `align`).
                #expect(step.advanced(after: .step, planIsRun: true, ended: false) == .align)
                let last: Step = try Self.advance(step, play: &play, action: .step(1))
                if last != step { seen.append(last) }
                #expect(seen == [Step.shift, Step.replay, Step.done], "level \(number)")
            }
            winTicks.append(firstWin)
            #expect(play.stage == .won)
            #expect(play.tick == firstWin)
        }
        print("ChronoConstellatorProgressTests win ticks of levels 1 … 3: \(winTicks)")
    }

    @Test func undoAndRedoNeverMoveTheStepBack() throws {
        let generated: ChronoConstellatorGenerated = try Core.generated(number: 1)
        var play: ChronoConstellatorPlay = try Core.freshPlay(of: generated.level)
        var step: Step = Step.initial(level: 1)
        let changes: [ChronoConstellatorAction] = ChronoConstellatorWitness.phaseChanges(
            for: generated.solution, level: generated.level)
        for action in changes {
            step = try Self.advance(step, play: &play, action: action)
        }
        #expect(step == .replay)
        try play.undo()
        #expect(play.records.last?.kind == .undo)
        let planIsRun: Bool = ChronoConstellatorGenerator.winTick(play.level, timeline: play.timeline) != nil
        step = step.advanced(after: play.records.last?.kind, planIsRun: planIsRun, ended: Self.ended(play))
        #expect(step == .replay)
        try play.redo()
        step = step.advanced(after: play.records.last?.kind, planIsRun: true, ended: false)
        #expect(step == .replay)
        let kinds: [ChronoConstellatorRecordKind] = [.undo, .redo]
        for start in Step.allCases {
            for kind in kinds {
                #expect(start.advanced(after: kind, planIsRun: true, ended: false) == start)
                #expect(start.advanced(after: kind, planIsRun: false, ended: false) == start)
            }
        }
    }

    @Test func transitionTableAndDismissal() {
        let all: [ChronoConstellatorRecordKind] = [.phase, .hold, .release, .step, .rewind, .undo, .redo]
        for start in Step.allCases {
            #expect(start.dismissed() == .done)
            #expect(start.advanced(after: nil, planIsRun: true, ended: true) == .done)
            #expect(start.advanced(after: nil, planIsRun: true, ended: false) == start)
            for kind in all {
                #expect(start.advanced(after: kind, planIsRun: true, ended: true) == .done)
                var expected: Step = start
                if start == .shift && kind == .phase { expected = .replay }
                if start == .replay && kind == .step { expected = .align }
                #expect(start.advanced(after: kind, planIsRun: true, ended: false) == expected, "\(start) \(kind)")
                let noRun: Step = start == .shift ? .shift : expected
                #expect(start.advanced(after: kind, planIsRun: false, ended: false) == noRun, "\(start) \(kind)")
            }
        }
        for level in 1...100 {
            #expect(Step.initial(level: level) == (level <= 3 ? Step.shift : Step.done))
        }
        #expect(Step.shift.text.hasPrefix("Drag a star along its silver loop (or use Phase − and +)"))
        #expect(Step.shift.text.hasSuffix("until every star can meet its target on the same tick; a hint shows which"))
        #expect(Step.replay.text == "Replay with Step or Run and watch the ribbons")
        #expect(Step.align.text == "Every star must stand on its own target on the same tick without two stars "
            + "meeting; undo or rewind a change that makes them collide")
        #expect(Step.done.text.isEmpty)
    }

    // MARK: - Progress

    @Test func starThresholds() {
        for smallest in 1...20 {
            for edits in 0...40 {
                let expected: Int = edits <= smallest ? 3 : (edits <= smallest + 2 ? 2 : 1)
                #expect(Progress.stars(edits: edits, smallest: smallest) == expected)
            }
        }
        #expect(Progress.stars(edits: 3, smallest: 3) == 3)
        #expect(Progress.stars(edits: 5, smallest: 3) == 2)
        #expect(Progress.stars(edits: 6, smallest: 3) == 1)
    }

    @Test func scriptedProgressThroughOneHundredLevels() {
        var progress: Progress = Progress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1))
        #expect(!progress.isOpen(2))
        #expect(!progress.isOpen(0))
        #expect(progress.nextOpen(after: 1) == nil)
        for level in 1...100 {
            let smallest: Int = (level - 1) % 5 + 1
            #expect(progress.isOpen(level))
            #expect(!progress.isOpen(level + 1) || level == 100)
            // A first, worse result: smallest + 3 edits → 1 star.
            let changed1: Bool = progress.record(level: level, edits: smallest + 3, smallest: smallest)
            #expect(changed1)
            #expect(progress.solved[level] == Progress.Result(bestEdits: smallest + 3, stars: 1))
            #expect(progress.frontier == min(level + 1, 100))
            // A worse and an equal result keep the stored one.
            let changed2: Bool = progress.record(level: level, edits: smallest + 5, smallest: smallest)
            #expect(!changed2)
            let changed3: Bool = progress.record(level: level, edits: smallest + 3, smallest: smallest)
            #expect(!changed3)
            // Better results replace it: 2 stars, then 3.
            let changed4: Bool = progress.record(level: level, edits: smallest + 1, smallest: smallest)
            #expect(changed4)
            #expect(progress.solved[level]?.stars == 2)
            let changed5: Bool = progress.record(level: level, edits: smallest, smallest: smallest)
            #expect(changed5)
            #expect(progress.solved[level] == Progress.Result(bestEdits: smallest, stars: 3))
            let changed6: Bool = progress.record(level: level, edits: smallest + 2, smallest: smallest)
            #expect(!changed6)
            #expect(progress.solved[level]?.bestEdits == smallest)
            if level < 100 {
                #expect(progress.nextOpen(after: level) == level + 1)
            }
            #expect(Progress.band(of: level) == (level - 1) / 20 + 1)
        }
        #expect(progress.frontier == 100)
        #expect(progress.nextOpen(after: 100) == nil)
        #expect(progress.solved.count == 100)
        let changed7: Bool = progress.record(level: 0, edits: 1, smallest: 1)
        #expect(!changed7)
        let changed8: Bool = progress.record(level: 101, edits: 1, smallest: 1)
        #expect(!changed8)
        #expect(Progress.band(of: 0) == 1)
        #expect(Progress.band(of: 101) == 5)
    }

    @Test func modesDailyAndPractice() {
        var progress: Progress = Progress()
        let changed9: Bool = progress.record(level: 1, edits: 1, smallest: 1, mode: .practice)
        #expect(!changed9)
        #expect(progress == Progress())
        let changed10: Bool = progress.record(level: 50, edits: 2, smallest: 1, mode: .daily(level: 50))
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
        #expect(Mode.practiceBudget == 20)
        #expect(Mode.practice.budget(base: 4) == 20)
        #expect(Mode.campaign.budget(base: 4) == 4)
        #expect(Mode.daily(level: 7).budget(base: 4) == 4)
        #expect(Mode.campaign.opensLevels)
        #expect(!Mode.daily(level: 7).opensLevels)
        #expect(!Mode.practice.awardsStars)
    }

    // MARK: - Daily level

    @Test func everyDateOfElevenYearsMapsIntoTheLevels() {
        var levels: [Int] = []
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...Progress.daysIn(month: month, year: year) {
                    let level: Int? = Progress.dailyLevel(year: year, month: month, day: day)
                    #expect(level != nil)
                    levels.append(level ?? 0)
                }
            }
        }
        #expect(levels.count == 4_018)
        #expect(levels[0] == 1)
        #expect(levels[1] == 60)
        var index: Int = 0
        while index < levels.count {
            #expect(levels[index] >= 1 && levels[index] <= 100)
            #expect(levels[index] == (index * 59) % 100 + 1)
            index += 1
        }
        var start: Int = 0
        while start + 100 <= levels.count {
            var visited: Set<Int> = []
            for offset in 0..<100 { visited.insert(levels[start + offset]) }
            #expect(visited.count == 100, "window from day \(start)")
            start += 1
        }
        // Negative day counts wrap: 2025-12-31 is day −1 → (−59 mod 100) + 1 = 42.
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 42)
        #expect(Progress.dailyLevel(year: 1, month: 1, day: 1) != nil)
        #expect(Progress.dailyLevel(year: 9999, month: 12, day: 31) != nil)
    }

    @Test func impossibleDatesAreRefused() {
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
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
        progress.record(level: 1, edits: 2, smallest: 1)
        progress.record(level: 2, edits: 9, smallest: 1)
        progress.record(level: 70, edits: 3, smallest: 3, mode: .daily(level: 70))
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":3,\"solved\":[{\"bestEdits\":2,\"level\":1,\"stars\":2},"
            + "{\"bestEdits\":9,\"level\":2,\"stars\":1},{\"bestEdits\":3,\"level\":70,\"stars\":3}]}")
        let bad: [String] = ["{\"frontier\":0,\"solved\":[]}", "{\"frontier\":101,\"solved\":[]}",
                             "{\"frontier\":1,\"solved\":[{\"bestEdits\":1,\"level\":1,\"stars\":4}]}",
                             "{\"frontier\":1,\"solved\":[{\"bestEdits\":1,\"level\":0,\"stars\":1}]}",
                             "{\"frontier\":1,\"solved\":[{\"bestEdits\":-1,\"level\":1,\"stars\":1}]}"]
        for json in bad {
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(Progress.self, from: Data(json.utf8)) }
        }
        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
        for mode in modes {
            let encoded: Data = try JSONEncoder().encode(mode)
            #expect(try JSONDecoder().decode(Mode.self, from: encoded) == mode)
        }
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"replay\",\"level\":1}"]
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
