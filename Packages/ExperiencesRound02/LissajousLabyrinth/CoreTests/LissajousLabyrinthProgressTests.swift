// LissajousLabyrinthProgressTests — feature 315 (R02-G02-05) T-R02G0205-003 (FR-R02G0205-001, 004, 005, 006;
// SC-R02G0205-001, 004; clarifications Q2–Q4; research R3–R6). The tutorial scripts on levels 1 … 3 (following each
// instruction with the certified solution wins; the step sequence; dismiss); scripted campaign progress through the 100
// certified levels (the frontier opens in order, 3 stars at the shortest); the star rule; better results replace worse
// ones; daily and practice leave the frontier; the daily level of every date 2026-01-01 … 2036-12-31 and of earlier
// dates, every level once per 100 consecutive days, impossible dates refused; all 100 levels reachable by progress
// alone; Codable round trips. The certified levels are read from the witness files in docs/games/lissajous-labyrinth/
// levels/. Test data uses explicit types and plain loops (CI type-check rule).
@testable import LissajousLabyrinthCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let progressWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/lissajous-labyrinth/levels", isDirectory: true)

/// The witness of certified level `number` (1 … 100), decoded (and so re-verified).
private func progressWitness(_ number: Int) throws -> LissajousLabyrinthWitness {
    let name: String = String(LissajousLabyrinthGenerator.levelID(number).suffix(3)) + ".witness.json"
    let data: Data = try Data(contentsOf: progressWitnessDirectory.appendingPathComponent(name))
    return try LissajousLabyrinthWitness.decode(data)
}

/// The 100 certified witnesses, decoded once per test process, in manifest order.
private let progressWitnesses: Result<[LissajousLabyrinthWitness], any Error> = Result {
    var result: [LissajousLabyrinthWitness] = []
    for entry in LissajousLabyrinthManifest.entries { result.append(try progressWitness(entry.number)) }
    return result
}

@Suite struct LissajousLabyrinthProgressTests {
    // MARK: Tutorial

    /// Plays tutorial level `number` following each instruction: the certified actions in order, asking for a hint
    /// after the first action when `hint`; returns the steps shown (the first, then one per change).
    func tutorialScript(_ number: Int, hint: Bool) throws -> [LissajousLabyrinthTutorialStep] {
        let witness: LissajousLabyrinthWitness = try progressWitness(number)
        #expect(witness.level.tutorial)
        #expect(LissajousLabyrinthGenerator.tutorialLevels.contains(number))
        var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: witness.level)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        try play.handle(.dismissTutorial)
        let firstDial: LissajousLabyrinthDial = witness.actions[0].dial
        var step: LissajousLabyrinthTutorialStep = .first(dial: firstDial)
        var shown: [LissajousLabyrinthTutorialStep] = [step]
        for (index, action) in witness.actions.enumerated() {
            if case .turn(let dial) = step { #expect(action.dial == dial, "level \(number): follows the turn step") }
            try play.apply(action, expecting: play.fingerprint)
            let next: LissajousLabyrinthTutorialStep = step.advancedByAction(stage: play.stage)
            if next != step { shown.append(next) }
            step = next
            if hint && index == 0 {
                let afterHint: LissajousLabyrinthTutorialStep = step.advancedByHint()
                if afterHint != step { shown.append(afterHint) }
                step = afterHint
            }
        }
        #expect(play.stage == .won, "level \(number)")
        #expect(step == .done, "level \(number)")
        return shown
    }

    /// The steps expected for a solution of `count` actions, with or without a hint after the first action.
    func expectedSteps(dial: LissajousLabyrinthDial, count: Int, hint: Bool) -> [LissajousLabyrinthTutorialStep] {
        if count == 1 { return [.turn(dial), .done] }
        if count == 2 && !hint { return [.turn(dial), .checkpoints, .done] }
        return [.turn(dial), .checkpoints, .hints, .done]
    }

    @Test func tutorialScriptsWinLevels1To3() throws {
        for number in 1...3 {
            let witness: LissajousLabyrinthWitness = try progressWitness(number)
            let dial: LissajousLabyrinthDial = witness.actions[0].dial
            let count: Int = witness.actions.count
            #expect(try tutorialScript(number, hint: true) == expectedSteps(dial: dial, count: count, hint: true),
                    "level \(number) with a hint")
            #expect(try tutorialScript(number, hint: false) == expectedSteps(dial: dial, count: count, hint: false),
                    "level \(number) without a hint")
        }
    }

    @Test func tutorialScriptsWithADetourShowEveryInstruction() throws {
        // Levels 1 and 2 are won in one action, so a perfect play goes turn → done. A player who first explores the
        // named ring (a non-winning value), asks for a hint, then follows the certified solution sees all three
        // instructions in order and still wins.
        for number in 1...3 {
            let witness: LissajousLabyrinthWitness = try progressWitness(number)
            let dial: LissajousLabyrinthDial = witness.actions[0].dial
            var base: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: witness.level)
            try base.handle(.begin)
            try base.handle(.dismissTutorial)
            var explored: LissajousLabyrinthPlay? = nil
            for value in dial.range where value != base.dials[dial] && value != witness.actions[0].value {
                var attempt: LissajousLabyrinthPlay = base
                guard (try? attempt.apply(LissajousLabyrinthAction(dial: dial, value: value),
                                          expecting: attempt.fingerprint)) != nil else { continue }
                if attempt.stage == .playing {
                    explored = attempt
                    break
                }
            }
            guard var play = explored else {
                Issue.record("level \(number): no non-winning value of the named ring")
                continue
            }
            var step: LissajousLabyrinthTutorialStep = .first(dial: dial)
            var shown: [LissajousLabyrinthTutorialStep] = [step]
            step = step.advancedByAction(stage: play.stage)
            shown.append(step)
            step = step.advancedByHint()
            shown.append(step)
            for action in witness.actions {
                try play.apply(action, expecting: play.fingerprint)
                let next: LissajousLabyrinthTutorialStep = step.advancedByAction(stage: play.stage)
                if next != step { shown.append(next) }
                step = next
            }
            #expect(play.stage == .won, "level \(number)")
            #expect(shown == [.turn(dial), .checkpoints, .hints, .done], "level \(number)")
            for shownStep in shown where shownStep != .done { #expect(!shownStep.text.isEmpty) }
        }
    }

    @Test func tutorialTexts() {
        #expect(LissajousLabyrinthTutorialStep.turn(.frequencyA).text == "Turn the Frequency A ring to change the path.")
        #expect(LissajousLabyrinthTutorialStep.turn(.frequencyB).text == "Turn the Frequency B ring to change the path.")
        #expect(LissajousLabyrinthTutorialStep.turn(.phaseA).text == "Turn the Phase A ring to change the path.")
        #expect(LissajousLabyrinthTutorialStep.turn(.phaseC).text == "Turn the Phase C ring to change the path.")
        #expect(LissajousLabyrinthTutorialStep.checkpoints.text
            == "Copper checkpoints light up when the lap reaches them in order; keep the path off the violet spheres.")
        #expect(LissajousLabyrinthTutorialStep.hints.text == "Ask for a hint whenever you are stuck.")
        #expect(LissajousLabyrinthTutorialStep.done.text == "")
        #expect(LissajousLabyrinthTutorialStep.first(dial: .phaseC) == .turn(.phaseC))
    }

    @Test func tutorialTransitions() {
        let steps: [LissajousLabyrinthTutorialStep] = [.turn(.phaseA), .checkpoints, .hints, .done]
        for step in steps {
            #expect(step.advancedByAction(stage: .won) == .done)
            #expect(step.dismissed == .done)
        }
        #expect(LissajousLabyrinthTutorialStep.turn(.phaseA).advancedByAction(stage: .playing) == .checkpoints)
        #expect(LissajousLabyrinthTutorialStep.checkpoints.advancedByAction(stage: .playing) == .hints)
        #expect(LissajousLabyrinthTutorialStep.hints.advancedByAction(stage: .playing) == .hints)
        #expect(LissajousLabyrinthTutorialStep.hints.advancedByAction(stage: .failed) == .hints)
        #expect(LissajousLabyrinthTutorialStep.done.advancedByAction(stage: .playing) == .done)
        // A hint advances only the checkpoints step.
        #expect(LissajousLabyrinthTutorialStep.turn(.phaseA).advancedByHint() == .turn(.phaseA))
        #expect(LissajousLabyrinthTutorialStep.checkpoints.advancedByHint() == .hints)
        #expect(LissajousLabyrinthTutorialStep.hints.advancedByHint() == .hints)
        #expect(LissajousLabyrinthTutorialStep.done.advancedByHint() == .done)
    }

    @Test func tutorialDismissEndsIt() throws {
        let witness: LissajousLabyrinthWitness = try progressWitness(1)
        let step: LissajousLabyrinthTutorialStep = .first(dial: witness.actions[0].dial)
        let dismissed: LissajousLabyrinthTutorialStep = step.dismissed
        #expect(dismissed == .done)
        #expect(dismissed.text.isEmpty)
        #expect(dismissed.advancedByHint() == .done)
        #expect(dismissed.advancedByAction(stage: .playing) == .done)
    }

    // MARK: Progress

    @Test func campaignThroughAllLevelsOpensInOrderWithThreeStars() throws {
        let witnesses: [LissajousLabyrinthWitness] = try progressWitnesses.get()
        #expect(witnesses.count == 100)
        var progress: LissajousLabyrinthProgress = LissajousLabyrinthProgress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1) && !progress.isOpen(2) && !progress.isOpen(0) && !progress.isOpen(101))
        for witness in witnesses {
            let number: Int = witness.number
            #expect(progress.isOpen(number), "level \(number) open before its win")
            #expect(progress.frontier == number, "level \(number)")
            if number < 100 { #expect(!progress.isOpen(number + 1), "level \(number + 1) closed") }
            var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: witness.level)
            try play.handle(.begin)
            if witness.level.tutorial { try play.handle(.dismissTutorial) }
            for action in witness.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .won, "level \(number)")
            progress.record(level: number, actions: play.spent, shortest: witness.actions.count, opensNext: true)
            #expect(progress.solved[number] == LissajousLabyrinthProgress.Result(bestActions: witness.actions.count,
                                                                                 stars: 3), "level \(number)")
        }
        #expect(progress.frontier == 100)
        #expect(progress.solved.count == 100)
        for level in 1...100 { #expect(progress.isOpen(level)) }
    }

    @Test func allLevelsReachableByProgressAlone() {
        // FR-R02G0205-006: campaign wins alone open every level; nothing else gates a level.
        var progress: LissajousLabyrinthProgress = LissajousLabyrinthProgress()
        var reached: Set<Int> = []
        while true {
            let frontier: Int = progress.frontier
            reached.insert(frontier)
            progress.record(level: frontier, actions: 9, shortest: 3, opensNext: true)
            if progress.frontier == frontier { break }
        }
        #expect(reached == Set(1...100))
        #expect(progress.frontier == 100)
    }

    @Test func starRule() {
        #expect(LissajousLabyrinthProgress.stars(actions: 3, shortest: 4) == 3)
        #expect(LissajousLabyrinthProgress.stars(actions: 4, shortest: 4) == 3)
        #expect(LissajousLabyrinthProgress.stars(actions: 5, shortest: 4) == 2)
        #expect(LissajousLabyrinthProgress.stars(actions: 6, shortest: 4) == 2)
        #expect(LissajousLabyrinthProgress.stars(actions: 7, shortest: 4) == 1)
        #expect(LissajousLabyrinthProgress.stars(actions: 64, shortest: 4) == 1)
    }

    @Test func extraActionsGiveFewerStarsAndBetterReplacesWorse() {
        var progress: LissajousLabyrinthProgress = LissajousLabyrinthProgress()
        progress.record(level: 1, actions: 8, shortest: 4, opensNext: true)
        #expect(progress.solved[1] == LissajousLabyrinthProgress.Result(bestActions: 8, stars: 1))
        progress.record(level: 1, actions: 6, shortest: 4, opensNext: true)
        #expect(progress.solved[1] == LissajousLabyrinthProgress.Result(bestActions: 6, stars: 2))
        progress.record(level: 1, actions: 7, shortest: 4, opensNext: true)
        #expect(progress.solved[1] == LissajousLabyrinthProgress.Result(bestActions: 6, stars: 2), "worse never wins")
        progress.record(level: 1, actions: 4, shortest: 4, opensNext: true)
        #expect(progress.solved[1] == LissajousLabyrinthProgress.Result(bestActions: 4, stars: 3))
        progress.record(level: 1, actions: 9, shortest: 4, opensNext: true)
        #expect(progress.solved[1] == LissajousLabyrinthProgress.Result(bestActions: 4, stars: 3))
        #expect(progress.frontier == 2)
        // Replaying an earlier level never lowers the frontier; levels outside 1 … 100 are ignored.
        progress.record(level: 2, actions: 4, shortest: 4, opensNext: true)
        progress.record(level: 1, actions: 4, shortest: 4, opensNext: true)
        #expect(progress.frontier == 3)
        progress.record(level: 0, actions: 4, shortest: 4, opensNext: true)
        progress.record(level: 101, actions: 4, shortest: 4, opensNext: true)
        #expect(progress.frontier == 3)
        #expect(progress.solved.count == 2)
    }

    @Test func dailyRecordingLeavesTheFrontier() {
        var progress: LissajousLabyrinthProgress = LissajousLabyrinthProgress()
        progress.record(level: 1, actions: 4, shortest: 4, opensNext: true)
        let level: Int = 57
        #expect(!progress.isOpen(level))
        progress.record(level: level, actions: 5, shortest: 4, opensNext: false)
        #expect(progress.solved[level] == LissajousLabyrinthProgress.Result(bestActions: 5, stars: 2))
        #expect(progress.frontier == 2)
        #expect(!progress.isOpen(level))
        progress.record(level: 2, actions: 4, shortest: 4, opensNext: false)
        #expect(progress.frontier == 2)
    }

    // MARK: Daily level

    @Test func dailyLevelOfEveryDate2026To2036() {
        var dates: [Int] = []
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...31 {
                    guard let level = LissajousLabyrinthProgress.dailyLevel(year: year, month: month, day: day) else {
                        #expect(day > LissajousLabyrinthProgress.daysIn(month: month, year: year))
                        continue
                    }
                    #expect(level >= 1 && level <= 100)
                    dates.append(level)
                }
            }
        }
        #expect(dates.count == 4_018)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 1, day: 2) == 42)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 1, day: 3) == 83)
        // Any 100 consecutive days visit every level exactly once.
        for start in 0...(dates.count - 100) {
            var seen: Set<Int> = []
            for offset in 0..<100 { seen.insert(dates[start + offset]) }
            #expect(seen.count == 100, "window from day \(start)")
        }
    }

    @Test func dailyLevelBefore2026() {
        // 2025-12-31 is day -1: (-41 mod 100) + 1 = 60.
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2025, month: 12, day: 31) == 60)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 1, month: 1, day: 1) != nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 9999, month: 12, day: 31) != nil)
        var levels: Set<Int> = []
        var year: Int = 2025
        var month: Int = 12
        var day: Int = 31
        for _ in 0..<100 {
            guard let level = LissajousLabyrinthProgress.dailyLevel(year: year, month: month, day: day) else {
                Issue.record("\(year)-\(month)-\(day)")
                return
            }
            levels.insert(level)
            day -= 1
            if day == 0 {
                month -= 1
                if month == 0 {
                    month = 12
                    year -= 1
                }
                day = LissajousLabyrinthProgress.daysIn(month: month, year: year)
            }
        }
        #expect(levels.count == 100)
    }

    @Test func impossibleDatesRefused() {
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 2, day: 29) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 5, day: 0) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2026, month: 5, day: -3) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(LissajousLabyrinthProgress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
    }

    // MARK: Codable

    @Test func progressRoundTripIsStable() throws {
        var progress: LissajousLabyrinthProgress = LissajousLabyrinthProgress()
        progress.record(level: 1, actions: 4, shortest: 4, opensNext: true)
        progress.record(level: 2, actions: 7, shortest: 4, opensNext: true)
        progress.record(level: 40, actions: 5, shortest: 4, opensNext: false)
        let data: Data = try progress.encoded()
        let decoded: LissajousLabyrinthProgress = try JSONDecoder().decode(LissajousLabyrinthProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":3,\"solved\":[{\"bestActions\":4,\"level\":1,\"stars\":3},"
            + "{\"bestActions\":7,\"level\":2,\"stars\":1},{\"bestActions\":5,\"level\":40,\"stars\":2}]}")
        let empty: Data = try LissajousLabyrinthProgress().encoded()
        #expect(try JSONDecoder().decode(LissajousLabyrinthProgress.self, from: empty) == LissajousLabyrinthProgress())
    }

    @Test func progressDecodingRefusesInvalidData() {
        let bad: [String] = [
            "{\"frontier\":0,\"solved\":[]}",
            "{\"frontier\":101,\"solved\":[]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":4,\"level\":0,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":4,\"level\":1,\"stars\":4}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":-1,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"bestActions\":4,\"level\":1,\"stars\":3},"
                + "{\"bestActions\":5,\"level\":1,\"stars\":2}]}",
        ]
        for json in bad {
            #expect(throws: DecodingError.self, "\(json)") {
                _ = try JSONDecoder().decode(LissajousLabyrinthProgress.self, from: Data(json.utf8))
            }
        }
    }

    @Test func modeAndStepRoundTrip() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let modes: [LissajousLabyrinthMode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
        for mode in modes {
            let data: Data = try encoder.encode(mode)
            #expect(try JSONDecoder().decode(LissajousLabyrinthMode.self, from: data) == mode)
        }
        #expect(String(decoding: try encoder.encode(LissajousLabyrinthMode.daily(level: 42)), as: UTF8.self)
            == "{\"level\":42,\"mode\":\"daily\"}")
        #expect(String(decoding: try encoder.encode(LissajousLabyrinthMode.campaign), as: UTF8.self)
            == "{\"mode\":\"campaign\"}")
        var steps: [LissajousLabyrinthTutorialStep] = [.checkpoints, .hints, .done]
        for dial in LissajousLabyrinthDial.allCases { steps.append(.turn(dial)) }
        for step in steps {
            let data: Data = try encoder.encode(step)
            #expect(try JSONDecoder().decode(LissajousLabyrinthTutorialStep.self, from: data) == step)
        }
        #expect(String(decoding: try encoder.encode(LissajousLabyrinthTutorialStep.turn(.phaseC)), as: UTF8.self)
            == "{\"dial\":\"phaseC\",\"step\":\"turn\"}")
        let badModes: [String] = ["{\"mode\":\"replay\"}", "{\"mode\":\"daily\",\"level\":0}",
                                  "{\"mode\":\"daily\",\"level\":101}"]
        for json in badModes {
            #expect(throws: DecodingError.self, "\(json)") {
                _ = try JSONDecoder().decode(LissajousLabyrinthMode.self, from: Data(json.utf8))
            }
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(LissajousLabyrinthTutorialStep.self, from: Data("{\"step\":\"x\"}".utf8))
        }
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(LissajousLabyrinthTutorialStep.self, from: Data("{\"step\":\"turn\"}".utf8))
        }
    }
}
