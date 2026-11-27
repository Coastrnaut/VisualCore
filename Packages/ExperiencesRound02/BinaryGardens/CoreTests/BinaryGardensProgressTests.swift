// BinaryGardensProgressTests — feature 505 (R02-G21-05) T-R02G2105-003 (FR-R02G2105-001, 004, 005, 006;
// SC-R02G2105-001, 004; clarifications Q2, Q3, Q4). The tutorial steps on levels 1 … 3 by scripted plays of their
// certified witnesses (`BinaryGardensExperienceCore.generated(number:)`, one arrangement action each in band 1, then
// the run) applied to the opening play through the real kernel (begin, dismissTutorial, then adjust → balance → done
// on the winning run), a two- or three-action detour that reaches `recover`, an undo and redo detour that never moves
// a step back, a failed run ending the tutorial and a redo that restores a failed run ending it; 500 seeded
// (SeededRandom seed 2_505) flag walks that never move a step back; the star thresholds at their edges; the actions
// spent, undone records included; the certified action counts (1, 2, 3, 3, 4 by band) at every band's edges; a
// 100-level progress script (frontier, best results, a worse replay not replacing a better one, daily and practice
// rules); every calendar day 2026-01-01 … 2036-12-31 mapping into 1 … 100, stably, against an independent day count,
// with known values computed outside the code under test, and 100 consecutive days visiting every level once;
// negative day counts wrapped; impossible days nil, leap years included; Codable round trips with the stable JSON
// shape and the validation helpers. Modelled on feature 495's MushroomWeatherProgressTests. Test data uses explicit
// types and plain loops (CI type-check rule); each test well under 10 s. No clock: dates are inputs. Dismissal is the
// adapter's and is tested there; only the step logic is tested here.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BinaryGardensCore

@Suite struct BinaryGardensProgressTests {
    typealias Step = BinaryGardensTutorialStep
    typealias Progress = BinaryGardensProgress
    typealias Mode = BinaryGardensMode
    typealias Play = BinaryGardensPlay
    typealias Action = BinaryGardensAction
    typealias Arrangement = BinaryGardensArrangement

    /// The seed of the seeded flag walks.
    static let seed: UInt64 = 2_505

    /// The certified witness action count of each band (clarification Q3).
    static let certifiedByBand: [Int] = [1, 2, 3, 3, 4]

    /// Whether `play` has ended (the run won or failed).
    static func ended(_ play: Play) -> Bool { play.stage == .won || play.stage == .failed }

    /// The step after `action` was applied to `play` (which it mutates): an accepted arrangement action (not the
    /// run), the arrangement actions of the opening so far and the play's real end.
    static func step(_ step: Step, applying action: Action, to play: inout Play) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        return step.advanced(afterAction: action != .run, actionsThisOpening: Progress.actionsSpent(play),
                             ended: ended(play))
    }

    /// The step after an undo or a redo: no accepted action and the play's real end.
    static func stepAfterHistory(_ step: Step, _ play: Play) -> Step {
        step.advanced(afterAction: false, actionsThisOpening: Progress.actionsSpent(play), ended: ended(play))
    }

    /// The opening play of level `number` (begun, its tutorial dismissed, stage `playing`), its certified witness's
    /// arrangement actions and the certified arrangement.
    static func opening(_ number: Int) throws -> (play: Play, actions: [Action], goal: Arrangement) {
        let generated: BinaryGardensGenerated = try BinaryGardensExperienceCore.generated(number: number)
        var play: Play = Play(level: generated.level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return (play, generated.plan.actions, generated.plan.arrangement)
    }

    /// The control an arrangement action sets: star s ring 3s, phase 3s + 1, luminosity 3s + 2; tilt 6; run −1.
    static func control(of action: Action) -> Int {
        switch action {
        case .ring(let star, _): return 3 * star
        case .phase(let star, _): return 3 * star + 1
        case .luminosity(let star, _): return 3 * star + 2
        case .tilt: return 6
        case .run: return -1
        }
    }

    /// The action that sets `control` back to its value in `arrangement`.
    static func restoring(_ control: Int, in arrangement: Arrangement) -> Action {
        let star: Int = control / 3
        switch control {
        case 6: return .tilt(step: arrangement.tilt)
        default:
            switch control % 3 {
            case 0: return .ring(star: star, index: arrangement.rings[star])
            case 1: return .phase(star: star, step: arrangement.phases[star])
            default: return .luminosity(star: star, index: arrangement.luminosities[star])
            }
        }
    }

    /// A detour script from the opening that ends at the certified arrangement with at least two arrangement actions,
    /// every one accepted: a legal move on the witness's own control followed by the witness action, or the witness
    /// action between a legal move on another control and its reversal. nil when no move gives one.
    static func detour(_ opening: (play: Play, actions: [Action], goal: Arrangement)) -> [Action]? {
        let puzzle: BinaryGardensPuzzle = BinaryGardensPuzzle(level: opening.play.level)
        let start: Arrangement = opening.play.arrangement
        let moves: [Action] = puzzle.moves(in: BinaryGardensPuzzle.Position(arrangement: start, actionsSpent: 0))
        for move in moves where !opening.actions.contains(move) {
            var script: [Action] = []
            if opening.actions.contains(where: { control(of: $0) == control(of: move) }) {
                script = [move] + opening.actions
            } else {
                script = [move] + opening.actions + [restoring(control(of: move), in: start)]
            }
            var play: Play = opening.play
            var accepted: Bool = true
            for action in script {
                do { try play.apply(action, expecting: play.fingerprint) } catch { accepted = false }
                if !accepted { break }
            }
            if accepted && play.arrangement == opening.goal && play.report.wins { return script }
        }
        return nil
    }

    /// Records a win in `progress` (outside `#expect`, which cannot mutate) and returns whether the result changed.
    static func record(_ progress: inout Progress, level: Int, actionsSpent: Int, certified: Int,
                       mode: Mode = .campaign) -> Bool {
        progress.record(level: level, actionsSpent: actionsSpent, certified: certified, mode: mode)
    }

    // MARK: Tutorial

    @Test func tutorialTextsAreClarificationQ2() {
        #expect(Step.adjust.text == "Change a star: drag it along its orbit or across its rings, tap a brightness pip "
            + "or the tilt dial, or use the panel; the gauges show every world's light over the whole cycle")
        #expect(Step.balance.text == "Keep every world's light comfortable for its window, never frozen or scorched "
            + "for too long, with its total light inside its bloom band, then press Run — a hint shows what to change")
        #expect(Step.recover.text == "A world that freezes or scorches for too many ticks, has too short a comfortable "
            + "window, or gets too little or too much light in total fails the run: undo and try another change")
        #expect(Step.done.text.isEmpty)
        #expect(Step.adjust.rawValue == "adjust" && Step.balance.rawValue == "balance")
        #expect(Step.recover.rawValue == "recover" && Step.done.rawValue == "done")
        #expect(Step.initial(tutorial: true) == .adjust && Step.initial(tutorial: false) == .done)
        for level in 1...100 {
            let expected: Step = level <= 3 ? .adjust : .done
            #expect(Step.initial(level: level) == expected)
        }
        for step in Step.allCases { #expect(step.dismissed() == .done) }
    }

    @Test func tutorialAdvancesInOrderNeverBack() {
        for count in 0...4 {
            #expect(Step.adjust.advanced(afterAction: true, actionsThisOpening: count, ended: false) == .balance)
            #expect(Step.adjust.advanced(afterAction: false, actionsThisOpening: count, ended: false) == .adjust)
            let afterSecond: Step = count >= 2 ? .recover : .balance
            #expect(Step.balance.advanced(afterAction: true, actionsThisOpening: count, ended: false) == afterSecond)
            #expect(Step.balance.advanced(afterAction: false, actionsThisOpening: count, ended: false) == .balance)
            for afterAction in [false, true] {
                #expect(Step.recover.advanced(afterAction: afterAction, actionsThisOpening: count, ended: false)
                    == .recover)
                #expect(Step.done.advanced(afterAction: afterAction, actionsThisOpening: count, ended: false) == .done)
                for step in Step.allCases {
                    #expect(step.advanced(afterAction: afterAction, actionsThisOpening: count, ended: true) == .done)
                }
            }
        }
    }

    @Test func seededFlagWalksNeverMoveBack() {
        let order: [Step] = [.adjust, .balance, .recover, .done]
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var reachedDone: Int = 0
        var reachedRecover: Int = 0
        for _ in 0..<500 {
            var step: Step = .adjust
            var count: Int = 0
            for _ in 0..<12 {
                let afterAction: Bool = random.int(0...1) == 1
                if afterAction { count += 1 }
                let ended: Bool = random.int(0...7) == 0
                let next: Step = step.advanced(afterAction: afterAction, actionsThisOpening: count, ended: ended)
                let before: Int = order.firstIndex(of: step) ?? -1
                let after: Int = order.firstIndex(of: next) ?? -1
                #expect(after >= before)
                #expect(after <= before + 1 || next == .done)
                if step == .adjust && next == .balance { #expect(afterAction) }
                if step == .balance && next == .recover { #expect(afterAction && count >= 2) }
                if next == .recover { reachedRecover += 1 }
                step = next
            }
            if step == .done { reachedDone += 1 }
        }
        #expect(reachedDone > 0 && reachedRecover > 0)
    }

    @Test func tutorialLevelsWitnessPlaysWalkTheSteps() throws {
        for number in 1...3 {
            let opening: (play: Play, actions: [Action], goal: Arrangement) = try Self.opening(number)
            #expect(opening.play.level.tutorial)
            var fresh: Play = Play(level: opening.play.level)
            try fresh.handle(.begin)
            #expect(fresh.stage == .tutorial)
            var play: Play = opening.play
            #expect(play.stage == .playing)
            #expect(opening.actions.count == 1)
            var step: Step = Step.initial(level: number)
            #expect(step == .adjust)
            for action in opening.actions {
                step = try Self.step(step, applying: action, to: &play)
                #expect(play.stage == .playing)
                #expect(step == .balance)
            }
            step = try Self.step(step, applying: .run, to: &play)
            #expect(play.stage == .won)
            #expect(step == .done)
            #expect(Progress.actionsSpent(play) == opening.actions.count)
            let stars: Int = Progress.stars(actionsSpent: Progress.actionsSpent(play), certified: opening.actions.count)
            #expect(stars == 3)
        }
    }

    @Test func detourReachesRecoverAndUndoRedoNeverMoveBack() throws {
        for number in 1...3 {
            let opening: (play: Play, actions: [Action], goal: Arrangement) = try Self.opening(number)
            let script: [Action]? = Self.detour(opening)
            #expect(script != nil)
            guard let script else { continue }
            #expect(script.count >= 2)
            var play: Play = opening.play
            var step: Step = .adjust
            for (index, action) in script.enumerated() {
                step = try Self.step(step, applying: action, to: &play)
                let expected: Step = index == 0 ? .balance : .recover
                #expect(step == expected)
                // An undo and a redo after each action never move the step back.
                try play.undo()
                step = Self.stepAfterHistory(step, play)
                #expect(step == expected)
                try play.redo()
                step = Self.stepAfterHistory(step, play)
                #expect(step == expected)
            }
            // Undo and redo records count nothing; the undone records stay counted.
            #expect(Progress.actionsSpent(play) == script.count)
            step = try Self.step(step, applying: .run, to: &play)
            #expect(play.stage == .won && step == .done)
            let stars: Int = Progress.stars(actionsSpent: Progress.actionsSpent(play), certified: opening.actions.count)
            #expect(stars == (script.count <= opening.actions.count + 2 ? 2 : 1))
        }
    }

    @Test func undoBeforeTheSecondActionKeepsBalance() throws {
        let opening: (play: Play, actions: [Action], goal: Arrangement) = try Self.opening(1)
        var play: Play = opening.play
        var step: Step = try Self.step(.adjust, applying: opening.actions[0], to: &play)
        #expect(step == .balance)
        try play.undo()
        step = Self.stepAfterHistory(step, play)
        #expect(step == .balance && play.actionsSpent == 0)
        // Re-applying the witness action is the second accepted arrangement action of the opening.
        step = try Self.step(step, applying: opening.actions[0], to: &play)
        #expect(step == .recover)
        #expect(Progress.actionsSpent(play) == 2 && play.actionsSpent == 1)
    }

    @Test func failedRunEndsTheTutorialAndRedoOfAFailureEndsIt() throws {
        for number in 1...3 {
            let opening: (play: Play, actions: [Action], goal: Arrangement) = try Self.opening(number)
            var play: Play = opening.play
            // A level never starts won, so running at once fails it.
            var step: Step = try Self.step(.adjust, applying: .run, to: &play)
            #expect(play.stage == .failed)
            #expect(play.failure != nil)
            #expect(step == .done)
            // An undo lands before the end: a tutorial at `recover` stays there.
            try play.undo()
            step = Self.stepAfterHistory(.recover, play)
            #expect(play.stage == .playing && step == .recover)
            // A redo that restores the failed run ends it.
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .failed && step == .done)
            #expect(Progress.actionsSpent(play) == 0)
        }
    }

    // MARK: Stars and actions

    @Test func starThresholds() {
        for certified in 1...5 {
            for spent in 1...24 {
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
        let opening: (play: Play, actions: [Action], goal: Arrangement) = try Self.opening(2)
        var play: Play = opening.play
        #expect(Progress.actionsSpent(play) == 0)
        // Records of begin and dismissTutorial count nothing.
        #expect(play.records.count == 2)
        try play.apply(opening.actions[0], expecting: play.fingerprint)
        try play.undo()
        try play.apply(opening.actions[0], expecting: play.fingerprint)
        #expect(play.actionsSpent == 1)
        #expect(Progress.actionsSpent(play) == 2)
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .won)
        try play.handle(.showResult)
        #expect(Progress.actionsSpent(play) == 2)
        #expect(Progress.stars(actionsSpent: 2, certified: opening.actions.count) == 2)
    }

    @Test func certifiedActionCountsOfTheCatalog() throws {
        // The tutorial levels and the first and last level of every band (generating all 100 takes about 7 s on the
        // development machine, too slow for CI's 10 s bound; the catalog tests cover every level).
        let numbers: [Int] = [1, 2, 3, 4, 20, 21, 40, 41, 60, 61, 80, 81, 100]
        for number in numbers {
            let generated: BinaryGardensGenerated = try BinaryGardensExperienceCore.generated(number: number)
            let expected: Int = Self.certifiedByBand[Progress.band(of: number) - 1]
            #expect(generated.plan.actions.count == expected)
            #expect(generated.level.tutorial == (number <= 3))
            #expect(Progress.stars(actionsSpent: generated.plan.actions.count,
                                   certified: generated.plan.actions.count) == 3)
        }
    }

    // MARK: Progress

    @Test func hundredLevelScript() {
        var progress: Progress = Progress()
        #expect(progress.frontier == 1 && progress.isOpen(1) && !progress.isOpen(2) && !progress.isOpen(0))
        #expect(progress.best(1) == nil && progress.stars(of: 1) == 0)
        #expect(progress.nextOpen(after: 1) == nil)
        for level in 1...100 {
            #expect(progress.isOpen(level))
            if level < 100 { #expect(!progress.isOpen(level + 1)) }
            let certified: Int = Self.certifiedByBand[Progress.band(of: level) - 1]
            let spent: Int = certified + level % 4
            let changed: Bool = Self.record(&progress, level: level, actionsSpent: spent, certified: certified)
            #expect(changed)
            #expect(progress.best(level) == spent)
            #expect(progress.stars(of: level) == Progress.stars(actionsSpent: spent, certified: certified))
            #expect(progress.frontier == min(level + 1, 100))
            #expect(progress.isValid)
        }
        #expect(progress.frontier == 100 && progress.solved.count == 100)
        // A worse or equal replay keeps the better result; a better one replaces it.
        for level in 1...100 {
            let certified: Int = Self.certifiedByBand[Progress.band(of: level) - 1]
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
        #expect(progress.nextOpen(after: 100) == nil)
        #expect(!Self.record(&progress, level: 0, actionsSpent: 1, certified: 1))
        #expect(!Self.record(&progress, level: 101, actionsSpent: 1, certified: 1))
        var fresh: Progress = Progress()
        #expect(!Self.record(&fresh, level: 1, actionsSpent: 0, certified: 1))
        #expect(fresh == Progress())
        #expect(Progress.band(of: 1) == 1 && Progress.band(of: 20) == 1 && Progress.band(of: 21) == 2)
        #expect(Progress.band(of: 100) == 5 && Progress.band(of: 0) == 1 && Progress.band(of: 200) == 5)
        #expect(Progress.bands == 1...5 && Progress.levelsPerBand == 20 && Progress.levelCount == 100)
    }

    @Test func modesRecordAndOpen() {
        var progress: Progress = Progress()
        // Practice never awards and never opens.
        for level in 1...100 {
            #expect(!Self.record(&progress, level: level, actionsSpent: 1, certified: 1, mode: .practice))
        }
        #expect(progress.solved.isEmpty && progress.frontier == 1)
        // Daily records the level's result but opens nothing, even a level still locked in the campaign.
        #expect(Self.record(&progress, level: 50, actionsSpent: 4, certified: 2, mode: .daily(level: 50)))
        #expect(progress.best(50) == 4 && progress.stars(of: 50) == 2 && progress.frontier == 1)
        #expect(!progress.isOpen(50) && !progress.isOpen(51))
        #expect(Self.record(&progress, level: 50, actionsSpent: 2, certified: 2, mode: .daily(level: 50)))
        #expect(progress.best(50) == 2 && progress.stars(of: 50) == 3 && progress.frontier == 1)
        #expect(Self.record(&progress, level: 1, actionsSpent: 2, certified: 1, mode: .campaign))
        #expect(progress.frontier == 2 && progress.nextOpen(after: 1) == 2)
        progress.open(through: 7)
        #expect(progress.frontier == 7)
        progress.open(through: 3)
        #expect(progress.frontier == 7)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        progress.open(through: -4)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 24 && Mode.practiceBudget == BinaryGardensLevel.budgets.upperBound)
        #expect(Mode.practice.budget(base: 9) == 24 && Mode.campaign.budget(base: 9) == 9)
        #expect(Mode.daily(level: 3).budget(base: 11) == 11)
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 1).awardsStars && !Mode.practice.awardsStars)
        #expect(Mode.campaign.opensLevels && !Mode.daily(level: 1).opensLevels && !Mode.practice.opensLevels)
        #expect(Mode.campaign.isValid && Mode.practice.isValid && Mode.daily(level: 100).isValid)
        #expect(!Mode.daily(level: 0).isValid && !Mode.daily(level: 101).isValid)
    }

    // MARK: Daily level

    @Test func dailyLevelOverElevenYears() {
        let monthDays: [Int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        var days: Int = 0
        var counts: [Int] = [Int](repeating: 0, count: 101)
        for year in 2026...2036 {
            let leap: Bool = year % 4 == 0
            for month in 1...12 {
                let length: Int = month == 2 && leap ? 29 : monthDays[month - 1]
                #expect(Progress.daysIn(month: month, year: year) == length)
                for day in 1...length {
                    let level: Int? = Progress.dailyLevel(year: year, month: month, day: day)
                    #expect(level != nil)
                    let value: Int = level ?? 0
                    #expect(value >= 1 && value <= 100)
                    #expect(Progress.dailyLevel(year: year, month: month, day: day) == level)
                    #expect(Progress.daysFromEpoch(year: year, month: month, day: day) == days)
                    #expect(value == (days * 13) % 100 + 1)
                    counts[min(max(value, 0), 100)] += 1
                    days += 1
                }
            }
        }
        #expect(days == 4_018)
        for level in 1...100 { #expect(counts[level] >= 40) }
        #expect(Progress.dailyMultiplier == 13)
        // Known values computed independently (Python `datetime.date` differences from 2026-01-01, × 13 mod 100 + 1).
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 2) == 14)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 5) == 53)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 1) == 4)
        #expect(Progress.dailyLevel(year: 2026, month: 11, day: 27) == 91)
        #expect(Progress.dailyLevel(year: 2027, month: 1, day: 1) == 46)
        #expect(Progress.dailyLevel(year: 2036, month: 12, day: 31) == 22)
        #expect(Progress.daysFromEpoch(year: 2036, month: 12, day: 31) == 4_017)
    }

    @Test func hundredConsecutiveDaysVisitEveryLevelOnce() {
        let starts: [(Int, Int, Int)] = [(2026, 1, 1), (2026, 11, 27), (2028, 2, 10), (2031, 12, 1)]
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
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 88)
        #expect(Progress.daysFromEpoch(year: 2025, month: 1, day: 1) == -365)
        #expect(Progress.dailyLevel(year: 2025, month: 1, day: 1) == 56)
        #expect(Progress.daysFromEpoch(year: 2000, month: 2, day: 29) == -9_438)
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) == 7)
        for year in [1, 1600, 1900, 2000, 2024] {
            for month in [1, 2, 7, 12] {
                let level: Int = Progress.dailyLevel(year: year, month: month, day: 28) ?? 0
                let days: Int = Progress.daysFromEpoch(year: year, month: month, day: 28) ?? 0
                #expect(days < 0)
                #expect(level >= 1 && level <= 100)
                #expect(level == ((days * 13) % 100 + 100) % 100 + 1)
            }
        }
        #expect(Progress.dailyLevel(year: 9999, month: 12, day: 31) != nil)
        #expect(Progress.dailyLevel(year: 1, month: 1, day: 1) != nil)
    }

    @Test func impossibleDaysAreNilAndLeapYears() {
        #expect(Progress.dailyLevel(year: 2027, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(Progress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2024, month: 4, day: 31) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 32) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: -1) == nil)
        #expect(Progress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: -1, month: 1, day: 1) == nil)
        #expect(Progress.daysFromEpoch(year: 2027, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
        #expect(Progress.dailyLevel(year: 2024, month: 2, day: 29) != nil)
        #expect(Progress.daysIn(month: 2, year: 2028) == 29 && Progress.daysIn(month: 2, year: 2026) == 28)
        #expect(Progress.daysIn(month: 11, year: 2026) == 30 && Progress.daysIn(month: 12, year: 2026) == 31)
    }

    // MARK: Codable and validation

    @Test func codableRoundTrips() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder: JSONDecoder = JSONDecoder()
        var progress: Progress = Progress()
        progress.record(level: 3, actionsSpent: 4, certified: 1, opens: false)
        progress.record(level: 1, actionsSpent: 1, certified: 1)
        progress.open(through: 4)
        let data: Data = try progress.encoded()
        let decoded: Progress = try decoder.decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(decoded.isValid)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":4,\"solved\":[{\"actionsSpent\":1,\"level\":1,\"stars\":3},"
            + "{\"actionsSpent\":4,\"level\":3,\"stars\":1}]}")
        let empty: Progress = try decoder.decode(Progress.self, from: try Progress().encoded())
        #expect(empty == Progress())
        #expect(String(decoding: try Progress().encoded(), as: UTF8.self) == "{\"frontier\":1,\"solved\":[]}")

        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 13), .daily(level: 100)]
        for mode in modes {
            let modeData: Data = try encoder.encode(mode)
            #expect(try decoder.decode(Mode.self, from: modeData) == mode)
        }
        #expect(String(decoding: try encoder.encode(Mode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        #expect(String(decoding: try encoder.encode(Mode.campaign), as: UTF8.self) == "{\"mode\":\"campaign\"}")
        #expect(String(decoding: try encoder.encode(Mode.practice), as: UTF8.self) == "{\"mode\":\"practice\"}")
        for step in Step.allCases {
            let stepData: Data = try encoder.encode(step)
            #expect(try decoder.decode(Step.self, from: stepData) == step)
            #expect(String(decoding: stepData, as: UTF8.self) == "\"\(step.rawValue)\"")
        }
    }

    @Test func invalidEncodingsAreRefused() {
        let decoder: JSONDecoder = JSONDecoder()
        let badProgress: [String] = [
            "{\"frontier\":0,\"solved\":[]}",
            "{\"frontier\":101,\"solved\":[]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":0,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":101,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":4}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":0}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":0,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":-1,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3},"
                + "{\"actionsSpent\":2,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2}",
            "{\"solved\":[]}"
        ]
        for text in badProgress {
            #expect(throws: (any Error).self) { try decoder.decode(Progress.self, from: Data(text.utf8)) }
        }
        let badModes: [String] = [
            "{\"mode\":\"replay\",\"level\":1}",
            "{\"mode\":\"daily\"}",
            "{\"mode\":\"daily\",\"level\":0}",
            "{\"mode\":\"daily\",\"level\":101}"
        ]
        for text in badModes {
            #expect(throws: (any Error).self) { try decoder.decode(Mode.self, from: Data(text.utf8)) }
        }
        #expect(throws: (any Error).self) { try decoder.decode(Step.self, from: Data("\"place\"".utf8)) }
    }

    @Test func validationHelpers() {
        #expect(Progress.isValid(level: 1) && Progress.isValid(level: 100))
        #expect(!Progress.isValid(level: 0) && !Progress.isValid(level: 101))
        #expect(Progress.isValidResult(actionsSpent: 1, stars: 1) && Progress.isValidResult(actionsSpent: 24, stars: 3))
        #expect(!Progress.isValidResult(actionsSpent: 0, stars: 3))
        #expect(!Progress.isValidResult(actionsSpent: 1, stars: 0))
        #expect(!Progress.isValidResult(actionsSpent: 1, stars: 4))
        #expect(Progress.Result(actionsSpent: 3, stars: 2).isValid)
        #expect(!Progress.Result(actionsSpent: 0, stars: 2).isValid)
        #expect(Progress().isValid)
        #expect(Progress.levels == 1...100 && Progress.starRange == 1...3)
    }
}
