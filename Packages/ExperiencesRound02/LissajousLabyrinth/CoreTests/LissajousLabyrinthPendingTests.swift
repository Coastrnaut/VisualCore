// LissajousLabyrinthPendingTests — feature 314 (R02-G02-04) T-R02G0204-003 (FR-R02G0204-006; SC-R02G0204-004; research
// R7). Pending dial values: every one of the 100 certified levels is won by setting its certified solution's final dials
// as pending and applying the actions in order, in exactly the certified shortest number of actions with no refusal; the
// frequency swap; the no-coprime-order case refused by the kernel; stepping wraps both ways; setting the current value
// removes it; clear. The certified levels are read from the witness files in docs/games/lissajous-labyrinth/levels/,
// which LissajousLabyrinthCatalogTests proves equal to the regenerated catalog byte for byte. Test data uses explicit
// types and plain loops (CI type-check rule).
@testable import LissajousLabyrinthCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let pendingWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/lissajous-labyrinth/levels", isDirectory: true)

/// The 100 certified witnesses, decoded (and so re-verified) once per test process, in manifest order.
private let pendingWitnesses: Result<[LissajousLabyrinthWitness], any Error> = Result {
    var result: [LissajousLabyrinthWitness] = []
    for entry in LissajousLabyrinthManifest.entries {
        let name: String = String(LissajousLabyrinthGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: pendingWitnessDirectory.appendingPathComponent(name))
        result.append(try LissajousLabyrinthWitness.decode(data))
    }
    return result
}

@Suite struct LissajousLabyrinthPendingTests {
    /// A playing play of a level starting at `start` whose one checkpoint is far away (so the start does not win).
    static func play(start: LissajousLabyrinthDials) throws -> LissajousLabyrinthPlay {
        let far: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 64)
        let level: LissajousLabyrinthLevel = try LissajousLabyrinthLevel(
            id: "pending", seed: 314, band: 1, amplitudes: [2, 2, 2], frequencyC: 1, start: start, checkpoints: [far],
            obstacles: [], allowance: 12)
        var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: level)
        try play.handle(.begin)
        return play
    }

    /// Wins the certified levels of `band` (1 … 5) through pending values and one Apply.
    func winBand(_ band: Int) throws {
        let witnesses: [LissajousLabyrinthWitness] = try pendingWitnesses.get()
        #expect(witnesses.count == 100)
        var checked: Int = 0
        for witness in witnesses where LissajousLabyrinthManifest.entries[witness.number - 1].band == band {
            var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: witness.level)
            try play.handle(.begin)
            if witness.level.tutorial { try play.handle(.dismissTutorial) }
            var final: LissajousLabyrinthDials = witness.level.start
            for action in witness.actions { final[action.dial] = action.value }
            var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
            for dial in LissajousLabyrinthDial.allCases { pending.set(dial, final[dial], current: play.dials) }
            let actions: [LissajousLabyrinthAction] = pending.actions(from: play.dials)
            #expect(actions.count == witness.actions.count, "level \(witness.number)")
            for action in actions {
                try play.apply(action, expecting: play.fingerprint)
            }
            #expect(play.stage == .won, "level \(witness.number)")
            #expect(play.spent == witness.actions.count, "level \(witness.number)")
            #expect(play.dials == final, "level \(witness.number)")
            checked += 1
        }
        #expect(checked == 20)
    }

    @Test func certifiedLevelsBand1WonThroughPending() throws { try winBand(1) }
    @Test func certifiedLevelsBand2WonThroughPending() throws { try winBand(2) }
    @Test func certifiedLevelsBand3WonThroughPending() throws { try winBand(3) }
    @Test func certifiedLevelsBand4WonThroughPending() throws { try winBand(4) }
    @Test func certifiedLevelsBand5WonThroughPending() throws { try winBand(5) }

    @Test func actionsFollowDefaultOrder() {
        let current: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 4, phaseC: 5)
        var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
        pending.set(.phaseC, 9, current: current)
        pending.set(.phaseA, 1, current: current)
        pending.set(.frequencyB, 7, current: current)
        pending.set(.frequencyA, 5, current: current)
        let expected: [LissajousLabyrinthAction] = [
            LissajousLabyrinthAction(dial: .frequencyA, value: 5), LissajousLabyrinthAction(dial: .frequencyB, value: 7),
            LissajousLabyrinthAction(dial: .phaseA, value: 1), LissajousLabyrinthAction(dial: .phaseC, value: 9),
        ]
        #expect(pending.actions(from: current) == expected)
    }

    @Test func frequencyBFirstWhenOnlyThatOrderIsCoprime() throws {
        // (2, 3) → (3, 5): A first passes (3, 3), not coprime; B first passes (2, 5), coprime.
        let current: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 0, phaseC: 0)
        var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
        pending.set(.frequencyA, 3, current: current)
        pending.set(.frequencyB, 5, current: current)
        pending.set(.phaseA, 6, current: current)
        let actions: [LissajousLabyrinthAction] = pending.actions(from: current)
        let expected: [LissajousLabyrinthAction] = [
            LissajousLabyrinthAction(dial: .frequencyB, value: 5), LissajousLabyrinthAction(dial: .frequencyA, value: 3),
            LissajousLabyrinthAction(dial: .phaseA, value: 6),
        ]
        #expect(actions == expected)
        var play: LissajousLabyrinthPlay = try Self.play(start: current)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.dials == LissajousLabyrinthDials(frequencyA: 3, frequencyB: 5, phaseA: 6, phaseC: 0))
        #expect(play.spent == 3)
    }

    @Test func noCoprimeOrderKeepsDefaultOrderAndIsRefused() throws {
        // (2, 3) → (3, 4): A first passes (3, 3) and B first passes (2, 4); neither is coprime.
        let current: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 0, phaseC: 0)
        var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
        pending.set(.frequencyA, 3, current: current)
        pending.set(.frequencyB, 4, current: current)
        let actions: [LissajousLabyrinthAction] = pending.actions(from: current)
        let expected: [LissajousLabyrinthAction] = [
            LissajousLabyrinthAction(dial: .frequencyA, value: 3), LissajousLabyrinthAction(dial: .frequencyB, value: 4),
        ]
        #expect(actions == expected)
        var play: LissajousLabyrinthPlay = try Self.play(start: current)
        let before: LissajousLabyrinthPlay = play
        #expect(throws: LissajousLabyrinthError.move("not-coprime")) {
            try play.apply(actions[0], expecting: play.fingerprint)
        }
        #expect(play == before)
    }

    @Test func stepWrapsBothWays() {
        let current: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 9, frequencyB: 1, phaseA: 15, phaseC: 0)
        var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
        pending.step(.frequencyA, by: 1, current: current)
        pending.step(.frequencyB, by: -1, current: current)
        pending.step(.phaseA, by: 1, current: current)
        pending.step(.phaseC, by: -1, current: current)
        #expect(pending.values == [.frequencyA: 1, .frequencyB: 9, .phaseA: 0, .phaseC: 15])
        // Stepping continues from the pending value: 1 − 1 → 9 is the current value again, so it is removed.
        pending.step(.frequencyA, by: -1, current: current)
        #expect(pending.values[.frequencyA] == nil)
        pending.step(.phaseA, by: 2, current: current)
        #expect(pending.values[.phaseA] == 2)
    }

    @Test func setClampsFrequenciesAndWrapsPhases() {
        let current: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 4, phaseC: 5)
        var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
        pending.set(.frequencyA, 12, current: current)
        pending.set(.frequencyB, 0, current: current)
        pending.set(.phaseA, 17, current: current)
        pending.set(.phaseC, -1, current: current)
        #expect(pending.values == [.frequencyA: 9, .frequencyB: 1, .phaseA: 1, .phaseC: 15])
    }

    @Test func settingCurrentValueRemovesIt() {
        let current: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 4, phaseC: 5)
        var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
        #expect(pending.isEmpty)
        pending.set(.phaseA, 4, current: current)
        #expect(pending.isEmpty)
        pending.set(.phaseA, 7, current: current)
        #expect(!pending.isEmpty)
        #expect(pending.values == [.phaseA: 7])
        pending.set(.phaseA, 4, current: current)
        #expect(pending.isEmpty)
        #expect(pending.actions(from: current).isEmpty)
    }

    @Test func clearDropsEverything() {
        let current: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 4, phaseC: 5)
        var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
        pending.set(.frequencyA, 5, current: current)
        pending.set(.phaseC, 1, current: current)
        #expect(pending.values.count == 2)
        pending.clear()
        #expect(pending.isEmpty)
        #expect(pending == LissajousLabyrinthPending())
        #expect(pending.actions(from: current).isEmpty)
    }

    @Test func pendingEqualToChangedCurrentYieldsNoAction() {
        let before: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 4, phaseC: 5)
        var pending: LissajousLabyrinthPending = LissajousLabyrinthPending()
        pending.set(.phaseA, 7, current: before)
        let after: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 7, phaseC: 5)
        #expect(pending.actions(from: after).isEmpty)
    }
}
