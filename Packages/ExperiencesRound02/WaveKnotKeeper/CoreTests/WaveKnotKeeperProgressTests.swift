// WaveKnotKeeperProgressTests — feature 325 (R02-G03-05) T-R02G0305-003 (FR-R02G0305-001, 004, 005, 006;
// SC-R02G0305-001, 004; clarifications Q2–Q4). The tutorial scripts on levels 1 … 3 (following each instruction with the
// certified solution wins; the step sequence; a detour with undo never moves the step back; dismiss); scripted campaign
// progress through the 100 certified levels (the frontier opens in order, 3 stars at the shortest); the star rule; better
// results replace worse ones; daily recording leaves the frontier; the daily level of every date 2026-01-01 … 2036-12-31
// and of earlier dates, every level once per 100 consecutive days, impossible dates refused; all 100 levels reachable by
// progress alone; Codable round trips. The certified levels are read from the witness files in
// docs/games/wave-knot-keeper/levels/. Test data uses explicit types and plain loops (CI type-check rule).
@testable import WaveKnotKeeperCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let progressWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/wave-knot-keeper/levels", isDirectory: true)

/// The witness of certified level `number` (1 … 100), decoded (and so re-verified).
private func progressWitness(_ number: Int) throws -> WaveKnotKeeperWitness {
    let name: String = String(format: "%03d", number) + ".witness.json"
    let data: Data = try Data(contentsOf: progressWitnessDirectory.appendingPathComponent(name))
    return try WaveKnotKeeperWitness.decode(data)
}

@Suite struct WaveKnotKeeperProgressTests {
    // MARK: Tutorial

    /// A begun play of `witness`'s level with its tutorial stage dismissed.
    func begunPlay(_ witness: WaveKnotKeeperWitness) throws -> WaveKnotKeeperPlay {
        var play: WaveKnotKeeperPlay = WaveKnotKeeperPlay(level: witness.level)
        try play.handle(.begin)
        if witness.level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    @Test func tutorialScriptsWinLevels1To3() throws {
        for number in 1...3 {
            let witness: WaveKnotKeeperWitness = try progressWitness(number)
            #expect(witness.level.tutorial, "level \(number)")
            #expect(WaveKnotKeeperGenerator.tutorialLevels.contains(number))
            var play: WaveKnotKeeperPlay = try begunPlay(witness)
            let point: Int = witness.moves[0].point
            var step: WaveKnotKeeperTutorialStep = .first(point: point)
            #expect(step == .move(point))
            #expect(step.text == "Drag point \(point + 1) one step (or use the panel)")
            var shown: [WaveKnotKeeperTutorialStep] = [step]
            for move in witness.moves {
                if case .move(let named) = step { #expect(move.point == named, "level \(number): follows the step") }
                try play.apply(move, expecting: play.fingerprint)
                let next: WaveKnotKeeperTutorialStep = step.advancedByAction(stage: play.stage)
                if next != step { shown.append(next) }
                step = next
            }
            #expect(play.stage == .won, "level \(number)")
            #expect(shown.last == .done, "level \(number)")
        }
    }

    /// The first legal move of `play` that does not win (point ascending, then direction), or nil.
    func nonWinningMove(_ play: WaveKnotKeeperPlay) -> WaveKnotKeeperMove? {
        for point in 0..<play.points.count {
            for direction in WaveKnotKeeperDirection.allCases {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                var attempt: WaveKnotKeeperPlay = play
                guard (try? attempt.apply(move, expecting: attempt.fingerprint)) != nil else { continue }
                if attempt.stage == .playing { return move }
            }
        }
        return nil
    }

    @Test func tutorialScriptsWithADetourShowEveryInstructionAndUndoNeverMovesBack() throws {
        // Levels 1 … 3 are won in one move, so a perfect play goes move → done. A player who first makes a non-winning
        // move sees the signature step; undoing that move keeps it; asking for a hint shows the hints step; following
        // the certified solution then wins and ends the tutorial.
        for number in 1...3 {
            let witness: WaveKnotKeeperWitness = try progressWitness(number)
            var play: WaveKnotKeeperPlay = try begunPlay(witness)
            guard let detour = nonWinningMove(play) else {
                Issue.record("level \(number): no non-winning move")
                continue
            }
            var step: WaveKnotKeeperTutorialStep = .first(point: witness.moves[0].point)
            var shown: [WaveKnotKeeperTutorialStep] = [step]
            try play.apply(detour, expecting: play.fingerprint)
            step = step.advancedByAction(stage: play.stage)
            shown.append(step)
            try play.undo()
            #expect(step == .signature, "level \(number): undo never moves the step back")
            step = step.advancedByHint()
            shown.append(step)
            for move in witness.moves {
                try play.apply(move, expecting: play.fingerprint)
                let next: WaveKnotKeeperTutorialStep = step.advancedByAction(stage: play.stage)
                if next != step { shown.append(next) }
                step = next
            }
            #expect(play.stage == .won, "level \(number)")
            #expect(shown == [.move(witness.moves[0].point), .signature, .hints, .done], "level \(number)")
            for shownStep in shown where shownStep != .done { #expect(!shownStep.text.isEmpty) }
        }
    }

    @Test func tutorialTexts() {
        #expect(WaveKnotKeeperTutorialStep.move(0).text == "Drag point 1 one step (or use the panel)")
        #expect(WaveKnotKeeperTutorialStep.move(3).text == "Drag point 4 one step (or use the panel)")
        #expect(WaveKnotKeeperTutorialStep.signature.text
            == "Match the target's crossings and twist (writhe); strands pass through each other only inside the blue gates")
        #expect(WaveKnotKeeperTutorialStep.hints.text == "Ask for a hint whenever you are stuck")
        #expect(WaveKnotKeeperTutorialStep.done.text == "")
        #expect(WaveKnotKeeperTutorialStep.first(point: 5) == .move(5))
    }

    @Test func tutorialTransitions() {
        let steps: [WaveKnotKeeperTutorialStep] = [.move(2), .signature, .hints, .done]
        for step in steps {
            #expect(step.advancedByAction(stage: .won) == .done)
            #expect(step.dismissed == .done)
        }
        #expect(WaveKnotKeeperTutorialStep.move(2).advancedByAction(stage: .playing) == .signature)
        #expect(WaveKnotKeeperTutorialStep.move(2).advancedByAction(stage: .failed) == .signature)
        #expect(WaveKnotKeeperTutorialStep.signature.advancedByAction(stage: .playing) == .hints)
        #expect(WaveKnotKeeperTutorialStep.hints.advancedByAction(stage: .playing) == .hints)
        #expect(WaveKnotKeeperTutorialStep.hints.advancedByAction(stage: .failed) == .hints)
        #expect(WaveKnotKeeperTutorialStep.done.advancedByAction(stage: .playing) == .done)
        // A hint advances only the signature step.
        #expect(WaveKnotKeeperTutorialStep.move(2).advancedByHint() == .move(2))
        #expect(WaveKnotKeeperTutorialStep.signature.advancedByHint() == .hints)
        #expect(WaveKnotKeeperTutorialStep.hints.advancedByHint() == .hints)
        #expect(WaveKnotKeeperTutorialStep.done.advancedByHint() == .done)
    }

    @Test func tutorialDismissEndsIt() throws {
        for number in 1...3 {
            let witness: WaveKnotKeeperWitness = try progressWitness(number)
            let dismissed: WaveKnotKeeperTutorialStep = WaveKnotKeeperTutorialStep.first(point: witness.moves[0].point)
                .dismissed
            #expect(dismissed == .done)
            #expect(dismissed.text.isEmpty)
            #expect(dismissed.advancedByHint() == .done)
            #expect(dismissed.advancedByAction(stage: .playing) == .done)
        }
    }

    // MARK: Progress

    @Test func campaignThroughAllLevelsOpensInOrderWithThreeStars() throws {
        var progress: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1) && !progress.isOpen(2) && !progress.isOpen(0) && !progress.isOpen(101))
        for number in 1...WaveKnotKeeperProgress.levelCount {
            let witness: WaveKnotKeeperWitness = try progressWitness(number)
            #expect(witness.number == number)
            #expect(progress.isOpen(number), "level \(number) open before its win")
            #expect(progress.frontier == number, "level \(number)")
            if number < 100 { #expect(!progress.isOpen(number + 1), "level \(number + 1) closed") }
            #expect(progress.nextOpen(after: number) == nil, "level \(number): nothing open beyond the frontier")
            var play: WaveKnotKeeperPlay = try begunPlay(witness)
            for move in witness.moves { try play.apply(move, expecting: play.fingerprint) }
            #expect(play.stage == .won, "level \(number)")
            progress.record(level: number, moves: play.spent, shortest: witness.moves.count, opensNext: true)
            #expect(progress.solved[number] == WaveKnotKeeperProgress.Result(bestMoves: witness.moves.count, stars: 3),
                    "level \(number)")
            if number < 100 { #expect(progress.nextOpen(after: number) == number + 1, "level \(number)") }
        }
        #expect(progress.frontier == 100)
        #expect(progress.solved.count == 100)
        for level in 1...100 { #expect(progress.isOpen(level)) }
        #expect(progress.nextOpen(after: 100) == nil)
        #expect(progress.nextOpen(after: 0) == 1)
    }

    @Test func allLevelsReachableByProgressAlone() {
        // FR-R02G0305-006: campaign wins alone open every level; nothing else gates a level.
        var progress: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        var reached: Set<Int> = []
        while true {
            let frontier: Int = progress.frontier
            reached.insert(frontier)
            progress.record(level: frontier, moves: 9, shortest: 3, opensNext: true)
            if progress.frontier == frontier { break }
        }
        #expect(reached == Set(1...100))
        #expect(progress.frontier == 100)
    }

    @Test func openThroughNeverLowersAndClamps() {
        var progress: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        progress.open(through: 40)
        #expect(progress.frontier == 40)
        progress.open(through: 10)
        #expect(progress.frontier == 40)
        progress.open(through: 500)
        #expect(progress.frontier == 100)
        var low: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        low.open(through: -5)
        #expect(low.frontier == 1)
    }

    @Test func starRule() {
        #expect(WaveKnotKeeperProgress.stars(moves: 2, shortest: 3) == 3)
        #expect(WaveKnotKeeperProgress.stars(moves: 3, shortest: 3) == 3)
        #expect(WaveKnotKeeperProgress.stars(moves: 4, shortest: 3) == 2)
        #expect(WaveKnotKeeperProgress.stars(moves: 5, shortest: 3) == 2)
        #expect(WaveKnotKeeperProgress.stars(moves: 6, shortest: 3) == 1)
        #expect(WaveKnotKeeperProgress.stars(moves: 64, shortest: 3) == 1)
    }

    @Test func extraMovesGiveFewerStarsAndBetterReplacesWorse() {
        var progress: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        progress.record(level: 1, moves: 7, shortest: 3, opensNext: true)
        #expect(progress.solved[1] == WaveKnotKeeperProgress.Result(bestMoves: 7, stars: 1))
        progress.record(level: 1, moves: 5, shortest: 3, opensNext: true)
        #expect(progress.solved[1] == WaveKnotKeeperProgress.Result(bestMoves: 5, stars: 2))
        progress.record(level: 1, moves: 6, shortest: 3, opensNext: true)
        #expect(progress.solved[1] == WaveKnotKeeperProgress.Result(bestMoves: 5, stars: 2), "worse never wins")
        progress.record(level: 1, moves: 3, shortest: 3, opensNext: true)
        #expect(progress.solved[1] == WaveKnotKeeperProgress.Result(bestMoves: 3, stars: 3))
        progress.record(level: 1, moves: 9, shortest: 3, opensNext: true)
        #expect(progress.solved[1] == WaveKnotKeeperProgress.Result(bestMoves: 3, stars: 3))
        #expect(progress.frontier == 2)
        // Replaying an earlier level never lowers the frontier; levels outside 1 … 100 are ignored.
        progress.record(level: 2, moves: 3, shortest: 3, opensNext: true)
        progress.record(level: 1, moves: 3, shortest: 3, opensNext: true)
        #expect(progress.frontier == 3)
        progress.record(level: 0, moves: 3, shortest: 3, opensNext: true)
        progress.record(level: 101, moves: 3, shortest: 3, opensNext: true)
        #expect(progress.frontier == 3)
        #expect(progress.solved.count == 2)
    }

    @Test func dailyRecordingLeavesTheFrontier() {
        var progress: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        progress.record(level: 1, moves: 3, shortest: 3, opensNext: true)
        let level: Int = 58
        #expect(!progress.isOpen(level))
        progress.record(level: level, moves: 4, shortest: 3, opensNext: false)
        #expect(progress.solved[level] == WaveKnotKeeperProgress.Result(bestMoves: 4, stars: 2))
        #expect(progress.frontier == 2)
        #expect(!progress.isOpen(level))
        progress.record(level: 2, moves: 3, shortest: 3, opensNext: false)
        #expect(progress.frontier == 2)
    }

    // MARK: Daily level

    @Test func dailyLevelOfEveryDate2026To2036() {
        var dates: [Int] = []
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...31 {
                    guard let level = WaveKnotKeeperProgress.dailyLevel(year: year, month: month, day: day) else {
                        #expect(day > WaveKnotKeeperProgress.daysIn(month: month, year: year))
                        continue
                    }
                    #expect(level >= 1 && level <= 100)
                    dates.append(level)
                }
            }
        }
        #expect(dates.count == 4_018)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 1, day: 2) == 44)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 1, day: 3) == 87)
        // Day n is (43 n mod 100) + 1 for every listed date.
        for index in 0..<dates.count { #expect(dates[index] == (index * 43) % 100 + 1, "day \(index)") }
        // Any 100 consecutive days visit every level exactly once.
        for start in 0...(dates.count - 100) {
            var seen: Set<Int> = []
            for offset in 0..<100 { seen.insert(dates[start + offset]) }
            #expect(seen.count == 100, "window from day \(start)")
        }
    }

    @Test func dailyLevelBefore2026() {
        // 2025-12-31 is day -1: (-43 mod 100) + 1 = 58.
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2025, month: 12, day: 31) == 58)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 1, month: 1, day: 1) != nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 9999, month: 12, day: 31) != nil)
        var levels: Set<Int> = []
        var year: Int = 2025
        var month: Int = 12
        var day: Int = 31
        for _ in 0..<100 {
            guard let level = WaveKnotKeeperProgress.dailyLevel(year: year, month: month, day: day) else {
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
                day = WaveKnotKeeperProgress.daysIn(month: month, year: year)
            }
        }
        #expect(levels.count == 100)
    }

    @Test func impossibleDatesRefused() {
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2027, month: 2, day: 29) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 5, day: 0) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 5, day: -3) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 0, month: 1, day: 1) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
    }

    // MARK: Codable

    @Test func progressRoundTripIsStable() throws {
        var progress: WaveKnotKeeperProgress = WaveKnotKeeperProgress()
        progress.record(level: 1, moves: 3, shortest: 3, opensNext: true)
        progress.record(level: 2, moves: 6, shortest: 3, opensNext: true)
        progress.record(level: 40, moves: 4, shortest: 3, opensNext: false)
        let data: Data = try progress.encoded()
        let decoded: WaveKnotKeeperProgress = try JSONDecoder().decode(WaveKnotKeeperProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text == "{\"frontier\":3,\"solved\":["
            + "{\"bestMoves\":3,\"level\":1,\"stars\":3,\"trace\":[],\"verified\":false},"
            + "{\"bestMoves\":6,\"level\":2,\"stars\":1,\"trace\":[],\"verified\":false},"
            + "{\"bestMoves\":4,\"level\":40,\"stars\":2,\"trace\":[],\"verified\":false}]}")
        let empty: Data = try WaveKnotKeeperProgress().encoded()
        #expect(try JSONDecoder().decode(WaveKnotKeeperProgress.self, from: empty) == WaveKnotKeeperProgress())
    }

    @Test func progressDecodingRefusesInvalidData() {
        let bad: [String] = [
            "{\"frontier\":0,\"solved\":[]}",
            "{\"frontier\":101,\"solved\":[]}",
            "{\"frontier\":2,\"solved\":[{\"bestMoves\":4,\"level\":0,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"bestMoves\":4,\"level\":1,\"stars\":4}]}",
            "{\"frontier\":2,\"solved\":[{\"bestMoves\":4,\"level\":1,\"stars\":0}]}",
            "{\"frontier\":2,\"solved\":[{\"bestMoves\":-1,\"level\":1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"bestMoves\":4,\"level\":1,\"stars\":3},"
                + "{\"bestMoves\":5,\"level\":1,\"stars\":2}]}",
        ]
        for json in bad {
            #expect(throws: DecodingError.self, "\(json)") {
                _ = try JSONDecoder().decode(WaveKnotKeeperProgress.self, from: Data(json.utf8))
            }
        }
    }

    @Test func modeAndStepRoundTrip() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let modes: [WaveKnotKeeperMode] = [.campaign, .practice, .daily(level: 1), .daily(level: 100)]
        for mode in modes {
            let data: Data = try encoder.encode(mode)
            #expect(try JSONDecoder().decode(WaveKnotKeeperMode.self, from: data) == mode)
        }
        #expect(String(decoding: try encoder.encode(WaveKnotKeeperMode.daily(level: 42)), as: UTF8.self)
            == "{\"level\":42,\"mode\":\"daily\"}")
        #expect(String(decoding: try encoder.encode(WaveKnotKeeperMode.campaign), as: UTF8.self)
            == "{\"mode\":\"campaign\"}")
        #expect(String(decoding: try encoder.encode(WaveKnotKeeperMode.practice), as: UTF8.self)
            == "{\"mode\":\"practice\"}")
        let steps: [WaveKnotKeeperTutorialStep] = [.move(0), .move(7), .signature, .hints, .done]
        for step in steps {
            let data: Data = try encoder.encode(step)
            #expect(try JSONDecoder().decode(WaveKnotKeeperTutorialStep.self, from: data) == step)
        }
        #expect(String(decoding: try encoder.encode(WaveKnotKeeperTutorialStep.move(3)), as: UTF8.self)
            == "{\"point\":3,\"step\":\"move\"}")
        let badModes: [String] = ["{\"mode\":\"replay\"}", "{\"mode\":\"daily\",\"level\":0}",
                                  "{\"mode\":\"daily\",\"level\":101}"]
        for json in badModes {
            #expect(throws: DecodingError.self, "\(json)") {
                _ = try JSONDecoder().decode(WaveKnotKeeperMode.self, from: Data(json.utf8))
            }
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(WaveKnotKeeperTutorialStep.self, from: Data("{\"step\":\"x\"}".utf8))
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(WaveKnotKeeperTutorialStep.self,
                                         from: Data("{\"step\":\"move\",\"point\":-1}".utf8))
        }
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(WaveKnotKeeperTutorialStep.self, from: Data("{\"step\":\"move\"}".utf8))
        }
    }
}
