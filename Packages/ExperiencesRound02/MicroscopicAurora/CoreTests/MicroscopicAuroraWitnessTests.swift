// MicroscopicAuroraWitnessTests — feature 482 (R02-G19-02) T-R02G1902-005 (FR-R02G1902-004; SC-R02G1902-003, 005;
// clarification Q4), on the rule kernel of feature 481 (R02-G19-01), modelled on ApsidesWorkshopWitnessTests (feature
// 472). Witnesses of generated levels 1, 2 and 3 (band 1, tutorials, each generated after the one before) and of level
// 41 (band 3, two placements, generated with no previous level), built once per process. The stored form round-trips
// byte for byte with sorted keys and one trailing newline; equal makes give equal bytes; the state digest is the first
// 16 hex characters of SHA-256 over the canonical wells and actions-spent text (checked against known values);
// digests, fingerprints and the terminal report agree with an independent replay; the counterexample is the solver's
// sets at the depth one below the plan and its nearest miss; one changed character, a newer schema, a damaged body, an
// edited level and actions that no longer win are refused with `r02-g19.witness`. Explicit types, plain loops (CI
// type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import MicroscopicAuroraCore

/// The generated levels and witnesses the tests share, built once.
struct MicroscopicAuroraWitnessFixtures: Sendable {
    /// Generated levels with their witnesses: levels 1, 2, 3 (chained) and 41.
    let cases: [(generated: MicroscopicAuroraGenerated, witness: MicroscopicAuroraWitness)]

    static let shared: MicroscopicAuroraWitnessFixtures = make()

    /// The generated level (after `previous`) and witness of manifest entry `index` (0-based).
    static func pair(_ index: Int, previous: MicroscopicAuroraLevel?)
        -> (generated: MicroscopicAuroraGenerated, witness: MicroscopicAuroraWitness) {
        let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[index]
        let generated: MicroscopicAuroraGenerated
        do { generated = try MicroscopicAuroraGenerator.generate(entry, previous: previous) } catch {
            preconditionFailure("level \(entry.number) does not generate: \(error)")
        }
        do { return (generated, try MicroscopicAuroraWitness.make(generated)) } catch {
            preconditionFailure("level \(entry.number) has no witness: \(error)")
        }
    }

    private static func make() -> MicroscopicAuroraWitnessFixtures {
        var cases: [(generated: MicroscopicAuroraGenerated, witness: MicroscopicAuroraWitness)] = []
        var previous: MicroscopicAuroraLevel?
        for index in 0..<3 {
            let next = pair(index, previous: previous)
            cases.append(next)
            previous = next.generated.level
        }
        cases.append(pair(40, previous: nil))
        return MicroscopicAuroraWitnessFixtures(cases: cases)
    }
}

@Suite struct MicroscopicAuroraWitnessTests {
    let fixtures: MicroscopicAuroraWitnessFixtures = .shared

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    func refusal(_ data: Data) -> MicroscopicAuroraError? {
        do {
            _ = try MicroscopicAuroraWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `w` with other actions, digests or report, through the unchecked initializer.
    func edited(_ w: MicroscopicAuroraWitness, actions: [MicroscopicAuroraAction]? = nil, digests: [String]? = nil,
                report: MicroscopicAuroraWitnessReport? = nil) -> MicroscopicAuroraWitness {
        MicroscopicAuroraWitness(number: w.number, level: w.level, actions: actions ?? w.actions,
                                 digests: digests ?? w.digests, fingerprints: w.fingerprints,
                                 report: report ?? w.report, counterexample: w.counterexample,
                                 difficulty: w.difficulty, skipped: w.skipped)
    }

    /// The stored form of `w` with one character changed: the last digit of the first number after `marker` (a
    /// JSON value preceded by a space, or any digit inside a string when `inString`) becomes the next digit mod 10.
    func oneCharacterChanged(_ w: MicroscopicAuroraWitness, after marker: String, inString: Bool) -> Data? {
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

    @Test("the fixtures cover tutorials, band 1 and a two-placement band-3 plan")
    func fixturesCover() {
        #expect(fixtures.cases.count == 4)
        var bands: [Int] = []
        for (generated, _) in fixtures.cases { bands.append(generated.entry.band) }
        #expect(bands == [1, 1, 1, 3])
        for index in 0..<3 { #expect(fixtures.cases[index].witness.level.tutorial) }
        #expect(!fixtures.cases[3].witness.level.tutorial)
        #expect(fixtures.cases[3].witness.actions.count == 3)
        #expect(fixtures.cases[0].witness.actions.count == 2)
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
            let decoded: MicroscopicAuroraWitness = try MicroscopicAuroraWitness.decode(data)
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
            #expect(text.contains("\"play\" : {"))
            #expect(text.contains("\"nearestMiss\" : \(witness.counterexample.nearestMiss)"))
            #expect(text.contains("\"smallestCoherenceTick\" : \(witness.report.smallestCoherenceTick)"))
        }
    }

    @Test("equal makes give equal bytes; the parts are the solver's")
    func partsAreTheSolvers() throws {
        for (generated, witness) in fixtures.cases {
            let again: MicroscopicAuroraWitness = try MicroscopicAuroraWitness.make(generated)
            #expect(again.encoded() == witness.encoded())
            let plan: MicroscopicAuroraPlan = generated.plan
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.actions == plan.actions + [.play])
            #expect(witness.actions.count - 1 <= witness.level.budget)
            let expected = MicroscopicAuroraCounterexample(depth: plan.size - 1, sets: plan.setsByDepth[plan.size - 1],
                                                           nearestMiss: plan.nearestMiss)
            #expect(witness.counterexample == expected)
            #expect(witness.counterexample.sets >= 1)
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.skipped == generated.skipped)
            #expect(witness.report.groups == 1)
            #expect(witness.report.ticks == witness.level.length)
        }
        // Band 1 plans have one placement: depth 0 is no well, one set judged.
        #expect(fixtures.cases[0].witness.counterexample.depth == 0)
        #expect(fixtures.cases[0].witness.counterexample.sets == 1)
        let sites: [MicroscopicAuroraCell] = fixtures.cases[3].witness.level.sites ?? []
        let depthOne: Int = MicroscopicAuroraSolver.sets(sites: sites, size: 1).count
        #expect(fixtures.cases[3].witness.counterexample.depth == 1)
        #expect(fixtures.cases[3].witness.counterexample.sets == depthOne)
    }

    @Test("the canonical text lists the three slots and the digest has known values")
    func digestDefinition() {
        let a = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 9, column: 14), strength: 3, sense: .clockwise)
        let b = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 4, column: 7), strength: 1,
                                      sense: .counterclockwise)
        let c = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 12, column: 3), strength: 4, sense: .clockwise)
        let one: [MicroscopicAuroraWell?] = [a, nil, nil]
        let none: [MicroscopicAuroraWell?] = [nil, nil, nil]
        let two: [MicroscopicAuroraWell?] = [b, c, nil]
        #expect(MicroscopicAuroraWitness.canonicalText(wells: one, spent: 1)
                == "wells=9 14 3 clockwise,none,none;spent=1")
        #expect(MicroscopicAuroraWitness.canonicalText(wells: none, spent: 0) == "wells=none,none,none;spent=0")
        #expect(MicroscopicAuroraWitness.canonicalText(wells: two, spent: 2)
                == "wells=4 7 1 counterclockwise,12 3 4 clockwise,none;spent=2")
        // Known values: `printf '<text>' | shasum -a 256`, first 16 characters.
        #expect(MicroscopicAuroraWitness.digest(wells: one, spent: 1) == "9c95d3af4833aba3")
        #expect(MicroscopicAuroraWitness.digest(wells: none, spent: 0) == "fa4c09001e00f714")
        #expect(MicroscopicAuroraWitness.digest(wells: two, spent: 2) == "65ab7cd305ec3599")
        for (_, witness) in fixtures.cases {
            for value in witness.digests { #expect(value.count == 16) }
        }
    }

    @Test("state digests, fingerprints and the terminal report agree with an independent replay")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            let level: MicroscopicAuroraLevel = witness.level
            var play = MicroscopicAuroraPlay(level: level)
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
                let text: String = MicroscopicAuroraWitness.canonicalText(wells: play.wells, spent: play.actionsSpent)
                digests.append(String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
            }
            #expect(play.stage == .won)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
            // The play spends nothing: the last two digests are equal.
            #expect(witness.digests[witness.digests.count - 1] == witness.digests[witness.digests.count - 2])
            let r: MicroscopicAuroraReport = play.report
            #expect(witness.report == MicroscopicAuroraWitnessReport(r))
            #expect(witness.report.litStencil == r.litStencil)
            #expect(witness.report.coverage == r.coverage)
            #expect(witness.report.coverage >= level.coverage)
            #expect(witness.report.smallestCoherence >= level.coherence)
            #expect(MicroscopicAuroraSolver.replayWins(level, actions: Array(witness.actions.dropLast())))
        }
    }

    @Test("a one-character edit, a newer schema, a damaged body and an edited level are refused")
    func damagedFormsRefused() throws {
        let w: MicroscopicAuroraWitness = fixtures.cases[0].witness
        let digestEdit: Data = try #require(oneCharacterChanged(w, after: "\"digests\" : [", inString: true))
        #expect(refusal(digestEdit) == .witness("digests"))
        let coverageEdit: Data = try #require(oneCharacterChanged(w, after: "\"report\" : {", inString: false))
        #expect(refusal(coverageEdit)?.reasonCode == "r02-g19.witness")
        let missEdit: Data = try #require(oneCharacterChanged(w, after: "\"nearestMiss\" :", inString: false))
        #expect(refusal(missEdit) == .witness("counterexample"))
        let levelEdit: Data = try #require(oneCharacterChanged(w, after: "\"threshold\" :", inString: false))
        #expect(refusal(levelEdit) == .witness("level"))
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let newer: String = text.replacingOccurrences(of: "\n  \"schema\" : 1,\n", with: "\n  \"schema\" : 2,\n")
        #expect(refusal(Data(newer.utf8)) == .witness("schema 2"))
        let zero: String = text.replacingOccurrences(of: "\n  \"schema\" : 1,\n", with: "\n  \"schema\" : 0,\n")
        #expect(refusal(Data(zero.utf8)) == .witness("schema 0"))
        let bytes: [UInt8] = Array(w.encoded())
        #expect(refusal(Data(bytes.prefix(bytes.count / 2))) == .witness("unreadable"))
        #expect(refusal(Data("not json".utf8)) == .witness("unreadable"))
        let missing: String = text.replacingOccurrences(of: "\n  \"skipped\" : \(w.skipped)\n", with: "\n")
            .replacingOccurrences(of: ",\n}", with: "\n}")
        #expect(refusal(Data(missing.utf8)) == .witness("unreadable"))
        var stale: [String] = w.digests
        stale[0] = "0000000000000000"
        #expect(refusal(edited(w, digests: stale).encoded()) == .witness("digests"))
        let r: MicroscopicAuroraWitnessReport = w.report
        let report = MicroscopicAuroraWitnessReport(litStencil: r.litStencil, coverage: r.coverage, groups: r.groups,
                                                    smallestCoherence: r.smallestCoherence,
                                                    smallestCoherenceTick: r.smallestCoherenceTick, ticks: r.ticks + 1)
        #expect(refusal(edited(w, report: report).encoded()) == .witness("report"))
    }

    @Test("a witness whose actions no longer win is refused")
    func actionsThatNoLongerWinRefused() throws {
        let w: MicroscopicAuroraWitness = fixtures.cases[3].witness
        let placements: [MicroscopicAuroraAction] = Array(w.actions.dropLast())
        // One placement fewer plays without winning (the counterexample says no set of one well wins).
        let shorter: [MicroscopicAuroraAction] = [placements[0], .play]
        #expect(refusal(edited(w, actions: shorter).encoded()) == .witness("replay"))
        #expect(refusal(edited(w, actions: [.play]).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: placements).encoded()) == .witness("actions"))
        #expect(refusal(edited(w, actions: [.remove(slot: 0)] + w.actions).encoded()) == .witness("actions"))
        // Another strength on the last well: no win, or a win that is not the solver's plan.
        guard case .place(let slot, let well) = placements[placements.count - 1] else {
            Issue.record("the last witness action is not a placement")
            return
        }
        let strength: Int = well.strength % 4 + 1
        let other = MicroscopicAuroraWell(cell: well.cell, strength: strength, sense: well.sense)
        let changed: [MicroscopicAuroraAction] = [placements[0], .place(slot: slot, well: other), .play]
        let refused: MicroscopicAuroraError? = refusal(edited(w, actions: changed).encoded())
        #expect(refused == .witness("replay") || refused == .witness("solution"))
        #expect(refused?.reasonCode == "r02-g19.witness")
        // A well off the level's sites is refused before the replay.
        var offSite = MicroscopicAuroraCell(row: 11, column: 11)
        let sites: [MicroscopicAuroraCell] = w.level.sites ?? []
        while sites.contains(offSite) { offSite = MicroscopicAuroraCell(row: offSite.row, column: offSite.column + 1) }
        let stray = MicroscopicAuroraWell(cell: offSite, strength: 1, sense: .clockwise)
        #expect(refusal(edited(w, actions: [.place(slot: 0, well: stray), .play]).encoded()) == .witness("actions"))
    }
}
