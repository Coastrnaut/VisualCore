// MicroscopicAuroraProgressTests — feature 485 (R02-G19-05) T-R02G1905-003 (FR-R02G1905-001, 004, 005;
// SC-R02G1905-001, 004; clarifications Q2, Q3, Q4). The tutorial steps on levels 1 … 3 by scripted plays of their
// stored witnesses (`docs/games/microscopic-aurora/levels/00N.witness.json`: one placement each, then the play) applied
// to the opening play through the real kernel (place → cover → done on the winning play), a strength detour before the
// witness placement (place → cover → recover → done, two stars), a removal detour, an undo and redo detour that never
// moves a step back, a failed play ending the tutorial and a redo that restores a failed play ending it; 500 seeded
// (SeededRandom seed 2_485) flag walks that never move a step back; the star thresholds at their edges; the actions
// spent, undone records included; a 100-level progress script (frontier, best results, a worse replay not replacing a
// better one, daily and practice rules); every calendar day 2026-01-01 … 2036-12-31 mapping into 1 … 100, stably,
// against an independent day count, with known values computed outside the code under test, and 100 consecutive days
// visiting every level once; negative day counts wrapped; impossible days nil, leap years included; Codable round
// trips with the stable JSON shape. Ported from feature 475's ApsidesWorkshopProgressTests. Test data uses explicit
// types and plain loops (CI type-check rule); each test well under 3 s. No clock: dates are inputs. Dismissal is the
// adapter's and is tested there; only the step logic is tested here.
// Feature 487 (R02-G19-07) T-R02G1907-002 (FR-R02G1907-001, 002, 003; clarifications Q1, Q2, Q3): each result carries
// its trace and verified flag in the stable JSON shape; a traced record stores a verified result and replaces only a
// worse one (a tie keeps the earlier trace); `drop(level:)` removes a result and keeps the frontier; payloads without
// trace or verified (snapshot schema 1 and 2) decode as unverified results with an empty trace; the replay mode encodes
// as `{"level":n,"mode":"replay"}`, keeps the campaign budget, awards no stars and opens nothing.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, MicroscopicAurora, the
/// package, Packages).
private let progressWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/microscopic-aurora/levels", isDirectory: true)

@Suite struct MicroscopicAuroraProgressTests {
    typealias Step = MicroscopicAuroraTutorialStep
    typealias Progress = MicroscopicAuroraProgress
    typealias Mode = MicroscopicAuroraMode
    typealias Play = MicroscopicAuroraPlay
    typealias Action = MicroscopicAuroraAction
    typealias Well = MicroscopicAuroraWell
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Witness = MicroscopicAuroraWitness

    /// The seed of the seeded flag walks.
    static let seed: UInt64 = 2_485

    /// Whether `play` has ended (the swim won or failed).
    static func ended(_ play: Play) -> Bool { play.stage == .won || play.stage == .failed }

    /// Whether `action` is a placement.
    static func isPlacement(_ action: Action) -> Bool {
        if case .place = action { return true }
        return false
    }

    /// The step after `action` was applied to `play` (which it mutates): an accepted placement or removal (not the
    /// play), whether it was a placement, and the play's real end.
    static func step(_ step: Step, applying action: Action, to play: inout Play) throws -> Step {
        try play.apply(action, expecting: play.fingerprint)
        return step.advanced(afterAction: action != .play, placement: isPlacement(action), ended: ended(play))
    }

    /// The step after an undo or a redo: no accepted action and the play's real end.
    static func stepAfterHistory(_ step: Step, _ play: Play) -> Step {
        step.advanced(afterAction: false, placement: false, ended: ended(play))
    }

    /// The stored witness of level `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> Witness {
        let name: String = String(MicroscopicAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: progressWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(Witness.self, from: data)
    }

    /// The opening play of level `number` and its witness's placements (the witness's actions without the play).
    static func opening(_ number: Int) throws -> (play: Play, placements: [Action]) {
        let play: Play = try Core.opening(number: number).play
        var placements: [Action] = []
        for action in try witness(number).actions where action != .play { placements.append(action) }
        return (play, placements)
    }

    /// The first witness placement's slot and well.
    static func firstPlacement(_ placements: [Action]) -> (slot: Int, well: Well)? {
        guard let first = placements.first, case .place(let slot, let well) = first else { return nil }
        return (slot, well)
    }

    /// The same well with another strength (a detour placement on the same site).
    static func otherStrength(_ well: Well) -> Well {
        Well(cell: well.cell, strength: well.strength == 1 ? 2 : 1, sense: well.sense)
    }

    /// Records a win in `progress` (outside `#expect`, which cannot mutate) and returns whether the result changed.
    static func record(_ progress: inout Progress, level: Int, actionsSpent: Int, certified: Int,
                       mode: Mode = .campaign) -> Bool {
        progress.record(level: level, actionsSpent: actionsSpent, certified: certified, mode: mode)
    }

    // MARK: Tutorial

    @Test func tutorialTextsAreClarificationQ2() {
        #expect(Step.place.text == "Tap a marked site (or choose a site and press Place) to put a magnetic well "
            + "there; the trails and gauges show the new swim")
        #expect(Step.cover.text == "Light every stencil cell with the trails as one joined pattern, then press Play "
            + "— a hint shows which site to use")
        #expect(Step.recover.text == "A swimmer leaving the dish, the swarm splitting, too few lit cells or a lit "
            + "cell cut off from the pattern fails the swim: undo and try another well")
        #expect(Step.done.text.isEmpty)
        #expect(Step.place.rawValue == "place" && Step.cover.rawValue == "cover")
        #expect(Step.recover.rawValue == "recover" && Step.done.rawValue == "done")
        #expect(Step.initial(tutorial: true) == .place && Step.initial(tutorial: false) == .done)
        for level in 1...100 {
            let expected: Step = level <= 3 ? .place : .done
            #expect(Step.initial(level: level) == expected)
        }
        for step in Step.allCases { #expect(step.dismissed() == .done) }
    }

    @Test func tutorialAdvancesInOrderNeverBack() {
        #expect(Step.place.advanced(afterAction: true, placement: true, ended: false) == .cover)
        #expect(Step.place.advanced(afterAction: true, placement: false, ended: false) == .place)
        #expect(Step.place.advanced(afterAction: false, placement: true, ended: false) == .place)
        #expect(Step.place.advanced(afterAction: false, placement: false, ended: false) == .place)
        #expect(Step.cover.advanced(afterAction: true, placement: true, ended: false) == .recover)
        #expect(Step.cover.advanced(afterAction: true, placement: false, ended: false) == .recover)
        #expect(Step.cover.advanced(afterAction: false, placement: false, ended: false) == .cover)
        #expect(Step.cover.advanced(afterAction: false, placement: true, ended: false) == .cover)
        for flags in 0..<4 {
            let afterAction: Bool = flags & 1 == 1
            let placement: Bool = flags & 2 == 2
            #expect(Step.recover.advanced(afterAction: afterAction, placement: placement, ended: false) == .recover)
            #expect(Step.done.advanced(afterAction: afterAction, placement: placement, ended: false) == .done)
            for step in Step.allCases {
                #expect(step.advanced(afterAction: afterAction, placement: placement, ended: true) == .done)
            }
        }
    }

    @Test func seededFlagWalksNeverMoveBack() {
        let order: [Step] = [.place, .cover, .recover, .done]
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var reachedDone: Int = 0
        var reachedRecover: Int = 0
        for _ in 0..<500 {
            var step: Step = .place
            for _ in 0..<12 {
                let afterAction: Bool = random.int(0...1) == 1
                let placement: Bool = random.int(0...1) == 1
                let ended: Bool = random.int(0...7) == 0
                let next: Step = step.advanced(afterAction: afterAction, placement: placement, ended: ended)
                let before: Int = order.firstIndex(of: step) ?? -1
                let after: Int = order.firstIndex(of: next) ?? -1
                #expect(after >= before)
                #expect(after <= before + 1 || next == .done)
                if step == .place && next == .cover { #expect(afterAction && placement) }
                if next == .recover { reachedRecover += 1 }
                step = next
            }
            if step == .done { reachedDone += 1 }
        }
        #expect(reachedDone > 0 && reachedRecover > 0)
    }

    @Test func tutorialLevelsWitnessPlaysWalkTheSteps() throws {
        for number in 1...3 {
            let opening: (play: Play, placements: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            #expect(play.level.tutorial)
            #expect(play.stage == .playing)
            #expect(!opening.placements.isEmpty)
            var step: Step = Step.initial(level: number)
            #expect(step == .place)
            for (index, action) in opening.placements.enumerated() {
                step = try Self.step(step, applying: action, to: &play)
                #expect(play.stage == .playing)
                let expected: Step = index == 0 ? .cover : .recover
                #expect(step == expected)
            }
            step = try Self.step(step, applying: .play, to: &play)
            #expect(play.stage == .won)
            #expect(step == .done)
            #expect(Progress.actionsSpent(play) == opening.placements.count)
            let stars: Int = Progress.stars(actionsSpent: Progress.actionsSpent(play),
                                            certified: opening.placements.count)
            #expect(stars == 3)
        }
    }

    @Test func secondPlacementMovesCoverToRecover() throws {
        for number in 1...3 {
            let opening: (play: Play, placements: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            guard let first = Self.firstPlacement(opening.placements) else {
                Issue.record("level \(number) witness has no placement")
                continue
            }
            // The witness's site with another strength first: place → cover; the witness placement then → recover.
            var step: Step = try Self.step(.place, applying: .place(slot: first.slot,
                                                                     well: Self.otherStrength(first.well)),
                                           to: &play)
            #expect(play.stage == .playing && step == .cover)
            for action in opening.placements {
                step = try Self.step(step, applying: action, to: &play)
                #expect(play.stage == .playing && step == .recover)
            }
            step = try Self.step(step, applying: .play, to: &play)
            #expect(play.stage == .won && step == .done)
            let spent: Int = Progress.actionsSpent(play)
            #expect(spent == opening.placements.count + 1)
            #expect(Progress.stars(actionsSpent: spent, certified: opening.placements.count) == 2)
        }
    }

    @Test func removalMovesCoverToRecover() throws {
        for number in 1...3 {
            let opening: (play: Play, placements: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            guard let first = Self.firstPlacement(opening.placements) else {
                Issue.record("level \(number) witness has no placement")
                continue
            }
            // The witness placement, its removal (a removal is the second action: cover → recover), the placement
            // again and the play.
            var step: Step = try Self.step(.place, applying: opening.placements[0], to: &play)
            #expect(play.stage == .playing && step == .cover)
            step = try Self.step(step, applying: .remove(slot: first.slot), to: &play)
            #expect(play.stage == .playing && step == .recover)
            for action in opening.placements {
                step = try Self.step(step, applying: action, to: &play)
                #expect(play.stage == .playing && step == .recover)
            }
            step = try Self.step(step, applying: .play, to: &play)
            #expect(play.stage == .won && step == .done)
            let spent: Int = Progress.actionsSpent(play)
            #expect(spent == opening.placements.count + 2)
            #expect(Progress.stars(actionsSpent: spent, certified: opening.placements.count) == 2)
        }
    }

    @Test func tutorialDetourNeverMovesBack() throws {
        for number in 1...3 {
            let opening: (play: Play, placements: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            var step: Step = .place
            // A detour: the witness's first placement accepted, undone, redone and undone again.
            step = try Self.step(step, applying: opening.placements[0], to: &play)
            #expect(play.stage == .playing && step == .cover)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .cover)
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .cover)
            try play.undo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .playing && step == .cover)
            for action in opening.placements {
                step = try Self.step(step, applying: action, to: &play)
                #expect(step == .recover)
            }
            step = try Self.step(step, applying: .play, to: &play)
            #expect(play.stage == .won && step == .done)
            // Every accepted placement record counts, the undone one included; the redo spends nothing new.
            #expect(Progress.actionsSpent(play) == opening.placements.count + 1)
            #expect(play.actionsSpent == opening.placements.count)
        }
    }

    @Test func failedPlayEndsTheTutorialAndRedoOfAFailureEndsIt() throws {
        for number in 1...3 {
            let opening: (play: Play, placements: [Action]) = try Self.opening(number)
            var play: Play = opening.play
            // A level never starts won (its witness needs a placement), so playing the swim at once fails it.
            var step: Step = try Self.step(.place, applying: .play, to: &play)
            #expect(play.stage == .failed)
            #expect(play.failure != nil)
            #expect(step == .done)
            // An undo lands before the end: a fresh tutorial at `recover` stays there.
            try play.undo()
            step = Self.stepAfterHistory(.recover, play)
            #expect(play.stage == .playing && step == .recover)
            // A redo that restores the failed play ends it.
            try play.redo()
            step = Self.stepAfterHistory(step, play)
            #expect(play.stage == .failed && step == .done)
            #expect(Progress.actionsSpent(play) == 0)
            // A detour placement first, then the play: place → cover → done, whatever the play's outcome.
            var other: Play = opening.play
            guard let first = Self.firstPlacement(opening.placements) else {
                Issue.record("level \(number) witness has no placement")
                continue
            }
            var walk: Step = try Self.step(.place, applying: .place(slot: first.slot,
                                                                     well: Self.otherStrength(first.well)),
                                           to: &other)
            #expect(walk == .cover)
            walk = try Self.step(walk, applying: .play, to: &other)
            #expect(Self.ended(other) && walk == .done)
            #expect(Progress.actionsSpent(other) == 1)
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
        let opening: (play: Play, placements: [Action]) = try Self.opening(1)
        var play: Play = opening.play
        #expect(Progress.actionsSpent(play) == 0)
        try play.apply(opening.placements[0], expecting: play.fingerprint)
        try play.undo()
        try play.apply(opening.placements[0], expecting: play.fingerprint)
        #expect(play.actionsSpent == 1)
        #expect(Progress.actionsSpent(play) == 2)
        for index in opening.placements.indices.dropFirst() {
            try play.apply(opening.placements[index], expecting: play.fingerprint)
        }
        try play.apply(.play, expecting: play.fingerprint)
        #expect(play.stage == .won)
        let spent: Int = Progress.actionsSpent(play)
        #expect(spent == opening.placements.count + 1)
        #expect(Progress.stars(actionsSpent: spent, certified: opening.placements.count) == 2)
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
            let certified: Int = level % 2 + 1
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
            let certified: Int = level % 2 + 1
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
        #expect(Self.record(&progress, level: 1, actionsSpent: 2, certified: 2, mode: .campaign))
        #expect(progress.frontier == 2 && progress.nextOpen(after: 1) == 2)
        progress.open(through: 7)
        #expect(progress.frontier == 7)
        progress.open(through: 3)
        #expect(progress.frontier == 7)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        #expect(Mode.practiceBudget == 24 && Mode.practiceBudget == MicroscopicAuroraLevel.budgets.upperBound)
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
                    #expect(value == (days * 19) % 100 + 1)
                    counts[min(max(value, 0), 100)] += 1
                    days += 1
                }
            }
        }
        #expect(days == 4_018)
        for level in 1...100 { #expect(counts[level] >= 40) }
        #expect(Progress.dailyMultiplier == 19)
        // Known values computed independently (Python `datetime.date` differences from 2026-01-01, × 19 mod 100 + 1).
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 2) == 20)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 5) == 77)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 1) == 90)
        #expect(Progress.dailyLevel(year: 2026, month: 11, day: 26) == 52)
        #expect(Progress.dailyLevel(year: 2027, month: 1, day: 1) == 36)
        #expect(Progress.dailyLevel(year: 2036, month: 12, day: 31) == 24)
        #expect(Progress.daysFromEpoch(year: 2036, month: 12, day: 31) == 4_017)
    }

    @Test func hundredConsecutiveDaysVisitEveryLevelOnce() {
        let starts: [(Int, Int, Int)] = [(2026, 1, 1), (2026, 11, 26), (2028, 2, 10), (2031, 12, 1)]
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
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 82)
        #expect(Progress.daysFromEpoch(year: 2025, month: 1, day: 1) == -365)
        #expect(Progress.dailyLevel(year: 2025, month: 1, day: 1) == 66)
        #expect(Progress.daysFromEpoch(year: 2000, month: 2, day: 29) == -9_438)
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) == 79)
        for year in [1, 1600, 1900, 2000, 2024] {
            for month in [1, 2, 7, 12] {
                let level: Int = Progress.dailyLevel(year: year, month: month, day: 28) ?? 0
                let days: Int = Progress.daysFromEpoch(year: year, month: month, day: 28) ?? 0
                #expect(days < 0)
                #expect(level >= 1 && level <= 100)
                #expect(level == ((days * 19) % 100 + 100) % 100 + 1)
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
        progress.record(level: 3, actionsSpent: 4, certified: 2, opensNext: false)
        progress.record(level: 1, actionsSpent: 1, certified: 1)
        progress.open(through: 4)
        let data: Data = try progress.encoded()
        let decoded: Progress = try decoder.decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        // Since feature 487 each result also carries its trace and whether it is verified (empty and false here).
        #expect(text == "{\"frontier\":4,\"solved\":[{\"actionsSpent\":1,\"level\":1,\"stars\":3,\"trace\":[],"
            + "\"verified\":false},{\"actionsSpent\":4,\"level\":3,\"stars\":2,\"trace\":[],\"verified\":false}]}")
        let empty: Progress = try decoder.decode(Progress.self, from: try Progress().encoded())
        #expect(empty == Progress())
        #expect(String(decoding: try Progress().encoded(), as: UTF8.self) == "{\"frontier\":1,\"solved\":[]}")

        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 19), .daily(level: 100),
                             .replay(level: 1), .replay(level: 100)]
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
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":4}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":0}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":-1,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3},"
                + "{\"actionsSpent\":2,\"level\":1,\"stars\":3}]}"
        ]
        for text in badProgress {
            #expect(throws: (any Error).self) { try decoder.decode(Progress.self, from: Data(text.utf8)) }
        }
        let badModes: [String] = [
            // Since feature 487 `replay` is a mode; it needs a level in 1 … 100.
            "{\"mode\":\"replay\"}",
            "{\"mode\":\"replay\",\"level\":0}",
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

    // MARK: Traces (feature 487)

    /// A trace of `placements` placements (on slot 0, alternating strengths on the cell at row and column `cell`) and
    /// the play.
    static func trace(placements: Int, cell: Int) -> [Action] {
        var actions: [Action] = []
        for index in 0..<placements {
            let site: MicroscopicAuroraCell = MicroscopicAuroraCell(row: cell, column: cell)
            actions.append(.place(slot: 0, well: Well(cell: site, strength: index % 2 + 1, sense: .clockwise)))
        }
        actions.append(.play)
        return actions
    }

    @Test func tracedRecordKeepsTheBetterResultAndTiesKeepTheEarlierTrace() {
        var progress: Progress = Progress()
        let first: [Action] = Self.trace(placements: 3, cell: 10)
        let changed: Bool = progress.record(level: 4, actionsSpent: 3, certified: 2, trace: first)
        #expect(changed)
        #expect(progress.solved[4]?.trace == first && progress.solved[4]?.verified == true)
        #expect(progress.stars(of: 4) == 2 && progress.frontier == 5)
        // A tie (equal actions spent, equal stars) keeps the earlier trace; a worse result keeps it too.
        let tie: [Action] = Self.trace(placements: 3, cell: 11)
        let tied: Bool = progress.record(level: 4, actionsSpent: 3, certified: 2, trace: tie)
        #expect(!tied && progress.solved[4]?.trace == first)
        let worse: Bool = progress.record(level: 4, actionsSpent: 5, certified: 2, trace: tie)
        #expect(!worse && progress.solved[4]?.trace == first)
        // A better result replaces the trace.
        let better: [Action] = Self.trace(placements: 2, cell: 12)
        let improved: Bool = progress.record(level: 4, actionsSpent: 2, certified: 2, trace: better)
        #expect(improved && progress.solved[4]?.trace == better && progress.stars(of: 4) == 3)
        // An untraced better result replaces a traced one and is unverified.
        let untraced: Bool = progress.record(level: 4, actionsSpent: 1, certified: 2, opensNext: true)
        #expect(untraced && progress.solved[4]?.trace == [] && progress.solved[4]?.verified == false)
        // Practice and replay record nothing; daily records and opens nothing.
        let practised: Bool = progress.record(level: 9, actionsSpent: 1, certified: 1, mode: .practice, trace: better)
        let replayed: Bool = progress.record(level: 9, actionsSpent: 1, certified: 1, mode: .replay(level: 9),
                                             trace: better)
        #expect(!practised && !replayed && progress.solved[9] == nil)
        let daily: Bool = progress.record(level: 9, actionsSpent: 2, certified: 2, mode: .daily(level: 9),
                                          trace: better)
        #expect(daily && progress.solved[9]?.verified == true && progress.frontier == 5)
        let outside: Bool = progress.record(level: 101, actionsSpent: 1, certified: 1, trace: better)
        #expect(!outside)
    }

    @Test func dropRemovesAResultAndKeepsTheFrontier() {
        var progress: Progress = Progress()
        for level in 1...10 {
            progress.record(level: level, actionsSpent: 2, certified: 2, trace: Self.trace(placements: 2, cell: level))
        }
        #expect(progress.frontier == 11 && progress.solved.count == 10)
        progress.drop(level: 5)
        progress.drop(level: 50)
        #expect(progress.solved[5] == nil && progress.solved.count == 9 && progress.frontier == 11)
        #expect(progress.isOpen(5) && progress.isOpen(11))
    }

    @Test func tracedProgressRoundTripsAndOldPayloadsDecodeUnverified() throws {
        let decoder: JSONDecoder = JSONDecoder()
        var progress: Progress = Progress()
        let first: Well = Well(cell: MicroscopicAuroraCell(row: 2, column: 3), strength: 3, sense: .clockwise)
        let second: Well = Well(cell: MicroscopicAuroraCell(row: 4, column: 5), strength: 4, sense: .counterclockwise)
        let trace: [Action] = [.place(slot: 1, well: first), .remove(slot: 1), .place(slot: 0, well: second), .play]
        progress.record(level: 2, actionsSpent: 3, certified: 1, trace: trace)
        progress.record(level: 7, actionsSpent: 4, certified: 3, opensNext: false)
        let data: Data = try progress.encoded()
        let decoded: Progress = try decoder.decode(Progress.self, from: data)
        #expect(decoded == progress && decoded.solved[2]?.trace == trace && decoded.solved[2]?.verified == true)
        #expect(try decoded.encoded() == data)
        // Snapshot schema 1 and 2 entries carry neither trace nor verified.
        let old: String = "{\"frontier\":3,\"solved\":[{\"actionsSpent\":1,\"level\":1,\"stars\":3},"
            + "{\"actionsSpent\":5,\"level\":2,\"stars\":1}]}"
        let legacy: Progress = try decoder.decode(Progress.self, from: Data(old.utf8))
        #expect(legacy.frontier == 3 && legacy.solved.count == 2)
        for level in 1...2 {
            #expect(legacy.solved[level]?.trace == [] && legacy.solved[level]?.verified == false)
        }
        #expect(legacy.best(2) == 5 && legacy.stars(of: 2) == 1)
        let result: Progress.Result = try decoder.decode(Progress.Result.self,
                                                         from: Data("{\"actionsSpent\":2,\"stars\":2}".utf8))
        #expect(result == Progress.Result(actionsSpent: 2, stars: 2, trace: [], verified: false))
    }

    @Test func replayModeEncodesKeepsTheBudgetAndAwardsNothing() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder: JSONDecoder = JSONDecoder()
        for level in 1...100 {
            let mode: Mode = .replay(level: level)
            let data: Data = try encoder.encode(mode)
            #expect(String(decoding: data, as: UTF8.self) == "{\"level\":\(level),\"mode\":\"replay\"}")
            #expect(try decoder.decode(Mode.self, from: data) == mode)
            #expect(!mode.awardsStars && !mode.opensLevels && mode.budget(base: 7) == 7)
        }
        var progress: Progress = Progress()
        let changed: Bool = Self.record(&progress, level: 1, actionsSpent: 1, certified: 1, mode: .replay(level: 1))
        #expect(!changed && progress == Progress())
    }
}
