// ChronoConstellatorWitnessTests — feature 352 (R02-G06-02) T-R02G0602-005 (FR-R02G0602-004; SC-R02G0602-003, 005;
// clarification Q4). Witnesses of generated catalog levels, two per band (levels 1, 2, 21, 22, 41, 42, 61, 62, 81, 82;
// level 1 has a tutorial, band 1 needs one edit, bands 2 … 5 at least two). The stored form round-trips byte for byte
// with one trailing newline; the actions have the canonical shape; digests and fingerprints agree with a replay; the
// counterexamples fail as recorded and the near miss of a one-edit solution is the unedited run; edited actions, digests,
// win tick, fingerprints, level, solver values, counterexamples, difficulty, number and skipped are refused; newer and
// damaged stored forms are refused; `make` refuses a solution that does not win and a difficulty that is not the
// solution's. Explicit types, plain loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import ChronoConstellatorCore

/// The generated levels and witnesses the tests share, built once.
struct ChronoConstellatorWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: ChronoConstellatorGenerated, witness: ChronoConstellatorWitness)]
    /// The index in ``cases`` of a level whose smallest edit count is 1.
    let one: Int
    /// The index in ``cases`` of a level whose smallest edit count is at least 2.
    let many: Int

    static let shared: ChronoConstellatorWitnessFixtures = make()

    private static func make() -> ChronoConstellatorWitnessFixtures {
        let entries: [ChronoConstellatorManifestEntry] = ChronoConstellatorManifest.entries
        var cases: [(generated: ChronoConstellatorGenerated, witness: ChronoConstellatorWitness)] = []
        for index in [0, 1, 20, 21, 40, 41, 60, 61, 80, 81] {
            let generated: ChronoConstellatorGenerated
            do { generated = try ChronoConstellatorGenerator.generate(entries[index]) } catch {
                preconditionFailure("level \(entries[index].number) does not generate: \(error)")
            }
            do { cases.append((generated, try ChronoConstellatorWitness.make(generated))) } catch {
                preconditionFailure("level \(generated.entry.number) has no witness: \(error)")
            }
        }
        let one: Int = cases.firstIndex { $0.generated.solution.lowerBound == 1 } ?? -1
        let many: Int = cases.firstIndex { $0.generated.solution.lowerBound >= 2 } ?? -1
        return ChronoConstellatorWitnessFixtures(cases: cases, one: one, many: many)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct ChronoConstellatorWitnessParts {
    var number: Int
    var level: ChronoConstellatorLevel
    var actions: [ChronoConstellatorAction]
    var winTick: Int
    var digests: [String]
    var fingerprints: [String]
    var lowerBound: Int
    var window: Int
    var windows: Int
    var blocked: Int
    var unedited: ChronoConstellatorCounterexample
    var nearMiss: ChronoConstellatorCounterexample
    var difficulty: ChronoConstellatorDifficulty
    var skipped: Int

    init(_ w: ChronoConstellatorWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        winTick = w.winTick
        digests = w.digests
        fingerprints = w.fingerprints
        lowerBound = w.lowerBound
        window = w.window
        windows = w.windows
        blocked = w.blocked
        unedited = w.unedited
        nearMiss = w.nearMiss
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: ChronoConstellatorWitness {
        ChronoConstellatorWitness(number: number, level: level, actions: actions, winTick: winTick, digests: digests,
                                  fingerprints: fingerprints, lowerBound: lowerBound, window: window, windows: windows,
                                  blocked: blocked, unedited: unedited, nearMiss: nearMiss, difficulty: difficulty,
                                  skipped: skipped)
    }
}

@Suite("Chrono Constellator witness")
struct ChronoConstellatorWitnessTests {
    let fixtures: ChronoConstellatorWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: ChronoConstellatorWitness) -> ChronoConstellatorError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> ChronoConstellatorError? {
        do {
            _ = try ChronoConstellatorWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: ChronoConstellatorWitness,
                _ change: (inout ChronoConstellatorWitnessParts) -> Void) -> ChronoConstellatorWitness {
        var parts = ChronoConstellatorWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: ChronoConstellatorWitness, key: String, line: String?) -> Data {
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

    /// The play after replaying `actions` on `level` from `begin` (and `dismissTutorial`).
    func played(_ level: ChronoConstellatorLevel, _ actions: [ChronoConstellatorAction]) throws -> ChronoConstellatorPlay {
        var play = ChronoConstellatorPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    @Test("the fixtures cover every band, one-edit and multi-edit levels and a tutorial")
    func fixturesCover() {
        #expect(fixtures.cases.count == 10)
        #expect(fixtures.one >= 0)
        #expect(fixtures.many >= 0)
        #expect(fixtures.cases[0].generated.level.tutorial)
        var bands: Set<Int> = []
        for (generated, _) in fixtures.cases { bands.insert(generated.entry.band) }
        #expect(bands == [1, 2, 3, 4, 5])
    }

    @Test("the stored form round-trips byte for byte with one trailing newline")
    func roundTripByteForByte() throws {
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: ChronoConstellatorWitness = try ChronoConstellatorWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            let text: String = String(decoding: data, as: UTF8.self)
            #expect(text.contains("\n  \"schema\" : 1,\n"))
        }
    }

    @Test("the actions are the solution's phase changes in star order, then one step of the tick limit")
    func actionsAreCanonical() {
        for (generated, witness) in fixtures.cases {
            var expected: [ChronoConstellatorAction] = []
            for star in generated.level.stars.indices
            where generated.solution.phases[star] != generated.level.stars[star].phase {
                expected.append(.phase(star, generated.solution.phases[star]))
            }
            #expect(expected.count == generated.solution.lowerBound)
            expected.append(.step(generated.level.tickLimit))
            #expect(witness.actions == expected)
            #expect(ChronoConstellatorWitness.actions(for: generated.solution, level: generated.level) == expected)
            #expect(witness.number == generated.entry.number)
            #expect(witness.skipped == generated.skipped)
            #expect(witness.lowerBound == generated.solution.lowerBound)
            #expect(witness.window == generated.solution.window)
            #expect(witness.windows == generated.solution.windows)
            #expect(witness.blocked == generated.solution.blocked)
            #expect(witness.difficulty == generated.difficulty)
        }
    }

    @Test("digests, fingerprints and win tick agree with a replay")
    func partsAgreeWithReplay() throws {
        for (generated, witness) in fixtures.cases {
            #expect(witness.winTick == generated.difficulty.winTick)
            #expect(witness.digests.count == witness.winTick)
            for digest in witness.digests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
            var play = ChronoConstellatorPlay(level: witness.level)
            try play.handle(.begin)
            if witness.level.tutorial { try play.handle(.dismissTutorial) }
            var fingerprints: [String] = [play.fingerprint]
            for action in witness.actions {
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
            }
            #expect(play.stage == .won)
            #expect(play.tick == witness.winTick)
            #expect(fingerprints == witness.fingerprints)
            #expect(witness.digests.last == ChronoConstellatorWitness.digest(play.positions))
            for tick in [1, witness.winTick / 2 + 1, witness.winTick] {
                let positions: [Int] = play.timeline.positions(at: tick, level: witness.level)
                #expect(witness.digests[tick - 1] == ChronoConstellatorWitness.digest(positions))
            }
        }
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over two-byte big-endian cells")
    func digestLayout() {
        let bytes: [UInt8] = [0, 3, 0, 119, 0, 0]
        #expect(ChronoConstellatorWitness.digest([3, 119, 0]) == String(StableHash.sha256Hex(bytes).prefix(16)))
        #expect(ChronoConstellatorWitness.digest([3, 119, 0]) != ChronoConstellatorWitness.digest([119, 3, 0]))
    }

    @Test("the counterexamples fail as recorded")
    func counterexamplesFailAsRecorded() throws {
        for (generated, witness) in fixtures.cases {
            let step: ChronoConstellatorAction = .step(witness.level.tickLimit)
            #expect(witness.unedited.actions == [step])
            var nearMiss: [ChronoConstellatorAction] = Array(witness.actions.dropLast(2))
            nearMiss.append(step)
            #expect(witness.nearMiss.actions == nearMiss)
            #expect(witness.nearMiss.actions.count == generated.solution.lowerBound)
            for example in [witness.unedited, witness.nearMiss] {
                let play: ChronoConstellatorPlay = try played(witness.level, example.actions)
                #expect(play.stage == .failed)
                #expect(play.failure == example.reason)
                #expect(play.tick == example.tick)
            }
        }
    }

    @Test("the near miss of a one-edit solution is the unedited counterexample")
    func nearMissOfOneEdit() {
        let one: ChronoConstellatorWitness = fixtures.cases[fixtures.one].witness
        #expect(one.nearMiss == one.unedited)
        let many: ChronoConstellatorWitness = fixtures.cases[fixtures.many].witness
        #expect(many.nearMiss.actions.count == many.actions.count - 1)
        #expect(many.nearMiss != many.unedited)
    }

    @Test("edited actions are refused")
    func editedActionsRefused() {
        let w: ChronoConstellatorWitness = fixtures.cases[fixtures.many].witness
        let limit: Int = w.level.tickLimit
        #expect(refusal(edited(w) { $0.actions.removeLast() }) == .witness("replay"))
        #expect(refusal(edited(w) { $0.actions[$0.actions.count - 1] = .step(w.winTick - 1) }) == .witness("replay"))
        if w.winTick < limit {
            #expect(refusal(edited(w) { $0.actions[$0.actions.count - 1] = .step(w.winTick) }) == .witness("actions"))
        }
        #expect(refusal(edited(w) { $0.actions.swapAt(0, 1) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions.removeFirst() }) == .witness("replay"))
        #expect(refusal(edited(w) { $0.actions.append($0.actions[0]) }) == .witness("replay"))
        // An extra hold that keeps the win is not the canonical witness.
        var extra: [ChronoConstellatorAction] = w.actions
        extra.insert(.hold(0, limit, 1), at: extra.count - 1)
        let error: ChronoConstellatorError? = refusal(edited(w) { $0.actions = extra })
        #expect(error == .witness("actions") || error == .witness("replay"))
    }

    @Test("edited digests and win tick are refused")
    func editedDigestsRefused() {
        let w: ChronoConstellatorWitness = fixtures.cases[fixtures.one].witness
        let first: String = w.digests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.digests[0] = flipped }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.digests.removeLast() }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.winTick += 1 }) == .witness("win-tick"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: ChronoConstellatorWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
    }

    @Test("an edited level is refused")
    func editedLevelRefused() {
        let w: ChronoConstellatorWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let limit: Int = w.level.tickLimit
        let changed: String = text.replacingOccurrences(of: "\"tickLimit\" : \(limit),",
                                                        with: "\"tickLimit\" : \(limit + 1),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
    }

    @Test("edited solver values are refused")
    func editedSolverValuesRefused() {
        let w: ChronoConstellatorWitness = fixtures.cases[fixtures.many].witness
        #expect(refusal(edited(w) { $0.lowerBound += 1 }) == .witness("lower-bound"))
        #expect(refusal(edited(w) { $0.window += 1 }) == .witness("window"))
        #expect(refusal(edited(w) { $0.windows += 1 }) == .witness("windows"))
        #expect(refusal(edited(w) { $0.blocked += 1 }) == .witness("blocked"))
    }

    @Test("edited counterexamples are refused")
    func editedCounterexamplesRefused() {
        let w: ChronoConstellatorWitness = fixtures.cases[fixtures.many].witness
        let u: ChronoConstellatorCounterexample = w.unedited
        let later = ChronoConstellatorCounterexample(actions: u.actions, reason: u.reason, tick: u.tick + 1)
        #expect(refusal(edited(w) { $0.unedited = later }) == .witness("unedited"))
        let n: ChronoConstellatorCounterexample = w.nearMiss
        let reason: ChronoConstellatorFailure = n.reason == .time ? .collision(0, 1, 0) : .time
        let wrong = ChronoConstellatorCounterexample(actions: n.actions, reason: reason, tick: n.tick)
        #expect(refusal(edited(w) { $0.nearMiss = wrong }) == .witness("near-miss"))
        #expect(refusal(edited(w) { $0.nearMiss = u }) == .witness("near-miss"))
    }

    @Test("edited difficulty, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: ChronoConstellatorWitness = fixtures.cases[fixtures.one].witness
        let d: ChronoConstellatorDifficulty = w.difficulty
        var lengths: [Int] = d.loopLengths
        lengths[0] += 1
        let loops = ChronoConstellatorDifficulty(smallest: d.smallest, winTick: d.winTick, stars: d.stars,
                                                 loopLengths: lengths, windows: d.windows, blocked: d.blocked)
        #expect(refusal(edited(w) { $0.difficulty = loops }) == .witness("difficulty"))
        let win = ChronoConstellatorDifficulty(smallest: d.smallest, winTick: d.winTick + 1, stars: d.stars,
                                               loopLengths: d.loopLengths, windows: d.windows, blocked: d.blocked)
        #expect(refusal(edited(w) { $0.difficulty = win }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = ChronoConstellatorGenerator.maxCandidates }) == .witness("skipped"))
    }

    @Test("newer and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: ChronoConstellatorWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .witness("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "digests", line: "\"none\"")) == .witness("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .witness("unreadable"))
        #expect(refusal(Data()) == .witness("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .witness("unreadable"))
    }

    @Test("make refuses a solution that does not win and a difficulty that is not the solution's")
    func makeRefuses() {
        let g: ChronoConstellatorGenerated = fixtures.cases[fixtures.one].generated
        let s: ChronoConstellatorSolution = g.solution
        let none = ChronoConstellatorSolution(lowerBound: s.lowerBound, phases: g.level.stars.map(\.phase),
                                              window: s.window, windows: s.windows, blocked: s.blocked, work: s.work)
        let losing = ChronoConstellatorGenerated(entry: g.entry, level: g.level, solution: none, difficulty: g.difficulty,
                                                 skipped: g.skipped)
        #expect(throws: ChronoConstellatorError.witness("replay")) { try ChronoConstellatorWitness.make(losing) }
        let d: ChronoConstellatorDifficulty = g.difficulty
        let other = ChronoConstellatorDifficulty(smallest: d.smallest, winTick: d.winTick, stars: d.stars,
                                                 loopLengths: d.loopLengths, windows: d.windows, blocked: d.blocked + 1)
        let wrong = ChronoConstellatorGenerated(entry: g.entry, level: g.level, solution: s, difficulty: other,
                                                skipped: g.skipped)
        #expect(throws: ChronoConstellatorError.witness("difficulty")) { try ChronoConstellatorWitness.make(wrong) }
    }
}
