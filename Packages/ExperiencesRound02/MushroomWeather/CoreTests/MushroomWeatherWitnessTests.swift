// MushroomWeatherWitnessTests — feature 492 (R02-G20-02) T-R02G2002-005 (FR-R02G2002-004; SC-R02G2002-003, 005;
// clarification Q4), on the rule kernel of feature 491 (R02-G20-01), modelled on MicroscopicAuroraWitnessTests (feature
// 482). Witnesses of generated levels 1 (band 1, tutorial), 21 (band 2) and 41 (band 3), each generated with no
// previous level, built once per process. The stored form round-trips byte for byte with sorted keys and one trailing
// newline; equal makes give equal bytes; the state digest is the first 16 hex characters of SHA-256 over the canonical
// arrangement and actions-spent text (checked against known values); digests, fingerprints and the terminal report
// agree with an independent replay; the counterexample is the solver's arrangements at the depth one below the plan and
// its nearest miss; truncated JSON, a newer schema, an edited action, digest, fingerprint, level, report,
// counterexample or difficulty, and actions that no longer replay are refused with their reasons. Explicit types, plain
// loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import MushroomWeatherCore

/// The generated levels and witnesses the tests share, built once.
struct MushroomWeatherWitnessFixtures: Sendable {
    /// Generated levels with their witnesses: levels 1, 21 and 41, each generated with no previous level.
    let cases: [(generated: MushroomWeatherGenerated, witness: MushroomWeatherWitness)]

    static let shared: MushroomWeatherWitnessFixtures = make()

    /// The generated level (with no previous level) and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: MushroomWeatherGenerated, witness: MushroomWeatherWitness) {
        let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[index]
        let generated: MushroomWeatherGenerated
        do { generated = try MushroomWeatherGenerator.generate(entry, previous: nil) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try MushroomWeatherWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> MushroomWeatherWitnessFixtures {
        var cases: [(generated: MushroomWeatherGenerated, witness: MushroomWeatherWitness)] = []
        for index in [0, 20, 40] { cases.append(pair(index)) }
        return MushroomWeatherWitnessFixtures(cases: cases)
    }
}

@Suite struct MushroomWeatherWitnessTests {
    let fixtures: MushroomWeatherWitnessFixtures = .shared

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> MushroomWeatherError? {
        do {
            _ = try MushroomWeatherWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// The payload of a `.witness` refusal, or nil for any other outcome.
    func witnessReason(_ error: MushroomWeatherError?) -> String? {
        if case .witness(let reason) = error { return reason }
        return nil
    }

    /// `w` with other actions, digests or fingerprints, through the unchecked initializer.
    func edited(_ w: MushroomWeatherWitness, actions: [MushroomWeatherAction]? = nil, digests: [String]? = nil,
                fingerprints: [String]? = nil) -> MushroomWeatherWitness {
        MushroomWeatherWitness(number: w.number, level: w.level, actions: actions ?? w.actions,
                               digests: digests ?? w.digests, fingerprints: fingerprints ?? w.fingerprints,
                               report: w.report, counterexample: w.counterexample, difficulty: w.difficulty,
                               skipped: w.skipped)
    }

    /// The stored form of `w` with one character changed: the last digit of the first number after `marker` (a
    /// JSON value preceded by a space, or any digit inside a string when `inString`) becomes the next digit mod 10.
    func oneCharacterChanged(_ w: MushroomWeatherWitness, after marker: String, inString: Bool) -> Data? {
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
        #expect(lengths == [2, 3, 3])
        #expect(fixtures.cases[0].witness.level.tutorial)
        #expect(!fixtures.cases[1].witness.level.tutorial)
        #expect(!fixtures.cases[2].witness.level.tutorial)
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
            let decoded: MushroomWeatherWitness = try MushroomWeatherWitness.decode(data)
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
            // The nested level is the level's own stored form, fingerprint and sites included.
            #expect(text.contains("\"fingerprint\" : \"\(witness.level.fingerprint)\""))
            #expect(text.contains("\"sites\" : ["))
            #expect(text.contains("\"run\" : {"))
            #expect(text.contains("\"arrangements\" : \(witness.counterexample.arrangements)"))
            #expect(text.contains("\"evaporated\" : \(witness.report.evaporated)"))
            #expect(text.contains("\"released\" : \(witness.report.released)"))
            #expect(text.contains("\"longestRun\" : "))
            #expect(text.contains("\"cycles\" : \(witness.report.cycles)"))
        }
    }

    @Test("equal makes give equal bytes; the counterexample and the parts are the plan's")
    func partsAreThePlans() throws {
        for (generated, witness) in fixtures.cases {
            let again: MushroomWeatherWitness = try MushroomWeatherWitness.make(generated)
            #expect(again.encoded() == witness.encoded())
            let plan: MushroomWeatherPlan = generated.plan
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.actions == plan.actions + [.run])
            #expect(witness.actions.count - 1 <= witness.level.budget)
            let expected = MushroomWeatherCounterexample(depth: plan.size - 1,
                                                         arrangements: plan.arrangementsByDepth[plan.size - 1],
                                                         nearestMiss: plan.nearestMiss)
            #expect(witness.counterexample == expected)
            #expect(witness.counterexample.depth == plan.size - 1)
            #expect(witness.counterexample.arrangements >= 1)
            #expect(witness.counterexample.nearestMiss > 0)
            // Every arrangement at the counterexample's depth was judged.
            let atDepth: Int = MushroomWeatherSolver.arrangements(witness.level,
                                                                  depth: witness.counterexample.depth).count
            #expect(witness.counterexample.arrangements == atDepth)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.nearestMiss == witness.counterexample.nearestMiss)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("the canonical text lists slots, vents, moonlight and spent; the digest has known values")
    func digestDefinition() {
        let one = MushroomWeatherArrangement(pods: [MushroomWeatherCell(row: 2, column: 3), nil], ventsOpen: [true],
                                             moonlight: 1)
        let none = MushroomWeatherArrangement(pods: [nil, nil], ventsOpen: [false, true], moonlight: 0)
        let two = MushroomWeatherArrangement(pods: [MushroomWeatherCell(row: 4, column: 5),
                                                    MushroomWeatherCell(row: 1, column: 2), nil],
                                             ventsOpen: [false, false], moonlight: 3)
        #expect(MushroomWeatherWitness.canonicalText(arrangement: one, spent: 1)
                == "pods=2 3,none;vents=open;moonlight=1;spent=1")
        #expect(MushroomWeatherWitness.canonicalText(arrangement: none, spent: 0)
                == "pods=none,none;vents=closed,open;moonlight=0;spent=0")
        #expect(MushroomWeatherWitness.canonicalText(arrangement: two, spent: 4)
                == "pods=4 5,1 2,none;vents=closed,closed;moonlight=3;spent=4")
        // Known values: `printf '<text>' | shasum -a 256`, first 16 characters.
        #expect(MushroomWeatherWitness.digest(arrangement: one, spent: 1) == "ed02f3f0aceb58d3")
        #expect(MushroomWeatherWitness.digest(arrangement: none, spent: 0) == "0991fae9539b93ba")
        #expect(MushroomWeatherWitness.digest(arrangement: two, spent: 4) == "8c3da8a385596ecb")
        for (_, witness) in fixtures.cases {
            #expect(witness.digests.count == witness.actions.count)
            for value in witness.digests { #expect(value.count == 16) }
        }
    }

    @Test("state digests, fingerprints and the terminal report agree with an independent replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: MushroomWeatherLevel = witness.level
            var play = MushroomWeatherPlay(level: level)
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
                let text: String = MushroomWeatherWitness.canonicalText(arrangement: play.arrangement,
                                                                        spent: play.actionsSpent)
                digests.append(String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(fingerprints.count == witness.actions.count + (level.tutorial ? 2 : 1))
            #expect(digests == witness.digests)
            // The run spends nothing: the last two digests are equal.
            #expect(witness.digests[witness.digests.count - 1] == witness.digests[witness.digests.count - 2])
            let r: MushroomWeatherReport = play.report
            #expect(witness.report == MushroomWeatherWitnessReport(r))
            var released: Int = 0
            var evaporated: Int = 0
            for entry in r.ledger {
                released += entry.released
                evaporated += entry.evaporated
            }
            #expect(witness.report.start == r.ledger[0].before)
            #expect(witness.report.end == r.ledger[r.ledger.count - 1].after)
            #expect(witness.report.released == released)
            #expect(witness.report.evaporated == evaporated)
            #expect(witness.report.balances)
            #expect(witness.report.cycles == level.length)
            #expect(witness.report.colonies.count == level.colonies.count)
            for colony in witness.report.colonies {
                #expect(colony.finalRun >= level.required)
                #expect(colony.longestRun >= colony.finalRun)
            }
            #expect(MushroomWeatherSolver.replayWins(level, actions: Array(witness.actions.dropLast())))
        }
    }

    @Test("truncated JSON, a newer or older schema and missing keys are refused")
    func damagedBodiesRefused() {
        let w: MushroomWeatherWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let bytes: [UInt8] = Array(w.encoded())
        #expect(refusal(Data(bytes.prefix(bytes.count / 2))) == .witness("unreadable"))
        #expect(refusal(Data(bytes.prefix(bytes.count - 3))) == .witness("unreadable"))
        #expect(refusal(Data("not json".utf8)) == .witness("unreadable"))
        let newer: String = text.replacingOccurrences(of: "\n  \"schema\" : 1,\n", with: "\n  \"schema\" : 2,\n")
        #expect(newer != text)
        #expect(refusal(Data(newer.utf8)) == .newerSchema(2))
        #expect(refusal(Data(newer.utf8))?.reasonCode == "r02-g20.newer-schema")
        let zero: String = text.replacingOccurrences(of: "\n  \"schema\" : 1,\n", with: "\n  \"schema\" : 0,\n")
        #expect(refusal(Data(zero.utf8)) == .witness("schema 0"))
        let missing: String = text.replacingOccurrences(of: "\n  \"skipped\" : \(w.skipped)\n", with: "\n")
            .replacingOccurrences(of: ",\n}", with: "\n}")
        #expect(missing != text)
        #expect(refusal(Data(missing.utf8)) == .witness("unreadable"))
    }

    @Test("an edited digest, fingerprint, level, report, counterexample or difficulty is refused")
    func editedValuesRefused() throws {
        let w: MushroomWeatherWitness = fixtures.cases[0].witness
        let digestEdit: Data = try #require(oneCharacterChanged(w, after: "\"digests\" : [", inString: true))
        #expect(refusal(digestEdit) == .witness("digests"))
        let fingerprintEdit: Data = try #require(oneCharacterChanged(w, after: "\"fingerprints\" : [",
                                                                     inString: true))
        #expect(refusal(fingerprintEdit) == .witness("fingerprints"))
        let levelEdit: Data = try #require(oneCharacterChanged(w, after: "\"moldBound\" :", inString: false))
        #expect(refusal(levelEdit) == .witness("level"))
        let reportEdit: Data = try #require(oneCharacterChanged(w, after: "\"evaporated\" :", inString: false))
        #expect(refusal(reportEdit) == .witness("report"))
        let missEdit: Data = try #require(oneCharacterChanged(w, after: "\"nearestMiss\" :", inString: false))
        #expect(refusal(missEdit) == .witness("counterexample"))
        let bandEdit: Data = try #require(oneCharacterChanged(w, after: "\"narrowestBand\" :", inString: false))
        #expect(refusal(bandEdit) == .witness("difficulty"))
        var stale: [String] = w.digests
        stale[0] = "0000000000000000"
        #expect(refusal(edited(w, digests: stale).encoded()) == .witness("digests"))
        var other: [String] = w.fingerprints
        other[0] = other[1]
        #expect(refusal(edited(w, fingerprints: other).encoded()) == .witness("fingerprints"))
    }

    @Test("an edited action, or actions that no longer replay, are refused")
    func editedActionsRefused() throws {
        let w: MushroomWeatherWitness = fixtures.cases[0].witness
        let arrangementActions: [MushroomWeatherAction] = Array(w.actions.dropLast())
        // One character changed inside the actions: refused before, during or after the replay.
        let actionEdit: Data = try #require(oneCharacterChanged(w, after: "\"actions\" : [", inString: false))
        let reason: String = try #require(witnessReason(refusal(actionEdit)))
        #expect(reason == "actions" || reason.hasPrefix("replay ") || reason == "solution")
        // One action fewer plays without winning (the counterexample says nothing one action short wins).
        let shorter: [MushroomWeatherAction] = Array(arrangementActions.dropLast()) + [.run]
        #expect(refusal(edited(w, actions: shorter).encoded()) == .witness("replay not won"))
        // A repeated action is refused by the play as unchanged.
        let repeated: [MushroomWeatherAction] = [arrangementActions[0]] + w.actions
        #expect(refusal(edited(w, actions: repeated).encoded()) == .witness("replay r02-g20.action"))
        // Shape refusals before the replay.
        #expect(refusal(edited(w, actions: [.run]).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: arrangementActions).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.remove(slot: 0)] + w.actions).encoded()) == .witness("actions"))
        var offSite = MushroomWeatherCell(row: 0, column: 0)
        let sites: [MushroomWeatherCell] = w.level.sites ?? []
        while sites.contains(offSite) { offSite = MushroomWeatherCell(row: offSite.row, column: offSite.column + 1) }
        #expect(refusal(edited(w, actions: [.place(slot: 0, cell: offSite), .run]).encoded()) == .witness("actions"))
        // A placement on another site: no win, or a win that is not the solver's plan.
        var firstPlacement: (slot: Int, cell: MushroomWeatherCell)?
        for action in arrangementActions {
            if case .place(let slot, let cell) = action, firstPlacement == nil { firstPlacement = (slot, cell) }
        }
        let placement = try #require(firstPlacement)
        var used: [MushroomWeatherCell] = []
        for action in arrangementActions { if case .place(_, let cell) = action { used.append(cell) } }
        let spare: MushroomWeatherCell = try #require(sites.first { !used.contains($0) })
        var moved: [MushroomWeatherAction] = []
        for action in w.actions {
            if case .place(let slot, let cell) = action, slot == placement.slot, cell == placement.cell {
                moved.append(.place(slot: slot, cell: spare))
            } else {
                moved.append(action)
            }
        }
        let refused: String = try #require(witnessReason(refusal(edited(w, actions: moved).encoded())))
        #expect(refused == "replay not won" || refused == "solution")
    }
}
