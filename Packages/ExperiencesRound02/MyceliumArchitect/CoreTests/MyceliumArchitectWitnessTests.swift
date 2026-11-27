// MyceliumArchitectWitnessTests — feature 512 (R02-G22-02) T-R02G2202-006 (FR-R02G2202-004; SC-R02G2202-003;
// clarification Q5; research R6), on the rule kernel of feature 511 (R02-G22-01), modelled on BinaryGardensWitnessTests
// (feature 502). Witnesses of generated levels 1 (band 1, tutorial), 21 (band 2) and 41 (band 3), each generated with
// no previous level, built once per process. The stored form round-trips byte for byte with sorted keys and one
// trailing newline, the level nested in its own stored form; encoding is deterministic and equal witnesses give equal
// bytes; verify passes; the state digest is the first 16 hex characters of SHA-256 over the canonical arrangement and
// actions-spent text (checked against known values); digests, fingerprints and the terminal report agree with an
// independent replay; the counterexample is the solver's count at the depth one below the plan with its nearest miss,
// which fails as stored; damaged JSON, a newer or older schema, one changed character, an edited action and a swapped
// digest are refused with their named reasons. Explicit types, plain loops (CI type-check rule), short runs, no
// wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import MyceliumArchitectCore

/// The generated levels and witnesses the tests share, built once.
struct MyceliumArchitectWitnessFixtures: Sendable {
    /// Generated levels with their witnesses: levels 1, 21 and 41, each generated with no previous level.
    let cases: [(generated: MyceliumArchitectGeneratedLevel, witness: MyceliumArchitectWitness)]

    static let shared: MyceliumArchitectWitnessFixtures = make()

    /// The generated level (with no previous level) and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int) -> (generated: MyceliumArchitectGeneratedLevel, witness: MyceliumArchitectWitness) {
        let entry: MyceliumArchitectManifestEntry = MyceliumArchitectManifest.entries[index]
        let generated: MyceliumArchitectGeneratedLevel
        do { generated = try MyceliumArchitectGenerator.generate(entry, previous: nil) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        return (generated, MyceliumArchitectWitness(generated: generated))
    }

    private static func make() -> MyceliumArchitectWitnessFixtures {
        var cases: [(generated: MyceliumArchitectGeneratedLevel, witness: MyceliumArchitectWitness)] = []
        for index in [0, 20, 40] { cases.append(pair(index)) }
        return MyceliumArchitectWitnessFixtures(cases: cases)
    }
}

@Suite struct MyceliumArchitectWitnessTests {
    let fixtures: MyceliumArchitectWitnessFixtures = .shared

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> MyceliumArchitectError? {
        do {
            _ = try MyceliumArchitectWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// The payload of a `.witness` refusal, or nil for any other outcome.
    func witnessReason(_ error: MyceliumArchitectError?) -> String? {
        if case .witness(let reason) = error { return reason }
        return nil
    }

    /// `w` with other actions, digests, fingerprints, skipped count or number, through the unchecked initializer.
    func edited(_ w: MyceliumArchitectWitness, actions: [MyceliumArchitectAction]? = nil, digests: [String]? = nil,
                fingerprints: [String]? = nil, skipped: Int? = nil,
                number: Int? = nil) -> MyceliumArchitectWitness {
        MyceliumArchitectWitness(number: number ?? w.number, level: w.level, actions: actions ?? w.actions,
                                 digests: digests ?? w.digests, fingerprints: fingerprints ?? w.fingerprints,
                                 report: w.report, counterexample: w.counterexample, difficulty: w.difficulty,
                                 skipped: skipped ?? w.skipped)
    }

    /// The stored form of `w` with one character changed: the last digit of the first number after `marker` (a
    /// JSON value preceded by a space, or any digit inside a string when `inString`) becomes the next digit mod 10.
    func oneCharacterChanged(_ w: MyceliumArchitectWitness, after marker: String, inString: Bool) -> Data? {
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

    @Test("the fixtures cover a tutorial, bands 1, 2 and 3 and their plan lengths; verify passes")
    func fixturesCoverAndVerify() throws {
        #expect(fixtures.cases.count == 3)
        var bands: [Int] = []
        var lengths: [Int] = []
        for (generated, witness) in fixtures.cases {
            bands.append(generated.entry.band)
            lengths.append(witness.actions.count - 1)
            try witness.verify()
        }
        #expect(bands == [1, 2, 3])
        #expect(lengths == [1, 2, 3])
        #expect(fixtures.cases[0].witness.level.tutorial)
        #expect(!fixtures.cases[1].witness.level.tutorial)
        #expect(!fixtures.cases[2].witness.level.tutorial)
        #expect(MyceliumArchitectWitness.schema == 1)
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
            let decoded: MyceliumArchitectWitness = try MyceliumArchitectWitness.decode(data)
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
            // The nested level is the level's own stored form, fingerprint included.
            #expect(text.contains("\"fingerprint\" : \"\(witness.level.fingerprint)\""))
            #expect(text.contains("\"run\" : {"))
            #expect(text.contains("\"arrangements\" : \(witness.counterexample.arrangements)"))
            #expect(text.contains("\"failureWords\" : \""))
            #expect(text.contains("\"firstToxic\" : null"))
            #expect(text.contains("\"outcome\" : \"won\""))
        }
    }

    @Test("encoding is deterministic: a witness built again gives the same bytes")
    func encodingIsDeterministic() {
        for (generated, witness) in fixtures.cases {
            let again = MyceliumArchitectWitness(generated: generated)
            #expect(again == witness)
            #expect(again.encoded() == witness.encoded())
        }
    }

    @Test("the counterexample, difficulty and provenance are the solver's and the generator's")
    func partsAreTheSolutions() throws {
        for (generated, witness) in fixtures.cases {
            let solution: MyceliumArchitectSolution = generated.solution
            let level: MyceliumArchitectLevel = witness.level
            #expect(witness.number == generated.entry.number)
            #expect(level == generated.level)
            #expect(witness.actions == solution.actions)
            #expect(witness.actions.count - 1 <= level.budget)
            let length: Int = solution.length
            let c: MyceliumArchitectCounterexample = witness.counterexample
            #expect(c.depth == length - 1)
            #expect(c.arrangements == solution.countsByDepth[length - 1])
            #expect(c.arrangements >= 1)
            #expect(c.nearestMiss == solution.nearestMissLoss)
            #expect(c.arrangement == solution.nearestMiss)
            let missReport: MyceliumArchitectReport = MyceliumArchitectGrowth.report(level, arrangement: c.arrangement)
            #expect(!missReport.wins)
            #expect(missReport.failure == c.failure)
            #expect(MyceliumArchitectSolver.loss(level, missReport) == c.nearestMiss)
            #expect(c.failureWords == level.failureDescription(c.failure))
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.difficulty.nearestMiss == c.nearestMiss)
            #expect(witness.difficulty.witnessLength == length)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("the canonical text lists nutrients, blockers, seeds and spent; the digest has known values")
    func digestDefinition() {
        let one = MyceliumArchitectArrangement(nutrients: [MyceliumArchitectCell(column: 3, row: 4)], blockers: [],
                                               seeds: [.north, .east])
        let none = MyceliumArchitectArrangement(nutrients: [], blockers: [], seeds: [.south])
        let two = MyceliumArchitectArrangement(nutrients: [MyceliumArchitectCell(column: 5, row: 6),
                                                           MyceliumArchitectCell(column: 1, row: 2)],
                                               blockers: [MyceliumArchitectCell(column: 7, row: 1)],
                                               seeds: [.southEast, .northEast])
        #expect(MyceliumArchitectWitness.canonicalText(arrangement: one, spent: 2)
                == "nutrients=[3,4];blockers=;seeds=0,2;spent=2")
        #expect(MyceliumArchitectWitness.canonicalText(arrangement: none, spent: 0)
                == "nutrients=;blockers=;seeds=4;spent=0")
        #expect(MyceliumArchitectWitness.canonicalText(arrangement: two, spent: 4)
                == "nutrients=[1,2],[5,6];blockers=[7,1];seeds=1,3;spent=4")
        // Known values: `printf '<text>' | shasum -a 256`, first 16 characters.
        #expect(MyceliumArchitectWitness.digest(arrangement: one, spent: 2) == "3e2c78712a6d9693")
        #expect(MyceliumArchitectWitness.digest(arrangement: none, spent: 0) == "6181a5723f4a5656")
        #expect(MyceliumArchitectWitness.digest(arrangement: two, spent: 4) == "544ce828b2a0508e")
        for (_, witness) in fixtures.cases {
            #expect(witness.digests.count == witness.actions.count)
            for value in witness.digests { #expect(value.count == 16) }
        }
    }

    @Test("state digests, fingerprints and the terminal report agree with an independent replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: MyceliumArchitectLevel = witness.level
            var play = MyceliumArchitectPlay(level: level)
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
                let text: String = MyceliumArchitectWitness.canonicalText(arrangement: play.arrangement,
                                                                          spent: play.actionsSpent)
                digests.append(String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(fingerprints.count == witness.actions.count + (level.tutorial ? 2 : 1))
            #expect(digests == witness.digests)
            // The run spends nothing: the last two digests are equal.
            #expect(witness.digests[witness.digests.count - 1] == witness.digests[witness.digests.count - 2])
            let r: MyceliumArchitectReport = play.report
            let stored: MyceliumArchitectWitnessReport = witness.report
            #expect(stored == MyceliumArchitectWitnessReport(level: level, report: r))
            #expect(stored.outcome == "won")
            #expect(stored.firstToxic == nil)
            #expect(stored.totalWeight == r.totalWeight)
            #expect(stored.totalWeight <= stored.weightLimit)
            #expect(stored.weightLimit <= stored.nutrientBudget)
            #expect(stored.nutrientBudget == level.nutrientBudget)
            #expect(stored.nodeCount == r.grown.count)
            #expect(stored.terminals.count == level.terminals.count)
            for terminal in stored.terminals {
                #expect(terminal.cell == level.terminals[terminal.index])
                #expect(terminal.pulse != nil)
                #expect(terminal.pathWeight != nil)
                #expect(terminal.pulse == r.terminalPulses[terminal.index])
                #expect(terminal.pathWeight == r.terminalPathWeights[terminal.index])
            }
        }
    }

    @Test("damaged JSON, a newer or older schema and a missing key are refused")
    func damagedBodiesRefused() {
        let w: MyceliumArchitectWitness = fixtures.cases[0].witness
        let data: Data = w.encoded()
        let text: String = String(decoding: data, as: UTF8.self)
        let bytes: [UInt8] = Array(data)
        #expect(refusal(Data(bytes.prefix(bytes.count / 2))) == .malformed("unreadable"))
        #expect(refusal(Data(bytes.prefix(bytes.count - 3))) == .malformed("unreadable"))
        #expect(refusal(Data("not json".utf8)) == .malformed("unreadable"))
        let newer: String = text.replacingOccurrences(of: "\n  \"schema\" : 1,\n", with: "\n  \"schema\" : 2,\n")
        #expect(newer != text)
        #expect(refusal(Data(newer.utf8)) == .newerSchema(2))
        #expect(refusal(Data(newer.utf8))?.reasonCode == "r02-g22.newer-schema")
        let zero: String = text.replacingOccurrences(of: "\n  \"schema\" : 1,\n", with: "\n  \"schema\" : 0,\n")
        #expect(refusal(Data(zero.utf8)) == .malformed("schema 0"))
        let missing: String = text.replacingOccurrences(of: "\n  \"skipped\" : \(w.skipped)\n", with: "\n")
            .replacingOccurrences(of: ",\n}", with: "\n}")
        #expect(missing != text)
        #expect(refusal(Data(missing.utf8)) == .malformed("unreadable"))
        #expect(refusal(Data(missing.utf8))?.reasonCode == "r02-g22.malformed")
    }

    @Test("one changed character in a digest, the level, the report, the counterexample or the difficulty is refused")
    func oneCharacterRefused() throws {
        let w: MyceliumArchitectWitness = fixtures.cases[1].witness
        let digestEdit: Data = try #require(oneCharacterChanged(w, after: "\"digests\" : [", inString: true))
        #expect(refusal(digestEdit) == .witness("digests"))
        #expect(refusal(digestEdit)?.reasonCode == "r02-g22.witness")
        let fingerprintEdit: Data = try #require(oneCharacterChanged(w, after: "\"fingerprints\" : [",
                                                                     inString: true))
        #expect(refusal(fingerprintEdit) == .witness("fingerprints"))
        let levelEdit: Data = try #require(oneCharacterChanged(w, after: "\"strength\" :", inString: false))
        #expect(refusal(levelEdit) == .malformed("level"))
        let reportEdit: Data = try #require(oneCharacterChanged(w, after: "\"pathWeight\" :", inString: false))
        #expect(refusal(reportEdit) == .witness("report"))
        let nodeEdit: Data = try #require(oneCharacterChanged(w, after: "\"nodeCount\" :", inString: false))
        #expect(refusal(nodeEdit) == .witness("report"))
        let missEdit: Data = try #require(oneCharacterChanged(w, after: "\"arrangements\" :", inString: false))
        #expect(refusal(missEdit) == .witness("counterexample"))
        let workEdit: Data = try #require(oneCharacterChanged(w, after: "\"work\" :", inString: false))
        #expect(refusal(workEdit) == .witness("difficulty"))
        let moveEdit: Data = try #require(oneCharacterChanged(w, after: "\"moveSpace\" :", inString: false))
        #expect(refusal(moveEdit) == .witness("difficulty"))
    }

    @Test("a swapped digest, an edited fingerprint and another provenance are refused")
    func swappedDigestAndProvenanceRefused() {
        let w: MyceliumArchitectWitness = fixtures.cases[1].witness
        var swapped: [String] = w.digests
        swapped.swapAt(0, swapped.count - 1)
        #expect(swapped != w.digests)
        #expect(refusal(edited(w, digests: swapped).encoded()) == .witness("digests"))
        var stale: [String] = w.digests
        stale[0] = "0000000000000000"
        #expect(refusal(edited(w, digests: stale).encoded()) == .witness("digests"))
        var other: [String] = w.fingerprints
        other[0] = other[1]
        #expect(refusal(edited(w, fingerprints: other).encoded()) == .witness("fingerprints"))
        #expect(refusal(edited(w, number: w.number + 1).encoded()) == .witness("number"))
        #expect(refusal(edited(w, number: 0).encoded()) == .witness("number"))
        #expect(refusal(edited(w, skipped: MyceliumArchitectGenerator.candidateBound).encoded())
                    == .witness("skipped"))
        #expect(refusal(edited(w, skipped: -1).encoded()) == .witness("skipped"))
        let otherCandidate: Int = w.skipped == 0 ? 1 : 0
        #expect(refusal(edited(w, skipped: otherCandidate).encoded()) == .witness("candidate"))
    }

    @Test("an edited action, or actions that no longer replay, are refused")
    func editedActionsRefused() throws {
        let w: MyceliumArchitectWitness = fixtures.cases[1].witness
        let level: MyceliumArchitectLevel = w.level
        let arrangementActions: [MyceliumArchitectAction] = Array(w.actions.dropLast())
        #expect(arrangementActions.count == 2)
        // One action fewer plays without winning (the counterexample says nothing one action short wins).
        let shorter: [MyceliumArchitectAction] = Array(arrangementActions.dropLast()) + [.run]
        #expect(refusal(edited(w, actions: shorter).encoded()) == .witness("replay not won"))
        // A repeated action is refused by the play.
        let repeated: [MyceliumArchitectAction] = [arrangementActions[0]] + w.actions
        #expect(refusal(edited(w, actions: repeated).encoded()) == .witness("replay r02-g22.action"))
        // Shape refusals before the replay: no arrangement action, no run, a run inside, a clear or an unseed.
        let cell: MyceliumArchitectCell = level.root
        #expect(refusal(edited(w, actions: [.run]).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: arrangementActions).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.run] + w.actions).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.clear(cell), .run]).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.unseed(.north), .run]).encoded()) == .witness("actions"))
        let tooMany: [MyceliumArchitectAction] = Array(repeating: arrangementActions[0], count: level.budget + 1)
            + [.run]
        #expect(refusal(edited(w, actions: tooMany).encoded()) == .witness("actions"))
        // The same actions in the other order may win but are not the solver's plan; a refused order names the play.
        var reordered: [MyceliumArchitectAction] = arrangementActions
        reordered.swapAt(0, 1)
        if reordered != arrangementActions {
            let reason: String = try #require(witnessReason(refusal(edited(w, actions: reordered + [.run]).encoded())))
            #expect(reason == "solution" || reason == "digests" || reason.hasPrefix("replay "))
        }
    }
}
