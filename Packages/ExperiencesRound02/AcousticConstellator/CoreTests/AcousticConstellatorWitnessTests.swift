// AcousticConstellatorWitnessTests — feature 422 (R02-G13-02) T-R02G1302-005 (FR-R02G1302-004; SC-R02G1302-003, 005;
// clarification Q4). Witnesses of generated catalog levels 1 (band 1, tutorial), 21 (band 2) and 41 (band 3), built
// once per process. The stored form round-trips byte for byte with sorted keys and one trailing newline; the state
// digest is the first 16 hex characters of SHA-256 over the canonical links-and-phases text (checked against a
// hand-computed value); digests and fingerprints agree with a replay; the counterexample is re-checked by the recount
// (no set of one extra fewer wins, the plan's extra size finds a win, its count and reason agree with the plan, and
// dropping any one action loses); edited actions, digests, fingerprints, counterexample, difficulty (work included),
// level, number, skipped and schema are refused naming the part; newer and damaged stored forms are refused; `make`
// refuses a losing plan and values that are not the plan's. Explicit types, plain loops (CI type-check rule), short
// runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import AcousticConstellatorCore

/// The generated levels and witnesses the tests share, built once.
struct AcousticConstellatorWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: AcousticConstellatorGenerated, witness: AcousticConstellatorWitness)]

    static let shared: AcousticConstellatorWitnessFixtures = make()

    /// The generated level and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: AcousticConstellatorGenerated, witness: AcousticConstellatorWitness) {
        let entry: AcousticConstellatorManifestEntry = AcousticConstellatorManifest.entries[index]
        let generated: AcousticConstellatorGenerated
        do { generated = try AcousticConstellatorGenerator.generate(entry) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try AcousticConstellatorWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> AcousticConstellatorWitnessFixtures {
        var cases: [(generated: AcousticConstellatorGenerated, witness: AcousticConstellatorWitness)] = []
        for index in [0, 20, 40] { cases.append(pair(index)) }
        return AcousticConstellatorWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct AcousticConstellatorWitnessParts {
    var number: Int
    var level: AcousticConstellatorLevel
    var actions: [AcousticConstellatorAction]
    var digests: [String]
    var fingerprints: [String]
    var counterexample: AcousticConstellatorCounterexample
    var difficulty: AcousticConstellatorDifficulty
    var skipped: Int

    init(_ w: AcousticConstellatorWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        counterexample = w.counterexample
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: AcousticConstellatorWitness {
        AcousticConstellatorWitness(number: number, level: level, actions: actions, digests: digests,
                                    fingerprints: fingerprints, counterexample: counterexample,
                                    difficulty: difficulty, skipped: skipped)
    }
}

/// `d` with its stars, smaller sets and work changed by the given amounts.
func acousticConstellatorDifficulty(_ d: AcousticConstellatorDifficulty, starsBy stars: Int = 0,
                                    smallerBy smaller: Int = 0,
                                    workBy work: Int = 0) -> AcousticConstellatorDifficulty {
    AcousticConstellatorDifficulty(actions: d.actions, stars: d.stars + stars, symbolPairs: d.symbolPairs,
                                   cycles: d.cycles, fixedLinks: d.fixedLinks, rateSpread: d.rateSpread,
                                   window: d.window, hold: d.hold, threshold: d.threshold,
                                   smallerSets: d.smallerSets + smaller, work: d.work + work)
}

@Suite("Acoustic Constellator witness")
struct AcousticConstellatorWitnessTests {
    let fixtures: AcousticConstellatorWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: AcousticConstellatorWitness) -> AcousticConstellatorError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> AcousticConstellatorError? {
        do {
            _ = try AcousticConstellatorWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: AcousticConstellatorWitness,
                _ change: (inout AcousticConstellatorWitnessParts) -> Void) -> AcousticConstellatorWitness {
        var parts = AcousticConstellatorWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: AcousticConstellatorWitness, key: String, line: String?) -> Data {
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

    /// A witness of `fixtures` with at least two actions before the listen.
    var multi: AcousticConstellatorWitness? {
        for (_, witness) in fixtures.cases where witness.actions.count >= 3 { return witness }
        return nil
    }

    /// The extra actions of a generated plan: its actions beyond the missing symbol pairs.
    func extras(_ generated: AcousticConstellatorGenerated) -> Int {
        generated.plan.size - AcousticConstellatorSolver.missing(generated.level).count
    }

    @Test("the fixtures cover bands 1 to 3, a tutorial, a multi-action plan and both counterexample reasons")
    func fixturesCover() {
        #expect(fixtures.cases.count == 3)
        #expect(fixtures.cases[0].generated.level.tutorial)
        var bands: [Int] = []
        for (generated, _) in fixtures.cases { bands.append(generated.entry.band) }
        #expect(bands == [1, 2, 3])
        #expect(multi != nil)
        // Both counterexample reasons occur: levels 1 and 41 have no extra action, level 21 has one.
        var reasons: [String] = []
        for (_, witness) in fixtures.cases { reasons.append(witness.counterexample.reason) }
        #expect(reasons == ["missing", "tried", "missing"])
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
            let decoded: AcousticConstellatorWitness = try AcousticConstellatorWitness.decode(data)
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

    @Test("the witness carries the plan's actions, counts, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == AcousticConstellatorGenerator.levelID(generated.entry.number))
            #expect(witness.actions == AcousticConstellatorSolver.actions(generated.plan))
            #expect(witness.actions.count == generated.plan.size + 1)
            #expect(witness.actions.last == .listen)
            #expect(witness.counterexample.size == generated.plan.size - 1)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.smallerSets == generated.plan.smallerSets)
            #expect(witness.difficulty.work == generated.plan.work)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("state digests and fingerprints agree with a replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: AcousticConstellatorLevel = witness.level
            #expect(witness.digests.count == witness.actions.count)
            let starts: Int = level.tutorial ? 2 : 1
            #expect(witness.fingerprints.count == starts + witness.actions.count)
            var play = AcousticConstellatorPlay(level: level)
            try play.handle(.begin)
            var fingerprints: [String] = [play.fingerprint]
            if play.stage == .tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            var links: [AcousticConstellatorLink] = level.fixedLinks
            var phases: [Int] = level.startingPhases
            var digests: [String] = []
            for action in witness.actions {
                #expect(play.stage == .playing)
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                if case let .link(a, b) = action { links.append(AcousticConstellatorLink.between(a, b)) }
                if case let .nudge(star, step) = action { phases[star] = (phases[star] + step + 12) % 12 }
                digests.append(AcousticConstellatorWitness.digest(links: links, phases: phases))
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            #expect(AcousticConstellatorSolver.wins(level, actions: witness.actions))
            for digest in witness.digests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
        }
    }

    @Test("the counterexample is consistent: one extra fewer loses, its count and reason are the plan's")
    func counterexampleConsistent() {
        for (generated, witness) in fixtures.cases {
            let level: AcousticConstellatorLevel = witness.level
            let e: Int = extras(generated)
            let counts: [Int]? = AcousticConstellatorWitness.smallerSets(level, extras: e)
            #expect(counts?.count == e)
            var total: Int = 0
            for count in counts ?? [] { total += count }
            #expect(total == generated.plan.smallerSets)
            // The plan's extra size is the first that wins: the recount one extra further finds the plan.
            #expect(AcousticConstellatorWitness.smallerSets(level, extras: e + 1) == nil)
            if e == 0 {
                #expect(witness.counterexample.reason == AcousticConstellatorCounterexample.missing)
                #expect(witness.counterexample.sets == 0)
                #expect(generated.plan.smallerSets == 0)
            } else {
                #expect(witness.counterexample.reason == AcousticConstellatorCounterexample.tried)
                #expect(witness.counterexample.sets == counts?[e - 1])
                #expect(witness.counterexample.sets >= 1)
            }
            // Dropping any one action of the plan loses.
            let actions: [AcousticConstellatorAction] = witness.actions
            for skip in 0..<(actions.count - 1) {
                var fewer: [AcousticConstellatorAction] = []
                for (index, action) in actions.enumerated() where index != skip { fewer.append(action) }
                #expect(!AcousticConstellatorSolver.wins(level, actions: fewer))
            }
        }
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over the canonical links-and-phases text")
    func digestLayout() {
        // printf '%s' 'links=0-1,1-2;phases=3,0,11' | shasum -a 256 → 9eb59b2db4d664aa…
        let links: [AcousticConstellatorLink] = [AcousticConstellatorLink(a: 1, b: 2),
                                                 AcousticConstellatorLink(a: 0, b: 1)]
        #expect(AcousticConstellatorWitness.canonicalText(links: links, phases: [3, 0, 11])
            == "links=0-1,1-2;phases=3,0,11")
        #expect(AcousticConstellatorWitness.digest(links: links, phases: [3, 0, 11]) == "9eb59b2db4d664aa")
        for (_, witness) in fixtures.cases {
            let level: AcousticConstellatorLevel = witness.level
            let start: String = AcousticConstellatorWitness.digest(links: level.fixedLinks,
                                                                   phases: level.startingPhases)
            // The last action is the listen, which changes neither links nor phases; the plan changed the state.
            let count: Int = witness.digests.count
            #expect(witness.digests[count - 1] == witness.digests[count - 2])
            #expect(witness.digests[count - 1] != start)
        }
    }

    @Test("edited actions are refused")
    func editedActionsRefused() throws {
        let w: AcousticConstellatorWitness = try #require(multi)
        let first: AcousticConstellatorAction = w.actions[0]
        #expect(refusal(edited(w) { $0.actions.removeLast() }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions.append(.listen) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.listen] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions.insert(first, at: 1) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions[0] = .unlink(0, 1) }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions.insert(.nudge(0, 2), at: w.actions.count - 1) })
            == .witness("actions"))
        // An extra nudge on the last star keeps the shape but breaks the replay or the win.
        let n: Int = w.level.stars.count
        #expect(refusal(edited(w) { $0.actions.insert(.nudge(n - 1, 1), at: w.actions.count - 1) }) != nil)
        // One action fewer: the shape holds but the listen loses.
        #expect(refusal(edited(w) { $0.actions.remove(at: 0) }) == .witness("replay"))
    }

    @Test("edited state digests are refused")
    func editedDigestsRefused() {
        let w: AcousticConstellatorWitness = fixtures.cases[1].witness
        let first: String = w.digests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.digests[0] = flipped }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.digests.removeLast() }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.digests.append(first) }) == .witness("digests"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: AcousticConstellatorWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
        // Level 1 has a tutorial: dropping the fingerprint after `dismissTutorial` is refused.
        #expect(refusal(edited(w) { $0.fingerprints.remove(at: 1) }) == .witness("fingerprints"))
    }

    @Test("an edited counterexample is refused")
    func editedCounterexampleRefused() {
        for (_, w) in fixtures.cases {
            let c: AcousticConstellatorCounterexample = w.counterexample
            let more = AcousticConstellatorCounterexample(size: c.size, sets: c.sets + 1, reason: c.reason)
            #expect(refusal(edited(w) { $0.counterexample = more }) == .witness("counterexample"))
            let smaller = AcousticConstellatorCounterexample(size: c.size - 1, sets: c.sets, reason: c.reason)
            #expect(refusal(edited(w) { $0.counterexample = smaller }) == .witness("counterexample"))
            let other: String = c.reason == AcousticConstellatorCounterexample.tried
                ? AcousticConstellatorCounterexample.missing : AcousticConstellatorCounterexample.tried
            let renamed = AcousticConstellatorCounterexample(size: c.size, sets: c.sets, reason: other)
            #expect(refusal(edited(w) { $0.counterexample = renamed }) == .witness("counterexample"))
        }
    }

    @Test("an edited level is refused")
    func editedLevelRefused() throws {
        let w: AcousticConstellatorWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let budget: Int = w.level.budget
        let changedBudget: Int = budget + 1
        let changed: String = text.replacingOccurrences(of: "\"budget\" : \(budget),",
                                                        with: "\"budget\" : \(changedBudget),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
        // A re-fingerprinted level that is not the generator's candidate.
        let l: AcousticConstellatorLevel = w.level
        let other = try AcousticConstellatorLevel(id: l.id, seed: l.seed, difficulty: l.difficulty, stars: l.stars,
                                                  fixedLinks: l.fixedLinks, symbol: l.symbol, coupling: l.coupling,
                                                  degreeLimit: l.degreeLimit, linkLimit: l.linkLimit,
                                                  snapLimit: l.snapLimit, threshold: l.threshold, hold: l.hold,
                                                  window: l.window, budget: changedBudget, tutorial: l.tutorial)
        #expect(refusal(edited(w) { $0.level = other }) == .witness("candidate"))
    }

    @Test("edited difficulty, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: AcousticConstellatorWitness = fixtures.cases[1].witness
        let wider: AcousticConstellatorDifficulty = acousticConstellatorDifficulty(w.difficulty, starsBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = wider }) == .witness("difficulty"))
        let smaller: AcousticConstellatorDifficulty = acousticConstellatorDifficulty(w.difficulty, smallerBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = smaller }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = 0 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = AcousticConstellatorGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = -1 }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    /// Feature 382's convergence lesson: decoding re-runs the solver, so an edited solver work count is refused.
    @Test("an edited solver result is refused")
    func editedSolverResultRefused() {
        let w: AcousticConstellatorWitness = fixtures.cases[2].witness
        let more: AcousticConstellatorDifficulty = acousticConstellatorDifficulty(w.difficulty, workBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = more }) == .witness("solution"))
        let less: AcousticConstellatorDifficulty = acousticConstellatorDifficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = less }) == .witness("solution"))
    }

    @Test("newer, older and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: AcousticConstellatorWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .witness("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "level", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "number", line: "\"one\"")) == .witness("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .witness("unreadable"))
        #expect(refusal(Data()) == .witness("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .witness("unreadable"))
        #expect(AcousticConstellatorError.witness("digests").reasonCode == "r02-g13.witness")
        #expect(AcousticConstellatorError.newerSchema(2).reasonCode == "r02-g13.newer-schema")
    }

    @Test("make refuses a losing plan and values that are not the plan's")
    func makeRefuses() throws {
        let w: AcousticConstellatorWitness = try #require(multi)
        var found: AcousticConstellatorGenerated?
        for (generated, witness) in fixtures.cases where witness == w { found = generated }
        let g: AcousticConstellatorGenerated = try #require(found)
        let p: AcousticConstellatorPlan = g.plan
        let shortLinks: [AcousticConstellatorLink] = p.nudges.isEmpty ? Array(p.links.dropLast()) : p.links
        let shortNudges: [AcousticConstellatorNudge] = p.nudges.isEmpty ? p.nudges : Array(p.nudges.dropLast())
        let short = AcousticConstellatorPlan(links: shortLinks, nudges: shortNudges, smallerSets: p.smallerSets,
                                             work: p.work)
        let losing = AcousticConstellatorGenerated(entry: g.entry, level: g.level, plan: short,
                                                   difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: AcousticConstellatorError.witness("replay")) { try AcousticConstellatorWitness.make(losing) }
        let miscounted = AcousticConstellatorPlan(links: p.links, nudges: p.nudges, smallerSets: p.smallerSets + 1,
                                                  work: p.work)
        let wrongCount = AcousticConstellatorGenerated(entry: g.entry, level: g.level, plan: miscounted,
                                                       difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: AcousticConstellatorError.witness("counterexample")) {
            try AcousticConstellatorWitness.make(wrongCount)
        }
        let wrongDifficulty = AcousticConstellatorGenerated(
            entry: g.entry, level: g.level, plan: p,
            difficulty: acousticConstellatorDifficulty(g.difficulty, starsBy: 1), skipped: g.skipped)
        #expect(throws: AcousticConstellatorError.witness("difficulty")) {
            try AcousticConstellatorWitness.make(wrongDifficulty)
        }
        let otherEntry = AcousticConstellatorGenerated(entry: AcousticConstellatorManifest.entries[g.entry.number],
                                                       level: g.level, plan: p, difficulty: g.difficulty,
                                                       skipped: g.skipped)
        #expect(throws: AcousticConstellatorError.witness("number")) {
            try AcousticConstellatorWitness.make(otherEntry)
        }
    }
}
