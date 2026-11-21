// HueCompassProgressTests — feature 335 (R02-G04-05) T-R02G0405-003 (FR-R02G0405-001, 004, 005; SC-R02G0405-001, 004;
// clarifications Q2–Q4). The tutorial scripts on levels 1 … 3 (following each instruction with the certified actions wins
// and shows aim → probe → select → done; a detour turn undone never moves the step back; dismiss; the same steps in every
// mode); scripted campaign progress through the 100 certified levels (the frontier opens in order, 3 stars at the
// smallest probe count + 1 units); the star table; better results replace worse ones (seeded, seed 2_335); practice
// records nothing and daily opens nothing; the daily level of every date 2026-01-01 … 2036-12-31 and of earlier dates,
// every level once per 100 consecutive days, impossible dates refused; all 100 levels reachable by progress alone;
// Codable round trips. The certified levels are read from the witness files in docs/games/hue-compass/levels/. Test data
// uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import HueCompassCore

/// The repository's witness directory, found from this file.
private let progressWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/hue-compass/levels", isDirectory: true)

/// The witness of certified level `number` (1 … 100), decoded (and so re-verified).
private func progressWitness(_ number: Int) throws -> HueCompassWitness {
    let name: String = String(format: "%03d", number) + ".witness.json"
    let data: Data = try Data(contentsOf: progressWitnessDirectory.appendingPathComponent(name))
    return try HueCompassWitness.decode(data)
}

@Suite struct HueCompassProgressTests {
    /// The test seed.
    static let seed: UInt64 = 2_335

    // MARK: Tutorial

    /// A begun play of `witness`'s level with its tutorial stage dismissed.
    func begunPlay(_ witness: HueCompassWitness) throws -> HueCompassPlay {
        var play: HueCompassPlay = HueCompassPlay(level: witness.level)
        try play.handle(.begin)
        if witness.level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The kind of `action`.
    func kind(_ action: HueCompassAction) -> HueCompassRecordKind {
        switch action {
        case .turn: .turn
        case .probe: .probe
        case .select: .select
        }
    }

    @Test func tutorialScriptsWinLevels1To3() throws {
        for number in 1...3 {
            let witness: HueCompassWitness = try progressWitness(number)
            #expect(witness.level.tutorial, "level \(number)")
            var play: HueCompassPlay = try begunPlay(witness)
            var step: HueCompassTutorialStep = HueCompassTutorialStep.initial(level: number)
            #expect(step == .aim)
            var shown: [HueCompassTutorialStep] = [step]
            for action in witness.actions {
                try play.apply(action, expecting: play.fingerprint)
                let next: HueCompassTutorialStep = step.after(kind(action), stage: play.stage)
                if next != step { shown.append(next) }
                step = next
            }
            #expect(play.stage == .won, "level \(number)")
            #expect(shown == [.aim, .probe, .select, .done], "level \(number)")
        }
    }

    @Test func tutorialDetourUndoNeverMovesBack() throws {
        // A turn shows the probe step; undoing it keeps the probe step; the certified actions then win.
        for number in 1...3 {
            let witness: HueCompassWitness = try progressWitness(number)
            var play: HueCompassPlay = try begunPlay(witness)
            var step: HueCompassTutorialStep = HueCompassTutorialStep.initial(level: number)
            var shown: [HueCompassTutorialStep] = [step]
            try play.apply(.turn(1), expecting: play.fingerprint)
            step = step.after(.turn, stage: play.stage)
            shown.append(step)
            try play.undo()
            step = step.after(.undo, stage: play.stage)
            #expect(step == .probe, "level \(number): undo never moves the step back")
            try play.redo()
            step = step.after(.redo, stage: play.stage)
            #expect(step == .probe, "level \(number)")
            try play.undo()
            for action in witness.actions {
                try play.apply(action, expecting: play.fingerprint)
                let next: HueCompassTutorialStep = step.after(kind(action), stage: play.stage)
                if next != step { shown.append(next) }
                step = next
            }
            #expect(play.stage == .won, "level \(number)")
            #expect(shown == [.aim, .probe, .select, .done], "level \(number)")
        }
    }

    @Test func tutorialFailureByLastProbeEndsIt() throws {
        // Probing until the allowance is spent fails the level; the tutorial ends with it.
        let witness: HueCompassWitness = try progressWitness(1)
        var play: HueCompassPlay = try begunPlay(witness)
        var step: HueCompassTutorialStep = .aim
        try play.apply(.turn(3), expecting: play.fingerprint)
        step = step.after(.turn, stage: play.stage)
        while play.stage == .playing {
            try play.apply(.probe, expecting: play.fingerprint)
            step = step.after(.probe, stage: play.stage)
        }
        #expect(play.stage == .failed)
        #expect(play.failure == .probes)
        #expect(step == .done)
    }

    @Test func tutorialTexts() {
        #expect(HueCompassTutorialStep.aim.text == "Swipe the compass, or use Turn, to aim the needle")
        #expect(HueCompassTutorialStep.probe.text
            == "Tap the hub to probe: the hue gap counts bands to the target, the fog depth sums the fog between")
        #expect(HueCompassTutorialStep.select.text
            == "When one bearing and band fit every clue, choose the band and Select")
        #expect(HueCompassTutorialStep.done.text == "")
    }

    @Test func tutorialTransitions() {
        #expect(HueCompassTutorialStep.aim.afterTurn() == .probe)
        #expect(HueCompassTutorialStep.probe.afterTurn() == .probe)
        #expect(HueCompassTutorialStep.select.afterTurn() == .select)
        #expect(HueCompassTutorialStep.done.afterTurn() == .done)
        #expect(HueCompassTutorialStep.aim.afterProbe(stage: .playing) == .aim)
        #expect(HueCompassTutorialStep.probe.afterProbe(stage: .playing) == .select)
        #expect(HueCompassTutorialStep.select.afterProbe(stage: .playing) == .select)
        #expect(HueCompassTutorialStep.done.afterProbe(stage: .playing) == .done)
        for step in HueCompassTutorialStep.allCases {
            #expect(step.afterEnd() == .done)
            #expect(step.afterDismiss() == .done)
            #expect(step.afterProbe(stage: .failed) == .done)
            #expect(step.after(.select, stage: .won) == .done)
            #expect(step.after(.select, stage: .failed) == .done)
            #expect(step.after(.undo, stage: .playing) == step)
            #expect(step.after(.redo, stage: .playing) == step.afterTurn())
        }
    }

    @Test func tutorialInEveryModeOnLevels1To3Only() {
        let modes: [HueCompassMode] = [.campaign, .practice, .daily(level: 2)]
        for mode in modes {
            for level in 1...100 {
                let step: HueCompassTutorialStep = HueCompassTutorialStep.initial(level: level)
                #expect(step == (level <= 3 ? .aim : .done), "level \(level) in \(mode)")
            }
        }
        #expect(HueCompassTutorialStep.initial(level: 0) == .done)
    }

    // MARK: Progress

    @Test func campaignThroughAllLevelsOpensInOrderWithThreeStars() throws {
        var progress: HueCompassProgress = HueCompassProgress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1) && !progress.isOpen(2) && !progress.isOpen(0) && !progress.isOpen(101))
        for number in 1...HueCompassProgress.levelCount {
            let witness: HueCompassWitness = try progressWitness(number)
            #expect(witness.number == number)
            #expect(progress.isOpen(number), "level \(number) open before its win")
            #expect(progress.frontier == number, "level \(number)")
            if number < 100 { #expect(!progress.isOpen(number + 1), "level \(number + 1) closed") }
            #expect(progress.nextOpen(after: number) == nil, "level \(number): nothing open beyond the frontier")
            var play: HueCompassPlay = try begunPlay(witness)
            for action in witness.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .won, "level \(number)")
            let smallest: Int = witness.difficulty.smallest
            #expect(play.spent == smallest + 1, "level \(number): probes and the selection")
            let changed1: Bool = progress.record(level: number, units: play.spent, smallest: smallest)
            #expect(changed1, "level \(number)")
            #expect(progress.solved[number] == HueCompassProgress.Result(bestUnits: smallest + 1, stars: 3),
                    "level \(number)")
            if number < 100 { #expect(progress.nextOpen(after: number) == number + 1, "level \(number)") }
        }
        #expect(progress.frontier == 100)
        #expect(progress.solved.count == 100)
        for level in 1...100 { #expect(progress.isOpen(level)) }
        #expect(progress.nextOpen(after: 100) == nil)
        #expect(progress.nextOpen(after: 0) == 1)
    }

    @Test func witnessSmallestIsTheGeneratorsCertifiedSmallest() throws {
        let numbers: [Int] = [1, 2, 3, 100]
        for number in numbers {
            let entry: HueCompassManifestEntry = HueCompassManifest.entries[number - 1]
            let generated: HueCompassGenerated = try HueCompassGenerator.generate(entry)
            #expect(try progressWitness(number).difficulty.smallest == generated.solution.smallest, "level \(number)")
        }
    }

    @Test func allLevelsReachableByProgressAlone() {
        var progress: HueCompassProgress = HueCompassProgress()
        var reached: Set<Int> = []
        while true {
            let frontier: Int = progress.frontier
            reached.insert(frontier)
            progress.record(level: frontier, units: 9, smallest: 1)
            if progress.frontier == frontier { break }
        }
        #expect(reached == Set(1...100))
        #expect(progress.frontier == 100)
    }

    @Test func openThroughNeverLowersAndClamps() {
        var progress: HueCompassProgress = HueCompassProgress()
        progress.open(through: 40)
        #expect(progress.frontier == 40)
        progress.open(through: 10)
        #expect(progress.frontier == 40)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        var low: HueCompassProgress = HueCompassProgress()
        low.open(through: -5)
        #expect(low.frontier == 1)
    }

    @Test func starTable() {
        for smallest in 0...2 {
            for units in 1...24 {
                let expected: Int = units <= smallest + 1 ? 3 : (units <= smallest + 2 ? 2 : 1)
                #expect(HueCompassProgress.stars(units: units, smallest: smallest) == expected, "\(units)/\(smallest)")
            }
        }
        #expect(HueCompassProgress.stars(units: 2, smallest: 1) == 3)
        #expect(HueCompassProgress.stars(units: 3, smallest: 1) == 2)
        #expect(HueCompassProgress.stars(units: 4, smallest: 1) == 1)
        #expect(HueCompassProgress.stars(units: 3, smallest: 2) == 3)
        #expect(HueCompassProgress.stars(units: 4, smallest: 2) == 2)
        #expect(HueCompassProgress.stars(units: 5, smallest: 2) == 1)
    }

    @Test func betterReplacesWorse() {
        var progress: HueCompassProgress = HueCompassProgress()
        let changed2: Bool = progress.record(level: 1, units: 6, smallest: 1)
        #expect(changed2)
        #expect(progress.solved[1] == HueCompassProgress.Result(bestUnits: 6, stars: 1))
        let changed3: Bool = progress.record(level: 1, units: 3, smallest: 1)
        #expect(changed3)
        #expect(progress.solved[1] == HueCompassProgress.Result(bestUnits: 3, stars: 2))
        let changed4: Bool = progress.record(level: 1, units: 4, smallest: 1)
        #expect(!changed4, "worse never wins")
        let changed5: Bool = progress.record(level: 1, units: 3, smallest: 1)
        #expect(!changed5, "equal is no improvement")
        let changed6: Bool = progress.record(level: 1, units: 2, smallest: 1)
        #expect(changed6)
        #expect(progress.solved[1] == HueCompassProgress.Result(bestUnits: 2, stars: 3))
        #expect(progress.frontier == 2)
        let changed7: Bool = progress.record(level: 0, units: 2, smallest: 1)
        #expect(!changed7)
        let changed8: Bool = progress.record(level: 101, units: 2, smallest: 1)
        #expect(!changed8)
        #expect(progress.frontier == 2)
        #expect(progress.solved.count == 1)
        // Seeded sequences: the stored result is always the best seen.
        var random: HueCompassRandom = HueCompassRandom(seed: Self.seed)
        for level in 21...40 {
            var best: Int = Int.max
            for _ in 0..<30 {
                let units: Int = random.int(1...24)
                let improved: Bool = progress.record(level: level, units: units, smallest: 2)
                #expect(improved == (units < best), "level \(level)")
                best = min(best, units)
                #expect(progress.solved[level]?.bestUnits == best, "level \(level)")
                #expect(progress.solved[level]?.stars == HueCompassProgress.stars(units: best, smallest: 2))
            }
        }
    }

    @Test func practiceNeverAwardsAndDailyNeverOpens() {
        var progress: HueCompassProgress = HueCompassProgress()
        let changed9: Bool = progress.record(level: 1, units: 2, smallest: 1, mode: .practice)
        #expect(!changed9)
        #expect(progress == HueCompassProgress())
        // A daily level still locked in the campaign is playable; its win records stars but opens nothing.
        let level: Int = 58
        #expect(!progress.isOpen(level))
        let changed10: Bool = progress.record(level: level, units: 3, smallest: 1, mode: .daily(level: level))
        #expect(changed10)
        #expect(progress.solved[level] == HueCompassProgress.Result(bestUnits: 3, stars: 2))
        #expect(progress.frontier == 1)
        #expect(!progress.isOpen(level))
        let changed11: Bool = progress.record(level: 1, units: 2, smallest: 1, mode: .daily(level: 1))
        #expect(changed11)
        #expect(progress.frontier == 1)
        let changed12: Bool = progress.record(level: 2, units: 2, smallest: 1, mode: .practice)
        #expect(!changed12)
        #expect(progress.solved[2] == nil)
        let changed13: Bool = progress.record(level: 1, units: 9, smallest: 1, mode: .campaign)
        #expect(changed13 == false)
        #expect(progress.frontier == 2)
    }

    @Test func modeRules() {
        #expect(HueCompassMode.practice.allowance(base: 9) == 24)
        #expect(HueCompassMode.campaign.allowance(base: 9) == 9)
        #expect(HueCompassMode.daily(level: 4).allowance(base: 11) == 11)
        #expect(HueCompassProgress.practiceAllowance == HueCompassLevel.allowances.upperBound)
        #expect(HueCompassMode.campaign.awardsStars && HueCompassMode.campaign.opensLevels)
        #expect(HueCompassMode.daily(level: 3).awardsStars && !HueCompassMode.daily(level: 3).opensLevels)
        #expect(!HueCompassMode.practice.awardsStars && !HueCompassMode.practice.opensLevels)
    }

    @Test func bandsOfTwenty() {
        #expect(HueCompassProgress.bands == 1...5)
        for level in 1...100 {
            let band: Int = HueCompassProgress.band(of: level)
            #expect(band == (level - 1) / 20 + 1, "level \(level)")
            #expect(band == HueCompassManifest.entries[level - 1].band, "level \(level): manifest band")
        }
    }

    // MARK: Daily level

    @Test func dailyLevelOfEveryDate2026To2036() {
        var dates: [Int] = []
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...31 {
                    guard let level = HueCompassProgress.dailyLevel(year: year, month: month, day: day) else {
                        #expect(day > HueCompassProgress.daysIn(month: month, year: year))
                        continue
                    }
                    #expect(level >= 1 && level <= 100)
                    dates.append(level)
                }
            }
        }
        #expect(dates.count == 4_018)
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 1, day: 2) == 48)
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 1, day: 3) == 95)
        for index in 0..<dates.count { #expect(dates[index] == (index * 47) % 100 + 1, "day \(index)") }
        for start in 0...(dates.count - 100) {
            var seen: Set<Int> = []
            for offset in 0..<100 { seen.insert(dates[start + offset]) }
            #expect(seen.count == 100, "window from day \(start)")
        }
    }

    @Test func dailyLevelBefore2026() {
        // 2025-12-31 is day -1: (-47 mod 100) + 1 = 54.
        #expect(HueCompassProgress.dailyLevel(year: 2025, month: 12, day: 31) == 54)
        #expect(HueCompassProgress.dailyLevel(year: 1, month: 1, day: 1) != nil)
        #expect(HueCompassProgress.dailyLevel(year: 9999, month: 12, day: 31) != nil)
        var levels: Set<Int> = []
        var year: Int = 2025
        var month: Int = 12
        var day: Int = 31
        for _ in 0..<100 {
            guard let level = HueCompassProgress.dailyLevel(year: year, month: month, day: day) else {
                Issue.record("\(year)-\(month)-\(day)")
                return
            }
            #expect(level >= 1 && level <= 100)
            levels.insert(level)
            day -= 1
            if day == 0 {
                month -= 1
                if month == 0 {
                    month = 12
                    year -= 1
                }
                day = HueCompassProgress.daysIn(month: month, year: year)
            }
        }
        #expect(levels.count == 100)
    }

    @Test func impossibleDatesRefused() {
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 2027, month: 2, day: 29) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 5, day: 0) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 5, day: -3) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        #expect(HueCompassProgress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(HueCompassProgress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
    }

    // MARK: Codable

    @Test func progressRoundTripIsStable() throws {
        var progress: HueCompassProgress = HueCompassProgress()
        progress.record(level: 1, units: 2, smallest: 1)
        progress.record(level: 2, units: 5, smallest: 1)
        progress.record(level: 40, units: 3, smallest: 1, mode: .daily(level: 40))
        let data: Data = try progress.encoded()
        let decoded: HueCompassProgress = try JSONDecoder().decode(HueCompassProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":3,\"solved\":["
            + "{\"bestUnits\":2,\"level\":1,\"stars\":3,\"trace\":[],\"verified\":false},"
            + "{\"bestUnits\":5,\"level\":2,\"stars\":1,\"trace\":[],\"verified\":false},"
            + "{\"bestUnits\":3,\"level\":40,\"stars\":2,\"trace\":[],\"verified\":false}]}")
        let empty: Data = try HueCompassProgress().encoded()
        #expect(try JSONDecoder().decode(HueCompassProgress.self, from: empty) == HueCompassProgress())
    }

    @Test func progressDecodingRefusesInvalidData() {
        let bad: [String] = [
            "{\"frontier\":0,\"solved\":[]}",
            "{\"frontier\":101,\"solved\":[]}",
            "{\"frontier\":2,\"solved\":[{\"bestUnits\":4,\"level\":0,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"bestUnits\":4,\"level\":1,\"stars\":4}]}",
            "{\"frontier\":2,\"solved\":[{\"bestUnits\":4,\"level\":1,\"stars\":0}]}",
            "{\"frontier\":2,\"solved\":[{\"bestUnits\":0,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"bestUnits\":4,\"level\":1,\"stars\":3},"
                + "{\"bestUnits\":5,\"level\":1,\"stars\":2}]}",
        ]
        for json in bad {
            #expect(throws: DecodingError.self, "\(json)") {
                _ = try JSONDecoder().decode(HueCompassProgress.self, from: Data(json.utf8))
            }
        }
    }

    @Test func modeAndStepRoundTrip() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let modes: [HueCompassMode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
        for mode in modes {
            let data: Data = try encoder.encode(mode)
            #expect(try JSONDecoder().decode(HueCompassMode.self, from: data) == mode)
        }
        #expect(String(decoding: try encoder.encode(HueCompassMode.daily(level: 42)), as: UTF8.self)
            == "{\"level\":42,\"mode\":\"daily\"}")
        #expect(String(decoding: try encoder.encode(HueCompassMode.campaign), as: UTF8.self)
            == "{\"mode\":\"campaign\"}")
        #expect(String(decoding: try encoder.encode(HueCompassMode.practice), as: UTF8.self)
            == "{\"mode\":\"practice\"}")
        let badModes: [String] = ["{\"mode\":\"daily\",\"level\":0}", "{\"mode\":\"daily\",\"level\":101}",
                                  "{\"mode\":\"endless\"}", "{\"mode\":\"daily\"}"]
        for json in badModes {
            #expect(throws: DecodingError.self, "\(json)") {
                _ = try JSONDecoder().decode(HueCompassMode.self, from: Data(json.utf8))
            }
        }
        for step in HueCompassTutorialStep.allCases {
            let data: Data = try encoder.encode(step)
            #expect(String(decoding: data, as: UTF8.self) == "\"\(step.rawValue)\"")
            #expect(try JSONDecoder().decode(HueCompassTutorialStep.self, from: data) == step)
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HueCompassTutorialStep.self, from: Data("\"hints\"".utf8))
        }
    }
}
