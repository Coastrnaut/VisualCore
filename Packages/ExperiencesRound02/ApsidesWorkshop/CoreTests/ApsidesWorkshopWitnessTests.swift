// ApsidesWorkshopWitnessTests — feature 472 (R02-G18-02) T-R02G1802-005 (FR-R02G1802-004; SC-R02G1802-003, 005;
// clarification Q4), on the rule kernel of feature 471 (R02-G18-01), modelled on CelestialEclipseLabWitnessTests
// (feature 462). Witnesses of generated levels 1 (band 1, tutorial), 4 (band 1), 41 (band 3) and 61 (band 4, two
// tunings), each generated with no previous level and built once per process, and of level 2 generated after level 1.
// The stored form round-trips byte for byte with sorted keys and one trailing newline; equal makes give equal bytes;
// the state digest is the first 16 hex characters of SHA-256 over the canonical orbit and actions-spent text (checked
// against known values); digests, fingerprints and the terminal report agree with an independent replay; the
// counterexample is the solver's orbits at the depth one below the plan; edited actions, digests, fingerprints, report,
// counterexample, difficulty, level (bytes and values), number, skipped and schema are refused naming the part; one
// changed character in an action, a digest or a share is refused with `r02-g18.witness`; newer and truncated stored
// forms are refused; `make` refuses values that are not the plan's. Explicit types, plain loops (CI type-check rule),
// short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import ApsidesWorkshopCore

/// The generated levels and witnesses the tests share, built once.
struct ApsidesWorkshopWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: ApsidesWorkshopGenerated, witness: ApsidesWorkshopWitness)]

    static let shared: ApsidesWorkshopWitnessFixtures = make()

    /// The generated level (after `previous`, nil by default) and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int, previous: ApsidesWorkshopLevel? = nil)
        -> (generated: ApsidesWorkshopGenerated, witness: ApsidesWorkshopWitness) {
        let entry: ApsidesWorkshopManifestEntry = ApsidesWorkshopManifest.entries[index]
        let generated: ApsidesWorkshopGenerated
        do { generated = try ApsidesWorkshopGenerator.generate(entry, previous: previous) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try ApsidesWorkshopWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> ApsidesWorkshopWitnessFixtures {
        var cases: [(generated: ApsidesWorkshopGenerated, witness: ApsidesWorkshopWitness)] = []
        for index in [0, 3, 40, 60] { cases.append(pair(index)) }
        return ApsidesWorkshopWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct ApsidesWorkshopWitnessParts {
    var number: Int
    var level: ApsidesWorkshopLevel
    var actions: [ApsidesWorkshopAction]
    var digests: [String]
    var fingerprints: [String]
    var report: ApsidesWorkshopWitnessReport
    var counterexample: ApsidesWorkshopCounterexample
    var difficulty: ApsidesWorkshopDifficulty
    var skipped: Int

    init(_ w: ApsidesWorkshopWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        report = w.report
        counterexample = w.counterexample
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: ApsidesWorkshopWitness {
        ApsidesWorkshopWitness(number: number, level: level, actions: actions, digests: digests,
                               fingerprints: fingerprints, report: report, counterexample: counterexample,
                               difficulty: difficulty, skipped: skipped)
    }

    /// `d` with its planets, orbits searched and work changed by the given amounts.
    static func difficulty(_ d: ApsidesWorkshopDifficulty, planetsBy planets: Int = 0, orbitsBy orbits: Int = 0,
                           workBy work: Int = 0) -> ApsidesWorkshopDifficulty {
        ApsidesWorkshopDifficulty(tunings: d.tunings, targets: d.targets, apsisTargets: d.apsisTargets,
                                  planets: d.planets + planets, narrowestShareBand: d.narrowestShareBand,
                                  narrowestDistanceRange: d.narrowestDistanceRange,
                                  orbitsSearched: d.orbitsSearched + orbits, work: d.work + work)
    }

    /// `r` with the given changes.
    static func report(_ r: ApsidesWorkshopWitnessReport, shares: [Int]? = nil, periapsisDistance: Int = 0,
                       apoapsisSector: Int = 0, residual: Int64 = 0, deviations: [Int]? = nil,
                       met: Int = 0) -> ApsidesWorkshopWitnessReport {
        ApsidesWorkshopWitnessReport(shares: shares ?? r.shares, periapsisSector: r.periapsisSector,
                                     periapsisDistance: r.periapsisDistance + periapsisDistance,
                                     apoapsisSector: (r.apoapsisSector + apoapsisSector) % 8,
                                     apoapsisDistance: r.apoapsisDistance,
                                     largestResidual: r.largestResidual + residual,
                                     deviations: deviations ?? r.deviations, met: r.met + met)
    }
}

@Suite struct ApsidesWorkshopWitnessTests {
    let fixtures: ApsidesWorkshopWitnessFixtures = .shared

    /// The refusal `decode` raises for the stored form of `witness`, or nil when it decodes.
    func refusal(_ witness: ApsidesWorkshopWitness) -> ApsidesWorkshopError? {
        refusal(witness.encoded())
    }

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> ApsidesWorkshopError? {
        do {
            _ = try ApsidesWorkshopWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: ApsidesWorkshopWitness,
                _ change: (inout ApsidesWorkshopWitnessParts) -> Void) -> ApsidesWorkshopWitness {
        var parts = ApsidesWorkshopWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: ApsidesWorkshopWitness, key: String, line: String?) -> Data {
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

    /// The stored form of `witness` with one character changed: the first decimal digit after `marker` becomes the
    /// next digit mod 10; when `value`, the last digit of the first number that follows a space (a JSON value, not a
    /// key such as `_0`) changes instead.
    func oneDigitChanged(_ witness: ApsidesWorkshopWitness, after marker: String, value: Bool) -> Data? {
        var bytes: [UInt8] = Array(witness.encoded())
        let needle: [UInt8] = Array(marker.utf8)
        var start: Int?
        var i: Int = 0
        while start == nil && i + needle.count <= bytes.count {
            if Array(bytes[i..<(i + needle.count)]) == needle { start = i + needle.count }
            i += 1
        }
        guard var j = start else { return nil }
        while j < bytes.count {
            let byte: UInt8 = bytes[j]
            if byte >= 0x30, byte <= 0x39, !value || bytes[j - 1] == 0x20 {
                // In a value, the last digit of the number changes, so no leading zero appears.
                while value && j + 1 < bytes.count && bytes[j + 1] >= 0x30 && bytes[j + 1] <= 0x39 { j += 1 }
                bytes[j] = 0x30 + (bytes[j] - 0x30 + 1) % 10
                return Data(bytes)
            }
            j += 1
        }
        return nil
    }

    /// A witness of `fixtures` with two tunings.
    var multi: ApsidesWorkshopWitness? {
        for (_, witness) in fixtures.cases where witness.actions.count >= 3 { return witness }
        return nil
    }

    /// The tunings of `witness` (its actions without the final play).
    func tunings(_ witness: ApsidesWorkshopWitness) -> [ApsidesWorkshopAction] {
        Array(witness.actions.dropLast())
    }

    @Test("the fixtures cover bands 1, 3 and 4, a tutorial and a two-tuning plan")
    func fixturesCover() {
        #expect(fixtures.cases.count == 4)
        #expect(fixtures.cases[0].generated.level.tutorial)
        #expect(!fixtures.cases[1].generated.level.tutorial)
        var bands: [Int] = []
        for (generated, _) in fixtures.cases { bands.append(generated.entry.band) }
        #expect(bands == [1, 1, 3, 4])
        #expect(multi != nil)
        #expect(fixtures.cases[3].witness.actions.count == 3)
    }

    @Test("the stored form round-trips byte for byte with sorted keys and one trailing newline")
    func roundTripByteForByte() throws {
        let keys: [String] = ["actions", "counterexample", "difficulty", "digests", "fingerprints", "level", "number",
                              "report", "schema", "skipped"]
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data == witness.encoded())
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: ApsidesWorkshopWitness = try ApsidesWorkshopWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            #expect(try JSONDecoder().decode(ApsidesWorkshopWitness.self, from: data) == witness)
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
            // The play is the last action; the report keys are sorted too.
            #expect(text.contains("\"play\" : {"))
            #expect(text.contains("\"largestResidual\" : \(witness.report.largestResidual)"))
        }
    }

    @Test("equal makes give equal bytes, also for a level generated after its neighbour")
    func equalMakesEqualBytes() throws {
        for (generated, witness) in fixtures.cases {
            let again: ApsidesWorkshopWitness = try ApsidesWorkshopWitness.make(generated)
            #expect(again == witness)
            #expect(again.encoded() == witness.encoded())
        }
        let entry: ApsidesWorkshopManifestEntry = ApsidesWorkshopManifest.entries[0]
        let regenerated: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(entry, previous: nil)
        let fresh: ApsidesWorkshopWitness = try ApsidesWorkshopWitness.make(regenerated)
        #expect(fresh.encoded() == fixtures.cases[0].witness.encoded())
        let second = ApsidesWorkshopWitnessFixtures.pair(1, previous: regenerated.level)
        #expect(second.witness.level.targets != regenerated.level.targets)
        #expect(second.witness.skipped == second.generated.skipped)
        let decoded: ApsidesWorkshopWitness = try ApsidesWorkshopWitness.decode(second.witness.encoded())
        #expect(decoded.encoded() == second.witness.encoded())
    }

    @Test("the witness carries the plan's tunings and play, counterexample, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == ApsidesWorkshopGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.plan.actions + [.play])
            #expect(witness.actions.last == .play)
            #expect(witness.actions.count - 1 <= witness.level.budget)
            #expect(witness.counterexample.depth == generated.plan.size - 1)
            #expect(witness.counterexample.orbits == generated.plan.orbitsByDepth[generated.plan.size - 1])
            #expect(witness.counterexample.orbits >= 1)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.orbitsSearched == generated.plan.orbitsSearched)
            #expect(witness.difficulty.work == generated.plan.work)
            #expect(witness.report.met == witness.level.targets.count)
            #expect(witness.report.deviations.count == witness.level.targets.count)
            for deviation in witness.report.deviations { #expect(deviation == 0) }
            #expect(witness.report.shares.count == ApsidesWorkshopSky.sectorCount)
            #expect(witness.report.periapsisSector == generated.plan.orbit.periapsisSector)
            #expect(witness.report.apoapsisDistance == generated.plan.orbit.apoapsisDistance)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("the counterexample has the solver's values")
    func counterexampleValues() {
        let first: ApsidesWorkshopWitness = fixtures.cases[0].witness
        let plan: ApsidesWorkshopPlan = fixtures.cases[0].generated.plan
        #expect(first.counterexample == ApsidesWorkshopCounterexample(depth: plan.size - 1,
                                                                      orbits: plan.orbitsByDepth.last ?? -1))
        // Band 1 plans have one tuning: depth 0 is the start alone, one orbit judged.
        #expect(first.counterexample == ApsidesWorkshopCounterexample(depth: 0, orbits: 1))
        let band4: ApsidesWorkshopWitness = fixtures.cases[3].witness
        let start: ApsidesWorkshopOrbit = band4.level.orbit
        let depthOne: Int = ApsidesWorkshopSolver.orbits(from: start, depth: 1).count
        #expect(band4.counterexample == ApsidesWorkshopCounterexample(depth: 1, orbits: depthOne))
        #expect(band4.counterexample.depth == band4.actions.count - 2)
    }

    @Test("state digests, fingerprints and the terminal report agree with an independent replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: ApsidesWorkshopLevel = witness.level
            #expect(witness.digests.count == witness.actions.count)
            let starts: Int = level.tutorial ? 2 : 1
            #expect(witness.fingerprints.count == starts + witness.actions.count)
            var play = ApsidesWorkshopPlay(level: level)
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
                let o: ApsidesWorkshopOrbit = play.orbit
                let text: String = "orbit=\(o.size),\(o.eccentricity),\(o.direction);spent=\(play.actionsSpent)"
                digests.append(String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
            }
            #expect(play.stage == .won)
            #expect(play.actionsSpent <= level.budget)
            #expect(play.actionsSpent == witness.actions.count - 1)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            // The play spends nothing: the last two digests are equal.
            #expect(witness.digests[witness.digests.count - 1] == witness.digests[witness.digests.count - 2])
            let r: ApsidesWorkshopReport = ApsidesWorkshopSky.report(level, orbit: play.orbit)
            #expect(witness.report.shares == r.shares)
            #expect(witness.report.largestResidual == r.largestResidual)
            #expect(witness.report.deviations == r.deviations)
            #expect(witness.report.met == r.met)
            #expect(witness.report.periapsisSector == play.orbit.periapsisSector)
            #expect(witness.report.periapsisDistance == play.orbit.periapsisDistance)
            #expect(witness.report.apoapsisSector == play.orbit.apoapsisSector)
            #expect(witness.report.apoapsisDistance == play.orbit.apoapsisDistance)
            #expect(ApsidesWorkshopSolver.replayWins(level, actions: tunings(witness)))
        }
    }

    @Test("a tutorial level records the fingerprint after dismissTutorial")
    func tutorialFingerprint() throws {
        let w: ApsidesWorkshopWitness = fixtures.cases[0].witness
        #expect(w.level.tutorial)
        #expect(w.fingerprints.count == w.actions.count + 2)
        var play = ApsidesWorkshopPlay(level: w.level)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        #expect(w.fingerprints[0] == play.fingerprint)
        try play.handle(.dismissTutorial)
        #expect(w.fingerprints[1] == play.fingerprint)
        #expect(w.fingerprints[0] != w.fingerprints[1])
        let plain: ApsidesWorkshopWitness = fixtures.cases[1].witness
        #expect(plain.fingerprints.count == plain.actions.count + 1)
        // Dropping the tutorial fingerprint is refused.
        #expect(refusal(edited(w) { _ = $0.fingerprints.remove(at: 1) }) == .witness("fingerprints"))
    }

    @Test("the canonical text keeps the lever order and the digest has known values")
    func digestDefinition() {
        let a = ApsidesWorkshopOrbit(size: 24, eccentricity: 5, direction: 6)
        let b = ApsidesWorkshopOrbit(size: 8, eccentricity: 0, direction: 0)
        let c = ApsidesWorkshopOrbit(size: 48, eccentricity: 15, direction: 23)
        #expect(ApsidesWorkshopWitness.canonicalText(orbit: a, spent: 2) == "orbit=24,5,6;spent=2")
        #expect(ApsidesWorkshopWitness.canonicalText(orbit: b, spent: 0) == "orbit=8,0,0;spent=0")
        #expect(ApsidesWorkshopWitness.canonicalText(orbit: c, spent: 1) == "orbit=48,15,23;spent=1")
        // Known values: `printf '<text>' | shasum -a 256`, first 16 characters.
        #expect(ApsidesWorkshopWitness.digest(orbit: a, spent: 2) == "808820af21a1f62b")
        #expect(ApsidesWorkshopWitness.digest(orbit: b, spent: 0) == "f7ad9e04f1f31ebd")
        #expect(ApsidesWorkshopWitness.digest(orbit: c, spent: 1) == "ab0d26aa6cc1689c")
        let full: String = StableHash.sha256Hex(Array("orbit=24,5,6;spent=2".utf8))
        #expect(ApsidesWorkshopWitness.digest(orbit: a, spent: 2) == String(full.prefix(16)))
        var seen: Set<String> = []
        seen.insert(ApsidesWorkshopWitness.digest(orbit: a, spent: 2))
        seen.insert(ApsidesWorkshopWitness.digest(orbit: a, spent: 3))
        seen.insert(ApsidesWorkshopWitness.digest(orbit: ApsidesWorkshopOrbit(size: 6, eccentricity: 5,
                                                                               direction: 24), spent: 2))
        seen.insert(ApsidesWorkshopWitness.digest(orbit: ApsidesWorkshopOrbit(size: 24, eccentricity: 6,
                                                                               direction: 5), spent: 2))
        seen.insert(ApsidesWorkshopWitness.digest(orbit: b, spent: 2))
        #expect(seen.count == 5)
    }

    @Test("no plan of one tuning fewer wins: dropping either tuning does not win")
    func droppingATuningLoses() throws {
        let w: ApsidesWorkshopWitness = try #require(multi)
        let plan: [ApsidesWorkshopAction] = tunings(w)
        for index in 0..<plan.count {
            var shorter: [ApsidesWorkshopAction] = plan
            shorter.remove(at: index)
            #expect(!ApsidesWorkshopSolver.replayWins(w.level, actions: shorter))
        }
    }

    @Test("an edited action is refused")
    func editedActionRefused() throws {
        let w: ApsidesWorkshopWitness = try #require(multi)
        let plan: [ApsidesWorkshopAction] = tunings(w)
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.play] }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = plan }) == .witness("actions"))
        #expect(refusal(edited(w) { $0.actions = [.play] + w.actions }) == .witness("actions"))
        let outOfRange: [ApsidesWorkshopAction] = [.size(7), .size(49), .periapsis(16, 0), .periapsis(-1, 0),
                                                   .periapsis(0, 24), .periapsis(0, -1)]
        for action in outOfRange {
            #expect(refusal(edited(w) { $0.actions = [action] + w.actions }) == .witness("actions"))
        }
        var long: [ApsidesWorkshopAction] = []
        for _ in 0...w.level.budget { long.append(plan[0]) }
        #expect(refusal(edited(w) { $0.actions = long + [.play] }) == .witness("actions"))
        // A shorter plan plays without winning.
        #expect(refusal(edited(w) { $0.actions = Array(plan.dropLast()) + [.play] }) == .witness("replay"))
        // Another size on the size tuning: refused as a non-replay, or as not the solver's plan when it still wins.
        var position: Int?
        var target: Int = 0
        for (index, action) in plan.enumerated() {
            if case .size(let size) = action {
                position = index
                target = size
            }
        }
        let at: Int = try #require(position)
        var checked: Int = 0
        for size in ApsidesWorkshopOrbit.sizes where size != target {
            var actions: [ApsidesWorkshopAction] = plan
            actions[at] = .size(size)
            let expected: ApsidesWorkshopError = ApsidesWorkshopSolver.replayWins(w.level, actions: actions)
                ? .witness("solution") : .witness("replay")
            #expect(refusal(edited(w) { $0.actions = actions + [.play] }) == expected)
            checked += 1
        }
        #expect(checked == ApsidesWorkshopOrbit.sizes.count - 1)
    }

    @Test("one changed character in an action, a digest or a share is refused")
    func oneCharacterEditsRefused() throws {
        for (_, w) in fixtures.cases {
            let action: Data = try #require(oneDigitChanged(w, after: "\"actions\" : [", value: true))
            let actionRefusal: ApsidesWorkshopError = try #require(refusal(action))
            #expect(actionRefusal.reasonCode == "r02-g18.witness")
            let digest: Data = try #require(oneDigitChanged(w, after: "\"digests\" : [", value: false))
            #expect(refusal(digest) == .witness("digests"))
            let share: Data = try #require(oneDigitChanged(w, after: "\"shares\" : [", value: true))
            #expect(refusal(share) == .witness("report"))
            #expect(refusal(share)?.reasonCode == "r02-g18.witness")
        }
    }

    @Test("an edited digest, fingerprint or report is refused")
    func editedDigestFingerprintAndReportRefused() {
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
            let r: ApsidesWorkshopWitnessReport = w.report
            var shares: [Int] = r.shares
            shares[7] += 1
            let changes: [ApsidesWorkshopWitnessReport] = [
                ApsidesWorkshopWitnessParts.report(r, shares: shares),
                ApsidesWorkshopWitnessParts.report(r, shares: Array(r.shares.dropLast())),
                ApsidesWorkshopWitnessParts.report(r, periapsisDistance: 1),
                ApsidesWorkshopWitnessParts.report(r, apoapsisSector: 1),
                ApsidesWorkshopWitnessParts.report(r, residual: 1),
                ApsidesWorkshopWitnessParts.report(r, deviations: r.deviations + [0]),
                ApsidesWorkshopWitnessParts.report(r, met: -1),
            ]
            for changed in changes {
                #expect(refusal(edited(w) { $0.report = changed }) == .witness("report"))
            }
        }
    }

    @Test("an edited counterexample or difficulty is refused")
    func editedCounterexampleAndDifficultyRefused() {
        let w: ApsidesWorkshopWitness = fixtures.cases[3].witness
        let c: ApsidesWorkshopCounterexample = w.counterexample
        let more = ApsidesWorkshopCounterexample(depth: c.depth, orbits: c.orbits + 1)
        #expect(refusal(edited(w) { $0.counterexample = more }) == .witness("counterexample"))
        let lower = ApsidesWorkshopCounterexample(depth: c.depth - 1, orbits: c.orbits)
        #expect(refusal(edited(w) { $0.counterexample = lower }) == .witness("counterexample"))
        let planets: ApsidesWorkshopDifficulty = ApsidesWorkshopWitnessParts.difficulty(w.difficulty, planetsBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = planets }) == .witness("difficulty"))
        let orbits: ApsidesWorkshopDifficulty = ApsidesWorkshopWitnessParts.difficulty(w.difficulty, orbitsBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = orbits }) == .witness("difficulty"))
        let work: ApsidesWorkshopDifficulty = ApsidesWorkshopWitnessParts.difficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = work }) == .witness("difficulty"))
    }

    @Test("an edited level, number or skipped count is refused")
    func editedLevelRefused() throws {
        let w: ApsidesWorkshopWitness = fixtures.cases[0].witness
        let l: ApsidesWorkshopLevel = w.level
        // A level that still replays but is not the generator's candidate.
        let reseeded = try ApsidesWorkshopLevel(id: l.id, seed: l.seed &+ 1, difficulty: l.difficulty,
                                                period: l.period, planets: l.planets, targets: l.targets,
                                                orbit: l.orbit, budget: l.budget, tutorial: l.tutorial)
        #expect(ApsidesWorkshopSolver.replayWins(reseeded, actions: tunings(w)))
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
        let maxCandidates: Int = ApsidesWorkshopGenerator.maxCandidates
        #expect(refusal(edited(w) { $0.skipped = maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = -1 }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    @Test("newer, older, truncated and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: ApsidesWorkshopWitness = fixtures.cases[0].witness
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
        #expect(ApsidesWorkshopError.witness("schema 2").reasonCode == "r02-g18.witness")
        #expect(ApsidesWorkshopError.witness("digests").reasonCode == "r02-g18.witness")
    }

    @Test("make refuses values that are not the solver's plan")
    func makeRefuses() throws {
        let w: ApsidesWorkshopWitness = try #require(multi)
        var found: ApsidesWorkshopGenerated?
        for (generated, witness) in fixtures.cases where witness == w { found = generated }
        let g: ApsidesWorkshopGenerated = try #require(found)
        let p: ApsidesWorkshopPlan = g.plan
        let short = ApsidesWorkshopPlan(actions: Array(p.actions.dropLast()), orbit: p.orbit,
                                        orbitsByDepth: p.orbitsByDepth, work: p.work)
        let losing = ApsidesWorkshopGenerated(entry: g.entry, level: g.level, plan: short, difficulty: g.difficulty,
                                              skipped: g.skipped)
        #expect(throws: ApsidesWorkshopError.witness("replay")) { try ApsidesWorkshopWitness.make(losing) }
        var orbits: [Int] = p.orbitsByDepth
        orbits[orbits.count - 1] += 1
        let miscounted = ApsidesWorkshopPlan(actions: p.actions, orbit: p.orbit, orbitsByDepth: orbits, work: p.work)
        let wrongCount = ApsidesWorkshopGenerated(entry: g.entry, level: g.level, plan: miscounted,
                                                  difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: ApsidesWorkshopError.witness("counterexample")) {
            try ApsidesWorkshopWitness.make(wrongCount)
        }
        let harder: ApsidesWorkshopDifficulty = ApsidesWorkshopWitnessParts.difficulty(g.difficulty, planetsBy: 1)
        let wrongDifficulty = ApsidesWorkshopGenerated(entry: g.entry, level: g.level, plan: p, difficulty: harder,
                                                       skipped: g.skipped)
        #expect(throws: ApsidesWorkshopError.witness("difficulty")) {
            try ApsidesWorkshopWitness.make(wrongDifficulty)
        }
        let moreWork = ApsidesWorkshopPlan(actions: p.actions, orbit: p.orbit, orbitsByDepth: p.orbitsByDepth,
                                           work: p.work + 1)
        let wrongWork = ApsidesWorkshopGenerated(entry: g.entry, level: g.level, plan: moreWork,
                                                 difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: ApsidesWorkshopError.witness("difficulty")) { try ApsidesWorkshopWitness.make(wrongWork) }
        let otherEntry = ApsidesWorkshopGenerated(entry: ApsidesWorkshopManifest.entries[g.entry.number],
                                                  level: g.level, plan: p, difficulty: g.difficulty,
                                                  skipped: g.skipped)
        #expect(throws: ApsidesWorkshopError.witness("number")) { try ApsidesWorkshopWitness.make(otherEntry) }
        let empty = ApsidesWorkshopPlan(actions: [], orbit: p.orbit, orbitsByDepth: [], work: p.work)
        let none = ApsidesWorkshopGenerated(entry: g.entry, level: g.level, plan: empty, difficulty: g.difficulty,
                                            skipped: g.skipped)
        #expect(throws: ApsidesWorkshopError.witness("actions")) { try ApsidesWorkshopWitness.make(none) }
    }
}
