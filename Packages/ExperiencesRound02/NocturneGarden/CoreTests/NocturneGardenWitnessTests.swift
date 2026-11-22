// NocturneGardenWitnessTests — feature 382 (R02-G09-02) T-R02G0902-005 (FR-R02G0902-004; SC-R02G0902-003, 005;
// clarification Q4). Witnesses of generated catalog levels 1 (band 1, tutorial) and 21 (band 2), built once per
// process. The stored form round-trips byte for byte with one trailing newline; the digest is the first 16 hex
// characters of SHA-256 over the sorted cells (checked against hand-computed values); digests and fingerprints agree
// with a replay; the near miss replays as recorded (not won, short of the need); edited actions, digests, fingerprints,
// level, smallest, bound, near miss, difficulty and number are refused naming the part; newer and damaged stored forms
// are refused; `make` refuses a bound or difficulty that is not the solution's. Explicit types, plain loops (CI
// type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import NocturneGardenCore

/// The generated levels and witnesses the tests share, built once.
struct NocturneGardenWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: NocturneGardenGenerated, witness: NocturneGardenWitness)]

    static let shared: NocturneGardenWitnessFixtures = make()

    private static func make() -> NocturneGardenWitnessFixtures {
        let entries: [NocturneGardenManifestEntry] = NocturneGardenManifest.entries
        var cases: [(generated: NocturneGardenGenerated, witness: NocturneGardenWitness)] = []
        for index in [0, 20] {
            let generated: NocturneGardenGenerated
            do { generated = try NocturneGardenGenerator.generate(entries[index]) } catch {
                preconditionFailure("level \(entries[index].number) does not generate: \(error)")
            }
            do { cases.append((generated, try NocturneGardenWitness.make(generated))) } catch {
                preconditionFailure("level \(generated.entry.number) has no witness: \(error)")
            }
        }
        return NocturneGardenWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct NocturneGardenWitnessParts {
    var number: Int
    var level: NocturneGardenLevel
    var actions: [NocturneGardenAction]
    var digests: [String]
    var fingerprints: [String]
    var smallest: Int
    var bound: NocturneGardenBound
    var nearMiss: NocturneGardenCounterexample
    var difficulty: NocturneGardenDifficulty
    var skipped: Int

    init(_ w: NocturneGardenWitness) {
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

    var witness: NocturneGardenWitness {
        NocturneGardenWitness(number: number, level: level, actions: actions, digests: digests,
                              fingerprints: fingerprints, smallest: smallest, bound: bound, nearMiss: nearMiss,
                              difficulty: difficulty, skipped: skipped)
    }
}

@Suite("Nocturne Garden witness")
struct NocturneGardenWitnessTests {
    let fixtures: NocturneGardenWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: NocturneGardenWitness) -> NocturneGardenError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> NocturneGardenError? {
        do {
            _ = try NocturneGardenWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: NocturneGardenWitness,
                _ change: (inout NocturneGardenWitnessParts) -> Void) -> NocturneGardenWitness {
        var parts = NocturneGardenWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: NocturneGardenWitness, key: String, line: String?) -> Data {
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
    func played(_ level: NocturneGardenLevel, _ actions: [NocturneGardenAction]) throws -> NocturneGardenPlay {
        var play = NocturneGardenPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    @Test("the fixtures cover bands 1 and 2 and a tutorial")
    func fixturesCover() {
        #expect(fixtures.cases.count == 2)
        #expect(fixtures.cases[0].generated.level.tutorial)
        #expect(fixtures.cases[0].generated.entry.band == 1)
        #expect(fixtures.cases[1].generated.entry.band == 2)
    }

    @Test("the stored form round-trips byte for byte with one trailing newline")
    func roundTripByteForByte() throws {
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: NocturneGardenWitness = try NocturneGardenWitness.decode(data)
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
            #expect(witness.level.id == NocturneGardenGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.solution.actions)
            #expect(witness.smallest == generated.solution.smallest)
            #expect(witness.smallest == witness.actions.count)
            #expect(witness.bound == generated.bound)
            #expect(witness.bound.smallest == witness.smallest)
            #expect(NocturneGardenBandProfile.of(band: generated.entry.band).smallest.contains(witness.smallest))
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("digests and fingerprints agree with a replay that wins on the last action")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            #expect(witness.digests.count == witness.smallest)
            #expect(witness.fingerprints.count == witness.smallest + 1)
            var play: NocturneGardenPlay = try played(witness.level, [])
            var fingerprints: [String] = [play.fingerprint]
            var digests: [String] = []
            for action in witness.actions {
                #expect(play.stage == .playing)
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(NocturneGardenWitness.digest(play.mask))
            }
            #expect(play.stage == .won)
            #expect(play.moves == witness.smallest)
            #expect(play.moves <= witness.level.budget)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            for digest in witness.digests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
        }
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over the sorted cells")
    func digestLayout() {
        // printf '3,5,17' | shasum -a 256 → e0e41a0627c2a3cc…; printf '' | shasum -a 256 → e3b0c44298fc1c14…
        let mask = NocturneGardenMask(width: 16, height: 12, cells: [17, 3, 5])
        #expect(NocturneGardenWitness.digest(mask) == "e0e41a0627c2a3cc")
        let empty = NocturneGardenMask(width: 16, height: 12, cells: [])
        #expect(NocturneGardenWitness.digest(empty) == "e3b0c44298fc1c14")
        let text: String = "3,5,17"
        #expect(NocturneGardenWitness.digest(mask) == String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
        let other = NocturneGardenMask(width: 16, height: 12, cells: [3, 5, 18])
        #expect(NocturneGardenWitness.digest(other) != NocturneGardenWitness.digest(mask))
    }

    @Test("the near miss replays as recorded: not won, short of the need")
    func nearMissReplays() throws {
        for (_, witness) in fixtures.cases {
            let n: NocturneGardenCounterexample = witness.nearMiss
            #expect(n.actions == Array(witness.actions.dropLast()))
            #expect(n.needed == NocturneGardenSolver.needed(witness.level))
            #expect(n.shared < n.needed)
            let near: NocturneGardenPlay = try played(witness.level, n.actions)
            #expect(near.stage != .won)
            #expect(near.match.shared == n.shared)
            #expect(!NocturneGardenMask.matches(mask: near.mask, target: witness.level.target,
                                               required: witness.level.required))
            #expect(near.fingerprint == witness.fingerprints[witness.smallest - 1])
        }
    }

    @Test("edited actions are refused")
    func editedActionsRefused() {
        let w: NocturneGardenWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.actions.removeLast() }) == .witness("actions"))
        let first: Int = w.level.elevations.sorted()[0]
        #expect(refusal(edited(w) { $0.actions.append(.sun(first)) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("actions"))
    }

    @Test("edited digests are refused")
    func editedDigestsRefused() {
        let w: NocturneGardenWitness = fixtures.cases[0].witness
        let first: String = w.digests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.digests[0] = flipped }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.digests.removeLast() }) == .witness("digests"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: NocturneGardenWitness = fixtures.cases[1].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
    }

    @Test("an edited level is refused")
    func editedLevelRefused() throws {
        let w: NocturneGardenWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let budget: Int = w.level.budget
        let changedBudget: Int = budget == NocturneGardenLevel.budgets.upperBound ? budget - 1 : budget + 1
        let changed: String = text.replacingOccurrences(of: "\"budget\" : \(budget),",
                                                        with: "\"budget\" : \(changedBudget),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
        // A re-fingerprinted level that is not the generator's candidate.
        let l: NocturneGardenLevel = w.level
        let other = try NocturneGardenLevel(id: l.id, seed: l.seed, difficulty: l.difficulty, width: l.width,
                                            height: l.height, target: l.target, forbidden: l.forbidden,
                                            supply: l.supply, sizes: l.sizes, elevations: l.elevations, sun: l.sun,
                                            budget: changedBudget, required: l.required,
                                            leakAllowance: l.leakAllowance, tutorial: l.tutorial)
        #expect(refusal(edited(w) { $0.level = other }) == .witness("candidate"))
    }

    @Test("edited smallest, bound and near miss are refused")
    func editedSolverValuesRefused() {
        let w: NocturneGardenWitness = fixtures.cases[1].witness
        #expect(refusal(edited(w) { $0.smallest += 1 }) == .witness("smallest"))
        let b: NocturneGardenBound = w.bound
        let wider = NocturneGardenBound(elevation: b.elevation, needed: b.needed, cover: b.cover + 1,
                                        sunMove: b.sunMove)
        #expect(refusal(edited(w) { $0.bound = wider }) == .witness("bound"))
        let needs = NocturneGardenBound(elevation: b.elevation, needed: b.needed - 1, cover: b.cover,
                                        sunMove: b.sunMove)
        #expect(refusal(edited(w) { $0.bound = needs }) == .witness("bound"))
        let n: NocturneGardenCounterexample = w.nearMiss
        let more = NocturneGardenCounterexample(actions: n.actions, shared: n.shared + 1, needed: n.needed)
        #expect(refusal(edited(w) { $0.nearMiss = more }) == .witness("near-miss"))
        let less = NocturneGardenCounterexample(actions: n.actions, shared: n.shared, needed: n.needed - 1)
        #expect(refusal(edited(w) { $0.nearMiss = less }) == .witness("near-miss"))
        let shorter = NocturneGardenCounterexample(actions: Array(n.actions.dropLast()), shared: n.shared,
                                                   needed: n.needed)
        #expect(refusal(edited(w) { $0.nearMiss = shorter }) == .witness("near-miss"))
    }

    @Test("edited difficulty, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: NocturneGardenWitness = fixtures.cases[0].witness
        let d: NocturneGardenDifficulty = w.difficulty
        let kinds = NocturneGardenDifficulty(smallest: d.smallest, kinds: d.kinds + 1, sizes: d.sizes,
                                             sunChange: d.sunChange, targetCells: d.targetCells,
                                             forbiddenCells: d.forbiddenCells, required: d.required, work: d.work)
        #expect(refusal(edited(w) { $0.difficulty = kinds }) == .witness("difficulty"))
        let cells = NocturneGardenDifficulty(smallest: d.smallest, kinds: d.kinds, sizes: d.sizes,
                                             sunChange: d.sunChange, targetCells: d.targetCells + 1,
                                             forbiddenCells: d.forbiddenCells, required: d.required, work: d.work)
        #expect(refusal(edited(w) { $0.difficulty = cells }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = NocturneGardenGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    /// Feature 382 convergence (T-R02G0902-013): decoding re-runs the solver, so an edited solver work count and a
    /// different winning sequence of the same length (the witness's plants in another order) are refused.
    @Test("an edited solver result is refused")
    func editedSolverResultRefused() {
        let w: NocturneGardenWitness = fixtures.cases[0].witness
        let d: NocturneGardenDifficulty = w.difficulty
        let work = NocturneGardenDifficulty(smallest: d.smallest, kinds: d.kinds, sizes: d.sizes,
                                            sunChange: d.sunChange, targetCells: d.targetCells,
                                            forbiddenCells: d.forbiddenCells, required: d.required, work: d.work + 1)
        #expect(refusal(edited(w) { $0.difficulty = work }) == .witness("solution"))
        var reordered: NocturneGardenWitness?
        for witness in fixtures.cases.map(\.witness) where reordered == nil {
            var plants: [NocturneGardenAction] = []
            var others: [NocturneGardenAction] = []
            for action in witness.actions {
                if case .plant = action { plants.append(action) } else { others.append(action) }
            }
            guard plants.count >= 2 else { continue }
            let swapped: [NocturneGardenAction] = others + plants.reversed()
            // A consistent witness of the reordered actions: replayed digests, fingerprints and near miss, the same
            // difficulty (the same kinds, sizes and sun change), so only the solver re-run can tell it apart.
            guard let run = NocturneGardenWitness.replay(witness.level, actions: swapped), run.play.stage == .won,
                  !run.endedEarly,
                  let near = NocturneGardenWitness.counterexample(witness.level, actions: Array(swapped.dropLast()))
            else { continue }
            reordered = NocturneGardenWitness(number: witness.number, level: witness.level, actions: swapped,
                                              digests: run.digests, fingerprints: run.fingerprints,
                                              smallest: witness.smallest, bound: witness.bound, nearMiss: near,
                                              difficulty: witness.difficulty, skipped: witness.skipped)
        }
        #expect(reordered != nil, "no fixture witness has two plants to reorder")
        if let reordered { #expect(refusal(reordered) == .witness("solution")) }
    }

    @Test("newer and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: NocturneGardenWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .malformed("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .malformed("unreadable"))
        #expect(refusal(storedText(w, key: "smallest", line: "\"none\"")) == .malformed("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .malformed("unreadable"))
        #expect(refusal(Data()) == .malformed("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .malformed("unreadable"))
        #expect(NocturneGardenError.witness("digests").reasonCode == "r02-g09.witness")
    }

    @Test("make refuses a losing solution, a wrong bound and a wrong difficulty")
    func makeRefuses() {
        let g: NocturneGardenGenerated = fixtures.cases[0].generated
        let s: NocturneGardenSolution = g.solution
        let short = NocturneGardenSolution(smallest: s.smallest, actions: Array(s.actions.dropLast()), work: s.work)
        let losing = NocturneGardenGenerated(entry: g.entry, level: g.level, solution: short, bound: g.bound,
                                             difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: NocturneGardenError.witness("actions")) { try NocturneGardenWitness.make(losing) }
        let b: NocturneGardenBound = g.bound
        let wider = NocturneGardenBound(elevation: b.elevation, needed: b.needed, cover: b.cover + 1,
                                        sunMove: b.sunMove)
        let wrongBound = NocturneGardenGenerated(entry: g.entry, level: g.level, solution: s, bound: wider,
                                                 difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: NocturneGardenError.witness("bound")) { try NocturneGardenWitness.make(wrongBound) }
        let d: NocturneGardenDifficulty = g.difficulty
        let other = NocturneGardenDifficulty(smallest: d.smallest, kinds: d.kinds, sizes: d.sizes,
                                             sunChange: d.sunChange, targetCells: d.targetCells,
                                             forbiddenCells: d.forbiddenCells, required: d.required,
                                             work: d.work + 1)
        let wrong = NocturneGardenGenerated(entry: g.entry, level: g.level, solution: s, bound: g.bound,
                                            difficulty: other, skipped: g.skipped)
        #expect(throws: NocturneGardenError.witness("difficulty")) { try NocturneGardenWitness.make(wrong) }
    }
}
