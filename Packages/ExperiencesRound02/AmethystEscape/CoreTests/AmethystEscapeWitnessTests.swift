// AmethystEscapeWitnessTests — feature 362 (R02-G07-02) T-R02G0702-005 (FR-R02G0702-004; SC-R02G0702-003, 005;
// clarification Q4). Witnesses of generated catalog levels across every band (levels 1, 2, 21, 22, 41, 61, 81; levels 1
// and 2 have a tutorial). The stored form round-trips byte for byte with one trailing newline; the actions are the
// solver's; digests and fingerprints agree with a replay; the counterexamples behave as recorded; edited actions,
// digests, fingerprints, level, solver values, counterexamples, difficulty, number and skipped are refused naming the
// part; newer and damaged stored forms are refused; `make` refuses a solution that does not win and a difficulty that is
// not the solution's. Explicit types, plain loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import AmethystEscapeCore

/// The generated levels and witnesses the tests share, built once.
struct AmethystEscapeWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: AmethystEscapeGenerated, witness: AmethystEscapeWitness)]

    static let shared: AmethystEscapeWitnessFixtures = make()

    private static func make() -> AmethystEscapeWitnessFixtures {
        let entries: [AmethystEscapeManifestEntry] = AmethystEscapeManifest.entries
        var cases: [(generated: AmethystEscapeGenerated, witness: AmethystEscapeWitness)] = []
        for index in [0, 1, 20, 21, 40, 60, 80] {
            let generated: AmethystEscapeGenerated
            do { generated = try AmethystEscapeGenerator.generate(entries[index]) } catch {
                preconditionFailure("level \(entries[index].number) does not generate: \(error)")
            }
            do { cases.append((generated, try AmethystEscapeWitness.make(generated))) } catch {
                preconditionFailure("level \(generated.entry.number) has no witness: \(error)")
            }
        }
        return AmethystEscapeWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct AmethystEscapeWitnessParts {
    var number: Int
    var level: AmethystEscapeLevel
    var actions: [AmethystEscapeAction]
    var digests: [String]
    var fingerprints: [String]
    var smallest: Int
    var depths: [Int]
    var unedited: AmethystEscapeCounterexample
    var nearMiss: AmethystEscapeCounterexample
    var difficulty: AmethystEscapeDifficulty
    var skipped: Int

    init(_ w: AmethystEscapeWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        smallest = w.smallest
        depths = w.depths
        unedited = w.unedited
        nearMiss = w.nearMiss
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: AmethystEscapeWitness {
        AmethystEscapeWitness(number: number, level: level, actions: actions, digests: digests,
                              fingerprints: fingerprints, smallest: smallest, depths: depths, unedited: unedited,
                              nearMiss: nearMiss, difficulty: difficulty, skipped: skipped)
    }
}

@Suite("Amethyst Escape witness")
struct AmethystEscapeWitnessTests {
    let fixtures: AmethystEscapeWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: AmethystEscapeWitness) -> AmethystEscapeError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> AmethystEscapeError? {
        do {
            _ = try AmethystEscapeWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: AmethystEscapeWitness,
                _ change: (inout AmethystEscapeWitnessParts) -> Void) -> AmethystEscapeWitness {
        var parts = AmethystEscapeWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: AmethystEscapeWitness, key: String, line: String?) -> Data {
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

    /// A play of `level` after `begin` (and `dismissTutorial`).
    func started(_ level: AmethystEscapeLevel) throws -> AmethystEscapePlay {
        var play = AmethystEscapePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The play after replaying `actions` on `level` from `begin` (and `dismissTutorial`).
    func played(_ level: AmethystEscapeLevel, _ actions: [AmethystEscapeAction]) throws -> AmethystEscapePlay {
        var play: AmethystEscapePlay = try started(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The first fixture case of `band`.
    func witness(band: Int) -> AmethystEscapeWitness {
        for (generated, witness) in fixtures.cases where generated.entry.band == band { return witness }
        preconditionFailure("no fixture of band \(band)")
    }

    @Test("the fixtures cover every band and a tutorial")
    func fixturesCover() {
        #expect(fixtures.cases.count == 7)
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
            let decoded: AmethystEscapeWitness = try AmethystEscapeWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            let text: String = String(decoding: data, as: UTF8.self)
            #expect(text.contains("\n  \"schema\" : 1,\n"))
            #expect(text.hasPrefix("{\n  \"actions\" : "))
        }
    }

    @Test("the witness carries the solver's actions, proof, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == AmethystEscapeGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.solution.actions)
            #expect(witness.actions.last == .advance)
            #expect(witness.smallest == generated.solution.smallest)
            #expect(witness.smallest == witness.actions.count)
            #expect(AmethystEscapeBandProfile.of(band: generated.entry.band).smallest.contains(witness.smallest))
            #expect(witness.depths == generated.solution.depths)
            #expect(witness.depths.count == witness.smallest)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("digests and fingerprints agree with a replay that wins on the last action")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            #expect(witness.digests.count == witness.smallest)
            #expect(witness.fingerprints.count == witness.smallest + 1)
            for digest in witness.digests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
            var play: AmethystEscapePlay = try started(witness.level)
            var fingerprints: [String] = [play.fingerprint]
            var digests: [String] = []
            for action in witness.actions {
                #expect(play.stage == .playing)
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(AmethystEscapeWitness.digest(play.crystal))
            }
            #expect(play.stage == .won)
            #expect(play.moves == witness.smallest)
            #expect(play.moves <= witness.level.budget)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
        }
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over the shell count, offsets and pearl")
    func digestLayout() {
        let crystal = AmethystEscapeCrystal(offsets: [3, 0, 7], pearl: AmethystEscapePocket(shell: 2, sector: 11))
        let bytes: [UInt8] = [3, 3, 0, 7, 2, 11]
        #expect(AmethystEscapeWitness.digest(crystal) == String(StableHash.sha256Hex(bytes).prefix(16)))
        let moved = AmethystEscapeCrystal(offsets: [3, 0, 7], pearl: AmethystEscapePocket(shell: 2, sector: 10))
        #expect(AmethystEscapeWitness.digest(crystal) != AmethystEscapeWitness.digest(moved))
        let turned = AmethystEscapeCrystal(offsets: [0, 3, 7], pearl: AmethystEscapePocket(shell: 2, sector: 11))
        #expect(AmethystEscapeWitness.digest(crystal) != AmethystEscapeWitness.digest(turned))
    }

    @Test("the counterexamples behave as recorded")
    func counterexamplesBehaveAsRecorded() throws {
        for (_, witness) in fixtures.cases {
            // The unedited run: advances only, ending stuck, in a wedge or on the budget.
            let u: AmethystEscapeCounterexample = witness.unedited
            #expect(u.actions.allSatisfy { $0 == .advance })
            #expect(u.move == u.actions.count)
            #expect(["stuck", "wedge", "budget"].contains(u.outcome))
            var play: AmethystEscapePlay = try played(witness.level, u.actions)
            #expect(play.moves == u.move)
            if u.outcome == "stuck" {
                #expect(play.stage == .playing)
                let fingerprint: String = play.fingerprint
                #expect(throws: AmethystEscapeError.stuck) { try play.apply(.advance, expecting: fingerprint) }
            } else {
                #expect(play.stage == .failed)
                #expect(play.failure?.code == u.outcome)
            }
            // The near miss: the witness without its last action, still playing.
            let n: AmethystEscapeCounterexample = witness.nearMiss
            #expect(n.actions == Array(witness.actions.dropLast()))
            #expect(n.outcome == "open")
            #expect(n.move == witness.smallest - 1)
            let near: AmethystEscapePlay = try played(witness.level, n.actions)
            #expect(near.stage == .playing)
            #expect(near.moves == n.move)
            #expect(near.fingerprint == witness.fingerprints[witness.smallest - 1])
        }
    }

    @Test("edited actions are refused")
    func editedActionsRefused() {
        let w: AmethystEscapeWitness = witness(band: 1)
        #expect(refusal(edited(w) { $0.actions.removeLast() }) == .witness("replay"))
        #expect(refusal(edited(w) { $0.actions.append(.advance) }) == .witness("replay"))
        // A detour that turns a shell and back still wins, but is not the solver's shortest sequence.
        var detour: [AmethystEscapeAction] = w.actions
        detour.insert(contentsOf: [.rotate(0, 1), .rotate(0, -1)], at: 0)
        #expect(detour.count <= w.level.budget)
        #expect(refusal(edited(w) { $0.actions = detour }) == .witness("actions"))
    }

    @Test("edited digests are refused")
    func editedDigestsRefused() {
        let w: AmethystEscapeWitness = witness(band: 1)
        let first: String = w.digests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.digests[0] = flipped }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.digests.removeLast() }) == .witness("digests"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: AmethystEscapeWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
    }

    @Test("an edited level is refused")
    func editedLevelRefused() throws {
        let w: AmethystEscapeWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let budget: Int = w.level.budget
        let changed: String = text.replacingOccurrences(of: "\"budget\" : \(budget),",
                                                        with: "\"budget\" : \(budget + 1),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
        // A re-fingerprinted level that is not the generator's candidate.
        let l: AmethystEscapeLevel = w.level
        let other = try AmethystEscapeLevel(id: l.id, seed: l.seed, difficulty: l.difficulty, sectors: l.sectors,
                                            shells: l.shells, start: l.start, budget: budget + 1,
                                            tutorial: l.tutorial)
        #expect(refusal(edited(w) { $0.level = other }) == .witness("candidate"))
    }

    @Test("edited solver values are refused")
    func editedSolverValuesRefused() {
        let w: AmethystEscapeWitness = witness(band: 2)
        #expect(refusal(edited(w) { $0.smallest += 1 }) == .witness("smallest"))
        #expect(refusal(edited(w) { $0.depths[0] += 1 }) == .witness("depths"))
        #expect(refusal(edited(w) { $0.depths.removeLast() }) == .witness("depths"))
    }

    @Test("edited counterexamples are refused")
    func editedCounterexamplesRefused() {
        let w: AmethystEscapeWitness = witness(band: 1)
        let u: AmethystEscapeCounterexample = w.unedited
        let later = AmethystEscapeCounterexample(actions: u.actions, outcome: u.outcome, move: u.move + 1)
        #expect(refusal(edited(w) { $0.unedited = later }) == .witness("unedited"))
        let outcome: String = u.outcome == "stuck" ? "wedge" : "stuck"
        let other = AmethystEscapeCounterexample(actions: u.actions, outcome: outcome, move: u.move)
        #expect(refusal(edited(w) { $0.unedited = other }) == .witness("unedited"))
        let n: AmethystEscapeCounterexample = w.nearMiss
        let stuck = AmethystEscapeCounterexample(actions: n.actions, outcome: "stuck", move: n.move)
        #expect(refusal(edited(w) { $0.nearMiss = stuck }) == .witness("near-miss"))
        #expect(refusal(edited(w) { $0.nearMiss = u }) == .witness("near-miss"))
    }

    @Test("edited difficulty, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: AmethystEscapeWitness = witness(band: 1)
        let d: AmethystEscapeDifficulty = w.difficulty
        let explored = AmethystEscapeDifficulty(smallest: d.smallest, turns: d.turns, advances: d.advances,
                                                shells: d.shells, sectors: d.sectors, explored: d.explored + 1)
        #expect(refusal(edited(w) { $0.difficulty = explored }) == .witness("difficulty"))
        let turns = AmethystEscapeDifficulty(smallest: d.smallest, turns: d.turns + 1, advances: d.advances - 1,
                                             shells: d.shells, sectors: d.sectors, explored: d.explored)
        #expect(refusal(edited(w) { $0.difficulty = turns }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = AmethystEscapeGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    @Test("newer and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: AmethystEscapeWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .witness("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "smallest", line: "\"none\"")) == .witness("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .witness("unreadable"))
        #expect(refusal(Data()) == .witness("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .witness("unreadable"))
        #expect(AmethystEscapeError.witness("unreadable").reasonCode == "r02-g07.witness")
    }

    @Test("make refuses a solution that does not win and a difficulty that is not the solution's")
    func makeRefuses() {
        let g: AmethystEscapeGenerated = fixtures.cases[0].generated
        let s: AmethystEscapeSolution = g.solution
        let short = AmethystEscapeSolution(smallest: s.smallest, actions: Array(s.actions.dropLast()), depths: s.depths,
                                           work: s.work)
        let losing = AmethystEscapeGenerated(entry: g.entry, level: g.level, solution: short, difficulty: g.difficulty,
                                             skipped: g.skipped)
        #expect(throws: AmethystEscapeError.witness("replay")) { try AmethystEscapeWitness.make(losing) }
        let d: AmethystEscapeDifficulty = g.difficulty
        let other = AmethystEscapeDifficulty(smallest: d.smallest, turns: d.turns, advances: d.advances,
                                             shells: d.shells, sectors: d.sectors + 1, explored: d.explored)
        let wrong = AmethystEscapeGenerated(entry: g.entry, level: g.level, solution: s, difficulty: other,
                                            skipped: g.skipped)
        #expect(throws: AmethystEscapeError.witness("difficulty")) { try AmethystEscapeWitness.make(wrong) }
    }
}
