// EchoCartographerProgressTests — feature 405 (R02-G11-05) T-R02G1105-003 (FR-R02G1105-001, 004, 005; SC-R02G1105-001,
// 004; clarifications Q2, Q3, Q4). The tutorial steps on levels 1 … 3 by scripted plays of their witnesses (and a
// detour of misses, markers, undo and redo, which never move a step back); the star thresholds; the energy spent,
// undone records included; a 100-level progress script (frontier, best results, a better result replacing a worse
// one, daily and practice rules); every calendar day 2026-01-01 … 2036-12-31 mapping into 1 … 100, stably, and 100
// consecutive days visiting every level; impossible days refused; Codable round trips.
// Test data uses explicit types and plain loops (CI type-check rule).
@testable import EchoCartographerCore
import Foundation
import Testing

@Suite struct EchoCartographerProgressTests {
    typealias Step = EchoCartographerTutorialStep
    typealias Progress = EchoCartographerProgress
    typealias Mode = EchoCartographerMode
    typealias Play = EchoCartographerPlay
    typealias Action = EchoCartographerAction
    typealias Cell = EchoCartographerCell
    typealias Core = EchoCartographerExperienceCore

    /// The step after `action` was applied to `play` (which it mutates), from the play's own change.
    static func step(_ step: Step, applying action: Action,
                     to play: inout Play) throws(EchoCartographerError) -> Step {
        let locatedBefore: Int = play.located.count
        try play.apply(action, expecting: play.fingerprint)
        var afterPulse: Bool = false
        if case .pulse = action { afterPulse = true }
        let located: Bool = play.located.count > locatedBefore
        let ended: Bool = play.stage == .won || play.stage == .failed
        return step.advanced(afterPulse: afterPulse, located: located, ended: ended)
    }

    /// A cell of `level` not known to be a wall whose claim misses every beacon (no beacon within the tolerance).
    static func missCell(_ level: EchoCartographerLevel, knowledge: EchoCartographerKnowledge) -> Cell? {
        for y in 0..<level.chamber.height {
            for x in 0..<level.chamber.width {
                let cell: Cell = Cell(x: x, y: y)
                if knowledge[cell] == .wall { continue }
                if level.claim(cell, located: []) == .miss { return cell }
            }
        }
        return nil
    }

    /// Records a win in `progress` (outside `#expect`, which cannot mutate) and returns whether the result changed.
    static func record(_ progress: inout Progress, level: Int, energySpent: Int, certified: Int,
                       mode: Mode = .campaign) -> Bool {
        progress.record(level: level, energySpent: energySpent, certified: certified, mode: mode)
    }

    // MARK: Tutorial

    @Test func tutorialTextsAreClarificationQ2() {
        #expect(Step.pulse.text == "Tap a lit floor cell to send a pulse (or use the panel) — the echoes tell how far "
            + "each beacon is along the open floor")
        #expect(Step.narrow.text == "Drag markers onto cells where a beacon could be and pulse again to narrow them "
            + "down — a hint shows where")
        #expect(Step.claim.text == "Hold a cell to claim a beacon there; a miss costs energy — locate every beacon "
            + "before the energy runs out")
        #expect(Step.done.text.isEmpty)
        #expect(Step.initial(tutorial: true) == .pulse && Step.initial(tutorial: false) == .done)
        for level in 1...100 {
            let expected: Step = level <= 3 ? .pulse : .done
            #expect(Step.initial(level: level) == expected)
        }
        for step in Step.allCases { #expect(step.dismissed() == .done) }
    }

    @Test func tutorialAdvancesOneStepPerEventInOrder() {
        // pulse: only an accepted pulse moves it; a located beacon before any pulse leaves it.
        #expect(Step.pulse.advanced(afterPulse: true, located: false, ended: false) == .narrow)
        #expect(Step.pulse.advanced(afterPulse: false, located: true, ended: false) == .pulse)
        #expect(Step.pulse.advanced(afterPulse: false, located: false, ended: false) == .pulse)
        // narrow: only a located beacon moves it; a further pulse leaves it.
        #expect(Step.narrow.advanced(afterPulse: true, located: false, ended: false) == .narrow)
        #expect(Step.narrow.advanced(afterPulse: false, located: true, ended: false) == .claim)
        // claim lasts until the end; done is final.
        #expect(Step.claim.advanced(afterPulse: true, located: true, ended: false) == .claim)
        #expect(Step.done.advanced(afterPulse: true, located: true, ended: false) == .done)
        // The end of the level moves every step to done.
        for step in Step.allCases {
            #expect(step.advanced(afterPulse: false, located: false, ended: true) == .done)
            #expect(step.advanced(afterPulse: true, located: true, ended: true) == .done)
        }
        // Never back: every step's successor is at or after it.
        let order: [Step] = [.pulse, .narrow, .claim, .done]
        for (position, step) in order.enumerated() {
            for flags in 0..<8 {
                let next: Step = step.advanced(afterPulse: flags & 1 != 0, located: flags & 2 != 0,
                                               ended: flags & 4 != 0)
                let nextPosition: Int = order.firstIndex(of: next) ?? -1
                #expect(nextPosition >= position)
            }
        }
    }

    @Test func tutorialLevelsWitnessPlaysWalkTheSteps() throws {
        for number in 1...3 {
            let generated: EchoCartographerGenerated = try Core.generated(number: number)
            let level: EchoCartographerLevel = generated.level
            #expect(level.tutorial)
            var play: Play = try Core.freshPlay(of: level)
            var step: Step = Step.initial(tutorial: level.tutorial)
            #expect(step == .pulse)
            var seen: [Step] = [step]
            for action in generated.actions {
                step = try Self.step(step, applying: action, to: &play)
                if seen.last != step { seen.append(step) }
            }
            #expect(play.stage == .won)
            #expect(step == .done)
            // The witness pulses first, then claims: pulse → narrow → (claim when a claim does not already win) → done.
            #expect(seen.first == .pulse && seen.count >= 3)
            #expect(seen[1] == .narrow)
            if level.beacons.count > 1 {
                #expect(seen == [.pulse, .narrow, .claim, .done], "level \(number): \(seen)")
            } else {
                #expect(seen == [.pulse, .narrow, .done], "level \(number): \(seen)")
            }
        }
    }

    @Test func tutorialDetourNeverMovesBack() throws {
        for number in 1...3 {
            let generated: EchoCartographerGenerated = try Core.generated(number: number)
            let level: EchoCartographerLevel = generated.level
            let actions: [Action] = generated.actions
            var play: Play = try Core.freshPlay(of: level)
            var step: Step = .pulse
            // A missed claim before any pulse, then its undo: still pulse.
            if level.energy > level.missCost, let miss = Self.missCell(level, knowledge: play.knowledge) {
                step = try Self.step(step, applying: .claim(miss.x, miss.y), to: &play)
                #expect(step == .pulse)
                try play.undo()
                #expect(step.advanced(afterPulse: false, located: false, ended: false) == .pulse)
            }
            // A marker and its undo: still pulse.
            step = try Self.step(step, applying: .mark(level.entry.x, level.entry.y), to: &play)
            #expect(step == .pulse)
            try play.undo()
            // The first witness pulse, undone and redone: narrow throughout (undo never moves back).
            step = try Self.step(step, applying: actions[0], to: &play)
            #expect(step == .narrow)
            try play.undo()
            step = step.advanced(afterPulse: false, located: false, ended: false)
            #expect(step == .narrow)
            try play.redo()
            step = step.advanced(afterPulse: false, located: false, ended: false)
            #expect(step == .narrow)
            // The rest of the witness wins; a located beacon is undone and redone on a multi-beacon level.
            for index in 1..<actions.count {
                step = try Self.step(step, applying: actions[index], to: &play)
                if play.stage == .playing && step == .claim {
                    try play.undo()
                    step = step.advanced(afterPulse: false, located: false, ended: false)
                    #expect(step == .claim)
                    try play.redo()
                }
            }
            #expect(play.stage == .won && step == .done)
        }
    }

    // MARK: Stars and energy

    @Test func starThresholds() {
        for certified in 0...8 {
            for spent in 0...(certified + 6) {
                let stars: Int = Progress.stars(energySpent: spent, certified: certified)
                let expected: Int = spent <= certified ? 3 : (spent <= certified + 2 ? 2 : 1)
                #expect(stars == expected)
            }
            #expect(Progress.stars(energySpent: certified, certified: certified) == 3)
            #expect(Progress.stars(energySpent: certified + 1, certified: certified) == 2)
            #expect(Progress.stars(energySpent: certified + 2, certified: certified) == 2)
            #expect(Progress.stars(energySpent: certified + 3, certified: certified) == 1)
        }
    }

    @Test func witnessEnergyIsTheCertifiedPulseCount() throws {
        for number in 1...3 {
            let generated: EchoCartographerGenerated = try Core.generated(number: number)
            var play: Play = try Core.freshPlay(of: generated.level)
            for action in generated.actions { try play.apply(action, expecting: play.fingerprint) }
            let spent: Int = Progress.energySpent(play)
            #expect(spent == generated.plan.pulses.count)
            #expect(spent == generated.level.energy - play.energy)
            #expect(Progress.stars(energySpent: spent, certified: generated.plan.pulses.count) == 3)
        }
    }

    @Test func energySpentCountsUndoneRecords() throws {
        // The hand level: entry (0, 0), beacons (2, 2) and (6, 0), tolerance 1, energy 6, a miss costs 2.
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var play: Play = try Core.freshPlay(of: level)
        #expect(Progress.energySpent(play) == 0)
        try play.apply(.pulse(0, 0), expecting: play.fingerprint)
        #expect(Progress.energySpent(play) == 1)
        try play.apply(.mark(3, 3), expecting: play.fingerprint)
        #expect(Progress.energySpent(play) == 1)
        try play.apply(.claim(2, 0), expecting: play.fingerprint)   // a miss: 2
        #expect(Progress.energySpent(play) == 3)
        try play.undo()
        try play.undo()
        try play.undo()                                              // everything undone: energy back to 6
        #expect(play.energy == level.energy)
        #expect(Progress.energySpent(play) == 3)
        try play.redo()                                              // a redo spends nothing new
        #expect(Progress.energySpent(play) == 3)
        try play.apply(.claim(2, 2), expecting: play.fingerprint)   // a hit: 0
        #expect(Progress.energySpent(play) == 3)
        // A pause between actions changes nothing.
        try play.handle(.pause)
        try play.handle(.resume)
        try play.apply(.pulse(0, 0), expecting: play.fingerprint)
        #expect(Progress.energySpent(play) == 4)
        try play.apply(.claim(6, 0), expecting: play.fingerprint)
        #expect(play.stage == .won)
        #expect(Progress.energySpent(play) == 4)
        // A miss capped by the energy left counts what it took: energy 1, a miss costs 2.
        let tight: EchoCartographerLevel = EchoCartographerFixtures.handLevel(energy: 2, missCost: 2)
        var short: Play = try Core.freshPlay(of: tight)
        try short.apply(.pulse(0, 0), expecting: short.fingerprint)
        try short.apply(.claim(2, 0), expecting: short.fingerprint)
        #expect(short.stage == .failed)
        #expect(Progress.energySpent(short) == 2)
    }

    // MARK: Progress

    @Test func hundredLevelScript() {
        var progress: Progress = Progress()
        #expect(progress.frontier == 1 && progress.solved.isEmpty)
        #expect(progress.isOpen(1) && !progress.isOpen(2) && !progress.isOpen(0) && !progress.isOpen(101))
        #expect(progress.nextOpen(after: 1) == nil)
        for level in 1...100 {
            #expect(progress.isOpen(level))
            #expect(!progress.isOpen(level + 1) || level == 100)
            let certified: Int = level % 6 + 1
            // A first, poor win: 1 star; it opens the next level.
            #expect(Self.record(&progress, level: level, energySpent: certified + 4, certified: certified) == true)
            #expect(progress.solved[level] == Progress.Result(energySpent: certified + 4, stars: 1))
            #expect(progress.frontier == min(level + 1, 100))
            // A worse result keeps the stored one.
            #expect(Self.record(&progress, level: level, energySpent: certified + 5, certified: certified) == false)
            #expect(progress.solved[level]?.energySpent == certified + 4)
            // A better result replaces it: 2 stars, then 3.
            #expect(Self.record(&progress, level: level, energySpent: certified + 2, certified: certified) == true)
            #expect(progress.solved[level]?.stars == 2)
            #expect(Self.record(&progress, level: level, energySpent: certified, certified: certified) == true)
            #expect(progress.solved[level] == Progress.Result(energySpent: certified, stars: 3))
            // An equal result keeps it.
            #expect(Self.record(&progress, level: level, energySpent: certified, certified: certified) == false)
            if level < 100 { #expect(progress.nextOpen(after: level) == level + 1) }
        }
        #expect(progress.frontier == 100 && progress.solved.count == 100)
        #expect(progress.nextOpen(after: 100) == nil)
        // Levels outside 1 … 100 are ignored; the frontier never falls.
        #expect(Self.record(&progress, level: 0, energySpent: 1, certified: 1) == false)
        #expect(Self.record(&progress, level: 101, energySpent: 1, certified: 1) == false)
        progress.open(through: 3)
        #expect(progress.frontier == 100)
        // Bands of 20.
        for level in 1...100 { #expect(Progress.band(of: level) == (level - 1) / 20 + 1) }
        #expect(Progress.band(of: 0) == 1 && Progress.band(of: 500) == 5)
    }

    @Test func modesRecordAndOpen() {
        var progress: Progress = Progress()
        // Practice records nothing and opens nothing.
        #expect(Self.record(&progress, level: 1, energySpent: 1, certified: 3, mode: .practice) == false)
        #expect(progress.solved.isEmpty && progress.frontier == 1)
        // A daily win on a locked level records its result without opening anything.
        #expect(Self.record(&progress, level: 42, energySpent: 4, certified: 3, mode: .daily(level: 42)) == true)
        #expect(progress.solved[42] == Progress.Result(energySpent: 4, stars: 2))
        #expect(progress.frontier == 1 && !progress.isOpen(42))
        // A campaign win opens the next level.
        #expect(Self.record(&progress, level: 1, energySpent: 3, certified: 3, mode: .campaign) == true)
        #expect(progress.frontier == 2)
        // open(through:) raises, clamps and never lowers.
        progress.open(through: 10)
        #expect(progress.frontier == 10)
        progress.open(through: 5)
        #expect(progress.frontier == 10)
        progress.open(through: 400)
        #expect(progress.frontier == 100)
        // Mode rules and energy.
        #expect(Mode.practiceEnergy == 60)
        #expect(Mode.practice.energy(base: 12) == 60)
        #expect(Mode.campaign.energy(base: 12) == 12 && Mode.daily(level: 3).energy(base: 12) == 12)
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 1).awardsStars && !Mode.practice.awardsStars)
        #expect(Mode.campaign.opensLevels && !Mode.daily(level: 1).opensLevels && !Mode.practice.opensLevels)
    }

    // MARK: Daily level

    @Test func dailyLevelOverElevenYears() {
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 2) == 80)
        #expect(Progress.dailyLevel(year: 2025, month: 12, day: 31) == 22)   // day −1: (−79 mod 100) + 1
        var counts: [Int] = Array(repeating: 0, count: 101)
        var window: [Int] = []
        var dayIndex: Int = 0
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...Progress.daysIn(month: month, year: year) {
                    guard let level = Progress.dailyLevel(year: year, month: month, day: day) else {
                        Issue.record("\(year)-\(month)-\(day) has no daily level")
                        continue
                    }
                    #expect(level >= 1 && level <= 100)
                    #expect(Progress.dailyLevel(year: year, month: month, day: day) == level)
                    #expect(level == (dayIndex * 79) % 100 + 1)
                    counts[level] += 1
                    if dayIndex < 100 { window.append(level) }
                    dayIndex += 1
                }
            }
        }
        #expect(dayIndex == 4_018)
        // 100 consecutive days visit every level once.
        #expect(Set(window).count == 100)
        for level in 1...100 { #expect(counts[level] >= 40) }
        // Negative day counts wrap into 1 … 100 and 100 consecutive days before the epoch visit every level too.
        var before: Set<Int> = []
        for day in 1...31 {
            if let level = Progress.dailyLevel(year: 2025, month: 12, day: day) { before.insert(level) }
        }
        for day in 1...30 {
            if let level = Progress.dailyLevel(year: 2025, month: 11, day: day) { before.insert(level) }
        }
        for day in 1...31 {
            if let level = Progress.dailyLevel(year: 2025, month: 10, day: day) { before.insert(level) }
        }
        for day in 24...30 {
            if let level = Progress.dailyLevel(year: 2025, month: 9, day: day) { before.insert(level) }
        }
        #expect(before.count == 99)   // 99 days 2025-09-24 … 2025-12-31
        let early: Int? = Progress.dailyLevel(year: 1, month: 1, day: 1)
        #expect(early != nil && (early ?? 0) >= 1 && (early ?? 0) <= 100)
    }

    @Test func impossibleDaysAreNil() {
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 2, day: 29) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 1, day: 32) == nil)
        #expect(Progress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(Progress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(Progress.dailyLevel(year: 2028, month: 2, day: 29) != nil)   // leap year
        #expect(Progress.dailyLevel(year: 2100, month: 2, day: 29) == nil)   // century, not leap
        #expect(Progress.dailyLevel(year: 2000, month: 2, day: 29) != nil)   // divisible by 400
    }

    // MARK: Codable

    @Test func codableRoundTrips() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder: JSONDecoder = JSONDecoder()
        for step in Step.allCases {
            let data: Data = try encoder.encode(step)
            #expect(try decoder.decode(Step.self, from: data) == step)
            #expect(String(decoding: data, as: UTF8.self) == "\"" + step.rawValue + "\"")
        }
        let modes: [Mode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
        for mode in modes {
            let data: Data = try encoder.encode(mode)
            #expect(try decoder.decode(Mode.self, from: data) == mode)
        }
        #expect(String(decoding: try encoder.encode(Mode.daily(level: 7)), as: UTF8.self)
            == "{\"level\":7,\"mode\":\"daily\"}")
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"daily\"}", "{\"mode\":\"replay\"}"]
        for text in badModes {
            #expect(throws: DecodingError.self) { try decoder.decode(Mode.self, from: Data(text.utf8)) }
        }
        var progress: Progress = Progress()
        for level in 1...30 {
            progress.record(level: level, energySpent: level % 7 + 1, certified: 3)
        }
        progress.record(level: 77, energySpent: 9, certified: 3, mode: .daily(level: 77))
        let data: Data = try progress.encoded()
        let decoded: Progress = try decoder.decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        #expect(String(decoding: try Progress().encoded(), as: UTF8.self) == "{\"frontier\":1,\"solved\":[]}")
        let badProgress: [String] = ["{\"frontier\":0,\"solved\":[]}",
                                     "{\"frontier\":101,\"solved\":[]}",
                                     "{\"frontier\":1,\"solved\":[{\"level\":0,\"energySpent\":1,\"stars\":3}]}",
                                     "{\"frontier\":1,\"solved\":[{\"level\":1,\"energySpent\":1,\"stars\":4}]}",
                                     "{\"frontier\":1,\"solved\":[{\"level\":1,\"energySpent\":-1,\"stars\":3}]}",
                                     "{\"frontier\":2,\"solved\":[{\"level\":1,\"energySpent\":1,\"stars\":3},"
                                         + "{\"level\":1,\"energySpent\":2,\"stars\":3}]}"]
        for text in badProgress {
            #expect(throws: DecodingError.self) { try decoder.decode(Progress.self, from: Data(text.utf8)) }
        }
    }
}
