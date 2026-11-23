// EchoCartographerWitnessTests — feature 402 (R02-G11-02) T-R02G1102-005 (FR-R02G1102-004; SC-R02G1102-003, 005;
// clarification Q4). Witnesses of generated catalog levels 1 (band 1, tutorial), 21 (band 2), 41 (band 3), 61 (band 4)
// and 81 (band 5), built once per process. The stored form round-trips byte for byte with sorted keys and one trailing
// newline; the echo digest is the first 16 hex characters of SHA-256 over the canonical echo text (checked against a
// hand-computed value) and changes with any ray or echo; digests, placements and fingerprints agree with a replay and a
// recount; the counterexample's two placements fit every pulse but the last; edited actions, digests, fingerprints,
// placements, counterexample, placements before the last pulse, difficulty (work included), level, number, skipped and
// schema are refused naming the part; a different winning claim order is refused by the solver re-run; newer and
// damaged stored forms are refused; `make` refuses a losing plan and values that are not the plan's. Explicit types,
// plain loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import EchoCartographerCore

/// The generated levels and witnesses the tests share, built once.
struct EchoCartographerWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: EchoCartographerGenerated, witness: EchoCartographerWitness)]

    static let shared: EchoCartographerWitnessFixtures = make()

    private static func make() -> EchoCartographerWitnessFixtures {
        let entries: [EchoCartographerManifestEntry] = EchoCartographerManifest.entries
        var cases: [(generated: EchoCartographerGenerated, witness: EchoCartographerWitness)] = []
        for index in [0, 20, 40, 60, 80] {
            let generated: EchoCartographerGenerated
            do { generated = try EchoCartographerGenerator.generate(entries[index]) } catch {
                preconditionFailure("level \(entries[index].number) does not generate: \(error)")
            }
            do { cases.append((generated, try EchoCartographerWitness.make(generated))) } catch {
                preconditionFailure("level \(generated.entry.number) has no witness: \(error)")
            }
        }
        return EchoCartographerWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct EchoCartographerWitnessParts {
    var number: Int
    var level: EchoCartographerLevel
    var actions: [EchoCartographerAction]
    var echoDigests: [String]
    var placements: [Int]
    var fingerprints: [String]
    var counterexample: [[EchoCartographerCell]]
    var placementsBeforeLast: Int
    var difficulty: EchoCartographerDifficulty
    var skipped: Int

    init(_ w: EchoCartographerWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        echoDigests = w.echoDigests
        placements = w.placements
        fingerprints = w.fingerprints
        counterexample = w.counterexample
        placementsBeforeLast = w.placementsBeforeLast
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: EchoCartographerWitness {
        EchoCartographerWitness(number: number, level: level, actions: actions, echoDigests: echoDigests,
                                placements: placements, fingerprints: fingerprints, counterexample: counterexample,
                                placementsBeforeLast: placementsBeforeLast, difficulty: difficulty, skipped: skipped)
    }
}

/// `d` with its width and work changed by the given amounts.
func echoCartographerDifficulty(_ d: EchoCartographerDifficulty, widthBy width: Int = 0,
                                workBy work: Int = 0) -> EchoCartographerDifficulty {
    EchoCartographerDifficulty(pulses: d.pulses, width: d.width + width, height: d.height, region: d.region,
                               beacons: d.beacons, tolerance: d.tolerance,
                               placementsBeforeLast: d.placementsBeforeLast, work: d.work + work)
}

@Suite("Echo Cartographer witness")
struct EchoCartographerWitnessTests {
    let fixtures: EchoCartographerWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: EchoCartographerWitness) -> EchoCartographerError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> EchoCartographerError? {
        do {
            _ = try EchoCartographerWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: EchoCartographerWitness,
                _ change: (inout EchoCartographerWitnessParts) -> Void) -> EchoCartographerWitness {
        var parts = EchoCartographerWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: EchoCartographerWitness, key: String, line: String?) -> Data {
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

    /// The pulse count of `witness`.
    func pulses(_ witness: EchoCartographerWitness) -> Int {
        var count: Int = 0
        for action in witness.actions {
            if case .pulse = action { count += 1 }
        }
        return count
    }

    @Test("the fixtures cover bands 1 to 5 and a tutorial")
    func fixturesCover() {
        #expect(fixtures.cases.count == 5)
        #expect(fixtures.cases[0].generated.level.tutorial)
        var bands: [Int] = []
        for (generated, _) in fixtures.cases { bands.append(generated.entry.band) }
        #expect(bands == [1, 2, 3, 4, 5])
        for index in 1..<fixtures.cases.count { #expect(!fixtures.cases[index].generated.level.tutorial) }
    }

    @Test("the stored form round-trips byte for byte with sorted keys and one trailing newline")
    func roundTripByteForByte() throws {
        let keys: [String] = ["actions", "counterexample", "difficulty", "echoDigests", "fingerprints", "level",
                              "number", "placements", "placementsBeforeLast", "schema", "skipped"]
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data == witness.encoded())
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: EchoCartographerWitness = try EchoCartographerWitness.decode(data)
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
            #expect(witness.level.id == EchoCartographerGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.actions)
            #expect(witness.actions.count == generated.plan.pulses.count + generated.level.beacons.count)
            #expect(witness.placements == generated.plan.placements)
            #expect(witness.placements.last == 1)
            #expect(witness.counterexample == generated.plan.counterexample)
            #expect(witness.counterexample.count == 2)
            #expect(witness.placementsBeforeLast == generated.plan.placementsBeforeLast)
            #expect(witness.placementsBeforeLast >= 2)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.work == generated.plan.work)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("digests, placements and fingerprints agree with a replay and a recount")
    func partsAgreeWithReplay() throws {
        for (generated, witness) in fixtures.cases {
            let level: EchoCartographerLevel = witness.level
            let pulseCount: Int = generated.plan.pulses.count
            #expect(witness.echoDigests.count == pulseCount)
            #expect(witness.placements.count == pulseCount)
            let starts: Int = level.tutorial ? 2 : 1
            #expect(witness.fingerprints.count == starts + witness.actions.count)
            var play = EchoCartographerPlay(level: level)
            try play.handle(.begin)
            var fingerprints: [String] = [play.fingerprint]
            if play.stage == .tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            var digests: [String] = []
            var observations: [EchoCartographerObservation] = []
            var placements: [Int] = []
            var work: Int = 0
            for action in witness.actions {
                #expect(play.stage == .playing)
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                if case let .pulse(x, y) = action {
                    let echo: EchoCartographerEcho = level.echo(from: EchoCartographerCell(x: x, y: y))
                    #expect(play.lastEcho == echo)
                    digests.append(EchoCartographerWitness.digest(echo))
                    observations.append(EchoCartographerObservation(emitter: echo.emitter,
                                                                    echoes: echo.beaconDistances))
                    let count: Int = EchoCartographerSolver.fitting(level, observations: observations,
                                                                    cap: EchoCartographerSolver.placementCap,
                                                                    work: &work).count
                    placements.append(count)
                }
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.echoDigests)
            #expect(placements == witness.placements)
            #expect(EchoCartographerSolver.wins(level, actions: witness.actions))
            for digest in witness.echoDigests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
        }
    }

    @Test("the counterexample's two placements fit every pulse but the last and differ")
    func counterexampleFits() {
        for (_, witness) in fixtures.cases {
            let level: EchoCartographerLevel = witness.level
            var observations: [EchoCartographerObservation] = []
            for action in witness.actions {
                if case let .pulse(x, y) = action {
                    let echo: EchoCartographerEcho = level.echo(from: EchoCartographerCell(x: x, y: y))
                    observations.append(EchoCartographerObservation(emitter: echo.emitter,
                                                                    echoes: echo.beaconDistances))
                }
            }
            let short: [EchoCartographerObservation] = Array(observations.dropLast())
            #expect(witness.counterexample[0] != witness.counterexample[1])
            var fittingAll: Int = 0
            for placement in witness.counterexample {
                #expect(EchoCartographerWitness.fits(level, placement: placement, observations: short))
                if EchoCartographerWitness.fits(level, placement: placement, observations: observations) {
                    fittingAll += 1
                }
            }
            // Exactly one placement fits every pulse, so at most one of the two survives the last pulse.
            #expect(fittingAll <= 1)
            #expect(EchoCartographerWitness.fits(level, placement: level.beacons, observations: observations))
        }
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over the canonical echo")
    func digestLayout() {
        // printf '%s' 'e=1,2;north=3,none;east=1,2,2;south=2,1,4;west=2,none;b=1,4' | shasum -a 256 → b11f180203ef3061…
        let emitter = EchoCartographerCell(x: 1, y: 2)
        let rays: [EchoCartographerRay] = [
            EchoCartographerRay(direction: .north, open: [], wall: nil, distance: 3),
            EchoCartographerRay(direction: .east, open: [], wall: EchoCartographerCell(x: 2, y: 2), distance: 1),
            EchoCartographerRay(direction: .south, open: [], wall: EchoCartographerCell(x: 1, y: 4), distance: 2),
            EchoCartographerRay(direction: .west, open: [], wall: nil, distance: 2),
        ]
        let echo = EchoCartographerEcho(emitter: emitter, rays: rays, beaconDistances: [1, 4])
        let text: String = "e=1,2;north=3,none;east=1,2,2;south=2,1,4;west=2,none;b=1,4"
        #expect(EchoCartographerWitness.canonicalText(echo) == text)
        #expect(EchoCartographerWitness.digest(echo) == "b11f180203ef3061")
        #expect(EchoCartographerWitness.digest(echo) == String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
        let base: String = EchoCartographerWitness.digest(echo)
        var others: [EchoCartographerEcho] = []
        var longer: [EchoCartographerRay] = rays
        longer[0] = EchoCartographerRay(direction: .north, open: [], wall: nil, distance: 4)
        others.append(EchoCartographerEcho(emitter: emitter, rays: longer, beaconDistances: [1, 4]))
        var walled: [EchoCartographerRay] = rays
        walled[3] = EchoCartographerRay(direction: .west, open: [], wall: EchoCartographerCell(x: 0, y: 2),
                                        distance: 2)
        others.append(EchoCartographerEcho(emitter: emitter, rays: walled, beaconDistances: [1, 4]))
        others.append(EchoCartographerEcho(emitter: emitter, rays: rays, beaconDistances: [1, 5]))
        others.append(EchoCartographerEcho(emitter: emitter, rays: rays, beaconDistances: [1]))
        others.append(EchoCartographerEcho(emitter: EchoCartographerCell(x: 2, y: 1), rays: rays,
                                           beaconDistances: [1, 4]))
        for other in others { #expect(EchoCartographerWitness.digest(other) != base) }
    }

    @Test("edited actions are refused")
    func editedActionsRefused() {
        let w: EchoCartographerWitness = fixtures.cases[1].witness
        #expect(refusal(edited(w) { $0.actions.removeLast() }) == .witness("replay"))
        #expect(refusal(edited(w) { $0.actions.append(w.actions[0]) }) == .witness("replay"))
        #expect(refusal(edited(w) { $0.actions = [] }) == .witness("replay"))
        #expect(refusal(edited(w) { $0.actions[0] = .pulse(-1, -1) }) == .witness("replay"))
        // Claims only: the play wins without a pulse, but a witness needs its pulses.
        let claims: [EchoCartographerAction] = Array(w.actions.dropFirst(pulses(w)))
        #expect(refusal(edited(w) { $0.actions = claims }) == .witness("replay"))
    }

    @Test("edited echo digests are refused")
    func editedDigestsRefused() {
        let w: EchoCartographerWitness = fixtures.cases[2].witness
        let first: String = w.echoDigests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.echoDigests[0] = flipped }) == .witness("echo-digests"))
        #expect(refusal(edited(w) { $0.echoDigests.removeLast() }) == .witness("echo-digests"))
        #expect(refusal(edited(w) { $0.echoDigests.append(first) }) == .witness("echo-digests"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: EchoCartographerWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
        // Level 1 has a tutorial: dropping the fingerprint after `dismissTutorial` is refused.
        #expect(refusal(edited(w) { $0.fingerprints.remove(at: 1) }) == .witness("fingerprints"))
    }

    @Test("edited placements, counterexample and placements before the last pulse are refused")
    func editedCountsRefused() {
        let w: EchoCartographerWitness = fixtures.cases[2].witness
        #expect(refusal(edited(w) { $0.placements[0] += 1 }) == .witness("placements"))
        #expect(refusal(edited(w) { $0.placements.removeLast() }) == .witness("placements"))
        #expect(refusal(edited(w) { $0.counterexample.swapAt(0, 1) }) == .witness("counterexample"))
        #expect(refusal(edited(w) { $0.counterexample.removeLast() }) == .witness("counterexample"))
        let second: [EchoCartographerCell] = w.counterexample[1]
        #expect(refusal(edited(w) { $0.counterexample[0] = second }) == .witness("counterexample"))
        #expect(refusal(edited(w) { $0.placementsBeforeLast += 1 }) == .witness("placements-before-last"))
        #expect(refusal(edited(w) { $0.placementsBeforeLast = 1 }) == .witness("placements-before-last"))
    }

    @Test("an edited level is refused")
    func editedLevelRefused() throws {
        let w: EchoCartographerWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let energy: Int = w.level.energy
        let changedEnergy: Int = energy + 1
        let changed: String = text.replacingOccurrences(of: "\"energy\" : \(energy),",
                                                        with: "\"energy\" : \(changedEnergy),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
        // A re-fingerprinted level that is not the generator's candidate.
        let l: EchoCartographerLevel = w.level
        let other = try EchoCartographerLevel(id: l.id, seed: l.seed, difficulty: l.difficulty, chamber: l.chamber,
                                              entry: l.entry, beacons: l.beacons, tolerance: l.tolerance,
                                              energy: changedEnergy, missCost: l.missCost, tutorial: l.tutorial)
        #expect(refusal(edited(w) { $0.level = other }) == .witness("candidate"))
    }

    @Test("edited difficulty, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: EchoCartographerWitness = fixtures.cases[1].witness
        let wider: EchoCartographerDifficulty = echoCartographerDifficulty(w.difficulty, widthBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = wider }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = EchoCartographerGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    /// Feature 382's convergence lesson: decoding re-runs the solver, so an edited solver work count and another
    /// winning action order (the claims reversed) are refused.
    @Test("an edited solver result and a different winning claim order are refused")
    func editedSolverResultRefused() {
        let w: EchoCartographerWitness = fixtures.cases[3].witness
        let more: EchoCartographerDifficulty = echoCartographerDifficulty(w.difficulty, workBy: 1)
        #expect(refusal(edited(w) { $0.difficulty = more }) == .witness("solution"))
        let less: EchoCartographerDifficulty = echoCartographerDifficulty(w.difficulty, workBy: -1)
        #expect(refusal(edited(w) { $0.difficulty = less }) == .witness("solution"))
        var reordered: EchoCartographerWitness?
        for witness in fixtures.cases.map(\.witness) where reordered == nil {
            guard witness.level.beacons.count >= 2 else { continue }
            let count: Int = pulses(witness)
            let swapped: [EchoCartographerAction] = Array(witness.actions.prefix(count))
                + Array(witness.actions.dropFirst(count).reversed())
            guard swapped != witness.actions,
                  let run = EchoCartographerWitness.replay(witness.level, actions: swapped), run.play.stage == .won,
                  !run.endedEarly else { continue }
            // A consistent witness of the reordered claims: replayed fingerprints, the same echoes, counts and
            // difficulty, so only the solver re-run can tell it apart.
            reordered = edited(witness) {
                $0.actions = swapped
                $0.fingerprints = run.fingerprints
            }
        }
        #expect(reordered != nil, "no fixture witness has two beacons")
        if let reordered {
            #expect(EchoCartographerSolver.wins(reordered.level, actions: reordered.actions))
            #expect(refusal(reordered) == .witness("solution"))
        }
    }

    @Test("newer, older and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: EchoCartographerWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .witness("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "level", line: nil)) == .witness("unreadable"))
        #expect(refusal(storedText(w, key: "placementsBeforeLast", line: "\"none\"")) == .witness("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .witness("unreadable"))
        #expect(refusal(Data()) == .witness("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .witness("unreadable"))
        #expect(EchoCartographerError.witness("echo-digests").reasonCode == "r02-g11.witness")
        #expect(EchoCartographerError.newerSchema(2).reasonCode == "r02-g11.newer-schema")
    }

    @Test("make refuses a losing plan and values that are not the plan's")
    func makeRefuses() {
        let g: EchoCartographerGenerated = fixtures.cases[2].generated
        let p: EchoCartographerPlan = g.plan
        let short = EchoCartographerPlan(pulses: Array(p.pulses.dropLast()), placements: Array(p.placements.dropLast()),
                                         placementsBeforeLast: p.placementsBeforeLast,
                                         counterexample: p.counterexample, work: p.work)
        // Fewer pulses: the claims still win, but the recount does not single out the beacons.
        let fewer = EchoCartographerGenerated(entry: g.entry, level: g.level, plan: short, difficulty: g.difficulty,
                                              skipped: g.skipped)
        #expect(throws: EchoCartographerError.witness("placements")) { try EchoCartographerWitness.make(fewer) }
        let bumped = EchoCartographerPlan(pulses: p.pulses, placements: p.placements,
                                          placementsBeforeLast: p.placementsBeforeLast + 1,
                                          counterexample: p.counterexample, work: p.work)
        let wrongCount = EchoCartographerGenerated(entry: g.entry, level: g.level, plan: bumped,
                                                   difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: EchoCartographerError.witness("placements-before-last")) {
            try EchoCartographerWitness.make(wrongCount)
        }
        let other: EchoCartographerDifficulty = echoCartographerDifficulty(g.difficulty, workBy: 1)
        let wrong = EchoCartographerGenerated(entry: g.entry, level: g.level, plan: p, difficulty: other,
                                              skipped: g.skipped)
        #expect(throws: EchoCartographerError.witness("difficulty")) { try EchoCartographerWitness.make(wrong) }
        let otherEntry = EchoCartographerGenerated(entry: EchoCartographerManifest.entries[0], level: g.level,
                                                   plan: p, difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: EchoCartographerError.witness("number")) { try EchoCartographerWitness.make(otherEntry) }
    }
}
