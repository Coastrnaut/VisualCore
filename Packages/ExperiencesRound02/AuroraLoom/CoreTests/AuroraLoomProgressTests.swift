// AuroraLoomProgressTests — feature 305 (R02-G01-05) T-R02G0105-003 (FR-R02G0105-001, 004, 005, 006; SC-R02G0105-001,
// 004; clarifications Q2, Q3, Q4; research R3, R4, R5). Tutorial scripts on the certified levels 1 … 3 (a wave move, a
// phase move, then the rest of the certified solution) advance wave → phase → harmony → done and win; undo and redo never
// move the step back; scripted campaign progress through all 100 levels opens them one by one with the right stars and
// keeps the bests; every date 2026-01-01 … 2036-12-31 maps purely to 1 … 100; invalid dates map to nil; every level is
// reachable by progress alone; Codable round trip and deterministic encoding.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreSimulation

@Suite struct AuroraLoomProgressTests {
    /// The certified levels 1 … 100 in manifest order (generated once).
    static let catalog: [AuroraLoomGenerated] = {
        var levels: [AuroraLoomGenerated] = []
        for entry in AuroraLoomManifest.entries {
            levels.append(try! AuroraLoomGenerator.generate(entry))
        }
        return levels
    }()

    /// The certified solution reordered for the tutorial: a wave move first, then a phase move, then the rest. When the
    /// solution has no move of a control, a detour (change it, later restore it) stands in for it.
    static func tutorialScript(_ generated: AuroraLoomGenerated) -> [AuroraLoomMove] {
        var rest: [AuroraLoomMove] = generated.solution.moves
        var script: [AuroraLoomMove] = []
        var restores: [AuroraLoomMove] = []
        let start: AuroraLoomSteps = generated.level.startSteps
        for control in [AuroraLoomControl.wave, AuroraLoomControl.phase] {
            if let index = rest.firstIndex(where: { (move: AuroraLoomMove) -> Bool in move.control == control }) {
                script.append(rest.remove(at: index))
            } else {
                let current: Int = control == .wave ? start.wave[0] : start.phase[0]
                script.append(AuroraLoomMove(ribbon: 0, control: control, step: (current + 1) % 16))
                restores.append(AuroraLoomMove(ribbon: 0, control: control, step: current))
            }
        }
        var result: [AuroraLoomMove] = script + rest + restores
        // The wave move and the phase move could already win (a two-move solution, or a reordered prefix that wins); a
        // phase detour on another ribbon (set, then restored) as the first phase move lets the player see `harmony`.
        let other: Int = (result[1].ribbon + 1) % 3
        let current: Int = start.phase[other]
        result.insert(contentsOf: [AuroraLoomMove(ribbon: other, control: .phase, step: (current + 1) % 16),
                                   AuroraLoomMove(ribbon: other, control: .phase, step: current)], at: 1)
        return result
    }

    /// A new play of `level` in stage `playing`.
    static func playing(_ level: AuroraLoomLevel) throws -> AuroraLoomPlay {
        var play: AuroraLoomPlay = AuroraLoomPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    @Test func tutorialAdvancesThroughScriptOnLevels1To3() throws {
        for index in 0..<3 {
            let generated: AuroraLoomGenerated = Self.catalog[index]
            #expect(generated.level.tutorial)
            let script: [AuroraLoomMove] = Self.tutorialScript(generated)
            var play: AuroraLoomPlay = try Self.playing(generated.level)
            var step: AuroraLoomTutorialStep = .first(ribbon: script[0].ribbon)
            #expect(step == .wave(ribbon: script[0].ribbon))
            var seen: [AuroraLoomTutorialStep] = [step]
            for (position, move) in script.enumerated() {
                if play.stage != .playing { break }   // a reordered prefix of the solution may already win
                try play.apply(move, expecting: play.fingerprint)
                let hintRibbon: Int = position + 1 < script.count ? script[position + 1].ribbon : 0
                let next: AuroraLoomTutorialStep = step.advanced(by: play.records[play.records.count - 1],
                                                                 stage: play.stage, hintRibbon: hintRibbon)
                if next != step { seen.append(next) }
                step = next
            }
            #expect(play.stage == .won, "level \(index + 1)")
            #expect(seen.count == 4, "level \(index + 1): \(seen)")
            if case .wave = seen[0] {} else { Issue.record("first step \(seen[0])") }
            if case .phase = seen[1] {} else { Issue.record("second step \(seen[1])") }
            #expect(seen[2] == .harmony)
            #expect(seen[3] == .done)
        }
    }

    @Test func undoAndRedoNeverMoveTheStepBack() throws {
        var random: SeededRandom = SeededRandom(seed: 2_305)
        for index in 0..<3 {
            let generated: AuroraLoomGenerated = Self.catalog[index]
            let script: [AuroraLoomMove] = Self.tutorialScript(generated)
            var play: AuroraLoomPlay = try Self.playing(generated.level)
            var step: AuroraLoomTutorialStep = .first(ribbon: script[0].ribbon)
            for move in script {
                try play.apply(move, expecting: play.fingerprint)
                step = step.advanced(by: play.records[play.records.count - 1], stage: play.stage, hintRibbon: 1)
                if play.stage != .playing { break }
                let rounds: Int = random.int(1...3)
                for _ in 0..<rounds {
                    let before: AuroraLoomTutorialStep = step
                    try play.undo()
                    step = step.advanced(by: play.records[play.records.count - 1], stage: play.stage, hintRibbon: 2)
                    #expect(step == before)
                    try play.redo()
                    step = step.advanced(by: play.records[play.records.count - 1], stage: play.stage, hintRibbon: 2)
                    #expect(step == before)
                }
            }
            #expect(play.stage == .won)
            #expect(step == .done)
        }
    }

    @Test func tutorialStepRulesAndText() {
        let record: (AuroraLoomRecordKind, AuroraLoomControl) -> AuroraLoomRecord = { kind, control in
            AuroraLoomRecord(schema: 1, seed: 0, tick: 0, kind: kind, ribbon: 0, control: control, step: 1,
                             previous: "", next: "")
        }
        let waveMove: AuroraLoomRecord = record(.move, .wave)
        let phaseMove: AuroraLoomRecord = record(.move, .phase)
        #expect(AuroraLoomTutorialStep.wave(ribbon: 1).advanced(by: phaseMove, stage: .playing, hintRibbon: 2)
                == .wave(ribbon: 1))
        #expect(AuroraLoomTutorialStep.wave(ribbon: 1).advanced(by: waveMove, stage: .playing, hintRibbon: 2)
                == .phase(ribbon: 2))
        #expect(AuroraLoomTutorialStep.phase(ribbon: 2).advanced(by: waveMove, stage: .playing, hintRibbon: 0)
                == .phase(ribbon: 2))
        #expect(AuroraLoomTutorialStep.phase(ribbon: 2).advanced(by: phaseMove, stage: .playing, hintRibbon: 0)
                == .harmony)
        #expect(AuroraLoomTutorialStep.harmony.advanced(by: waveMove, stage: .playing, hintRibbon: 0) == .harmony)
        #expect(AuroraLoomTutorialStep.harmony.advanced(by: waveMove, stage: .won, hintRibbon: 0) == .done)
        #expect(AuroraLoomTutorialStep.wave(ribbon: 0).advanced(by: waveMove, stage: .won, hintRibbon: 0) == .done)
        #expect(AuroraLoomTutorialStep.done.advanced(by: record(.undo, .wave), stage: .playing, hintRibbon: 0) == .done)
        #expect(AuroraLoomTutorialStep.wave(ribbon: 1).advanced(by: record(.redo, .wave), stage: .playing,
                                                                 hintRibbon: 0) == .wave(ribbon: 1))
        #expect(AuroraLoomTutorialStep.wave(ribbon: 1).text
                == "Drag ribbon 2's anchor up or down to change its wave.")
        #expect(AuroraLoomTutorialStep.phase(ribbon: 1).text == "Turn ribbon 2's dial to change its phase.")
        #expect(AuroraLoomTutorialStep.harmony.text == "Bring every ribbon through the gold markers at all four gates.")
        #expect(AuroraLoomTutorialStep.done.text.isEmpty)
    }

    @Test func starRules() {
        for shortest in 1...12 {
            #expect(AuroraLoomProgress.stars(moves: shortest, shortest: shortest) == 3)
            #expect(AuroraLoomProgress.stars(moves: shortest + 1, shortest: shortest) == 2)
            #expect(AuroraLoomProgress.stars(moves: shortest + 2, shortest: shortest) == 2)
            #expect(AuroraLoomProgress.stars(moves: shortest + 3, shortest: shortest) == 1)
            #expect(AuroraLoomProgress.stars(moves: shortest + 5, shortest: shortest) == 1)
        }
    }

    @Test func scriptedCampaignOpensLevelByLevelWithStarsAndBests() {
        var random: SeededRandom = SeededRandom(seed: 2_305)
        var progress: AuroraLoomProgress = AuroraLoomProgress()
        #expect(progress.frontier == 1)
        #expect(progress.isOpen(1))
        #expect(!progress.isOpen(2))
        #expect(!progress.isOpen(0))
        let offsets: [Int] = [5, 1, 0]
        let expectedStars: [Int] = [1, 2, 3]
        for index in 0..<100 {
            let level: Int = index + 1
            let shortest: Int = Self.catalog[index].solution.shortest
            #expect(progress.isOpen(level))
            if level < 100 { #expect(!progress.isOpen(level + 1)) }
            // A seeded order of the three variants; the best and the stars never get worse.
            var order: [Int] = [0, 1, 2]
            let swap: Int = random.int(0...2)
            order.swapAt(0, swap)
            var bestMoves: Int = Int.max
            var bestStars: Int = 0
            for variant in order {
                let moves: Int = shortest + offsets[variant]
                progress.record(level: level, moves: moves, shortest: shortest)
                bestMoves = min(bestMoves, moves)
                bestStars = max(bestStars, expectedStars[variant])
                #expect(progress.solved[level] == AuroraLoomProgress.Result(bestMoves: bestMoves, stars: bestStars))
            }
            #expect(progress.solved[level] == AuroraLoomProgress.Result(bestMoves: shortest, stars: 3))
            #expect(progress.frontier == min(level + 1, 100))
        }
        #expect(progress.solved.count == 100)
        #expect(progress.frontier == 100)
        #expect(!progress.isOpen(101))
        progress.record(level: 101, moves: 1, shortest: 1)
        progress.record(level: 0, moves: 1, shortest: 1)
        #expect(progress.solved.count == 100)
    }

    @Test func everyLevelReachableByProgressAlone() {
        var progress: AuroraLoomProgress = AuroraLoomProgress()
        var opened: [Int] = [1]
        for level in 1...100 {
            #expect(progress.isOpen(level), "level \(level)")
            let worst: Int = Self.catalog[level - 1].solution.shortest + 5
            progress.record(level: level, moves: worst, shortest: Self.catalog[level - 1].solution.shortest)
            if level < 100 { opened.append(level + 1) }
        }
        #expect(opened.count == 100)
        for level in 1...100 { #expect(progress.isOpen(level)) }
    }

    @Test func bandsMatchTheManifest() {
        for entry in AuroraLoomManifest.entries {
            #expect(AuroraLoomProgress.band(of: entry.number) == entry.band, "level \(entry.number)")
        }
        #expect(AuroraLoomProgress.bandSize == 20)
        #expect(AuroraLoomProgress.band(of: 1) == 1)
        #expect(AuroraLoomProgress.band(of: 20) == 1)
        #expect(AuroraLoomProgress.band(of: 21) == 2)
        #expect(AuroraLoomProgress.band(of: 100) == 5)
    }

    @Test func dailyLevelCoversEveryDateFrom2026To2036() {
        var count: Int = 0
        var previous: Int? = nil
        var seen: Set<Int> = []
        for year in 2026...2036 {
            for month in 1...12 {
                for day in 1...31 {
                    let valid: Bool = day <= AuroraLoomProgress.daysIn(month: month, year: year)
                    let level: Int? = AuroraLoomProgress.dailyLevel(year: year, month: month, day: day)
                    if !valid {
                        #expect(level == nil, "\(year)-\(month)-\(day)")
                        continue
                    }
                    guard let level else {
                        Issue.record("nil for \(year)-\(month)-\(day)")
                        continue
                    }
                    #expect(level >= 1 && level <= 100)
                    #expect(AuroraLoomProgress.dailyLevel(year: year, month: month, day: day) == level)
                    #expect(level == (count * 37) % 100 + 1)
                    if let previous { #expect(level == (previous - 1 + 37) % 100 + 1) }
                    previous = level
                    seen.insert(level)
                    count += 1
                }
            }
        }
        #expect(count == 4_018)
        #expect(seen.count == 100)
    }

    @Test func dailyLevelKnownAndInvalidDates() {
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 1, day: 2) == 38)
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 1, day: 3) == 75)
        #expect(AuroraLoomProgress.dailyLevel(year: 2027, month: 1, day: 1) == (365 * 37) % 100 + 1)
        #expect(AuroraLoomProgress.dailyLevel(year: 2028, month: 2, day: 29) != nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 2, day: 29) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2100, month: 2, day: 29) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2400, month: 2, day: 29) != nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 2, day: 30) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 13, day: 1) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 0, day: 1) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 4, day: 31) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2026, month: 1, day: 0) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 10_000, month: 1, day: 1) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 0, month: 12, day: 31) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: -5, month: 1, day: 1) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 1900, month: 2, day: 29) == nil)
        #expect(AuroraLoomProgress.dailyLevel(year: 2000, month: 2, day: 29) != nil)
        // Dates before 2026 map with a non-negative modulo: d = −1 → (−37 mod 100) + 1 = 64.
        #expect(AuroraLoomProgress.dailyLevel(year: 2025, month: 12, day: 31) == 64)
        #expect(AuroraLoomProgress.dailyLevel(year: 2025, month: 12, day: 30) == ((-2 * 37) % 100 + 100) % 100 + 1)
        let bounds: [(Int, Int, Int)] = [(1, 1, 1), (1, 12, 31), (1900, 3, 1), (2000, 2, 29), (9_999, 12, 31)]
        for (year, month, day) in bounds {
            let d: Int = AuroraLoomProgress.daysFromCivil(year: year, month: month, day: day)
                - AuroraLoomProgress.daysFromCivil(year: 2026, month: 1, day: 1)
            let expected: Int = ((d * 37) % 100 + 100) % 100 + 1
            #expect(AuroraLoomProgress.dailyLevel(year: year, month: month, day: day) == expected, "\(year)")
        }
        // Known day counts: 0001-01-01 is 719,162 days before 1970-01-01; 2026-01-01 is day 20,454.
        #expect(AuroraLoomProgress.daysFromCivil(year: 1, month: 1, day: 1) == -719_162)
        #expect(AuroraLoomProgress.daysFromCivil(year: 2026, month: 1, day: 1) == 20_454)
        #expect(AuroraLoomProgress.daysFromCivil(year: 1970, month: 1, day: 1) == 0)
    }

    @Test func codableRoundTripAndDeterministicEncoding() throws {
        var random: SeededRandom = SeededRandom(seed: 2_305)
        var progress: AuroraLoomProgress = AuroraLoomProgress()
        for level in 1...60 {
            let shortest: Int = random.int(2...8)
            progress.record(level: level, moves: shortest + random.int(0...6), shortest: shortest)
        }
        let data: Data = try progress.encoded()
        let decoded: AuroraLoomProgress = try JSONDecoder().decode(AuroraLoomProgress.self, from: data)
        #expect(decoded == progress)
        #expect(decoded.digestBytes == progress.digestBytes)
        // The same progress built in a different order encodes to the same bytes.
        var reversed: AuroraLoomProgress = AuroraLoomProgress()
        for level in stride(from: 60, through: 1, by: -1) {
            if let result = progress.solved[level] {
                reversed.record(level: level, moves: result.bestMoves, shortest: result.bestMoves)
            }
        }
        reversed.frontier = progress.frontier
        var expected: AuroraLoomProgress = AuroraLoomProgress()
        for level in 1...60 {
            if let result = progress.solved[level] {
                expected.record(level: level, moves: result.bestMoves, shortest: result.bestMoves)
            }
        }
        #expect(try reversed.encoded() == expected.encoded())
        #expect(reversed.digestBytes == expected.digestBytes)
        for _ in 0..<5 { #expect(try progress.encoded() == data) }
        let text: String = String(decoding: try AuroraLoomProgress().encoded(), as: UTF8.self)
        #expect(text == "{\"frontier\":1,\"solved\":[]}")
        // Modes and tutorial steps round trip.
        let modes: [AuroraLoomMode] = [.campaign, .practice, .daily(level: 38)]
        for mode in modes {
            #expect(try JSONDecoder().decode(AuroraLoomMode.self, from: JSONEncoder().encode(mode)) == mode)
        }
        let steps: [AuroraLoomTutorialStep] = [.wave(ribbon: 2), .phase(ribbon: 0), .harmony, .done]
        for step in steps {
            #expect(try JSONDecoder().decode(AuroraLoomTutorialStep.self, from: JSONEncoder().encode(step)) == step)
        }
    }

    @Test func decodingRejectsInvalidProgress() {
        let bad: [String] = [
            "{\"frontier\":0,\"solved\":[]}",
            "{\"frontier\":101,\"solved\":[]}",
            "{\"frontier\":2,\"solved\":[{\"level\":0,\"bestMoves\":3,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"level\":1,\"bestMoves\":3,\"stars\":4}]}",
            "{\"frontier\":2,\"solved\":[{\"level\":1,\"bestMoves\":-1,\"stars\":3}]}",
            "{\"frontier\":2,\"solved\":[{\"level\":1,\"bestMoves\":3,\"stars\":3},{\"level\":1,\"bestMoves\":3,\"stars\":3}]}",
        ]
        for text in bad {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(AuroraLoomProgress.self, from: Data(text.utf8))
            }
        }
    }
}
