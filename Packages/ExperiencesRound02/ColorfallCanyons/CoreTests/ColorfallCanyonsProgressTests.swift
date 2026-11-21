// ColorfallCanyonsProgressTests — feature 345 (R02-G05-05) T-R02G0505-003 (FR-R02G0505-001, 004, 005;
// SC-R02G0505-001, 004; clarifications Q2–Q4). The tutorial on levels 1 … 3 driven by the certified solutions (each
// certified edit applied, `planEmpty` given as "every certified edit applied", the certified step split into one tick and
// the rest): steer → run → fill → done, done at the win; a detour carve undone and redone never moves the step back;
// texts and the transition table; scripted campaign progress through the 100 certified levels with various action counts
// (the frontier opens in order, the stars follow the certified smallest edit count); better results replace worse ones;
// practice records nothing and daily opens nothing; the daily level of every date 2026-01-01 … 2036-12-31 and of earlier
// dates, every level once per 100 consecutive days, impossible dates refused; Codable round trips. Host-run
// (`swift test`); explicit types, plain loops (CI type-check rule).
#if DEBUG || VISUALCORE_AUTOMATION
@testable import ColorfallCanyonsCore
import Foundation
import Testing

@Suite struct ColorfallCanyonsProgressTests {
    // MARK: Tutorial

    /// The record kind of `action`.
    func kind(_ action: ColorfallCanyonsAction) -> ColorfallCanyonsRecordKind {
        switch action {
        case .carve: .carve
        case .valve: .valve
        case .step: .step
        }
    }

    /// Whether the play has ended (won or failed).
    func ended(_ play: ColorfallCanyonsPlay) -> Bool {
        play.stage == .won || play.stage == .failed
    }

    /// The certified actions of level `number` with every step split into one tick and the rest (when longer than one
    /// tick), so the tutorial shows its `fill` step before the win; the ticks played are unchanged.
    func splitActions(_ number: Int) -> [ColorfallCanyonsAction] {
        var result: [ColorfallCanyonsAction] = []
        for action in ColorfallCanyonsExperienceCore.certifiedActions(number) {
            if case .step(let ticks) = action, ticks > 1 {
                result.append(.step(1))
                result.append(.step(ticks - 1))
            } else {
                result.append(action)
            }
        }
        return result
    }

    @Test func tutorialFollowsTheCertifiedSolutionsOnLevels1To3() throws {
        for number in 1...3 {
            let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsExperienceCore.generated(number: number)
            #expect(generated.level.tutorial, "level \(number)")
            let edits: Int = generated.solution.edits.count
            var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: generated.level)
            var step: ColorfallCanyonsTutorialStep = ColorfallCanyonsTutorialStep.initial(level: number)
            #expect(step == .steer, "level \(number)")
            var shown: [ColorfallCanyonsTutorialStep] = [step]
            var applied: Int = 0
            for action in splitActions(number) {
                if play.stage != .playing { break }
                try play.apply(action, expecting: play.fingerprint)
                if case .step = action {} else { applied += 1 }
                let next: ColorfallCanyonsTutorialStep = step.advanced(after: kind(action), planEmpty: applied == edits,
                                                                       ended: ended(play))
                if next != step { shown.append(next) }
                step = next
            }
            #expect(play.stage == .won, "level \(number)")
            #expect(shown == [.steer, .run, .fill, .done], "level \(number): \(shown)")
        }
    }

    @Test func tutorialUndoAndRedoNeverMoveTheStep() throws {
        for number in 1...3 {
            let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsExperienceCore.generated(number: number)
            let edits: Int = generated.solution.edits.count
            var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: generated.level)
            var step: ColorfallCanyonsTutorialStep = ColorfallCanyonsTutorialStep.initial(level: number)
            var applied: Int = 0
            let actions: [ColorfallCanyonsAction] = splitActions(number)
            // Apply every certified edit: the step reaches `run`.
            for action in actions {
                if case .step = action { break }
                try play.apply(action, expecting: play.fingerprint)
                applied += 1
                step = step.advanced(after: kind(action), planEmpty: applied == edits, ended: ended(play))
            }
            #expect(step == .run, "level \(number)")
            // Undoing the last edit keeps `run` (undo never moves back), even with a plan that is no longer empty.
            try play.undo()
            step = step.advanced(after: .undo, planEmpty: false, ended: ended(play))
            #expect(step == .run, "level \(number): undo never moves the step back")
            try play.redo()
            step = step.advanced(after: .redo, planEmpty: true, ended: ended(play))
            #expect(step == .run, "level \(number): redo never moves the step")
            // The steps then advance as before.
            for action in actions {
                guard case .step = action, play.stage == .playing else { continue }
                try play.apply(action, expecting: play.fingerprint)
                step = step.advanced(after: .step, planEmpty: true, ended: ended(play))
                if play.stage == .playing { #expect(step == .fill, "level \(number)") }
            }
            #expect(play.stage == .won, "level \(number)")
            #expect(step == .done, "level \(number)")
        }
    }

    @Test func tutorialTexts() {
        #expect(ColorfallCanyonsTutorialStep.steer.text
            == "Drag across a sandstone cell (or use Carve) to cut a channel, and tap a spring (or its valve button) to "
            + "open or close it, until the fluid will reach the right basins; a hint shows how")
        #expect(ColorfallCanyonsTutorialStep.run.text
            == "Let the fluid run with Step or Run and watch the basins fill")
        #expect(ColorfallCanyonsTutorialStep.fill.text
            == "Fill every basin with its colours without overflow; undo any change that sends a wrong colour in")
        #expect(ColorfallCanyonsTutorialStep.done.text == "")
    }

    @Test func tutorialTransitionTable() {
        let steer: ColorfallCanyonsTutorialStep = .steer
        #expect(steer.advanced(after: .carve, planEmpty: true, ended: false) == .run)
        #expect(steer.advanced(after: .valve, planEmpty: true, ended: false) == .run)
        #expect(steer.advanced(after: .carve, planEmpty: false, ended: false) == .steer)
        #expect(steer.advanced(after: .valve, planEmpty: false, ended: false) == .steer)
        #expect(steer.advanced(after: .step, planEmpty: true, ended: false) == .steer)
        #expect(steer.advanced(after: nil, planEmpty: true, ended: false) == .steer)
        let run: ColorfallCanyonsTutorialStep = .run
        #expect(run.advanced(after: .step, planEmpty: false, ended: false) == .fill)
        #expect(run.advanced(after: .carve, planEmpty: true, ended: false) == .run)
        #expect(run.advanced(after: .valve, planEmpty: true, ended: false) == .run)
        let fill: ColorfallCanyonsTutorialStep = .fill
        #expect(fill.advanced(after: .step, planEmpty: true, ended: false) == .fill)
        #expect(fill.advanced(after: .carve, planEmpty: true, ended: false) == .fill)
        let kinds: [ColorfallCanyonsRecordKind?] = [nil, .carve, .valve, .step, .undo, .redo]
        let flags: [Bool] = [false, true]
        for step in ColorfallCanyonsTutorialStep.allCases {
            #expect(step.dismissed() == .done)
            for flag in flags {
                #expect(step.advanced(after: .undo, planEmpty: flag, ended: false) == step, "\(step)")
                #expect(step.advanced(after: .redo, planEmpty: flag, ended: false) == step, "\(step)")
                for kind in kinds {
                    #expect(step.advanced(after: kind, planEmpty: flag, ended: true) == .done, "\(step)")
                }
            }
            for kind in kinds {
                #expect(ColorfallCanyonsTutorialStep.done.advanced(after: kind, planEmpty: true, ended: false) == .done)
            }
        }
    }

    @Test func tutorialOnLevels1To3Only() {
        for level in 1...100 {
            let step: ColorfallCanyonsTutorialStep = ColorfallCanyonsTutorialStep.initial(level: level)
            #expect(step == (level <= 3 ? .steer : .done), "level \(level)")
        }
        #expect(ColorfallCanyonsTutorialStep.initial(level: 0) == .done)
        #expect(ColorfallCanyonsTutorialStep.initial(level: 101) == .done)
    }

    // MARK: Progress

    @Test func starTable() {
        let smallests: [Int] = [1, 2, 3]
        for smallest in smallests {
            for actions in 0...(smallest + 6) {
                let expected: Int = actions <= smallest ? 3 : (actions <= smallest + 2 ? 2 : 1)
                #expect(ColorfallCanyonsProgress.stars(actions: actions, smallest: smallest) == expected,
                        "actions \(actions), smallest \(smallest)")
            }
        }
        #expect(ColorfallCanyonsProgress.stars(actions: 2, smallest: 2) == 3)
        #expect(ColorfallCanyonsProgress.stars(actions: 3, smallest: 2) == 2)
        #expect(ColorfallCanyonsProgress.stars(actions: 4, smallest: 2) == 2)
        #expect(ColorfallCanyonsProgress.stars(actions: 5, smallest: 2) == 1)
    }

    @Test func certifiedSolutionsOfLevels1To3EarnThreeStars() throws {
        for number in 1...3 {
            let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsExperienceCore.generated(number: number)
            var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: generated.level)
            for action in ColorfallCanyonsExperienceCore.certifiedActions(number) where play.stage == .playing {
                try play.apply(action, expecting: play.fingerprint)
            }
            #expect(play.stage == .won, "level \(number)")
            let smallest: Int = generated.solution.smallest
            #expect(smallest == generated.difficulty.smallest, "level \(number)")
            #expect(play.spent == smallest, "level \(number)")
            #expect(ColorfallCanyonsProgress.stars(actions: play.spent, smallest: smallest) == 3, "level \(number)")
        }
    }

    @Test func scriptedCampaignThroughAllLevels() {
        var numbers: [Int] = []
        for number in 1...ColorfallCanyonsProgress.levelCount { numbers.append(number) }
        var progress: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1) && !progress.isOpen(2) && !progress.isOpen(0) && !progress.isOpen(101))
        for number in numbers {
            // The rules do not depend on the level's content: a synthetic smallest edit count 1 … 3 keeps the test short.
            let smallest: Int = 1 + number % 3
            #expect(progress.isOpen(number), "level \(number) open before its win")
            #expect(progress.frontier == number, "level \(number)")
            if number < 100 { #expect(!progress.isOpen(number + 1), "level \(number + 1) closed") }
            #expect(progress.nextOpen(after: number) == nil, "level \(number)")
            let extra: Int = number % 4
            let actions: Int = smallest + extra
            let expectedStars: Int = extra == 0 ? 3 : (extra <= 2 ? 2 : 1)
            let changed: Bool = progress.record(level: number, actions: actions, smallest: smallest)
            #expect(changed, "level \(number)")
            #expect(progress.solved[number] == ColorfallCanyonsProgress.Result(bestActions: actions,
                                                                                stars: expectedStars),
                    "level \(number)")
            if number < 100 { #expect(progress.nextOpen(after: number) == number + 1, "level \(number)") }
        }
        #expect(progress.frontier == 100)
        #expect(progress.solved.count == 100)
        for level in 1...100 { #expect(progress.isOpen(level)) }
        #expect(progress.nextOpen(after: 100) == nil)
        #expect(progress.nextOpen(after: 0) == 1)
    }

    @Test func betterResultsReplaceWorseOnes() {
        var progress: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
        let recorded1: Bool = progress.record(level: 1, actions: 6, smallest: 2)
        #expect(recorded1)
        #expect(progress.solved[1] == ColorfallCanyonsProgress.Result(bestActions: 6, stars: 1))
        let recorded2: Bool = progress.record(level: 1, actions: 6, smallest: 2)
        #expect(!recorded2, "equal keeps")
        let recorded3: Bool = progress.record(level: 1, actions: 9, smallest: 2)
        #expect(!recorded3, "worse keeps")
        #expect(progress.solved[1] == ColorfallCanyonsProgress.Result(bestActions: 6, stars: 1))
        let recorded4: Bool = progress.record(level: 1, actions: 4, smallest: 2)
        #expect(recorded4)
        #expect(progress.solved[1] == ColorfallCanyonsProgress.Result(bestActions: 4, stars: 2))
        let recorded5: Bool = progress.record(level: 1, actions: 2, smallest: 2)
        #expect(recorded5)
        #expect(progress.solved[1] == ColorfallCanyonsProgress.Result(bestActions: 2, stars: 3))
        let recorded6: Bool = progress.record(level: 1, actions: 5, smallest: 2)
        #expect(!recorded6)
        #expect(progress.solved[1] == ColorfallCanyonsProgress.Result(bestActions: 2, stars: 3))
        #expect(progress.frontier == 2)
        // Levels outside 1 … 100 are ignored.
        let recorded7: Bool = progress.record(level: 0, actions: 1, smallest: 1)
        #expect(!recorded7)
        let recorded8: Bool = progress.record(level: 101, actions: 1, smallest: 1)
        #expect(!recorded8)
        #expect(progress.solved.count == 1)
        #expect(progress.frontier == 2)
    }

    @Test func practiceRecordsNothingAndDailyOpensNothing() {
        var progress: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
        let recorded9: Bool = progress.record(level: 1, actions: 1, smallest: 1, mode: .practice)
        #expect(!recorded9)
        #expect(progress == ColorfallCanyonsProgress())
        // A daily win on a locked level records its result but opens nothing.
        let recorded10: Bool = progress.record(level: 57, actions: 4, smallest: 3, mode: .daily(level: 57))
        #expect(recorded10)
        #expect(progress.solved[57] == ColorfallCanyonsProgress.Result(bestActions: 4, stars: 2))
        #expect(progress.frontier == 1)
        #expect(!progress.isOpen(57))
        let recorded11: Bool = progress.record(level: 1, actions: 1, smallest: 1, mode: .daily(level: 1))
        #expect(recorded11)
        #expect(progress.frontier == 1)
        let recorded12: Bool = progress.record(level: 1, actions: 1, smallest: 1, mode: .campaign)
        #expect(recorded12 == false)
        #expect(progress.frontier == 2)
        // Mode rules and budgets.
        #expect(ColorfallCanyonsMode.practiceBudget == 30)
        #expect(ColorfallCanyonsMode.practiceBudget == ColorfallCanyonsLevel.budgets.upperBound)
        #expect(ColorfallCanyonsMode.practice.budget(base: 4) == 30)
        #expect(ColorfallCanyonsMode.campaign.budget(base: 4) == 4)
        #expect(ColorfallCanyonsMode.daily(level: 9).budget(base: 7) == 7)
        #expect(ColorfallCanyonsMode.campaign.awardsStars && ColorfallCanyonsMode.campaign.opensLevels)
        #expect(ColorfallCanyonsMode.daily(level: 9).awardsStars && !ColorfallCanyonsMode.daily(level: 9).opensLevels)
        #expect(!ColorfallCanyonsMode.practice.awardsStars && !ColorfallCanyonsMode.practice.opensLevels)
    }

    @Test func openThroughAndBands() {
        var progress: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
        progress.open(through: 40)
        #expect(progress.frontier == 40)
        progress.open(through: 10)
        #expect(progress.frontier == 40, "never falls")
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        for level in 1...100 {
            #expect(ColorfallCanyonsProgress.band(of: level) == (level - 1) / 20 + 1, "level \(level)")
        }
        #expect(ColorfallCanyonsProgress.band(of: 0) == 1)
        #expect(ColorfallCanyonsProgress.band(of: 101) == 5)
    }

    @Test func allLevelsReachableByProgressAlone() {
        var progress: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
        var reached: Set<Int> = []
        while true {
            let frontier: Int = progress.frontier
            reached.insert(frontier)
            progress.record(level: frontier, actions: 9, smallest: 1)
            if progress.frontier == frontier { break }
        }
        #expect(reached.count == 100)
    }

    // MARK: Daily level

    @Test func dailyLevelOfEveryDate2026To2036() {
        #expect(ColorfallCanyonsProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(ColorfallCanyonsProgress.dailyLevel(year: 2026, month: 1, day: 2) == 54)
        #expect(ColorfallCanyonsProgress.dailyLevel(year: 2026, month: 1, day: 3) == 7)
        #expect(ColorfallCanyonsProgress.dailyLevel(year: 2025, month: 12, day: 31) == 48)
        var dayIndex: Int = 0
        var window: Set<Int> = []
        var count: Int = 0
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...ColorfallCanyonsProgress.daysIn(month: month, year: year) {
                    let level: Int? = ColorfallCanyonsProgress.dailyLevel(year: year, month: month, day: day)
                    let expected: Int = (dayIndex * 53) % 100 + 1
                    #expect(level == expected, "\(year)-\(month)-\(day)")
                    #expect(level == ColorfallCanyonsProgress.dailyLevel(year: year, month: month, day: day),
                            "stable")
                    if let level { window.insert(level) }
                    count += 1
                    if count % 100 == 0 {
                        #expect(window.count == 100, "100 consecutive days ending \(year)-\(month)-\(day)")
                        window = []
                    }
                    dayIndex += 1
                }
            }
        }
        #expect(dayIndex == 4_018)
    }

    @Test func dailyLevelBeforeTheEpochWraps() {
        var window: Set<Int> = []
        for offset in 1...100 {
            // Walk back from 2025-12-31 day by day through the civil arithmetic.
            let days: Int = ColorfallCanyonsProgress.daysFromCivil(year: 2026, month: 1, day: 1) - offset
            let date: (Int, Int, Int) = civil(days)
            let level: Int? = ColorfallCanyonsProgress.dailyLevel(year: date.0, month: date.1, day: date.2)
            let expected: Int = ((-offset * 53) % 100 + 100) % 100 + 1
            #expect(level == expected, "\(date)")
            if let level { window.insert(level) }
        }
        #expect(window.count == 100)
        let ancient: Int? = ColorfallCanyonsProgress.dailyLevel(year: 1, month: 1, day: 1)
        #expect(ancient != nil && (1...100).contains(ancient ?? 0))
        let far: Int? = ColorfallCanyonsProgress.dailyLevel(year: 9999, month: 12, day: 31)
        #expect(far != nil && (1...100).contains(far ?? 0))
    }

    /// The proleptic Gregorian date of `days` from 1970-01-01 (H. Hinnant's civil-from-days).
    func civil(_ days: Int) -> (Int, Int, Int) {
        let z: Int = days + 719_468
        let era: Int = (z >= 0 ? z : z - 146_096) / 146_097
        let doe: Int = z - era * 146_097
        let yoe: Int = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let doy: Int = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp: Int = (5 * doy + 2) / 153
        let day: Int = doy - (153 * mp + 2) / 5 + 1
        let month: Int = mp < 10 ? mp + 3 : mp - 9
        let year: Int = yoe + era * 400 + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }

    @Test func impossibleDatesAreRefused() {
        let dates: [[Int]] = [[2026, 2, 29], [2027, 2, 29], [2100, 2, 29], [2026, 4, 31], [2026, 6, 31], [2026, 9, 31],
                              [2026, 11, 31], [2026, 13, 1], [2026, 0, 1], [2026, 1, 0], [2026, 1, 32], [0, 1, 1],
                              [10_000, 1, 1], [-5, 3, 3], [2026, -1, 5], [2026, 5, -2]]
        for date in dates {
            #expect(ColorfallCanyonsProgress.dailyLevel(year: date[0], month: date[1], day: date[2]) == nil, "\(date)")
        }
        #expect(ColorfallCanyonsProgress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(ColorfallCanyonsProgress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
    }

    // MARK: Codable

    @Test func progressAndModeRoundTrip() throws {
        var progress: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
        progress.record(level: 1, actions: 1, smallest: 1)
        progress.record(level: 2, actions: 5, smallest: 2)
        progress.record(level: 70, actions: 4, smallest: 3, mode: .daily(level: 70))
        let data: Data = try progress.encoded()
        let decoded: ColorfallCanyonsProgress = try JSONDecoder().decode(ColorfallCanyonsProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":3,\"solved\":[{\"bestActions\":1,\"level\":1,\"stars\":3},"
            + "{\"bestActions\":5,\"level\":2,\"stars\":1},{\"bestActions\":4,\"level\":70,\"stars\":2}]}")
        let empty: ColorfallCanyonsProgress = try JSONDecoder().decode(
            ColorfallCanyonsProgress.self, from: Data("{\"frontier\":1,\"solved\":[]}".utf8))
        #expect(empty == ColorfallCanyonsProgress())

        let modes: [ColorfallCanyonsMode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for mode in modes {
            let encoded: Data = try encoder.encode(mode)
            #expect(try JSONDecoder().decode(ColorfallCanyonsMode.self, from: encoded) == mode, "\(mode)")
        }
        #expect(String(decoding: try encoder.encode(ColorfallCanyonsMode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        for step in ColorfallCanyonsTutorialStep.allCases {
            let encoded: Data = try encoder.encode([step])
            #expect(try JSONDecoder().decode([ColorfallCanyonsTutorialStep].self, from: encoded) == [step])
        }
    }

    @Test func invalidEncodingsAreRefused() {
        let bad: [String] = [
            "{\"frontier\":0,\"solved\":[]}",
            "{\"frontier\":101,\"solved\":[]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":1,\"level\":0,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":1,\"level\":1,\"stars\":4}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":1,\"level\":1,\"stars\":0}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":-1,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":1,\"level\":1,\"stars\":3},"
                + "{\"bestActions\":2,\"level\":1,\"stars\":3}]}",
        ]
        for text in bad {
            #expect(throws: (any Error).self, "\(text)") {
                _ = try JSONDecoder().decode(ColorfallCanyonsProgress.self, from: Data(text.utf8))
            }
        }
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"daily\"}", "{\"mode\":\"replay\",\"level\":3}", "{\"level\":3}"]
        for text in badModes {
            #expect(throws: (any Error).self, "\(text)") {
                _ = try JSONDecoder().decode(ColorfallCanyonsMode.self, from: Data(text.utf8))
            }
        }
    }
}
#endif
