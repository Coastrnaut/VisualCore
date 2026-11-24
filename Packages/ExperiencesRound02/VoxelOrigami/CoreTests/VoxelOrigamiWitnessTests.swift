// VoxelOrigamiWitnessTests — feature 442 (R02-G15-02) T-R02G1502-005 (FR-R02G1502-004; SC-R02G1502-003, 005;
// clarification Q4), modelled on MoonlitMechanismWitnessTests (feature 432). Witnesses of generated catalog levels 1
// (band 1, tutorial), 4 (band 1), 21 and 22 (band 2), built once per process. The stored form round-trips byte for
// byte with sorted keys and one trailing newline; equal makes give equal bytes; the state digest is the first 16 hex
// characters of SHA-256 over the canonical quarter-turn text (checked against a hand-built value); digests and
// fingerprints agree with an independent replay; the counterexample is the solver's states at the depth one below the
// plan; edited actions, digests, fingerprints, counterexample, difficulty, level (bytes and values), number, skipped and
// schema are refused naming the part; newer and truncated stored forms are refused; `make` refuses values that are not
// the plan's. Explicit types, plain loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import VoxelOrigamiCore

/// The generated levels and witnesses the tests share, built once.
struct VoxelOrigamiWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: VoxelOrigamiGenerated, witness: VoxelOrigamiWitness)]

    static let shared: VoxelOrigamiWitnessFixtures = make()

    /// The generated level and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: VoxelOrigamiGenerated, witness: VoxelOrigamiWitness) {
        let entry: VoxelOrigamiManifestEntry = VoxelOrigamiManifest.entries[index]
        let generated: VoxelOrigamiGenerated
        do { generated = try VoxelOrigamiGenerator.generate(entry) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try VoxelOrigamiWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> VoxelOrigamiWitnessFixtures {
        var cases: [(generated: VoxelOrigamiGenerated, witness: VoxelOrigamiWitness)] = []
        for index in [0, 3, 20, 21] { cases.append(pair(index)) }
        return VoxelOrigamiWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct VoxelOrigamiWitnessParts {
    var number: Int
    var level: VoxelOrigamiLevel
    var actions: [VoxelOrigamiAction]
    var digests: [String]
    var fingerprints: [String]
    var counterexample: VoxelOrigamiCounterexample
    var difficulty: VoxelOrigamiDifficulty
    var skipped: Int

    init(_ w: VoxelOrigamiWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        counterexample = w.counterexample
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: VoxelOrigamiWitness {
        VoxelOrigamiWitness(number: number, level: level, actions: actions, digests: digests,
                            fingerprints: fingerprints, counterexample: counterexample, difficulty: difficulty,
                            skipped: skipped)
    }
}

/// `d` with its cubes, states searched and work changed by the given amounts.
func voxelOrigamiDifficulty(_ d: VoxelOrigamiDifficulty, cubesBy cubes: Int = 0, statesBy states: Int = 0,
                            workBy work: Int = 0) -> VoxelOrigamiDifficulty {
    VoxelOrigamiDifficulty(turns: d.turns, cubes: d.cubes + cubes, turnableHinges: d.turnableHinges,
                           orientations: d.orientations, statesSearched: d.statesSearched + states,
                           work: d.work + work)
}

@Suite struct VoxelOrigamiWitnessTests {
    let fixtures: VoxelOrigamiWitnessFixtures = .shared

    /// The refusal `decode` raises for the stored form of `witness`, or nil when it decodes.
    func refusal(_ witness: VoxelOrigamiWitness) -> VoxelOrigamiError? {
        refusal(witness.encoded())
    }

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> VoxelOrigamiError? {
        do {
            _ = try VoxelOrigamiWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: VoxelOrigamiWitness,
                _ change: (inout VoxelOrigamiWitnessParts) -> Void) -> VoxelOrigamiWitness {
        var parts = VoxelOrigamiWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: VoxelOrigamiWitness, key: String, line: String?) -> Data {
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

    /// A witness of `fixtures` with at least two turns.
    var multi: VoxelOrigamiWitness? {
        for (_, witness) in fixtures.cases where witness.actions.count >= 2 { return witness }
        return nil
    }

    @Test("the fixtures cover bands 1 and 2, a tutorial and a multi-turn plan")
    func fixturesCover() {
        #expect(fixtures.cases.count == 4)
        #expect(fixtures.cases[0].generated.level.tutorial)
        #expect(!fixtures.cases[1].generated.level.tutorial)
        var bands: [Int] = []
        for (generated, _) in fixtures.cases { bands.append(generated.entry.band) }
        #expect(bands == [1, 1, 2, 2])
        #expect(multi != nil)
    }

    @Test("the stored form round-trips byte for byte with sorted keys and one trailing newline")
    func roundTripByteForByte() throws {
        let keys: [String] = ["actions", "counterexample", "difficulty", "digests", "fingerprints", "level", "number",
                              "schema", "skipped"]
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data == witness.encoded())
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: VoxelOrigamiWitness = try VoxelOrigamiWitness.decode(data)
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
            // The nested level is the level's own stored form, fingerprint included.
            #expect(text.contains("\"fingerprint\" : \"\(witness.level.fingerprint)\""))
        }
    }

    @Test("equal makes give equal bytes")
    func equalMakesEqualBytes() throws {
        for (generated, witness) in fixtures.cases {
            let again: VoxelOrigamiWitness = try VoxelOrigamiWitness.make(generated)
            #expect(again == witness)
            #expect(again.encoded() == witness.encoded())
        }
        let regenerated: VoxelOrigamiGenerated = try VoxelOrigamiGenerator.generate(VoxelOrigamiManifest.entries[0])
        let fresh: VoxelOrigamiWitness = try VoxelOrigamiWitness.make(regenerated)
        #expect(fresh.encoded() == fixtures.cases[0].witness.encoded())
    }

    @Test("the witness carries the plan's turns, counterexample, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == VoxelOrigamiGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.plan.turns)
            #expect(witness.counterexample.depth == generated.plan.size - 1)
            #expect(witness.counterexample.states == generated.plan.statesByDepth[generated.plan.size - 1])
            #expect(witness.counterexample.states >= 1)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.statesSearched == generated.plan.statesSearched)
            #expect(witness.difficulty.work == generated.plan.work)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("state digests and fingerprints agree with an independent replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: VoxelOrigamiLevel = witness.level
            #expect(witness.digests.count == witness.actions.count)
            let starts: Int = level.tutorial ? 2 : 1
            #expect(witness.fingerprints.count == starts + witness.actions.count)
            var play = VoxelOrigamiPlay(level: level)
            try play.handle(.begin)
            var fingerprints: [String] = [play.fingerprint]
            if level.tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            var digests: [String] = []
            for action in witness.actions {
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                var text: String = "turns="
                for (position, turn) in play.turns.enumerated() {
                    if position > 0 { text += "," }
                    text += String(turn)
                }
                digests.append(String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            #expect(VoxelOrigamiSolver.matches(level, actions: witness.actions))
        }
    }

    @Test("the state digest is 16 hex characters of SHA-256 over the canonical text and follows the turns")
    func digestDefinition() {
        #expect(VoxelOrigamiWitness.canonicalText(turns: [0, 1, 3, 0]) == "turns=0,1,3,0")
        let full: String = StableHash.sha256Hex(Array("turns=0,1,3,0".utf8))
        let digest: String = VoxelOrigamiWitness.digest(turns: [0, 1, 3, 0])
        #expect(digest == String(full.prefix(16)))
        #expect(digest.count == 16)
        var hex: Bool = true
        for scalar in digest.unicodeScalars where !"0123456789abcdef".unicodeScalars.contains(scalar) { hex = false }
        #expect(hex)
        var seen: Set<String> = [digest]
        for hinge in 1..<4 {
            var turns: [Int] = [0, 1, 3, 0]
            turns[hinge] = (turns[hinge] + 1) % 4
            seen.insert(VoxelOrigamiWitness.digest(turns: turns))
        }
        seen.insert(VoxelOrigamiWitness.digest(turns: [0, 1, 3, 0, 0]))
        #expect(seen.count == 5)
    }

    @Test("no plan of one turn fewer matches: dropping any one turn does not win")
    func droppingATurnLoses() throws {
        let w: VoxelOrigamiWitness = try #require(multi)
        for index in 0..<w.actions.count {
            var shorter: [VoxelOrigamiAction] = w.actions
            shorter.remove(at: index)
            #expect(!VoxelOrigamiSolver.matches(w.level, actions: shorter))
        }
    }

    @Test("an edited action is refused")
    func editedActionRefused() throws {
        let w: VoxelOrigamiWitness = try #require(multi)
        let hinges: Int = w.level.cubes.count
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.turn(1, 2)] + w.actions }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.turn(0, 1)] + w.actions }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.turn(hinges, 1)] + w.actions }) == .witness("actions"))
        var long: [VoxelOrigamiAction] = []
        for _ in 0...w.level.budget { long.append(w.actions[0]) }
        #expect(refusal(edited(w) { $0.actions = long }) == .witness("actions"))
        // A shorter plan replays without winning; a turn after the win is refused by the play.
        #expect(refusal(edited(w) { $0.actions = Array(w.actions.dropLast()) }) == .witness("replay"))
        guard case .turn(let hinge, let step) = w.actions[w.actions.count - 1] else { return }
        #expect(refusal(edited(w) { $0.actions = w.actions + [.turn(hinge, -step)] }) == .witness("replay"))
    }

    @Test("a longer winning sequence is not the solver's and is refused")
    func longerWinRefused() throws {
        let w: VoxelOrigamiWitness = fixtures.cases[1].witness
        var found: [VoxelOrigamiAction]?
        for hinge in 1..<w.level.cubes.count where found == nil {
            for step in [-1, 1] where found == nil {
                let padded: [VoxelOrigamiAction] = [.turn(hinge, step), .turn(hinge, -step)] + w.actions
                if VoxelOrigamiSolver.matches(w.level, actions: padded), padded.count <= w.level.budget {
                    found = padded
                }
            }
        }
        let padded: [VoxelOrigamiAction] = try #require(found)
        #expect(refusal(edited(w) { $0.actions = padded }) == .witness("solution"))
    }

    @Test("an edited digest or fingerprint is refused")
    func editedDigestAndFingerprintRefused() {
        for (_, w) in fixtures.cases {
            var digests: [String] = w.digests
            digests[0] = "0000000000000000"
            #expect(refusal(edited(w) { $0.digests = digests }) == .witness("digests"))
            #expect(refusal(edited(w) { $0.digests = Array(w.digests.dropLast()) }) == .witness("digests"))
            var fingerprints: [String] = w.fingerprints
            fingerprints[fingerprints.count - 1] = String(repeating: "0", count: 64)
            #expect(refusal(edited(w) { $0.fingerprints = fingerprints }) == .witness("fingerprints"))
            #expect(refusal(edited(w) { $0.fingerprints = Array(w.fingerprints.dropFirst()) })
                    == .witness("fingerprints"))
        }
    }

    @Test("an edited counterexample or difficulty is refused")
    func editedCounterexampleAndDifficultyRefused() {
        let w: VoxelOrigamiWitness = fixtures.cases[2].witness
        let c: VoxelOrigamiCounterexample = w.counterexample
        let more = VoxelOrigamiCounterexample(depth: c.depth, states: c.states + 1)
        #expect(refusal(edited(w) { $0.counterexample = more }) == .witness("counterexample"))
        let lower = VoxelOrigamiCounterexample(depth: c.depth - 1, states: c.states)
        #expect(refusal(edited(w) { $0.counterexample = lower }) == .witness("counterexample"))
        let cubes: VoxelOrigamiDifficulty = voxelOrigamiDifficulty(w.difficulty, cubesBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = cubes }) == .witness("difficulty"))
        let states: VoxelOrigamiDifficulty = voxelOrigamiDifficulty(w.difficulty, statesBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = states }) == .witness("difficulty"))
        let work: VoxelOrigamiDifficulty = voxelOrigamiDifficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = work }) == .witness("difficulty"))
    }

    @Test("an edited level, number or skipped count is refused")
    func editedLevelRefused() throws {
        let w: VoxelOrigamiWitness = fixtures.cases[0].witness
        let l: VoxelOrigamiLevel = w.level
        // A level that still replays but is not the generator's candidate.
        let reseeded = try VoxelOrigamiLevel(id: l.id, seed: l.seed &+ 1, difficulty: l.difficulty, cubes: l.cubes,
                                             target: l.target, orientations: l.orientations, budget: l.budget,
                                             tutorial: l.tutorial)
        #expect(VoxelOrigamiSolver.matches(reseeded, actions: w.actions))
        #expect(refusal(edited(w) { $0.level = reseeded }) == .witness("candidate"))
        // A level field edited in the stored bytes breaks the level's fingerprint.
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let budget: String = "    \"budget\" : \(l.budget),"
        #expect(text.contains(budget))
        let damaged: String = text.replacingOccurrences(of: budget, with: "    \"budget\" : \(l.budget + 1),")
        #expect(refusal(Data(damaged.utf8)) == .witness("level"))
        let fingerprint: String = "\"fingerprint\" : \"\(l.fingerprint)\""
        let forged: String = text.replacingOccurrences(
            of: fingerprint, with: "\"fingerprint\" : \"\(String(repeating: "0", count: 64))\"")
        #expect(refusal(Data(forged.utf8)) == .witness("level"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = 0 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = VoxelOrigamiGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = -1 }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    @Test("newer, older, truncated and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: VoxelOrigamiWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .witness("schema 2"))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .witness("schema 0"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "level", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "number", line: "\"one\"")) == .witness("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .witness("unreadable"))
        #expect(refusal(data.prefix(data.count - 3)) == .witness("unreadable"))
        #expect(refusal(Data()) == .witness("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .witness("unreadable"))
        #expect(VoxelOrigamiError.witness("digests").reasonCode == "r02-g15.witness")
    }

    @Test("make refuses values that are not the solver's plan")
    func makeRefuses() throws {
        let w: VoxelOrigamiWitness = try #require(multi)
        var found: VoxelOrigamiGenerated?
        for (generated, witness) in fixtures.cases where witness == w { found = generated }
        let g: VoxelOrigamiGenerated = try #require(found)
        let p: VoxelOrigamiPlan = g.plan
        let short = VoxelOrigamiPlan(turns: Array(p.turns.dropLast()), statesByDepth: p.statesByDepth, work: p.work)
        let losing = VoxelOrigamiGenerated(entry: g.entry, level: g.level, plan: short, difficulty: g.difficulty,
                                           skipped: g.skipped)
        #expect(throws: VoxelOrigamiError.witness("replay")) { try VoxelOrigamiWitness.make(losing) }
        var states: [Int] = p.statesByDepth
        states[states.count - 1] += 1
        let miscounted = VoxelOrigamiPlan(turns: p.turns, statesByDepth: states, work: p.work)
        let wrongCount = VoxelOrigamiGenerated(entry: g.entry, level: g.level, plan: miscounted,
                                               difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: VoxelOrigamiError.witness("counterexample")) { try VoxelOrigamiWitness.make(wrongCount) }
        let wrongDifficulty = VoxelOrigamiGenerated(entry: g.entry, level: g.level, plan: p,
                                                    difficulty: voxelOrigamiDifficulty(g.difficulty, cubesBy: 1),
                                                    skipped: g.skipped)
        #expect(throws: VoxelOrigamiError.witness("difficulty")) { try VoxelOrigamiWitness.make(wrongDifficulty) }
        let moreWork = VoxelOrigamiPlan(turns: p.turns, statesByDepth: p.statesByDepth, work: p.work + 1)
        let wrongWork = VoxelOrigamiGenerated(entry: g.entry, level: g.level, plan: moreWork,
                                              difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: VoxelOrigamiError.witness("difficulty")) { try VoxelOrigamiWitness.make(wrongWork) }
        let otherEntry = VoxelOrigamiGenerated(entry: VoxelOrigamiManifest.entries[g.entry.number],
                                               level: g.level, plan: p, difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: VoxelOrigamiError.witness("number")) { try VoxelOrigamiWitness.make(otherEntry) }
        let empty = VoxelOrigamiPlan(turns: [], statesByDepth: [], work: p.work)
        let none = VoxelOrigamiGenerated(entry: g.entry, level: g.level, plan: empty, difficulty: g.difficulty,
                                         skipped: g.skipped)
        #expect(throws: VoxelOrigamiError.witness("actions")) { try VoxelOrigamiWitness.make(none) }
    }
}
