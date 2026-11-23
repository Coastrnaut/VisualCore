// BackwardsAuroraWitnessTests — feature 392 (R02-G10-02) T-R02G1002-005 (FR-R02G1002-004; clarification Q4). Witnesses
// of generated catalog levels 1 (band 1, tutorial), 21 (band 2), 41 (band 3) and 61 (band 4), built once per process.
// The stored form round-trips byte for byte with one trailing newline; the digest is the first 16 hex characters of
// SHA-256 over the samples as signed bytes (checked against a hand-computed value); digests and fingerprints agree with
// a replay; the near miss replays as recorded (not won, bad bends above 0); edited actions, digests, fingerprints,
// level, smallest, bound, near miss, difficulty (work included) and number are refused naming the part; a different
// winning sequence is refused by the solver re-run; newer and damaged stored forms are refused; `make` refuses a bound
// or difficulty that is not the solution's. Explicit types, plain loops (CI type-check rule), short runs, no wall-clock
// asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import BackwardsAuroraCore

/// The generated levels and witnesses the tests share, built once.
struct BackwardsAuroraWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: BackwardsAuroraGenerated, witness: BackwardsAuroraWitness)]

    static let shared: BackwardsAuroraWitnessFixtures = make()

    private static func make() -> BackwardsAuroraWitnessFixtures {
        let entries: [BackwardsAuroraManifestEntry] = BackwardsAuroraManifest.entries
        var cases: [(generated: BackwardsAuroraGenerated, witness: BackwardsAuroraWitness)] = []
        for index in [0, 20, 40, 60] {
            let generated: BackwardsAuroraGenerated
            do { generated = try BackwardsAuroraGenerator.generate(entries[index]) } catch {
                preconditionFailure("level \(entries[index].number) does not generate: \(error)")
            }
            do { cases.append((generated, try BackwardsAuroraWitness.make(generated))) } catch {
                preconditionFailure("level \(generated.entry.number) has no witness: \(error)")
            }
        }
        return BackwardsAuroraWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct BackwardsAuroraWitnessParts {
    var number: Int
    var level: BackwardsAuroraLevel
    var actions: [BackwardsAuroraAction]
    var digests: [String]
    var fingerprints: [String]
    var smallest: Int
    var bound: BackwardsAuroraBound
    var nearMiss: BackwardsAuroraCounterexample
    var difficulty: BackwardsAuroraDifficulty
    var skipped: Int

    init(_ w: BackwardsAuroraWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        smallest = w.smallest
        bound = w.bound
        nearMiss = w.nearMiss
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: BackwardsAuroraWitness {
        BackwardsAuroraWitness(number: number, level: level, actions: actions, digests: digests,
                               fingerprints: fingerprints, smallest: smallest, bound: bound, nearMiss: nearMiss,
                               difficulty: difficulty, skipped: skipped)
    }
}

/// `d` with its reversed samples and work changed by the given amounts.
func backwardsAuroraDifficulty(_ d: BackwardsAuroraDifficulty, reversedBy reversed: Int = 0,
                               workBy work: Int = 0) -> BackwardsAuroraDifficulty {
    BackwardsAuroraDifficulty(smallest: d.smallest, length: d.length, checkpoints: d.checkpoints,
                              reversedSamples: d.reversedSamples + reversed, longestSection: d.longestSection,
                              badBends: d.badBends, bendLimit: d.bendLimit, breakingMargin: d.breakingMargin,
                              work: d.work + work)
}

@Suite("Backwards Aurora witness")
struct BackwardsAuroraWitnessTests {
    let fixtures: BackwardsAuroraWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: BackwardsAuroraWitness) -> BackwardsAuroraError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> BackwardsAuroraError? {
        do {
            _ = try BackwardsAuroraWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: BackwardsAuroraWitness,
                _ change: (inout BackwardsAuroraWitnessParts) -> Void) -> BackwardsAuroraWitness {
        var parts = BackwardsAuroraWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: BackwardsAuroraWitness, key: String, line: String?) -> Data {
        let text: String = String(decoding: witness.encoded(), as: UTF8.self)
        var lines: [String] = text.components(separatedBy: "\n")
        let prefix: String = "  \"\(key)\" : "
        guard let index = lines.firstIndex(where: { $0.hasPrefix(prefix) }) else { return Data(text.utf8) }
        if let line {
            let comma: String = lines[index].hasSuffix(",") ? "," : ""
            lines[index] = prefix + line + comma
        } else {
            lines.remove(at: index)
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// The play after `begin` (and `dismissTutorial`) and `actions` on `level`.
    func played(_ level: BackwardsAuroraLevel, _ actions: [BackwardsAuroraAction]) throws -> BackwardsAuroraPlay {
        var play = BackwardsAuroraPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    @Test("the fixtures cover bands 1 to 4 and a tutorial")
    func fixturesCover() {
        #expect(fixtures.cases.count == 4)
        #expect(fixtures.cases[0].generated.level.tutorial)
        var bands: [Int] = []
        for (generated, _) in fixtures.cases { bands.append(generated.entry.band) }
        #expect(bands == [1, 2, 3, 4])
        for index in 1..<fixtures.cases.count { #expect(!fixtures.cases[index].generated.level.tutorial) }
    }

    @Test("the stored form round-trips byte for byte with one trailing newline")
    func roundTripByteForByte() throws {
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: BackwardsAuroraWitness = try BackwardsAuroraWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            let text: String = String(decoding: data, as: UTF8.self)
            #expect(text.contains("\n  \"schema\" : 1,\n"))
            #expect(text.hasPrefix("{\n  \"actions\" : "))
        }
    }

    @Test("the witness carries the solver's actions, bound, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == BackwardsAuroraGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.solution.actions)
            #expect(witness.smallest == generated.solution.smallest)
            #expect(witness.smallest == witness.actions.count)
            #expect(witness.bound == generated.bound)
            #expect(witness.bound.smallest == witness.smallest)
            #expect(witness.bound.badBends == 4 * witness.smallest)
            #expect(BackwardsAuroraBandProfile.of(band: generated.entry.band).reversals.contains(witness.smallest))
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.work == generated.solution.work)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("digests and fingerprints agree with a replay that wins on the last reversal")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            #expect(witness.digests.count == witness.smallest)
            #expect(witness.fingerprints.count == witness.smallest + 1)
            var play: BackwardsAuroraPlay = try played(witness.level, [])
            var fingerprints: [String] = [play.fingerprint]
            var digests: [String] = []
            for action in witness.actions {
                #expect(play.stage == .playing)
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(BackwardsAuroraWitness.digest(play.wave))
            }
            #expect(play.stage == .won)
            #expect(play.spent == witness.smallest)
            #expect(play.spent <= witness.level.budget)
            #expect(play.wave == witness.level.target || witness.level.wins(play.wave))
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            #expect(BackwardsAuroraSolver.wins(witness.level, actions: witness.actions))
            for digest in witness.digests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
        }
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over the samples as signed bytes")
    func digestLayout() throws {
        // printf '\x01\xff\x00\x40\xc0\x00\x00\x00\x00\x00\x00\x00' | shasum -a 256 → 77b7258bc6637115…
        let samples: [Int] = [1, -1, 0, 64, -64, 0, 0, 0, 0, 0, 0, 0]
        let wave: BackwardsAuroraWave = try BackwardsAuroraWave(samples)
        #expect(BackwardsAuroraWitness.digest(wave) == "77b7258bc6637115")
        let bytes: [UInt8] = [0x01, 0xFF, 0x00, 0x40, 0xC0, 0, 0, 0, 0, 0, 0, 0]
        #expect(BackwardsAuroraWitness.digest(wave) == String(StableHash.sha256Hex(bytes).prefix(16)))
        var changed: [Int] = samples
        changed[11] = 1
        let other: BackwardsAuroraWave = try BackwardsAuroraWave(changed)
        #expect(BackwardsAuroraWitness.digest(other) != BackwardsAuroraWitness.digest(wave))
    }

    @Test("the near miss replays as recorded: not won, bad bends above 0")
    func nearMissReplays() throws {
        for (_, witness) in fixtures.cases {
            let n: BackwardsAuroraCounterexample = witness.nearMiss
            #expect(n.actions == Array(witness.actions.dropLast()))
            #expect(n.badBends > 0)
            #expect(n.badBends >= 4)
            let near: BackwardsAuroraPlay = try played(witness.level, n.actions)
            #expect(near.stage == .playing)
            #expect(!witness.level.wins(near.wave))
            #expect(BackwardsAuroraSolver.badBends(near.wave, limit: witness.level.bendLimit) == n.badBends)
            #expect(!near.wave.isSmooth(limit: witness.level.bendLimit))
            #expect(near.fingerprint == witness.fingerprints[witness.smallest - 1])
            #expect(!BackwardsAuroraSolver.wins(witness.level, actions: n.actions))
        }
    }

    @Test("edited actions are refused")
    func editedActionsRefused() {
        let w: BackwardsAuroraWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.actions.removeLast() }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions.append(w.actions[0]) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions[0] = .reverse(0, w.level.count) }) == .witness("actions"))
    }

    @Test("edited digests are refused")
    func editedDigestsRefused() {
        let w: BackwardsAuroraWitness = fixtures.cases[0].witness
        let first: String = w.digests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.digests[0] = flipped }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.digests.removeLast() }) == .witness("digests"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: BackwardsAuroraWitness = fixtures.cases[1].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
    }

    @Test("an edited level is refused")
    func editedLevelRefused() throws {
        let w: BackwardsAuroraWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let budget: Int = w.level.budget
        let changedBudget: Int = budget == BackwardsAuroraLevel.budgets.upperBound ? budget - 1 : budget + 1
        let changed: String = text.replacingOccurrences(of: "\"budget\" : \(budget),",
                                                        with: "\"budget\" : \(changedBudget),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
        // A re-fingerprinted level that is not the generator's candidate.
        let l: BackwardsAuroraLevel = w.level
        let other = try BackwardsAuroraLevel(id: l.id, seed: l.seed, difficulty: l.difficulty, opening: l.opening,
                                             target: l.target, checkpoints: l.checkpoints, bendLimit: l.bendLimit,
                                             breakingLimit: l.breakingLimit, shortest: l.shortest,
                                             longest: l.longest, budget: changedBudget, tutorial: l.tutorial)
        #expect(refusal(edited(w) { $0.level = other }) == .witness("candidate"))
    }

    @Test("edited smallest, bound and near miss are refused")
    func editedSolverValuesRefused() {
        let w: BackwardsAuroraWitness = fixtures.cases[1].witness
        #expect(refusal(edited(w) { $0.smallest += 1 }) == .witness("smallest"))
        let more = BackwardsAuroraBound(badBends: w.bound.badBends + 1)
        #expect(refusal(edited(w) { $0.bound = more }) == .witness("bound"))
        let fewer = BackwardsAuroraBound(badBends: w.bound.badBends - 4)
        #expect(refusal(edited(w) { $0.bound = fewer }) == .witness("bound"))
        let n: BackwardsAuroraCounterexample = w.nearMiss
        let bent = BackwardsAuroraCounterexample(actions: n.actions, badBends: n.badBends + 1)
        #expect(refusal(edited(w) { $0.nearMiss = bent }) == .witness("near-miss"))
        let smooth = BackwardsAuroraCounterexample(actions: n.actions, badBends: 0)
        #expect(refusal(edited(w) { $0.nearMiss = smooth }) == .witness("near-miss"))
        let shorter = BackwardsAuroraCounterexample(actions: Array(n.actions.dropLast()), badBends: n.badBends)
        #expect(refusal(edited(w) { $0.nearMiss = shorter }) == .witness("near-miss"))
        let whole = BackwardsAuroraCounterexample(actions: w.actions, badBends: n.badBends)
        #expect(refusal(edited(w) { $0.nearMiss = whole }) == .witness("near-miss"))
    }

    @Test("edited difficulty, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: BackwardsAuroraWitness = fixtures.cases[0].witness
        let d: BackwardsAuroraDifficulty = w.difficulty
        let reversed: BackwardsAuroraDifficulty = backwardsAuroraDifficulty(d, reversedBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = reversed }) == .witness("difficulty"))
        let length = BackwardsAuroraDifficulty(smallest: d.smallest, length: d.length + 1, checkpoints: d.checkpoints,
                                               reversedSamples: d.reversedSamples, longestSection: d.longestSection,
                                               badBends: d.badBends, bendLimit: d.bendLimit,
                                               breakingMargin: d.breakingMargin, work: d.work)
        #expect(refusal(edited(w) { $0.difficulty = length }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = BackwardsAuroraGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    /// Feature 382's convergence lesson: decoding re-runs the solver, so an edited solver work count and a different
    /// winning sequence of the same length (the witness's reversals in another order) are refused.
    @Test("an edited solver result and a different winning sequence are refused")
    func editedSolverResultRefused() {
        let w: BackwardsAuroraWitness = fixtures.cases[0].witness
        let more: BackwardsAuroraDifficulty = backwardsAuroraDifficulty(w.difficulty, workBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = more }) == .witness("solution"))
        let less: BackwardsAuroraDifficulty = backwardsAuroraDifficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = less }) == .witness("solution"))
        var reordered: BackwardsAuroraWitness?
        for witness in fixtures.cases.map(\.witness) where reordered == nil {
            guard witness.actions.count >= 2 else { continue }
            let swapped: [BackwardsAuroraAction] = Array(witness.actions.reversed())
            guard swapped != witness.actions else { continue }
            // A consistent witness of the reordered reversals: replayed digests, fingerprints and near miss, the same
            // difficulty (the same sections), so only the solver re-run can tell it apart.
            guard let run = BackwardsAuroraWitness.replay(witness.level, actions: swapped), run.play.stage == .won,
                  !run.endedEarly,
                  let near = BackwardsAuroraWitness.counterexample(witness.level, actions: Array(swapped.dropLast()))
            else { continue }
            reordered = BackwardsAuroraWitness(number: witness.number, level: witness.level, actions: swapped,
                                               digests: run.digests, fingerprints: run.fingerprints,
                                               smallest: witness.smallest, bound: witness.bound, nearMiss: near,
                                               difficulty: witness.difficulty, skipped: witness.skipped)
        }
        #expect(reordered != nil, "no fixture witness has a reorderable winning sequence")
        if let reordered {
            #expect(BackwardsAuroraSolver.wins(reordered.level, actions: reordered.actions))
            #expect(refusal(reordered) == .witness("solution"))
        }
    }

    @Test("newer and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: BackwardsAuroraWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .malformed("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .malformed("unreadable"))
        #expect(refusal(storedText(w, key: "smallest", line: "\"none\"")) == .malformed("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .malformed("unreadable"))
        #expect(refusal(Data()) == .malformed("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .malformed("unreadable"))
        #expect(BackwardsAuroraError.witness("digests").reasonCode == "r02-g10.witness")
    }

    @Test("make refuses a losing solution, a wrong bound and a wrong difficulty")
    func makeRefuses() {
        let g: BackwardsAuroraGenerated = fixtures.cases[0].generated
        let s: BackwardsAuroraSolution = g.solution
        let short = BackwardsAuroraSolution(smallest: s.smallest, actions: Array(s.actions.dropLast()), work: s.work)
        let losing = BackwardsAuroraGenerated(entry: g.entry, level: g.level, solution: short, bound: g.bound,
                                              difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: BackwardsAuroraError.witness("actions")) { try BackwardsAuroraWitness.make(losing) }
        let wider = BackwardsAuroraBound(badBends: g.bound.badBends + 1)
        let wrongBound = BackwardsAuroraGenerated(entry: g.entry, level: g.level, solution: s, bound: wider,
                                                  difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: BackwardsAuroraError.witness("bound")) { try BackwardsAuroraWitness.make(wrongBound) }
        let other: BackwardsAuroraDifficulty = backwardsAuroraDifficulty(g.difficulty, workBy: 1)
        let wrong = BackwardsAuroraGenerated(entry: g.entry, level: g.level, solution: s, bound: g.bound,
                                             difficulty: other, skipped: g.skipped)
        #expect(throws: BackwardsAuroraError.witness("difficulty")) { try BackwardsAuroraWitness.make(wrong) }
    }
}
