// CelestialEclipseLabProgressTests — feature 465 (R02-G17-05) T-R02G1705-003 (FR-R02G1705-001, 004, 005;
// SC-R02G1705-001, 004; clarifications Q2, Q3, Q4). The tutorial steps on levels 1 … 3 by scripted plays of their
// stored witnesses (`docs/games/celestial-eclipse-lab/levels/00N.witness.json`: the phase changes, then the run)
// applied to the opening play through the real kernel (phase → order → recover → done on the winning run; level 2's
// single change goes phase → order → done), an undo and redo detour that never moves a step back, a failed run ending
// the tutorial and a redo that restores a failed run ending it; 500 seeded (SeededRandom seed 2_465) flag walks that
// never move a step back; the star thresholds; the actions spent, undone records included; a 100-level progress script
// (frontier, best results, a worse replay not replacing a better one, daily and practice rules); every calendar day
// 2026-01-01 … 2036-12-31 mapping into 1 … 100, stably, against an independent day count, with known values computed
// outside the code under test, and 100 consecutive days visiting every level once; negative day counts wrapped;
// impossible days nil, leap years included; Codable round trips. Test data uses explicit types and plain loops (CI
// type-check rule); each test well under 3 s. No clock: dates are inputs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, CelestialEclipseLab, the
/// package, Packages).
private let progressWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/celestial-eclipse-lab/levels", isDirectory: true)

@Suite struct CelestialEclipseLabProgressTests {
    typealias Step = CelestialEclipseLabTutorialStep
    typealias Progress = CelestialEclipseLabProgress
    typealias Mode = CelestialEclipseLabMode
    typealias Play = CelestialEclipseLabPlay
    typealias Action = CelestialEclipseLabAction
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Witness = CelestialEclipseLabWitness

    /// The seed of the seeded flag walks.
    static let seed: UInt64 = 2_465

    /// Whether `play` has ended (the run won or failed).
    static func ended(_ play: Play) -> Bool { play.stage == .won || play.stage == .failed }

    /// The step after `action` was applied to `play` (which it mutates): an accepted phase change (not the run) and
    /// the play's real end.
    static func step(_ step: Step, applying action: Action, to play: inout Play) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        return step.advanced(afterChange: action != .run, ended: ended(play))
    }

    /// The step after an undo or a redo: no accepted phase change and the play's real end.
    static func stepAfterHistory(_ step: Step, _ play: Play) -> Step {
        step.advanced(afterChange: false, ended: ended(play))
    }

    /// The stored witness of level `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> Witness {
        let name: String = String(CelestialEclipseLabGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: progressWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(Witness.self, from: data)
    }

    /// The opening play of level `number` and its witness's phase changes (the witness's actions without the run).
    static func opening(_ number: Int) throws -> (play: Play, changes: [Action]) {
        let play: Play = try Core.opening(number: number).play
        var changes: [Action] = []
        for action in try witness(number).actions where action != .run { changes.append(action) }
        return (play, changes)
    }

    /// Records a win in `progress` (outside `#expect`, which cannot mutate) and returns whether the result changed.
    static func record(_ progress: inout Progress, level: Int, actionsSpent: Int, certified: Int,
                       mode: Mode = .campaign) -> Bool {
        progress.record(level: level, actionsSpent: actionsSpent, certified: certified, mode: mode)
    }

    // MARK: Tutorial

    @Test func tutorialTextsAreClarificationQ2() {
        #expect(Step.phase.text == "Drag a planet along its orbit (or use Phase − and + and Set phase) to change when "
            + "it passes the others; the timeline below the sky shows the eclipses that would follow")
        #expect(Step.order.text == "Make the target eclipses happen in order, each inside its bracket, then press Run "
            + "— a hint shows which planet to move")
        #expect(Step.recover.text == "Any other eclipse first, or a target outside its window, fails the run: undo and "
            + "change a phase")
        #expect(Step.done.text.isEmpty)
        #expect(Step.initial(tutorial: true) == .phase && Step.initial(tutorial: false) == .done)
        for level in 1...100 {
            let expected: Step = level <= 3 ? .phase : .done
            #expect(Step.initial(level: level) == expected)
        }
        for step in Step.allCases { #expect(step.dismissed() == .done) }
    }

    @Test func tutorialAdvancesInOrderNeverBack() {
        #expect(Step.phase.advanced(afterChange: true, ended: false) == .order)
        #expect(Step.phase.advanced(afterChange: false, ended: false) == .phase)
        #expect(Step.order.advanced(afterChange: true, ended: false) == .recover)
        #expect(Step.order.advanced(afterChange: false, ended: false) == .order)
        #expect(Step.recover.advanced(afterChange: true, ended: false) == .recover)
        #expect(Step.recover.advanced(afterChange: false, ended: false) == .recover)
        #expect(Step.done.advanced(afterChange: true, ended: false) == .done)
        #expect(Step.done.advanced(afterChange: false, ended: false) == .done)
        for step in Step.allCases {
            #expect(step.advanced(afterChange: false, ended: true) == .done)
            #expect(step.advanced(afterChange: true, ended: true) == .done)
        }
    }

    @Test func seededFlagWalksNeverMoveBack() {
        let order: [Step] = [.phase, .order, .recover, .done]
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var reachedDone: Int = 0
        var reachedRecover: Int = 0
        for _ in 0..<500 {
            var step: Step = .phase
            for _ in 0..<12 {
                let afterChange: Bool = random.int(0...1) == 1
                let ended: Bool = random.int(0...7) == 0
                let next: Step = step.advanced(afterChange: afterChange, ended: ended)
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
        let expectedChanges: [Int] = [2, 1, 2]
        for number in 1...3 {
            let opening: (play: Play, changes: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            #expect(play.level.tutorial)
            #expect(play.stage == .playing)
            #expect(opening.changes.count == expectedChanges[number - 1])
            var step: Step = Step.initial(level: number)
            #expect(step == .phase)
            for (index, action) in opening.changes.enumerated() {
                step = try Self.step(step, applying: action, to: &play)
                #expect(play.stage == .playing)
                let expected: Step = index == 0 ? .order : .recover
                #expect(step == expected)
            }
            step = try Self.step(step, applying: .run, to: &play)
            #expect(play.stage == .won)
            #expect(step == .done)
            #expect(Progress.actionsSpent(play) == opening.changes.count)
            let stars: Int = Progress.stars(actionsSpent: Progress.actionsSpent(play),
                                            certified: opening.changes.count)
            #expect(stars == 3)
        }
    }

    @Test func tutorialDetourNeverMovesBack() throws {
        for number in 1...3 {
            let opening: (play: Play, changes: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            var step: Step = .phase
            // A detour: the witness's first change accepted, undone, redone and undone again.
            step = try Self.step(step, applying: opening.changes[0], to: &play)
            #expect(play.stage == .playing && step == .order)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .order)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .order)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .order)
            for action in opening.changes {
                step = try Self.step(step, applying: action, to: &play)
                #expect(step == .recover)
            }
            step = try Self.step(step, applying: .run, to: &play)
            #expect(play.stage == .won && step == .done)
            // Every accepted phase-change record counts, the undone one included; the redo spends nothing new.
            #expect(Progress.actionsSpent(play) == opening.changes.count + 1)
            #expect(play.actionsSpent == opening.changes.count)
        }
    }

    @Test func failedRunEndsTheTutorialAndRedoOfAFailureEndsIt() throws {
        for number in 1...3 {
            let opening: (play: Play, changes: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            // A level never starts won, so running the clock at once fails it.
            var step: Step = try Self.step(.phase, applying: .run, to: &play)
            #expect(play.stage == .failed)
            #expect(play.failure != nil)
            #expect(step == .done)
            // An undo lands before the end: a fresh tutorial at `recover` stays there.
            try play.undo()
            step = Self.stepAfterHistory(.recover, play)
            #expect(play.stage == .playing && step == .recover)
            // A redo that restores the failed run ends it.
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .failed && step == .done)
            #expect(Progress.actionsSpent(play) == 0)
            // A change first, then a failing run: phase → order → done.
            var other: Play = opening.play
            var walk: Step = try Self.step(.phase, applying: opening.changes[0], to: &other)
            #expect(walk == .order)
            if opening.changes.count > 1 {
                walk = try Self.step(walk, applying: .run, to: &other)
                #expect(other.stage == .failed && walk == .done)
                #expect(Progress.actionsSpent(other) == 1)
            }
        }
    }

    // MARK: Stars and actions

    @Test func starThresholds() {
        for certified in 0...5 {
            for spent in 0...24 {
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
        let opening: (play: Play, changes: [Action]) = try Self.opening(1)
        var play: Play = opening.play
        #expect(Progress.actionsSpent(play) == 0)
        try play.apply(opening.changes[0], expecting: play.fingerprint)
        try play.undo()
        try play.apply(opening.changes[0], expecting: play.fingerprint)
        #expect(play.actionsSpent == 1)
        #expect(Progress.actionsSpent(play) == 2)
        for index in 1..<opening.changes.count {
            try play.apply(opening.changes[index], expecting: play.fingerprint)
        }
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .won)
        let spent: Int = Progress.actionsSpent(play)
        #expect(spent == opening.changes.count + 1)
        #expect(Progress.stars(actionsSpent: spent, certified: opening.changes.count) == 2)
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
            let certified: Int = level % 5 + 1
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
            let certified: Int = level % 5 + 1
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
        #expect(Progress.band(of: 1) == 1 && Progress.band(of: 20) == 1 && Progress.band(of: 21) == 2)
        #expect(Progress.band(of: 100) == 5 && Progress.band(of: 0) == 1 && Progress.band(of: 200) == 5)
    }

    @Test func modesRecordAndOpen() {
        var progress: Progress = Progress()
        #expect(!Self.record(&progress, level: 1, actionsSpent: 2, certified: 2, mode: .practice))
        #expect(progress.best(1) == nil && progress.frontier == 1)
        #expect(Self.record(&progress, level: 50, actionsSpent: 4, certified: 3, mode: .daily(level: 50)))
        #expect(progress.best(50) == 4 && progress.stars(of: 50) == 2 && progress.frontier == 1)
        #expect(!progress.isOpen(50))
        #expect(Self.record(&progress, level: 1, actionsSpent: 2, certified: 2, mode: .campaign))
        #expect(progress.frontier == 2 && progress.nextOpen(after: 1) == 2)
        progress.open(through: 7)
        #expect(progress.frontier == 7)
        progress.open(through: 3)
        #expect(progress.frontier == 7)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 24 && Mode.practiceBudget == CelestialEclipseLabLevel.budgets.upperBound)
        #expect(Mode.practice.budget(base: 9) == 24 && Mode.campaign.budget(base: 9) == 9)
        #expect(Mode.daily(level: 3).budget(base: 11) == 11)
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 1).awardsStars && !Mode.practice.awardsStars)
        #expect(Mode.campaign.opensLevels && !Mode.daily(level: 1).opensLevels && !Mode.practice.opensLevels)
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
                    #expect(value == (days * 29) % 100 + 1)
                    counts[min(max(value, 0), 100)] += 1
                    days += 1
                }
            }
        }
        #expect(days == 4_018)
        for level in 1...100 { #expect(counts[level] >= 40) }
        #expect(Progress.dailyMultiplier == 29)
        // Known values computed independently (Python `datetime.date` differences from 2026-01-01, × 29 mod 100 + 1).
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 2) == 30)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 5) == 17)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 1) == 100)
        #expect(Progress.dailyLevel(year: 2026, month: 11, day: 25) == 13)
        #expect(Progress.dailyLevel(year: 2027, month: 1, day: 1) == 86)
        #expect(Progress.dailyLevel(year: 2036, month: 12, day: 31) == 94)
        #expect(Progress.daysFromEpoch(year: 2036, month: 12, day: 31) == 4_017)
    }

    @Test func hundredConsecutiveDaysVisitEveryLevelOnce() {
        let starts: [(Int, Int, Int)] = [(2026, 1, 1), (2026, 11, 25), (2028, 2, 10), (2031, 12, 1)]
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
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 72)
        #expect(Progress.daysFromEpoch(year: 2025, month: 1, day: 1) == -365)
        #expect(Progress.dailyLevel(year: 2025, month: 1, day: 1) == 16)
        #expect(Progress.daysFromEpoch(year: 2000, month: 2, day: 29) == -9_438)
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) == 99)
        for year in [1, 1600, 1900, 2000, 2024] {
            for month in [1, 2, 7, 12] {
                let level: Int = Progress.dailyLevel(year: year, month: month, day: 28) ?? 0
                let days: Int = Progress.daysFromEpoch(year: year, month: month, day: 28) ?? 0
                #expect(days < 0)
                #expect(level >= 1 && level <= 100)
                #expect(level == ((days * 29) % 100 + 100) % 100 + 1)
            }
        }
    }

    @Test func impossibleDaysAreNilAndLeapYears() {
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(Progress.dailyLevel(year: 2027, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2024, month: 4, day: 31) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 32) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: -1) == nil)
        #expect(Progress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(Progress.daysFromEpoch(year: 2027, month: 2, day: 29) == nil)
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
        // Since feature 467 every result also writes its trace and whether it is verified.
        #expect(text == "{\"frontier\":4,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,\"trace\":[],"
            + "\"verified\":false},{\"actionsSpent\":5,\"level\":3,\"stars\":2,\"trace\":[],\"verified\":false}]}")
        let empty: Progress = try decoder.decode(Progress.self, from: try Progress().encoded())
        #expect(empty == Progress())

        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 29), .daily(level: 100),
                             .replay(level: 1), .replay(level: 100)]
        for mode in modes {
            let modeData: Data = try encoder.encode(mode)
            #expect(try decoder.decode(Mode.self, from: modeData) == mode)
        }
        #expect(String(decoding: try encoder.encode(Mode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        #expect(String(decoding: try encoder.encode(Mode.campaign), as: UTF8.self) == "{\"mode\":\"campaign\"}")
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
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":4}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":-1,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3},"
                + "{\"actionsSpent\":2,\"level\":1,\"stars\":3}]}"
        ]
        for text in badProgress {
            #expect(throws: (any Error).self) { try decoder.decode(Progress.self, from: Data(text.utf8)) }
        }
        let badModes: [String] = [
            "{\"mode\":\"replay\"}",   // since feature 467 replay is a mode, but it needs a level in 1 … 100
            "{\"mode\":\"replay\",\"level\":101}",
            "{\"mode\":\"rewind\",\"level\":1}",
            "{\"mode\":\"daily\"}",
            "{\"mode\":\"daily\",\"level\":0}",
            "{\"mode\":\"daily\",\"level\":101}"
        ]
        for text in badModes {
            #expect(throws: (any Error).self) { try decoder.decode(Mode.self, from: Data(text.utf8)) }
        }
    }
}
