// CelestialEclipseLabWitnessTests — feature 462 (R02-G17-02) T-R02G1702-005 (FR-R02G1702-004; SC-R02G1702-003, 005;
// clarification Q4), modelled on StarlitCartoucheWitnessTests (feature 452). Witnesses of generated levels 1 (band 1,
// tutorial), 4 (band 1), 21 and 22 (band 2), each generated with no previous level and built once per process. The
// stored form round-trips byte for byte with sorted keys and one trailing newline; equal makes give equal bytes; the
// state digest is the first 16 hex characters of SHA-256 over the canonical phases and actions-spent text (checked
// against known values); digests, fingerprints and the terminal timeline agree with an independent replay; the
// counterexample is the solver's settings at the depth one below the plan; edited actions, digests, fingerprints,
// timeline, counterexample, difficulty, level (bytes and values), number, skipped and schema are refused naming the
// part; newer and truncated stored forms are refused; `make` refuses values that are not the plan's. Explicit types,
// plain loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import CelestialEclipseLabCore

/// The generated levels and witnesses the tests share, built once.
struct CelestialEclipseLabWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: CelestialEclipseLabGenerated, witness: CelestialEclipseLabWitness)]

    static let shared: CelestialEclipseLabWitnessFixtures = make()

    /// The generated level (no previous level) and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: CelestialEclipseLabGenerated, witness: CelestialEclipseLabWitness) {
        let entry: CelestialEclipseLabManifestEntry = CelestialEclipseLabManifest.entries[index]
        let generated: CelestialEclipseLabGenerated
        do { generated = try CelestialEclipseLabGenerator.generate(entry, previous: nil) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try CelestialEclipseLabWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> CelestialEclipseLabWitnessFixtures {
        var cases: [(generated: CelestialEclipseLabGenerated, witness: CelestialEclipseLabWitness)] = []
        for index in [0, 3, 20, 21] { cases.append(pair(index)) }
        return CelestialEclipseLabWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct CelestialEclipseLabWitnessParts {
    var number: Int
    var level: CelestialEclipseLabLevel
    var actions: [CelestialEclipseLabAction]
    var digests: [String]
    var fingerprints: [String]
    var timeline: CelestialEclipseLabWitnessTimeline
    var counterexample: CelestialEclipseLabCounterexample
    var difficulty: CelestialEclipseLabDifficulty
    var skipped: Int

    init(_ w: CelestialEclipseLabWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        timeline = w.timeline
        counterexample = w.counterexample
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: CelestialEclipseLabWitness {
        CelestialEclipseLabWitness(number: number, level: level, actions: actions, digests: digests,
                                   fingerprints: fingerprints, timeline: timeline, counterexample: counterexample,
                                   difficulty: difficulty, skipped: skipped)
    }
}

/// `d` with its bodies, settings searched and work changed by the given amounts.
func celestialEclipseLabDifficulty(_ d: CelestialEclipseLabDifficulty, bodiesBy bodies: Int = 0,
                                   settingsBy settings: Int = 0,
                                   workBy work: Int = 0) -> CelestialEclipseLabDifficulty {
    CelestialEclipseLabDifficulty(changes: d.changes, bodies: d.bodies + bodies, movable: d.movable,
                                  targets: d.targets, events: d.events, settingsSearched: d.settingsSearched + settings,
                                  work: d.work + work)
}

@Suite struct CelestialEclipseLabWitnessTests {
    let fixtures: CelestialEclipseLabWitnessFixtures = .shared

    /// The refusal `decode` raises for the stored form of `witness`, or nil when it decodes.
    func refusal(_ witness: CelestialEclipseLabWitness) -> CelestialEclipseLabError? {
        refusal(witness.encoded())
    }

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> CelestialEclipseLabError? {
        do {
            _ = try CelestialEclipseLabWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: CelestialEclipseLabWitness,
                _ change: (inout CelestialEclipseLabWitnessParts) -> Void) -> CelestialEclipseLabWitness {
        var parts = CelestialEclipseLabWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: CelestialEclipseLabWitness, key: String, line: String?) -> Data {
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

    /// A witness of `fixtures` with at least two phase changes.
    var multi: CelestialEclipseLabWitness? {
        for (_, witness) in fixtures.cases where witness.actions.count >= 3 { return witness }
        return nil
    }

    /// The phase changes of `witness` (its actions without the final run).
    func changes(_ witness: CelestialEclipseLabWitness) -> [CelestialEclipseLabAction] {
        Array(witness.actions.dropLast())
    }

    @Test("the fixtures cover bands 1 and 2, a tutorial and a multi-change plan")
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
                              "schema", "skipped", "timeline"]
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data == witness.encoded())
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: CelestialEclipseLabWitness = try CelestialEclipseLabWitness.decode(data)
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
            // The run is the last action; visibility classes are stored as their raw values.
            #expect(text.contains("\"run\" : {"))
            for interval in witness.timeline.intervals {
                #expect(text.contains("\"visibility\" : \"\(interval.visibility.rawValue)\""))
            }
        }
    }

    @Test("equal makes give equal bytes")
    func equalMakesEqualBytes() throws {
        for (generated, witness) in fixtures.cases {
            let again: CelestialEclipseLabWitness = try CelestialEclipseLabWitness.make(generated)
            #expect(again == witness)
            #expect(again.encoded() == witness.encoded())
        }
        let entry: CelestialEclipseLabManifestEntry = CelestialEclipseLabManifest.entries[0]
        let regenerated: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(entry, previous: nil)
        let fresh: CelestialEclipseLabWitness = try CelestialEclipseLabWitness.make(regenerated)
        #expect(fresh.encoded() == fixtures.cases[0].witness.encoded())
    }

    @Test("the witness carries the plan's changes and run, counterexample, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == CelestialEclipseLabGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.plan.actions + [.run])
            #expect(witness.actions.last == .run)
            #expect(witness.actions.count - 1 <= witness.level.budget)
            #expect(witness.counterexample.depth == generated.plan.size - 1)
            #expect(witness.counterexample.settings == generated.plan.settingsByDepth[generated.plan.size - 1])
            #expect(witness.counterexample.settings >= 1)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.settingsSearched == generated.plan.settingsSearched)
            #expect(witness.difficulty.work == generated.plan.work)
            #expect(witness.timeline.matched == witness.level.target.count)
            #expect(witness.timeline.intervals.count == witness.difficulty.events)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("the counterexample of the first level of each band has the solver's values")
    func counterexampleValues() {
        let first: CelestialEclipseLabWitness = fixtures.cases[0].witness
        let plan: CelestialEclipseLabPlan = fixtures.cases[0].generated.plan
        #expect(first.counterexample == CelestialEclipseLabCounterexample(depth: plan.size - 1,
                                                                          settings: plan.settingsByDepth.last ?? -1))
        // Depth 0 is the start alone: one setting judged.
        if plan.size == 1 { #expect(first.counterexample == CelestialEclipseLabCounterexample(depth: 0, settings: 1)) }
        let band2: CelestialEclipseLabWitness = fixtures.cases[2].witness
        #expect(band2.counterexample.depth >= 1)
        #expect(band2.counterexample.depth == band2.actions.count - 2)
    }

    @Test("state digests, fingerprints and the terminal timeline agree with an independent replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: CelestialEclipseLabLevel = witness.level
            #expect(witness.digests.count == witness.actions.count)
            let starts: Int = level.tutorial ? 2 : 1
            #expect(witness.fingerprints.count == starts + witness.actions.count)
            var play = CelestialEclipseLabPlay(level: level)
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
                var text: String = "phases="
                for (position, phase) in play.phases.enumerated() {
                    if position > 0 { text += "," }
                    text += String(phase)
                }
                text += ";spent=" + String(play.actionsSpent)
                digests.append(String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
            }
            #expect(play.stage == .won)
            #expect(play.actionsSpent <= level.budget)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            // The run spends nothing: the last two digests are equal.
            #expect(witness.digests[witness.digests.count - 1] == witness.digests[witness.digests.count - 2])
            #expect(witness.timeline == CelestialEclipseLabWitnessTimeline(play.timeline))
            let expected: [CelestialEclipseLabInterval] = CelestialEclipseLabSky.intervals(level, phases: play.phases)
            #expect(witness.timeline.intervals.count == expected.count)
            #expect(CelestialEclipseLabSolver.wins(level, actions: changes(witness)))
        }
    }

    @Test("a tutorial level records the fingerprint after dismissTutorial")
    func tutorialFingerprint() throws {
        let w: CelestialEclipseLabWitness = fixtures.cases[0].witness
        #expect(w.level.tutorial)
        #expect(w.fingerprints.count == w.actions.count + 2)
        var play = CelestialEclipseLabPlay(level: w.level)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        #expect(w.fingerprints[0] == play.fingerprint)
        try play.handle(.dismissTutorial)
        #expect(w.fingerprints[1] == play.fingerprint)
        #expect(w.fingerprints[0] != w.fingerprints[1])
        let plain: CelestialEclipseLabWitness = fixtures.cases[1].witness
        #expect(plain.fingerprints.count == plain.actions.count + 1)
        // Dropping the tutorial fingerprint is refused.
        #expect(refusal(edited(w) { _ = $0.fingerprints.remove(at: 1) }) == .witness("fingerprints"))
    }

    @Test("the canonical text keeps body order and the digest has known values")
    func digestDefinition() {
        #expect(CelestialEclipseLabWitness.canonicalText(phases: [0, 3, 5], spent: 2) == "phases=0,3,5;spent=2")
        #expect(CelestialEclipseLabWitness.canonicalText(phases: [0, 0, 0], spent: 0) == "phases=0,0,0;spent=0")
        #expect(CelestialEclipseLabWitness.canonicalText(phases: [4], spent: 1) == "phases=4;spent=1")
        // Known values: `printf '<text>' | shasum -a 256`, first 16 characters.
        #expect(CelestialEclipseLabWitness.digest(phases: [0, 3, 5], spent: 2) == "6c6e622daf393f01")
        #expect(CelestialEclipseLabWitness.digest(phases: [0, 0, 0], spent: 0) == "bf88f24a96a57fe9")
        #expect(CelestialEclipseLabWitness.digest(phases: [4], spent: 1) == "73a09ce467df4b41")
        let full: String = StableHash.sha256Hex(Array("phases=0,3,5;spent=2".utf8))
        #expect(CelestialEclipseLabWitness.digest(phases: [0, 3, 5], spent: 2) == String(full.prefix(16)))
        var seen: Set<String> = []
        seen.insert(CelestialEclipseLabWitness.digest(phases: [0, 3, 5], spent: 2))
        seen.insert(CelestialEclipseLabWitness.digest(phases: [5, 3, 0], spent: 2))
        seen.insert(CelestialEclipseLabWitness.digest(phases: [0, 3, 5], spent: 3))
        seen.insert(CelestialEclipseLabWitness.digest(phases: [0, 3], spent: 2))
        seen.insert(CelestialEclipseLabWitness.digest(phases: [0, 3, 5, 0], spent: 2))
        #expect(seen.count == 5)
    }

    @Test("no plan of one change fewer wins: dropping any one change does not win")
    func droppingAChangeLoses() throws {
        let w: CelestialEclipseLabWitness = try #require(multi)
        let plan: [CelestialEclipseLabAction] = changes(w)
        for index in 0..<plan.count {
            var shorter: [CelestialEclipseLabAction] = plan
            shorter.remove(at: index)
            #expect(!CelestialEclipseLabSolver.wins(w.level, actions: shorter))
        }
    }

    @Test("an edited action is refused")
    func editedActionRefused() throws {
        let w: CelestialEclipseLabWitness = try #require(multi)
        let plan: [CelestialEclipseLabAction] = changes(w)
        let count: Int = w.level.bodies.count
        guard case .phase(let firstBody, let firstOffset) = plan[0] else { return }
        let period: Int = w.level.bodies[firstBody].period
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.run] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = plan }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.run] + w.actions }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.phase(count, 0)] + w.actions }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.phase(-1, 0)] + w.actions }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.phase(0, 1)] + w.actions }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.phase(firstBody, period)] + w.actions }) == .witness("actions"))
        var long: [CelestialEclipseLabAction] = []
        for _ in 0...w.level.budget { long.append(plan[0]) }
        #expect(refusal(edited(w) { $0.actions = long + [.run] }) == .witness("actions"))
        // A shorter plan runs without winning.
        #expect(refusal(edited(w) { $0.actions = Array(plan.dropLast()) + [.run] }) == .witness("replay"))
        // Another offset on the first change: refused as a non-replay, or as not the solver's plan when it still wins.
        var checked: Int = 0
        for offset in 0..<period where offset != firstOffset {
            var actions: [CelestialEclipseLabAction] = plan
            actions[0] = .phase(firstBody, offset)
            let expected: CelestialEclipseLabError = CelestialEclipseLabSolver.wins(w.level, actions: actions)
                ? .witness("solution") : .witness("replay")
            #expect(refusal(edited(w) { $0.actions = actions + [.run] }) == expected)
            checked += 1
        }
        #expect(checked == period - 1)
    }

    @Test("an edited digest, fingerprint or timeline is refused")
    func editedDigestFingerprintAndTimelineRefused() {
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
            let t: CelestialEclipseLabWitnessTimeline = w.timeline
            let more = CelestialEclipseLabWitnessTimeline(intervals: t.intervals, matched: t.matched + 1)
            #expect(refusal(edited(w) { $0.timeline = more }) == .witness("timeline"))
            let fewer = CelestialEclipseLabWitnessTimeline(intervals: Array(t.intervals.dropLast()), matched: t.matched)
            #expect(refusal(edited(w) { $0.timeline = fewer }) == .witness("timeline"))
        }
    }

    @Test("an edited interval visibility is refused")
    func editedVisibilityRefused() throws {
        let w: CelestialEclipseLabWitness = fixtures.cases[0].witness
        let t: CelestialEclipseLabWitnessTimeline = w.timeline
        let i: CelestialEclipseLabWitnessInterval = try #require(t.intervals.first)
        let other: CelestialEclipseLabVisibility = i.visibility == .partial ? .total : .partial
        var intervals: [CelestialEclipseLabWitnessInterval] = t.intervals
        intervals[0] = CelestialEclipseLabWitnessInterval(front: i.front, back: i.back, first: i.first, last: i.last,
                                                          visibility: other)
        let changed = CelestialEclipseLabWitnessTimeline(intervals: intervals, matched: t.matched)
        #expect(refusal(edited(w) { $0.timeline = changed }) == .witness("timeline"))
        // An unknown class in the stored bytes is unreadable.
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let stored: String = "\"visibility\" : \"\(i.visibility.rawValue)\""
        let damaged: String = text.replacingOccurrences(of: stored, with: "\"visibility\" : \"eclipsed\"")
        #expect(refusal(Data(damaged.utf8)) == .witness("unreadable"))
    }

    @Test("an edited counterexample or difficulty is refused")
    func editedCounterexampleAndDifficultyRefused() {
        let w: CelestialEclipseLabWitness = fixtures.cases[2].witness
        let c: CelestialEclipseLabCounterexample = w.counterexample
        let more = CelestialEclipseLabCounterexample(depth: c.depth, settings: c.settings + 1)
        #expect(refusal(edited(w) { $0.counterexample = more }) == .witness("counterexample"))
        let lower = CelestialEclipseLabCounterexample(depth: c.depth - 1, settings: c.settings)
        #expect(refusal(edited(w) { $0.counterexample = lower }) == .witness("counterexample"))
        let bodies: CelestialEclipseLabDifficulty = celestialEclipseLabDifficulty(w.difficulty, bodiesBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = bodies }) == .witness("difficulty"))
        let settings: CelestialEclipseLabDifficulty = celestialEclipseLabDifficulty(w.difficulty, settingsBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = settings }) == .witness("difficulty"))
        let work: CelestialEclipseLabDifficulty = celestialEclipseLabDifficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = work }) == .witness("difficulty"))
    }

    @Test("an edited level, number or skipped count is refused")
    func editedLevelRefused() throws {
        let w: CelestialEclipseLabWitness = fixtures.cases[0].witness
        let l: CelestialEclipseLabLevel = w.level
        // A level that still replays but is not the generator's candidate.
        let reseeded = try CelestialEclipseLabLevel(id: l.id, seed: l.seed &+ 1, difficulty: l.difficulty,
                                                    bodies: l.bodies, horizon: l.horizon, target: l.target,
                                                    phases: l.phases, budget: l.budget, tutorial: l.tutorial)
        #expect(CelestialEclipseLabSolver.wins(reseeded, actions: changes(w)))
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
        let maxCandidates: Int = CelestialEclipseLabGenerator.maxCandidates
        #expect(refusal(edited(w) { $0.skipped = maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = -1 }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    @Test("newer, older, truncated and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: CelestialEclipseLabWitness = fixtures.cases[0].witness
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
        #expect(CelestialEclipseLabError.witness("digests").reasonCode == "r02-g17.witness")
    }

    @Test("make refuses values that are not the solver's plan")
    func makeRefuses() throws {
        let w: CelestialEclipseLabWitness = try #require(multi)
        var found: CelestialEclipseLabGenerated?
        for (generated, witness) in fixtures.cases where witness == w { found = generated }
        let g: CelestialEclipseLabGenerated = try #require(found)
        let p: CelestialEclipseLabPlan = g.plan
        let short = CelestialEclipseLabPlan(actions: Array(p.actions.dropLast()), settingsByDepth: p.settingsByDepth,
                                            work: p.work)
        let losing = CelestialEclipseLabGenerated(entry: g.entry, level: g.level, plan: short,
                                                  difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: CelestialEclipseLabError.witness("replay")) { try CelestialEclipseLabWitness.make(losing) }
        var settings: [Int] = p.settingsByDepth
        settings[settings.count - 1] += 1
        let miscounted = CelestialEclipseLabPlan(actions: p.actions, settingsByDepth: settings, work: p.work)
        let wrongCount = CelestialEclipseLabGenerated(entry: g.entry, level: g.level, plan: miscounted,
                                                      difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: CelestialEclipseLabError.witness("counterexample")) {
            try CelestialEclipseLabWitness.make(wrongCount)
        }
        let harder: CelestialEclipseLabDifficulty = celestialEclipseLabDifficulty(g.difficulty, bodiesBy: 1)
        let wrongDifficulty = CelestialEclipseLabGenerated(entry: g.entry, level: g.level, plan: p, difficulty: harder,
                                                           skipped: g.skipped)
        #expect(throws: CelestialEclipseLabError.witness("difficulty")) {
            try CelestialEclipseLabWitness.make(wrongDifficulty)
        }
        let moreWork = CelestialEclipseLabPlan(actions: p.actions, settingsByDepth: p.settingsByDepth, work: p.work + 1)
        let wrongWork = CelestialEclipseLabGenerated(entry: g.entry, level: g.level, plan: moreWork,
                                                     difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: CelestialEclipseLabError.witness("difficulty")) {
            try CelestialEclipseLabWitness.make(wrongWork)
        }
        let otherEntry = CelestialEclipseLabGenerated(entry: CelestialEclipseLabManifest.entries[g.entry.number],
                                                      level: g.level, plan: p, difficulty: g.difficulty,
                                                      skipped: g.skipped)
        #expect(throws: CelestialEclipseLabError.witness("number")) { try CelestialEclipseLabWitness.make(otherEntry) }
        let empty = CelestialEclipseLabPlan(actions: [], settingsByDepth: [], work: p.work)
        let none = CelestialEclipseLabGenerated(entry: g.entry, level: g.level, plan: empty, difficulty: g.difficulty,
                                                skipped: g.skipped)
        #expect(throws: CelestialEclipseLabError.witness("actions")) { try CelestialEclipseLabWitness.make(none) }
    }
}
