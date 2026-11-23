// HarmonicBridgesWitnessTests — feature 412 (R02-G12-02) T-R02G1202-005 (FR-R02G1202-004; SC-R02G1202-003, 005;
// clarification Q4). Witnesses of generated catalog levels 1 and 2 (band 1, tutorial), 11 (band 1), 21 and 31 (band 2),
// 41 and 51 (band 3), 61 and 71 (band 4) and 81 and 91 (band 5), plus the first band-1 level with a one-tuning plan,
// built once per process. The stored form round-trips byte for byte with sorted keys and one trailing newline; the
// bridge digest is the first 16 hex characters of SHA-256 over the canonical bridges text (checked against a
// hand-computed value); digests and fingerprints agree with a replay; the counterexample is re-checked by an
// independent recount (no choice of one tuning fewer wins; a one-tuning plan names the starting pegs' break); edited
// actions, digests, fingerprints, counterexample, difficulty (work included), level, number, skipped and schema are
// refused naming the part; another winning peg is refused by the solver re-run; newer and damaged stored forms are
// refused; `make` refuses a losing plan and values that are not the plan's. Explicit types, plain loops (CI
// type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import HarmonicBridgesCore

/// The generated levels and witnesses the tests share, built once.
struct HarmonicBridgesWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: HarmonicBridgesGenerated, witness: HarmonicBridgesWitness)]
    /// The first band-1 level whose plan has one tuning, with its witness.
    let single: (generated: HarmonicBridgesGenerated, witness: HarmonicBridgesWitness)?

    static let shared: HarmonicBridgesWitnessFixtures = make()

    /// The generated level and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: HarmonicBridgesGenerated, witness: HarmonicBridgesWitness) {
        let entry: HarmonicBridgesManifestEntry = HarmonicBridgesManifest.entries[index]
        let generated: HarmonicBridgesGenerated
        do { generated = try HarmonicBridgesGenerator.generate(entry) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try HarmonicBridgesWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> HarmonicBridgesWitnessFixtures {
        var cases: [(generated: HarmonicBridgesGenerated, witness: HarmonicBridgesWitness)] = []
        for index in [0, 1, 10, 20, 30, 40, 50, 60, 70, 80, 90] { cases.append(pair(index)) }
        var single: (generated: HarmonicBridgesGenerated, witness: HarmonicBridgesWitness)?
        for (generated, witness) in cases where single == nil && generated.plan.tunings.count == 1 {
            single = (generated, witness)
        }
        var index: Int = 0
        while single == nil && index < 20 {
            let candidate: (generated: HarmonicBridgesGenerated, witness: HarmonicBridgesWitness) = pair(index)
            if candidate.generated.plan.tunings.count == 1 { single = candidate }
            index += 1
        }
        return HarmonicBridgesWitnessFixtures(cases: cases, single: single)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct HarmonicBridgesWitnessParts {
    var number: Int
    var level: HarmonicBridgesLevel
    var actions: [HarmonicBridgesAction]
    var bridgeDigests: [String]
    var fingerprints: [String]
    var counterexample: HarmonicBridgesCounterexample
    var difficulty: HarmonicBridgesDifficulty
    var skipped: Int

    init(_ w: HarmonicBridgesWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        bridgeDigests = w.bridgeDigests
        fingerprints = w.fingerprints
        counterexample = w.counterexample
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: HarmonicBridgesWitness {
        HarmonicBridgesWitness(number: number, level: level, actions: actions, bridgeDigests: bridgeDigests,
                               fingerprints: fingerprints, counterexample: counterexample, difficulty: difficulty,
                               skipped: skipped)
    }
}

/// `d` with its islands, smaller choices and work changed by the given amounts.
func harmonicBridgesDifficulty(_ d: HarmonicBridgesDifficulty, islandsBy islands: Int = 0, smallerBy smaller: Int = 0,
                               workBy work: Int = 0) -> HarmonicBridgesDifficulty {
    HarmonicBridgesDifficulty(tunings: d.tunings, islands: d.islands + islands, strings: d.strings, locked: d.locked,
                              steps: d.steps, tones: d.tones, threshold: d.threshold,
                              smallerChoices: d.smallerChoices + smaller, work: d.work + work)
}

@Suite("Harmonic Bridges witness")
struct HarmonicBridgesWitnessTests {
    let fixtures: HarmonicBridgesWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: HarmonicBridgesWitness) -> HarmonicBridgesError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> HarmonicBridgesError? {
        do {
            _ = try HarmonicBridgesWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: HarmonicBridgesWitness,
                _ change: (inout HarmonicBridgesWitnessParts) -> Void) -> HarmonicBridgesWitness {
        var parts = HarmonicBridgesWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: HarmonicBridgesWitness, key: String, line: String?) -> Data {
        let text: String = String(decoding: witness.encoded(), as: UTF8.self)
        var lines: [String] = text.components(separatedBy: "\n")
        let prefix: String = "  \"\(key)\" : "
        var found: Int?
        for (index, entry) in lines.enumerated() where found == nil && entry.hasPrefix(prefix) { found = index }
        guard let index = found else { return Data(text.utf8) }
        if let line {
            let comma: String = lines[index].hasSuffix(",") ? "," : ""
            lines[index] = prefix + line + comma
        } else {
            lines.remove(at: index)
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// A witness of `fixtures` with at least two tunings.
    var multi: HarmonicBridgesWitness? {
        for (_, witness) in fixtures.cases where witness.actions.count >= 3 { return witness }
        return nil
    }

    @Test("the fixtures cover bands 1 to 5, a tutorial and a one-tuning plan")
    func fixturesCover() {
        #expect(fixtures.cases.count == 11)
        #expect(fixtures.cases[0].generated.level.tutorial)
        var bands: [Int] = []
        for (generated, _) in fixtures.cases { bands.append(generated.entry.band) }
        #expect(bands == [1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5])
        #expect(fixtures.single != nil)
        #expect(multi != nil)
    }

    @Test("the stored form round-trips byte for byte with sorted keys and one trailing newline")
    func roundTripByteForByte() throws {
        let keys: [String] = ["actions", "bridgeDigests", "counterexample", "difficulty", "fingerprints", "level",
                              "number", "schema", "skipped"]
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data == witness.encoded())
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: HarmonicBridgesWitness = try HarmonicBridgesWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            let text: String = String(decoding: data, as: UTF8.self)
            #expect(text.contains("\n  \"schema\" : 1,\n"))
            #expect(text.hasPrefix("{\n  \"actions\" : "))
            var found: [String] = []
            for line in text.components(separatedBy: "\n") where line.hasPrefix("  \"") {
                let name: Substring = line.dropFirst(3).prefix { $0 != "\"" }
                found.append(String(name))
            }
            #expect(found == keys)
        }
        if let single = fixtures.single {
            let data: Data = single.witness.encoded()
            #expect(try HarmonicBridgesWitness.decode(data).encoded() == data)
        }
    }

    @Test("the witness carries the plan's actions, counts, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == HarmonicBridgesGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.actions)
            #expect(witness.actions.count == generated.plan.tunings.count + 1)
            #expect(witness.actions.last == .test)
            #expect(witness.counterexample.size == generated.plan.tunings.count - 1)
            #expect(witness.counterexample.choices == generated.plan.smallerChoices)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.work == generated.plan.work)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("bridge digests and fingerprints agree with a replay")
    func partsAgreeWithReplay() throws {
        for (generated, witness) in fixtures.cases {
            let level: HarmonicBridgesLevel = witness.level
            #expect(witness.bridgeDigests.count == generated.plan.tunings.count)
            let starts: Int = level.tutorial ? 2 : 1
            #expect(witness.fingerprints.count == starts + witness.actions.count)
            var play = HarmonicBridgesPlay(level: level)
            try play.handle(.begin)
            var fingerprints: [String] = [play.fingerprint]
            if play.stage == .tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            var pegs: [Int] = level.startingPegs
            var digests: [String] = []
            for action in witness.actions {
                #expect(play.stage == .playing)
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                if case let .tune(string, peg) = action {
                    pegs[string] = peg
                    digests.append(HarmonicBridgesWitness.digest(level.report(pegs: pegs)))
                }
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.bridgeDigests)
            #expect(HarmonicBridgesSolver.wins(level, actions: witness.actions))
            for digest in witness.bridgeDigests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
        }
    }

    @Test("the counterexample is re-checked: no choice of one tuning fewer wins")
    func counterexampleRechecked() {
        for (generated, witness) in fixtures.cases {
            let level: HarmonicBridgesLevel = witness.level
            let size: Int = witness.counterexample.size
            #expect(HarmonicBridgesWitness.smallerChoices(level, size: size) == witness.counterexample.choices)
            // The plan's size is the first that wins: the recount one size up finds the plan.
            #expect(HarmonicBridgesWitness.smallerChoices(level, size: size + 1) == nil)
            #expect(level.firstBreak(level.report(pegs: level.startingPegs)) != nil)
            if size == 0 {
                #expect(witness.counterexample.start != nil)
            } else {
                #expect(witness.counterexample.start == nil)
            }
            // Dropping any one tuning of the plan loses.
            for skip in 0..<generated.plan.tunings.count {
                var fewer: [HarmonicBridgesAction] = []
                for (index, tuning) in generated.plan.tunings.enumerated() where index != skip {
                    fewer.append(.tune(tuning.string, tuning.peg))
                }
                fewer.append(.test)
                #expect(!HarmonicBridgesSolver.wins(level, actions: fewer))
            }
        }
    }

    @Test("a one-tuning plan names the starting pegs' break")
    func singleNamesStartingBreak() throws {
        let single = try #require(fixtures.single)
        let witness: HarmonicBridgesWitness = single.witness
        let level: HarmonicBridgesLevel = witness.level
        #expect(witness.counterexample.size == 0)
        #expect(witness.counterexample.choices == 0)
        let broken: HarmonicBridgesBreak? = level.firstBreak(level.report(pegs: level.startingPegs))
        #expect(broken != nil)
        #expect(witness.counterexample.start == broken)
        #expect(try HarmonicBridgesWitness.decode(witness.encoded()) == witness)
        let moved = HarmonicBridgesBreak(step: (broken?.step ?? 0) + 1, string: broken?.string)
        let edit: HarmonicBridgesCounterexample = HarmonicBridgesCounterexample(size: 0, choices: 0, start: moved)
        #expect(refusal(edited(witness) { $0.counterexample = edit }) == .witness("counterexample"))
        let none: HarmonicBridgesCounterexample = HarmonicBridgesCounterexample(size: 0, choices: 0, start: nil)
        #expect(refusal(edited(witness) { $0.counterexample = none }) == .witness("counterexample"))
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over the canonical bridges text")
    func digestLayout() {
        // printf '%s' '0=101;1=011' | shasum -a 256 → 3e4583e066ab6452…
        #expect(String(StableHash.sha256Hex(Array("0=101;1=011".utf8)).prefix(16)) == "3e4583e066ab6452")
        for (_, witness) in fixtures.cases {
            let level: HarmonicBridgesLevel = witness.level
            let report: HarmonicBridgesReport = level.report(pegs: level.startingPegs)
            var parts: [String] = []
            for step in 0..<report.bridges.count {
                var text: String = "\(step)="
                for bridge in report.bridges[step] { text += bridge ? "1" : "0" }
                parts.append(text)
            }
            let canonical: String = parts.joined(separator: ";")
            #expect(HarmonicBridgesWitness.canonicalText(report) == canonical)
            let expected: String = String(StableHash.sha256Hex(Array(canonical.utf8)).prefix(16))
            #expect(HarmonicBridgesWitness.digest(report) == expected)
            // The digest after the last tuning differs from the starting one: the plan changes a bridge.
            #expect(witness.bridgeDigests.last != HarmonicBridgesWitness.digest(report))
        }
    }

    @Test("edited actions are refused")
    func editedActionsRefused() throws {
        let w: HarmonicBridgesWitness = try #require(multi)
        let first: HarmonicBridgesAction = w.actions[0]
        #expect(refusal(edited(w) { $0.actions.removeLast() }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions.append(.test) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.test] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions.swapAt(0, 1) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions.insert(first, at: 1) }) == .witness("actions"))
        guard case let .tune(string, _) = first else {
            Issue.record("the first action is not a tuning")
            return
        }
        #expect(refusal(edited(w) { $0.actions[0] = .tune(string, 13) }) == .witness("replay"))
        let starting: Int = w.level.strings[string].peg
        #expect(refusal(edited(w) { $0.actions[0] = .tune(string, starting) }) == .witness("replay"))
        // One tuning fewer: the shape holds but the test breaks.
        #expect(refusal(edited(w) { $0.actions.remove(at: 0) }) == .witness("replay"))
    }

    @Test("edited bridge digests are refused")
    func editedDigestsRefused() {
        let w: HarmonicBridgesWitness = fixtures.cases[4].witness
        let first: String = w.bridgeDigests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.bridgeDigests[0] = flipped }) == .witness("bridge-digests"))
        #expect(refusal(edited(w) { $0.bridgeDigests.removeLast() }) == .witness("bridge-digests"))
        #expect(refusal(edited(w) { $0.bridgeDigests.append(first) }) == .witness("bridge-digests"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: HarmonicBridgesWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
        // Level 1 has a tutorial: dropping the fingerprint after `dismissTutorial` is refused.
        #expect(refusal(edited(w) { $0.fingerprints.remove(at: 1) }) == .witness("fingerprints"))
    }

    @Test("an edited counterexample is refused")
    func editedCounterexampleRefused() throws {
        let w: HarmonicBridgesWitness = try #require(multi)
        let c: HarmonicBridgesCounterexample = w.counterexample
        let more = HarmonicBridgesCounterexample(size: c.size, choices: c.choices + 1, start: c.start)
        #expect(refusal(edited(w) { $0.counterexample = more }) == .witness("counterexample"))
        let less = HarmonicBridgesCounterexample(size: c.size, choices: c.choices - 1, start: c.start)
        #expect(refusal(edited(w) { $0.counterexample = less }) == .witness("counterexample"))
        let smaller = HarmonicBridgesCounterexample(size: c.size - 1, choices: c.choices, start: c.start)
        #expect(refusal(edited(w) { $0.counterexample = smaller }) == .witness("counterexample"))
        let named = HarmonicBridgesCounterexample(size: c.size, choices: c.choices,
                                                  start: HarmonicBridgesBreak(step: 0, string: nil))
        #expect(refusal(edited(w) { $0.counterexample = named }) == .witness("counterexample"))
    }

    @Test("an edited level is refused")
    func editedLevelRefused() throws {
        let w: HarmonicBridgesWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let budget: Int = w.level.budget
        let changedBudget: Int = budget + 1
        let changed: String = text.replacingOccurrences(of: "\"budget\" : \(budget),",
                                                        with: "\"budget\" : \(changedBudget),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
        // A re-fingerprinted level that is not the generator's candidate.
        let l: HarmonicBridgesLevel = w.level
        let other = try HarmonicBridgesLevel(id: l.id, seed: l.seed, difficulty: l.difficulty, islands: l.islands,
                                             strings: l.strings, start: l.start, goal: l.goal, steps: l.steps,
                                             threshold: l.threshold, budget: changedBudget, tutorial: l.tutorial)
        #expect(refusal(edited(w) { $0.level = other }) == .witness("candidate"))
    }

    @Test("edited difficulty, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: HarmonicBridgesWitness = fixtures.cases[3].witness
        let wider: HarmonicBridgesDifficulty = harmonicBridgesDifficulty(w.difficulty, islandsBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = wider }) == .witness("difficulty"))
        let smaller: HarmonicBridgesDifficulty = harmonicBridgesDifficulty(w.difficulty, smallerBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = smaller }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = 0 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = HarmonicBridgesGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = -1 }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    /// A consistent witness of another plan of the same size that wins `witness`'s level: one tuning moved to another
    /// string or peg (the tunings kept in ascending string order), with replayed fingerprints and digests; nil when
    /// none wins.
    func alternative(_ witness: HarmonicBridgesWitness) -> HarmonicBridgesWitness? {
        var tunings: [HarmonicBridgesTuning] = []
        for action in witness.actions {
            if case let .tune(string, peg) = action { tunings.append(HarmonicBridgesTuning(string: string, peg: peg)) }
        }
        let level: HarmonicBridgesLevel = witness.level
        for position in 0..<tunings.count {
            for string in 0..<level.strings.count where !level.strings[string].locked {
                var taken: Bool = false
                for (index, tuning) in tunings.enumerated() where index != position && tuning.string == string {
                    taken = true
                }
                if taken { continue }
                for peg in HarmonicBridgesLevel.pegs where peg != level.strings[string].peg {
                    var trial: [HarmonicBridgesTuning] = tunings
                    trial[position] = HarmonicBridgesTuning(string: string, peg: peg)
                    if trial == tunings { continue }
                    trial.sort { $0.string < $1.string }
                    var actions: [HarmonicBridgesAction] = []
                    for tuning in trial { actions.append(.tune(tuning.string, tuning.peg)) }
                    actions.append(.test)
                    guard let run = HarmonicBridgesWitness.replay(level, actions: actions), run.play.stage == .won,
                          !run.endedEarly else { continue }
                    var parts = HarmonicBridgesWitnessParts(witness)
                    parts.actions = actions
                    parts.fingerprints = run.fingerprints
                    parts.bridgeDigests = run.digests
                    return parts.witness
                }
            }
        }
        return nil
    }

    /// Feature 382's convergence lesson: decoding re-runs the solver, so an edited solver work count and another
    /// winning peg for a tuning (a consistent witness of a plan the solver does not choose) are refused.
    @Test("an edited solver result and another winning plan are refused")
    func editedSolverResultRefused() {
        let w: HarmonicBridgesWitness = fixtures.cases[5].witness
        let more: HarmonicBridgesDifficulty = harmonicBridgesDifficulty(w.difficulty, workBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = more }) == .witness("solution"))
        let less: HarmonicBridgesDifficulty = harmonicBridgesDifficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = less }) == .witness("solution"))
        var other: HarmonicBridgesWitness?
        for (_, witness) in fixtures.cases where other == nil {
            other = alternative(witness)
        }
        #expect(other != nil, "no fixture witness has another winning peg")
        if let other {
            #expect(HarmonicBridgesSolver.wins(other.level, actions: other.actions))
            #expect(refusal(other) == .witness("solution"))
        }
    }

    @Test("newer, older and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: HarmonicBridgesWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .witness("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "level", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "number", line: "\"one\"")) == .witness("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .witness("unreadable"))
        #expect(refusal(Data()) == .witness("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .witness("unreadable"))
        #expect(HarmonicBridgesError.witness("bridge-digests").reasonCode == "r02-g12.witness")
        #expect(HarmonicBridgesError.newerSchema(2).reasonCode == "r02-g12.newer-schema")
    }

    @Test("make refuses a losing plan and values that are not the plan's")
    func makeRefuses() throws {
        let g: HarmonicBridgesGenerated = fixtures.cases[5].generated
        let p: HarmonicBridgesPlan = g.plan
        let short = HarmonicBridgesPlan(tunings: Array(p.tunings.dropLast()), smallerChoices: p.smallerChoices,
                                        work: p.work)
        let losing = HarmonicBridgesGenerated(entry: g.entry, level: g.level, plan: short, difficulty: g.difficulty,
                                              skipped: g.skipped)
        #expect(throws: HarmonicBridgesError.witness("replay")) { try HarmonicBridgesWitness.make(losing) }
        let bumped = HarmonicBridgesPlan(tunings: p.tunings, smallerChoices: p.smallerChoices + 1, work: p.work)
        let wrongCount = HarmonicBridgesGenerated(entry: g.entry, level: g.level, plan: bumped,
                                                  difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: HarmonicBridgesError.witness("counterexample")) {
            try HarmonicBridgesWitness.make(wrongCount)
        }
        let other: HarmonicBridgesDifficulty = harmonicBridgesDifficulty(g.difficulty, workBy: 1)
        let wrong = HarmonicBridgesGenerated(entry: g.entry, level: g.level, plan: p, difficulty: other,
                                             skipped: g.skipped)
        #expect(throws: HarmonicBridgesError.witness("difficulty")) { try HarmonicBridgesWitness.make(wrong) }
        let otherEntry = HarmonicBridgesGenerated(entry: HarmonicBridgesManifest.entries[0], level: g.level,
                                                  plan: p, difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: HarmonicBridgesError.witness("number")) { try HarmonicBridgesWitness.make(otherEntry) }
    }
}
