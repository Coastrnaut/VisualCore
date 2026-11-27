// BinaryGardensWitnessTests — feature 502 (R02-G21-02) T-R02G2102-005 (FR-R02G2102-004; SC-R02G2102-003, 005;
// clarification Q4; research R8, R9), on the rule kernel of feature 501 (R02-G21-01), modelled on
// MushroomWeatherWitnessTests (feature 492). Witnesses of generated levels 1 (band 1, tutorial), 21 (band 2) and 41
// (band 3), each generated with no previous level, built once per process. The stored form round-trips byte for byte
// with sorted keys and one trailing newline, the level nested in its own stored form with its phase step; equal makes
// give equal bytes; the state digest is the first 16 hex characters of SHA-256 over the canonical arrangement and
// actions-spent text (checked against known values); digests, fingerprints and the terminal light report agree with an
// independent replay (per world integral, exact mean as I / 48 and I mod 48, lethal run, window, bloom; star
// separation); the counterexample is the solver's arrangements at the depth one below the plan with its nearest miss,
// whose arrangement fails as stored; truncated JSON, a newer or older schema, an edited action, digest, fingerprint,
// level, report, counterexample or difficulty, and actions that no longer replay are refused with their reasons.
// Explicit types, plain loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import BinaryGardensCore

/// The generated levels and witnesses the tests share, built once.
struct BinaryGardensWitnessFixtures: Sendable {
    /// Generated levels with their witnesses: levels 1, 21 and 41, each generated with no previous level.
    let cases: [(generated: BinaryGardensGenerated, witness: BinaryGardensWitness)]

    static let shared: BinaryGardensWitnessFixtures = make()

    /// The generated level (with no previous level) and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: BinaryGardensGenerated, witness: BinaryGardensWitness) {
        let entry: BinaryGardensManifestEntry = BinaryGardensManifest.entries[index]
        let generated: BinaryGardensGenerated
        do { generated = try BinaryGardensGenerator.generate(entry, previous: nil) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try BinaryGardensWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> BinaryGardensWitnessFixtures {
        var cases: [(generated: BinaryGardensGenerated, witness: BinaryGardensWitness)] = []
        for index in [0, 20, 40] { cases.append(pair(index)) }
        return BinaryGardensWitnessFixtures(cases: cases)
    }
}

@Suite struct BinaryGardensWitnessTests {
    let fixtures: BinaryGardensWitnessFixtures = .shared

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> BinaryGardensError? {
        do {
            _ = try BinaryGardensWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// The payload of a `.witness` refusal, or nil for any other outcome.
    func witnessReason(_ error: BinaryGardensError?) -> String? {
        if case .witness(let reason) = error { return reason }
        return nil
    }

    /// `w` with other actions, digests or fingerprints, through the unchecked initializer.
    func edited(_ w: BinaryGardensWitness, actions: [BinaryGardensAction]? = nil, digests: [String]? = nil,
                fingerprints: [String]? = nil, skipped: Int? = nil, number: Int? = nil) -> BinaryGardensWitness {
        BinaryGardensWitness(number: number ?? w.number, level: w.level, actions: actions ?? w.actions,
                             digests: digests ?? w.digests, fingerprints: fingerprints ?? w.fingerprints,
                             report: w.report, counterexample: w.counterexample, difficulty: w.difficulty,
                             skipped: skipped ?? w.skipped)
    }

    /// The stored form of `w` with one character changed: the last digit of the first number after `marker` (a
    /// JSON value preceded by a space, or any digit inside a string when `inString`) becomes the next digit mod 10.
    func oneCharacterChanged(_ w: BinaryGardensWitness, after marker: String, inString: Bool) -> Data? {
        var bytes: [UInt8] = Array(w.encoded())
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
            if byte >= 0x30, byte <= 0x39, inString || bytes[j - 1] == 0x20 {
                while !inString && j + 1 < bytes.count && bytes[j + 1] >= 0x30 && bytes[j + 1] <= 0x39 { j += 1 }
                bytes[j] = 0x30 + (bytes[j] - 0x30 + 1) % 10
                return Data(bytes)
            }
            j += 1
        }
        return nil
    }

    @Test("the fixtures cover a tutorial, bands 1, 2 and 3 and their plan lengths")
    func fixturesCover() {
        #expect(fixtures.cases.count == 3)
        var bands: [Int] = []
        var lengths: [Int] = []
        for (generated, witness) in fixtures.cases {
            bands.append(generated.entry.band)
            lengths.append(witness.actions.count - 1)
        }
        #expect(bands == [1, 2, 3])
        #expect(lengths == [1, 2, 3])
        #expect(fixtures.cases[0].witness.level.tutorial)
        #expect(!fixtures.cases[1].witness.level.tutorial)
        #expect(!fixtures.cases[2].witness.level.tutorial)
        #expect(BinaryGardensWitness.schema == 1)
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
            let decoded: BinaryGardensWitness = try BinaryGardensWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            let text: String = String(decoding: data, as: UTF8.self)
            #expect(text.hasPrefix("{\n  \"actions\" : "))
            #expect(text.contains("\n  \"schema\" : 1,\n"))
            var found: [String] = []
            for line in text.components(separatedBy: "\n") where line.hasPrefix("  \"") {
                found.append(String(line.dropFirst(3).prefix { $0 != "\"" }))
            }
            #expect(found == keys)
            // The nested level is the level's own stored form, fingerprint and phase step included.
            #expect(text.contains("\"fingerprint\" : \"\(witness.level.fingerprint)\""))
            #expect(text.contains("\"phaseStep\" : \(witness.level.phaseStep)"))
            #expect(witness.level.phaseStep == BinaryGardensBandProfile.of(band: witness.level.difficulty).phaseStep)
            #expect(text.contains("\"run\" : {"))
            #expect(text.contains("\"arrangements\" : \(witness.counterexample.arrangements)"))
            #expect(text.contains("\"meanRemainder\" : "))
            #expect(text.contains("\"minimumSeparationSquared\" : \(witness.report.minimumSeparationSquared)"))
            #expect(text.contains("\"outcome\" : \"won\""))
            #expect(text.contains("\"failure\" : {"))
        }
    }

    @Test("equal makes give equal bytes; the counterexample and the parts are the plan's")
    func partsAreThePlans() throws {
        for (generated, witness) in fixtures.cases {
            let again: BinaryGardensWitness = try BinaryGardensWitness.make(generated)
            #expect(again.encoded() == witness.encoded())
            let plan: BinaryGardensPlan = generated.plan
            let level: BinaryGardensLevel = witness.level
            #expect(witness.number == generated.entry.number)
            #expect(level == generated.level)
            #expect(witness.actions == plan.actions + [.run])
            #expect(witness.actions.count - 1 <= level.budget)
            let failure: BinaryGardensFailure = try #require(
                BinaryGardensSky.report(level, arrangement: plan.nearestMissArrangement).failure)
            let expected = BinaryGardensCounterexample(depth: plan.size - 1,
                                                       arrangements: plan.arrangementsByDepth[plan.size - 1],
                                                       nearestMiss: plan.nearestMiss,
                                                       arrangement: plan.nearestMissArrangement, failure: failure)
            #expect(witness.counterexample == expected)
            #expect(witness.counterexample.depth == plan.size - 1)
            #expect(witness.counterexample.arrangements >= 1)
            #expect(witness.counterexample.nearestMiss > 0 || witness.counterexample.failure.code == "frozen"
                        || witness.counterexample.failure.code == "scorched")
            #expect(BinaryGardensSolver.loss(level, report: BinaryGardensSky.report(
                level, arrangement: witness.counterexample.arrangement)) == witness.counterexample.nearestMiss)
            #expect(witness.counterexample.failure.world < level.worlds.count)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.nearestMiss == witness.counterexample.nearestMiss)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("the canonical text lists rings, phases, luminosities, tilt and spent; the digest has known values")
    func digestDefinition() {
        let one = BinaryGardensArrangement(rings: [0, 2], phases: [8, 24], luminosities: [1, 0], tilt: 1)
        let none = BinaryGardensArrangement(rings: [1, 1], phases: [0, 0], luminosities: [0, 0], tilt: 0)
        let two = BinaryGardensArrangement(rings: [3, 0], phases: [42, 6], luminosities: [2, 1], tilt: 3)
        #expect(BinaryGardensWitness.canonicalText(arrangement: one, spent: 2)
                == "rings=0,2;phases=8,24;luminosities=1,0;tilt=1;spent=2")
        #expect(BinaryGardensWitness.canonicalText(arrangement: none, spent: 0)
                == "rings=1,1;phases=0,0;luminosities=0,0;tilt=0;spent=0")
        #expect(BinaryGardensWitness.canonicalText(arrangement: two, spent: 4)
                == "rings=3,0;phases=42,6;luminosities=2,1;tilt=3;spent=4")
        // Known values: `printf '<text>' | shasum -a 256`, first 16 characters.
        #expect(BinaryGardensWitness.digest(arrangement: one, spent: 2) == "4053abb556d53109")
        #expect(BinaryGardensWitness.digest(arrangement: none, spent: 0) == "6e286e13907d3aca")
        #expect(BinaryGardensWitness.digest(arrangement: two, spent: 4) == "08355c8ae95226b0")
        for (_, witness) in fixtures.cases {
            #expect(witness.digests.count == witness.actions.count)
            for value in witness.digests { #expect(value.count == 16) }
        }
    }

    @Test("state digests, fingerprints and the terminal light report agree with an independent replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: BinaryGardensLevel = witness.level
            var play = BinaryGardensPlay(level: level)
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
                let text: String = BinaryGardensWitness.canonicalText(arrangement: play.arrangement,
                                                                      spent: play.actionsSpent)
                digests.append(String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(fingerprints.count == witness.actions.count + (level.tutorial ? 2 : 1))
            #expect(digests == witness.digests)
            // The run spends nothing: the last two digests are equal.
            #expect(witness.digests[witness.digests.count - 1] == witness.digests[witness.digests.count - 2])
            let r: BinaryGardensReport = play.report
            #expect(witness.report == BinaryGardensWitnessReport(level: level, report: r))
            #expect(witness.report.outcome == "won")
            #expect(witness.report.minimumSeparationSquared == r.minimumSeparationSquared)
            #expect(witness.report.minimumSeparationTick == r.minimumSeparationTick)
            #expect(witness.report.minimumSeparationSquared
                        >= level.minimumSeparation * level.minimumSeparation * BinaryGardensSky.squaredScale)
            #expect(witness.report.worlds.count == level.worlds.count)
            for (index, world) in witness.report.worlds.enumerated() {
                let light: BinaryGardensWorldLight = r.worlds[index]
                var sum: Int = 0
                for flux in light.flux { sum += flux }
                #expect(world.integral == sum)
                #expect(world.meanWhole * 48 + world.meanRemainder == world.integral)
                #expect((0..<48).contains(world.meanRemainder))
                #expect(world.longestLethalRun <= world.tolerance)
                #expect(world.tolerance == level.lethalTolerance)
                #expect(world.window >= world.requiredWindow)
                #expect(world.requiredWindow == level.worlds[index].window)
                #expect(world.windowStart == light.windowStart)
                #expect(world.bloom == .inside)
            }
            #expect(BinaryGardensSolver.replayWins(level, actions: Array(witness.actions.dropLast())))
        }
    }

    @Test("truncated JSON, a newer or older schema and missing keys are refused")
    func damagedBodiesRefused() {
        let w: BinaryGardensWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let bytes: [UInt8] = Array(w.encoded())
        #expect(refusal(Data(bytes.prefix(bytes.count / 2))) == .witness("unreadable"))
        #expect(refusal(Data(bytes.prefix(bytes.count - 3))) == .witness("unreadable"))
        #expect(refusal(Data("not json".utf8)) == .witness("unreadable"))
        let newer: String = text.replacingOccurrences(of: "\n  \"schema\" : 1,\n", with: "\n  \"schema\" : 2,\n")
        #expect(newer != text)
        #expect(refusal(Data(newer.utf8)) == .newerSchema(2))
        #expect(refusal(Data(newer.utf8))?.reasonCode == "r02-g21.newer-schema")
        let zero: String = text.replacingOccurrences(of: "\n  \"schema\" : 1,\n", with: "\n  \"schema\" : 0,\n")
        #expect(refusal(Data(zero.utf8)) == .witness("schema 0"))
        let missing: String = text.replacingOccurrences(of: "\n  \"skipped\" : \(w.skipped)\n", with: "\n")
            .replacingOccurrences(of: ",\n}", with: "\n}")
        #expect(missing != text)
        #expect(refusal(Data(missing.utf8)) == .witness("unreadable"))
        #expect(refusal(Data(missing.utf8))?.reasonCode == "r02-g21.witness")
    }

    @Test("an edited digest, fingerprint, level, report, counterexample or difficulty is refused")
    func editedValuesRefused() throws {
        let w: BinaryGardensWitness = fixtures.cases[1].witness
        let digestEdit: Data = try #require(oneCharacterChanged(w, after: "\"digests\" : [", inString: true))
        #expect(refusal(digestEdit) == .witness("digests"))
        let fingerprintEdit: Data = try #require(oneCharacterChanged(w, after: "\"fingerprints\" : [",
                                                                     inString: true))
        #expect(refusal(fingerprintEdit) == .witness("fingerprints"))
        let levelEdit: Data = try #require(oneCharacterChanged(w, after: "\"clampRadius\" :", inString: false))
        #expect(refusal(levelEdit) == .witness("level"))
        let reportEdit: Data = try #require(oneCharacterChanged(w, after: "\"meanWhole\" :", inString: false))
        #expect(refusal(reportEdit) == .witness("report"))
        let separationEdit: Data = try #require(oneCharacterChanged(w, after: "\"minimumSeparationTick\" :",
                                                                    inString: false))
        #expect(refusal(separationEdit) == .witness("report"))
        let missEdit: Data = try #require(oneCharacterChanged(w, after: "\"arrangements\" :", inString: false))
        #expect(refusal(missEdit) == .witness("counterexample"))
        let bandEdit: Data = try #require(oneCharacterChanged(w, after: "\"narrowestBand\" :", inString: false))
        #expect(refusal(bandEdit) == .witness("difficulty"))
        let workEdit: Data = try #require(oneCharacterChanged(w, after: "\"work\" :", inString: false))
        #expect(refusal(workEdit) == .witness("difficulty"))
        var stale: [String] = w.digests
        stale[0] = "0000000000000000"
        #expect(refusal(edited(w, digests: stale).encoded()) == .witness("digests"))
        var other: [String] = w.fingerprints
        other[0] = other[1]
        #expect(refusal(edited(w, fingerprints: other).encoded()) == .witness("fingerprints"))
        // Provenance: another number, a skipped count out of range or of another candidate.
        #expect(refusal(edited(w, number: w.number + 1).encoded()) == .witness("number"))
        #expect(refusal(edited(w, number: 0).encoded()) == .witness("number"))
        #expect(refusal(edited(w, skipped: 64).encoded()) == .witness("skipped"))
        #expect(refusal(edited(w, skipped: -1).encoded()) == .witness("skipped"))
        let otherCandidate: Int = w.skipped == 0 ? 1 : 0
        #expect(refusal(edited(w, skipped: otherCandidate).encoded()) == .witness("candidate"))
    }

    @Test("an edited action, or actions that no longer replay, are refused")
    func editedActionsRefused() throws {
        let w: BinaryGardensWitness = fixtures.cases[2].witness
        let level: BinaryGardensLevel = w.level
        let arrangementActions: [BinaryGardensAction] = Array(w.actions.dropLast())
        // One character changed inside the actions: refused before, during or after the replay.
        let actionEdit: Data = try #require(oneCharacterChanged(w, after: "\"actions\" : [", inString: false))
        let reason: String = try #require(witnessReason(refusal(actionEdit)))
        #expect(reason == "actions" || reason.hasPrefix("replay ") || reason == "solution")
        // One action fewer plays without winning (the counterexample says nothing one action short wins).
        let shorter: [BinaryGardensAction] = Array(arrangementActions.dropLast()) + [.run]
        #expect(refusal(edited(w, actions: shorter).encoded()) == .witness("replay not won"))
        // A repeated action is refused by the play as unchanged.
        let repeated: [BinaryGardensAction] = [arrangementActions[0]] + w.actions
        #expect(refusal(edited(w, actions: repeated).encoded()) == .witness("replay r02-g21.action"))
        // Shape refusals before the replay: no arrangement action, no run, a run inside, a value off the level.
        #expect(refusal(edited(w, actions: [.run]).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: arrangementActions).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.run] + w.actions).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.phase(star: 0, step: 1), .run]).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.ring(star: 2, index: 0), .run]).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.ring(star: 0, index: level.ringRadii.count), .run]).encoded())
                    == .witness("actions"))
        #expect(refusal(edited(w, actions: [.tilt(step: level.maxTilt + 1), .run]).encoded()) == .witness("actions"))
        let tooMany: [BinaryGardensAction] = Array(repeating: arrangementActions[0], count: level.budget + 1) + [.run]
        #expect(refusal(edited(w, actions: tooMany).encoded()) == .witness("actions"))
        // The same actions in another legal order win but are not the solver's plan; a refused order names the play.
        var reordered: [BinaryGardensAction] = arrangementActions
        reordered.swapAt(0, reordered.count - 1)
        let refused: String = try #require(witnessReason(refusal(edited(w, actions: reordered + [.run]).encoded())))
        #expect(refused == "solution" || refused.hasPrefix("replay "))
    }
}
