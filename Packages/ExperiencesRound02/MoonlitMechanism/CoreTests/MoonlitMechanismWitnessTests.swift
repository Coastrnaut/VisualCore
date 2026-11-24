// MoonlitMechanismWitnessTests — feature 432 (R02-G14-02) T-R02G1402-005 (FR-R02G1402-004; SC-R02G1402-003, 005;
// clarification Q4). Witnesses of generated catalog levels 1 (band 1, tutorial), 21 (band 2), 41 (band 3) and 61
// (band 4), built once per process. The stored form round-trips byte for byte with sorted keys and one trailing
// newline; equal makes give equal bytes; the state digest is the first 16 hex characters of SHA-256 over the canonical
// phases-and-height text (checked against a hand-built value) and changes with the phases or the height; digests and
// fingerprints agree with a replay; the counterexample's closed-form vector count equals a brute-force enumeration and
// the plan's smaller vectors; edited actions, digests, fingerprints, counterexample, difficulty (work included), level,
// number, skipped and schema are refused naming the part; newer and damaged stored forms are refused; `make` refuses a
// losing plan and values that are not the plan's. Explicit types, plain loops (CI type-check rule), short runs, no
// wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import MoonlitMechanismCore

/// The generated levels and witnesses the tests share, built once.
struct MoonlitMechanismWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: MoonlitMechanismGenerated, witness: MoonlitMechanismWitness)]

    static let shared: MoonlitMechanismWitnessFixtures = make()

    /// The generated level and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: MoonlitMechanismGenerated, witness: MoonlitMechanismWitness) {
        let entry: MoonlitMechanismManifestEntry = MoonlitMechanismManifest.entries[index]
        let generated: MoonlitMechanismGenerated
        do { generated = try MoonlitMechanismGenerator.generate(entry) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try MoonlitMechanismWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> MoonlitMechanismWitnessFixtures {
        var cases: [(generated: MoonlitMechanismGenerated, witness: MoonlitMechanismWitness)] = []
        for index in [0, 20, 40, 60] { cases.append(pair(index)) }
        return MoonlitMechanismWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct MoonlitMechanismWitnessParts {
    var number: Int
    var level: MoonlitMechanismLevel
    var actions: [MoonlitMechanismAction]
    var digests: [String]
    var fingerprints: [String]
    var counterexample: MoonlitMechanismCounterexample
    var difficulty: MoonlitMechanismDifficulty
    var skipped: Int

    init(_ w: MoonlitMechanismWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        counterexample = w.counterexample
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: MoonlitMechanismWitness {
        MoonlitMechanismWitness(number: number, level: level, actions: actions, digests: digests,
                                fingerprints: fingerprints, counterexample: counterexample, difficulty: difficulty,
                                skipped: skipped)
    }
}

/// `d` with its gears, smaller vectors and work changed by the given amounts.
func moonlitMechanismDifficulty(_ d: MoonlitMechanismDifficulty, gearsBy gears: Int = 0, smallerBy smaller: Int = 0,
                                workBy work: Int = 0) -> MoonlitMechanismDifficulty {
    MoonlitMechanismDifficulty(actions: d.actions, gears: d.gears + gears, meshes: d.meshes, teeth: d.teeth,
                               keyFrames: d.keyFrames, requiredKeyFrames: d.requiredKeyFrames,
                               targetCells: d.targetCells, forbiddenCells: d.forbiddenCells,
                               lampHeights: d.lampHeights, smallerVectors: d.smallerVectors + smaller,
                               work: d.work + work)
}

/// `level` rebuilt (and re-fingerprinted) with a new seed, starting height or gear phases.
func moonlitMechanismLevel(_ level: MoonlitMechanismLevel, seed: UInt64? = nil, startingHeight: Int? = nil,
                           phaseShift: Int = 0) throws -> MoonlitMechanismLevel {
    var gears: [MoonlitMechanismGear] = []
    for (index, g) in level.gears.enumerated() {
        let phase: Int = index == 0 ? MoonlitMechanismTrain.mod(g.phase + phaseShift, g.teeth) : g.phase
        gears.append(MoonlitMechanismGear(teeth: g.teeth, phase: phase, blades: g.blades, depth: g.depth,
                                          centre: g.centre, parent: g.parent, alignment: g.alignment, slots: g.slots))
    }
    return try MoonlitMechanismLevel(id: level.id, seed: seed ?? level.seed, difficulty: level.difficulty,
                                     gears: gears, width: level.width, rows: level.rows,
                                     lampHeights: level.lampHeights,
                                     startingHeight: startingHeight ?? level.startingHeight,
                                     keyFrames: level.keyFrames, forbidden: level.forbidden,
                                     allowance: level.allowance, budget: level.budget, tutorial: level.tutorial)
}

@Suite struct MoonlitMechanismWitnessTests {
    let fixtures: MoonlitMechanismWitnessFixtures = .shared

    /// The refusal `decode` raises for the stored form of `witness`, or nil when it decodes.
    func refusal(_ witness: MoonlitMechanismWitness) -> MoonlitMechanismError? {
        refusal(witness.encoded())
    }

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> MoonlitMechanismError? {
        do {
            _ = try MoonlitMechanismWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: MoonlitMechanismWitness,
                _ change: (inout MoonlitMechanismWitnessParts) -> Void) -> MoonlitMechanismWitness {
        var parts = MoonlitMechanismWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: MoonlitMechanismWitness, key: String, line: String?) -> Data {
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

    /// A witness of `fixtures` with at least two actions before the run.
    var multi: MoonlitMechanismWitness? {
        for (_, witness) in fixtures.cases where witness.actions.count >= 3 { return witness }
        return nil
    }

    @Test("the fixtures cover bands 1 to 4, a tutorial and a multi-action plan")
    func fixturesCover() {
        #expect(fixtures.cases.count == 4)
        #expect(fixtures.cases[0].generated.level.tutorial)
        #expect(!fixtures.cases[1].generated.level.tutorial)
        var bands: [Int] = []
        for (generated, _) in fixtures.cases { bands.append(generated.entry.band) }
        #expect(bands == [1, 2, 3, 4])
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
            let decoded: MoonlitMechanismWitness = try MoonlitMechanismWitness.decode(data)
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
    }

    @Test("equal makes give equal bytes")
    func equalMakesEqualBytes() throws {
        for (generated, witness) in fixtures.cases {
            let again: MoonlitMechanismWitness = try MoonlitMechanismWitness.make(generated)
            #expect(again == witness)
            #expect(again.encoded() == witness.encoded())
        }
        let regenerated: MoonlitMechanismGenerated = try MoonlitMechanismGenerator.generate(
            MoonlitMechanismManifest.entries[0])
        let fresh: MoonlitMechanismWitness = try MoonlitMechanismWitness.make(regenerated)
        #expect(fresh.encoded() == fixtures.cases[0].witness.encoded())
    }

    @Test("the witness carries the plan's actions, counts, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == MoonlitMechanismGenerator.levelID(generated.entry.number))
            #expect(witness.actions == MoonlitMechanismSolver.actions(generated.plan))
            #expect(witness.actions.count == generated.plan.size + 1)
            #expect(witness.actions.last == .run)
            #expect(witness.counterexample.norm == generated.plan.size - 1)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.smallerVectors == generated.plan.smallerVectors)
            #expect(witness.difficulty.work == generated.plan.work)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("state digests and fingerprints agree with a replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: MoonlitMechanismLevel = witness.level
            #expect(witness.digests.count == witness.actions.count)
            let starts: Int = level.tutorial ? 2 : 1
            #expect(witness.fingerprints.count == starts + witness.actions.count)
            var play = MoonlitMechanismPlay(level: level)
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
                digests.append(MoonlitMechanismWitness.digest(phases: play.phases, height: play.height))
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            // The run changes no set-up, so the last two digests agree.
            #expect(witness.digests[witness.digests.count - 1] == witness.digests[witness.digests.count - 2])
        }
    }

    @Test("the state digest is 16 hex characters of SHA-256 over the canonical text and follows the state")
    func digestDefinition() {
        #expect(MoonlitMechanismWitness.canonicalText(phases: [3, 0, 11], height: 2) == "phases=3,0,11;height=2")
        let full: String = StableHash.sha256Hex(Array("phases=3,0,11;height=2".utf8))
        let digest: String = MoonlitMechanismWitness.digest(phases: [3, 0, 11], height: 2)
        #expect(digest == String(full.prefix(16)))
        #expect(digest.count == 16)
        var hex: Bool = true
        for scalar in digest.unicodeScalars where !"0123456789abcdef".unicodeScalars.contains(scalar) { hex = false }
        #expect(hex)
        #expect(MoonlitMechanismWitness.digest(phases: [3, 0, 11], height: 2) == digest)
        // Each phase change and each height change gives a new digest.
        var seen: Set<String> = [digest]
        for gear in 0..<3 {
            var phases: [Int] = [3, 0, 11]
            phases[gear] += 1
            seen.insert(MoonlitMechanismWitness.digest(phases: phases, height: 2))
        }
        for height in [0, 1, 3] { seen.insert(MoonlitMechanismWitness.digest(phases: [3, 0, 11], height: height)) }
        seen.insert(MoonlitMechanismWitness.digest(phases: [3, 0, 1, 1], height: 2))
        #expect(seen.count == 8)
    }

    @Test("the closed-form vector count equals a brute-force enumeration and the plan's smaller vectors")
    func counterexampleCounts() {
        // Dimensions 1 … 6 (one to five gears); norms up to 6 below dimension 6, up to 4 at dimension 6 (short run).
        for dimensions in 1...6 {
            let top: Int = dimensions == 6 ? 4 : 6
            let side: Int = 2 * top + 1
            var counts: [Int] = Array(repeating: 0, count: top + 1)
            var total: Int = 1
            for _ in 0..<dimensions { total *= side }
            for code in 0..<total {
                var rest: Int = code
                var norm: Int = 0
                for _ in 0..<dimensions {
                    norm += abs(rest % side - top)
                    rest /= side
                }
                if norm <= top { counts[norm] += 1 }
            }
            var formula: [Int] = []
            for norm in 0...top { formula.append(MoonlitMechanismWitness.vectors(dimensions: dimensions, norm: norm)) }
            #expect(formula == counts)
        }
        #expect(MoonlitMechanismWitness.vectors(dimensions: 3, norm: -1) == 0)
        #expect(MoonlitMechanismWitness.vectors(dimensions: 0, norm: 0) == 1)
        #expect(MoonlitMechanismWitness.vectors(dimensions: 0, norm: 2) == 0)
        for (generated, witness) in fixtures.cases {
            let dimensions: Int = generated.level.gears.count + 1
            var smaller: Int = 0
            for norm in 0..<generated.plan.size {
                smaller += MoonlitMechanismWitness.vectors(dimensions: dimensions, norm: norm)
            }
            #expect(smaller == generated.plan.smallerVectors)
            let atNorm: Int = MoonlitMechanismWitness.vectors(dimensions: dimensions, norm: generated.plan.size - 1)
            #expect(witness.counterexample.vectors == atNorm)
            #expect(witness.counterexample.vectors >= 1)
        }
    }

    @Test("no plan of one action fewer wins: dropping any one action before the run loses")
    func droppingAnActionLoses() throws {
        let w: MoonlitMechanismWitness = try #require(multi)
        for index in 0..<(w.actions.count - 1) {
            var shorter: [MoonlitMechanismAction] = w.actions
            shorter.remove(at: index)
            #expect(!MoonlitMechanismSolver.wins(w.level, actions: shorter))
        }
        #expect(MoonlitMechanismSolver.wins(w.level, actions: w.actions))
    }

    @Test("an edited action is refused")
    func editedActionRefused() throws {
        let w: MoonlitMechanismWitness = try #require(multi)
        // An opposite pair inserted in front keeps the net vector but breaks the solver's action order.
        let inverse: MoonlitMechanismAction
        switch w.actions[0] {
        case .turn(let step): inverse = .turn(-step)
        case .reseat(let gear, let step): inverse = .reseat(gear, -step)
        case .lamp(let step): inverse = .lamp(-step)
        case .run: inverse = .run
        }
        let padded: [MoonlitMechanismAction] = [inverse, w.actions[0]] + w.actions
        #expect(refusal(edited(w) { $0.actions = padded }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = Array(w.actions.dropLast()) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.run] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.reseat(0, 1), .run] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.turn(2), .run] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.run, .run] }) == .witness("actions"))
        // A well-ordered but shorter plan replays without winning.
        let shorter: [MoonlitMechanismAction] = Array(w.actions.dropFirst())
        #expect(refusal(edited(w) { $0.actions = shorter }) == .witness("replay"))
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
        let w: MoonlitMechanismWitness = fixtures.cases[1].witness
        let c: MoonlitMechanismCounterexample = w.counterexample
        let more = MoonlitMechanismCounterexample(norm: c.norm, vectors: c.vectors + 1)
        #expect(refusal(edited(w) { $0.counterexample = more }) == .witness("counterexample"))
        let lower = MoonlitMechanismCounterexample(norm: c.norm - 1, vectors: c.vectors)
        #expect(refusal(edited(w) { $0.counterexample = lower }) == .witness("counterexample"))
        let gears: MoonlitMechanismDifficulty = moonlitMechanismDifficulty(w.difficulty, gearsBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = gears }) == .witness("difficulty"))
        let smaller: MoonlitMechanismDifficulty = moonlitMechanismDifficulty(w.difficulty, smallerBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = smaller }) == .witness("difficulty"))
    }

    /// Feature 382's convergence lesson: decoding re-runs the solver, so an edited solver work count is refused.
    @Test("an edited solver result is refused")
    func editedSolverResultRefused() {
        let w: MoonlitMechanismWitness = fixtures.cases[2].witness
        let more: MoonlitMechanismDifficulty = moonlitMechanismDifficulty(w.difficulty, workBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = more }) == .witness("solution"))
        let less: MoonlitMechanismDifficulty = moonlitMechanismDifficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = less }) == .witness("solution"))
    }

    @Test("an edited level, number or skipped count is refused")
    func editedLevelRefused() throws {
        let w: MoonlitMechanismWitness = fixtures.cases[0].witness
        // A level whose start is changed (and re-fingerprinted) no longer replays to a win.
        let shifted: MoonlitMechanismLevel = try moonlitMechanismLevel(w.level, phaseShift: 1)
        #expect(refusal(edited(w) { $0.level = shifted }) == .witness("replay"))
        // A level that still replays but is not the generator's candidate.
        let reseeded: MoonlitMechanismLevel = try moonlitMechanismLevel(w.level, seed: w.level.seed &+ 1)
        #expect(MoonlitMechanismSolver.wins(reseeded, actions: w.actions))
        #expect(refusal(edited(w) { $0.level = reseeded }) == .witness("candidate"))
        // A level field edited in the stored text breaks the level's fingerprint.
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let budget: String = "    \"budget\" : \(w.level.budget),"
        #expect(text.contains(budget))
        let damaged: String = text.replacingOccurrences(of: budget, with: "    \"budget\" : \(w.level.budget + 1),")
        #expect(refusal(Data(damaged.utf8)) == .witness("level"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = 0 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = MoonlitMechanismGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = -1 }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    @Test("newer, older and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: MoonlitMechanismWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .witness("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "level", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "number", line: "\"one\"")) == .witness("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .witness("unreadable"))
        #expect(refusal(Data()) == .witness("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .witness("unreadable"))
        #expect(MoonlitMechanismError.witness("digests").reasonCode == "r02-g14.witness")
        #expect(MoonlitMechanismError.newerSchema(2).reasonCode == "r02-g14.newer-schema")
    }

    @Test("make refuses a losing plan and values that are not the plan's")
    func makeRefuses() throws {
        let w: MoonlitMechanismWitness = try #require(multi)
        var found: MoonlitMechanismGenerated?
        for (generated, witness) in fixtures.cases where witness == w { found = generated }
        let g: MoonlitMechanismGenerated = try #require(found)
        let p: MoonlitMechanismPlan = g.plan
        // One step fewer on the first non-zero coordinate: a well-ordered plan that loses.
        var turns: Int = p.turns
        var lamp: Int = p.lamp
        var reseats: [Int] = p.reseats
        if turns != 0 {
            turns -= turns > 0 ? 1 : -1
        } else if let gear = reseats.firstIndex(where: { $0 != 0 }) {
            reseats[gear] -= reseats[gear] > 0 ? 1 : -1
        } else {
            lamp -= lamp > 0 ? 1 : -1
        }
        let short = MoonlitMechanismPlan(turns: turns, lamp: lamp, reseats: reseats, smallerVectors: p.smallerVectors,
                                         work: p.work)
        let losing = MoonlitMechanismGenerated(entry: g.entry, level: g.level, plan: short, difficulty: g.difficulty,
                                               skipped: g.skipped)
        #expect(throws: MoonlitMechanismError.witness("replay")) { try MoonlitMechanismWitness.make(losing) }
        let miscounted = MoonlitMechanismPlan(turns: p.turns, lamp: p.lamp, reseats: p.reseats,
                                              smallerVectors: p.smallerVectors + 1, work: p.work)
        let wrongCount = MoonlitMechanismGenerated(entry: g.entry, level: g.level, plan: miscounted,
                                                   difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: MoonlitMechanismError.witness("counterexample")) {
            try MoonlitMechanismWitness.make(wrongCount)
        }
        let wrongDifficulty = MoonlitMechanismGenerated(
            entry: g.entry, level: g.level, plan: p,
            difficulty: moonlitMechanismDifficulty(g.difficulty, gearsBy: 1), skipped: g.skipped)
        #expect(throws: MoonlitMechanismError.witness("difficulty")) {
            try MoonlitMechanismWitness.make(wrongDifficulty)
        }
        let otherEntry = MoonlitMechanismGenerated(entry: MoonlitMechanismManifest.entries[g.entry.number],
                                                   level: g.level, plan: p, difficulty: g.difficulty,
                                                   skipped: g.skipped)
        #expect(throws: MoonlitMechanismError.witness("number")) { try MoonlitMechanismWitness.make(otherEntry) }
        let zero = MoonlitMechanismPlan(turns: 0, lamp: 0, reseats: Array(repeating: 0, count: p.reseats.count),
                                        smallerVectors: 0, work: p.work)
        let empty = MoonlitMechanismGenerated(entry: g.entry, level: g.level, plan: zero, difficulty: g.difficulty,
                                              skipped: g.skipped)
        #expect(throws: MoonlitMechanismError.witness("actions")) { try MoonlitMechanismWitness.make(empty) }
    }
}
