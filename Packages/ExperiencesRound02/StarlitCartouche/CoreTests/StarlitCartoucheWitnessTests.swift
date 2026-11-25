// StarlitCartoucheWitnessTests — feature 452 (R02-G16-02) T-R02G1602-005 (FR-R02G1602-004; SC-R02G1602-003, 005;
// clarification Q4), modelled on VoxelOrigamiWitnessTests (feature 442). Witnesses of generated catalog levels 1 (band
// 1, tutorial), 4 (band 1), 21 and 22 (band 2), built once per process. The stored form round-trips byte for byte with
// sorted keys and one trailing newline; equal makes give equal bytes; the state digest is the first 16 hex characters
// of SHA-256 over the canonical star, beat and drawn-strokes text (checked against known values); digests and
// fingerprints agree with an independent replay; the counterexample is the solver's states at the depth one below the
// plan; edited actions, digests, fingerprints, counterexample, difficulty, level (bytes and values), number, skipped
// and schema are refused naming the part; newer and truncated stored forms are refused; `make` refuses values that are
// not the plan's. Explicit types, plain loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import StarlitCartoucheCore

/// The generated levels and witnesses the tests share, built once.
struct StarlitCartoucheWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: StarlitCartoucheGenerated, witness: StarlitCartoucheWitness)]

    static let shared: StarlitCartoucheWitnessFixtures = make()

    /// The generated level and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: StarlitCartoucheGenerated, witness: StarlitCartoucheWitness) {
        let entry: StarlitCartoucheManifestEntry = StarlitCartoucheManifest.entries[index]
        let generated: StarlitCartoucheGenerated
        do { generated = try StarlitCartoucheGenerator.generate(entry) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try StarlitCartoucheWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> StarlitCartoucheWitnessFixtures {
        var cases: [(generated: StarlitCartoucheGenerated, witness: StarlitCartoucheWitness)] = []
        for index in [0, 3, 20, 21] { cases.append(pair(index)) }
        return StarlitCartoucheWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct StarlitCartoucheWitnessParts {
    var number: Int
    var level: StarlitCartoucheLevel
    var actions: [StarlitCartoucheAction]
    var digests: [String]
    var fingerprints: [String]
    var counterexample: StarlitCartoucheCounterexample
    var difficulty: StarlitCartoucheDifficulty
    var skipped: Int

    init(_ w: StarlitCartoucheWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        counterexample = w.counterexample
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: StarlitCartoucheWitness {
        StarlitCartoucheWitness(number: number, level: level, actions: actions, digests: digests,
                                fingerprints: fingerprints, counterexample: counterexample, difficulty: difficulty,
                                skipped: skipped)
    }
}

/// `d` with its stars, states searched and work changed by the given amounts.
func starlitCartoucheDifficulty(_ d: StarlitCartoucheDifficulty, starsBy stars: Int = 0, statesBy states: Int = 0,
                                workBy work: Int = 0) -> StarlitCartoucheDifficulty {
    StarlitCartoucheDifficulty(legs: d.legs, stars: d.stars + stars, corridors: d.corridors, hazards: d.hazards,
                               strokes: d.strokes, statesSearched: d.statesSearched + states, work: d.work + work)
}

@Suite struct StarlitCartoucheWitnessTests {
    let fixtures: StarlitCartoucheWitnessFixtures = .shared

    /// The refusal `decode` raises for the stored form of `witness`, or nil when it decodes.
    func refusal(_ witness: StarlitCartoucheWitness) -> StarlitCartoucheError? {
        refusal(witness.encoded())
    }

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> StarlitCartoucheError? {
        do {
            _ = try StarlitCartoucheWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: StarlitCartoucheWitness,
                _ change: (inout StarlitCartoucheWitnessParts) -> Void) -> StarlitCartoucheWitness {
        var parts = StarlitCartoucheWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: StarlitCartoucheWitness, key: String, line: String?) -> Data {
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

    /// A witness of `fixtures` with at least two legs.
    var multi: StarlitCartoucheWitness? {
        for (_, witness) in fixtures.cases where witness.actions.count >= 2 { return witness }
        return nil
    }

    @Test("the fixtures cover bands 1 and 2, a tutorial and a multi-leg plan")
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
            let decoded: StarlitCartoucheWitness = try StarlitCartoucheWitness.decode(data)
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
            let again: StarlitCartoucheWitness = try StarlitCartoucheWitness.make(generated)
            #expect(again == witness)
            #expect(again.encoded() == witness.encoded())
        }
        let entry: StarlitCartoucheManifestEntry = StarlitCartoucheManifest.entries[0]
        let regenerated: StarlitCartoucheGenerated = try StarlitCartoucheGenerator.generate(entry)
        let fresh: StarlitCartoucheWitness = try StarlitCartoucheWitness.make(regenerated)
        #expect(fresh.encoded() == fixtures.cases[0].witness.encoded())
    }

    @Test("the witness carries the plan's legs, counterexample, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == StarlitCartoucheGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.plan.legs)
            #expect(witness.actions.count <= witness.level.budget)
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
            let level: StarlitCartoucheLevel = witness.level
            #expect(witness.digests.count == witness.actions.count)
            let starts: Int = level.tutorial ? 2 : 1
            #expect(witness.fingerprints.count == starts + witness.actions.count)
            var play = StarlitCartouchePlay(level: level)
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
                var text: String = "star=\(play.star);beat=\(play.beat);drawn="
                for (position, stroke) in play.drawn.sorted().enumerated() {
                    if position > 0 { text += "," }
                    text += String(stroke)
                }
                digests.append(String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
            }
            #expect(play.stage == .won)
            #expect(play.actionsSpent <= level.budget)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            #expect(StarlitCartoucheSolver.wins(level, actions: witness.actions))
        }
    }

    @Test("the canonical text sorts the drawn strokes and the digest has known values")
    func digestDefinition() {
        #expect(StarlitCartoucheWitness.canonicalText(star: 2, beat: 7, drawn: [0, 3]) == "star=2;beat=7;drawn=0,3")
        #expect(StarlitCartoucheWitness.canonicalText(star: 2, beat: 7, drawn: [3, 0]) == "star=2;beat=7;drawn=0,3")
        #expect(StarlitCartoucheWitness.canonicalText(star: 0, beat: 0, drawn: []) == "star=0;beat=0;drawn=")
        // Known values: `printf '<text>' | shasum -a 256`, first 16 characters.
        #expect(StarlitCartoucheWitness.digest(star: 2, beat: 7, drawn: [0, 3]) == "cd57e83b4df7af36")
        #expect(StarlitCartoucheWitness.digest(star: 2, beat: 7, drawn: [3, 0]) == "cd57e83b4df7af36")
        #expect(StarlitCartoucheWitness.digest(star: 0, beat: 0, drawn: []) == "69c5ac880eac74ba")
        let full: String = StableHash.sha256Hex(Array("star=2;beat=7;drawn=0,3".utf8))
        #expect(StarlitCartoucheWitness.digest(star: 2, beat: 7, drawn: [0, 3]) == String(full.prefix(16)))
        var seen: Set<String> = []
        seen.insert(StarlitCartoucheWitness.digest(star: 2, beat: 7, drawn: [0, 3]))
        seen.insert(StarlitCartoucheWitness.digest(star: 3, beat: 7, drawn: [0, 3]))
        seen.insert(StarlitCartoucheWitness.digest(star: 2, beat: 8, drawn: [0, 3]))
        seen.insert(StarlitCartoucheWitness.digest(star: 2, beat: 7, drawn: [0]))
        seen.insert(StarlitCartoucheWitness.digest(star: 2, beat: 7, drawn: [0, 3, 4]))
        #expect(seen.count == 5)
    }

    @Test("no plan of one leg fewer wins: dropping any one leg does not win")
    func droppingALegLoses() throws {
        let w: StarlitCartoucheWitness = try #require(multi)
        for index in 0..<w.actions.count {
            var shorter: [StarlitCartoucheAction] = w.actions
            shorter.remove(at: index)
            #expect(!StarlitCartoucheSolver.wins(w.level, actions: shorter))
        }
    }

    @Test("an edited action is refused")
    func editedActionRefused() throws {
        let w: StarlitCartoucheWitness = try #require(multi)
        let stars: Int = w.level.stars.count
        guard case .leg(let firstStar, let firstWait) = w.actions[0] else { return }
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.leg(stars, 0)] + w.actions }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.leg(-1, 0)] + w.actions }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.leg(firstStar, 9)] + w.actions }) == .witness("actions"))
        var long: [StarlitCartoucheAction] = []
        for _ in 0...w.level.budget { long.append(w.actions[0]) }
        #expect(refusal(edited(w) { $0.actions = long }) == .witness("actions"))
        // A shorter plan replays without winning; a leg after the win is refused by the play.
        #expect(refusal(edited(w) { $0.actions = Array(w.actions.dropLast()) }) == .witness("replay"))
        #expect(refusal(edited(w) { $0.actions = w.actions + [w.actions[0]] }) == .witness("replay"))
        // Another wait on the first leg: refused as a non-replay, or as not the solver's plan when it still wins.
        var checked: Int = 0
        for wait in StarlitCartoucheChart.waits where wait != firstWait {
            var actions: [StarlitCartoucheAction] = w.actions
            actions[0] = .leg(firstStar, wait)
            let expected: StarlitCartoucheError = StarlitCartoucheSolver.wins(w.level, actions: actions)
                ? .witness("solution") : .witness("replay")
            #expect(refusal(edited(w) { $0.actions = actions }) == expected)
            checked += 1
        }
        #expect(checked == 8)
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
        let w: StarlitCartoucheWitness = fixtures.cases[2].witness
        let c: StarlitCartoucheCounterexample = w.counterexample
        let more = StarlitCartoucheCounterexample(depth: c.depth, states: c.states + 1)
        #expect(refusal(edited(w) { $0.counterexample = more }) == .witness("counterexample"))
        let lower = StarlitCartoucheCounterexample(depth: c.depth - 1, states: c.states)
        #expect(refusal(edited(w) { $0.counterexample = lower }) == .witness("counterexample"))
        let stars: StarlitCartoucheDifficulty = starlitCartoucheDifficulty(w.difficulty, starsBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = stars }) == .witness("difficulty"))
        let states: StarlitCartoucheDifficulty = starlitCartoucheDifficulty(w.difficulty, statesBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = states }) == .witness("difficulty"))
        let work: StarlitCartoucheDifficulty = starlitCartoucheDifficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = work }) == .witness("difficulty"))
    }

    @Test("an edited level, number or skipped count is refused")
    func editedLevelRefused() throws {
        let w: StarlitCartoucheWitness = fixtures.cases[0].witness
        let l: StarlitCartoucheLevel = w.level
        // A level that still replays but is not the generator's candidate.
        let reseeded = try StarlitCartoucheLevel(id: l.id, seed: l.seed &+ 1, difficulty: l.difficulty,
                                                 stars: l.stars, range: l.range, corridors: l.corridors,
                                                 hazards: l.hazards, start: l.start, beacon: l.beacon,
                                                 deadline: l.deadline, symbol: l.symbol, budget: l.budget,
                                                 tutorial: l.tutorial)
        #expect(StarlitCartoucheSolver.wins(reseeded, actions: w.actions))
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
        let maxCandidates: Int = StarlitCartoucheGenerator.maxCandidates
        #expect(refusal(edited(w) { $0.skipped = maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = -1 }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    @Test("newer, older, truncated and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: StarlitCartoucheWitness = fixtures.cases[0].witness
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
        #expect(StarlitCartoucheError.witness("digests").reasonCode == "r02-g16.witness")
    }

    @Test("make refuses values that are not the solver's plan")
    func makeRefuses() throws {
        let w: StarlitCartoucheWitness = try #require(multi)
        var found: StarlitCartoucheGenerated?
        for (generated, witness) in fixtures.cases where witness == w { found = generated }
        let g: StarlitCartoucheGenerated = try #require(found)
        let p: StarlitCartouchePlan = g.plan
        let short = StarlitCartouchePlan(legs: Array(p.legs.dropLast()), statesByDepth: p.statesByDepth,
                                         work: p.work)
        let losing = StarlitCartoucheGenerated(entry: g.entry, level: g.level, plan: short, difficulty: g.difficulty,
                                               skipped: g.skipped)
        #expect(throws: StarlitCartoucheError.witness("replay")) { try StarlitCartoucheWitness.make(losing) }
        var states: [Int] = p.statesByDepth
        states[states.count - 1] += 1
        let miscounted = StarlitCartouchePlan(legs: p.legs, statesByDepth: states, work: p.work)
        let wrongCount = StarlitCartoucheGenerated(entry: g.entry, level: g.level, plan: miscounted,
                                                   difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: StarlitCartoucheError.witness("counterexample")) {
            try StarlitCartoucheWitness.make(wrongCount)
        }
        let wrongDifficulty = StarlitCartoucheGenerated(entry: g.entry, level: g.level, plan: p,
                                                        difficulty: starlitCartoucheDifficulty(g.difficulty,
                                                                                               starsBy: 1),
                                                        skipped: g.skipped)
        #expect(throws: StarlitCartoucheError.witness("difficulty")) {
            try StarlitCartoucheWitness.make(wrongDifficulty)
        }
        let moreWork = StarlitCartouchePlan(legs: p.legs, statesByDepth: p.statesByDepth, work: p.work + 1)
        let wrongWork = StarlitCartoucheGenerated(entry: g.entry, level: g.level, plan: moreWork,
                                                  difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: StarlitCartoucheError.witness("difficulty")) { try StarlitCartoucheWitness.make(wrongWork) }
        let otherEntry = StarlitCartoucheGenerated(entry: StarlitCartoucheManifest.entries[g.entry.number],
                                                   level: g.level, plan: p, difficulty: g.difficulty,
                                                   skipped: g.skipped)
        #expect(throws: StarlitCartoucheError.witness("number")) { try StarlitCartoucheWitness.make(otherEntry) }
        let empty = StarlitCartouchePlan(legs: [], statesByDepth: [], work: p.work)
        let none = StarlitCartoucheGenerated(entry: g.entry, level: g.level, plan: empty, difficulty: g.difficulty,
                                             skipped: g.skipped)
        #expect(throws: StarlitCartoucheError.witness("actions")) { try StarlitCartoucheWitness.make(none) }
    }
}
