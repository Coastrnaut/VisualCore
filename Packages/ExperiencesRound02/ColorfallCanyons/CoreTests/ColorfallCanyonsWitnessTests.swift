// ColorfallCanyonsWitnessTests — feature 342 (R02-G05-02) T-R02G0502-005 (FR-R02G0502-004; SC-R02G0502-003, 005;
// clarification Q4). Witnesses of generated catalog levels from bands 1 and 2 (cheap to generate and solve): level 1
// (with a tutorial), the first band-1 level whose smallest edit count is 1, the first whose count is 2, and level 21.
// The stored form round-trips byte for byte with one trailing newline; the actions have the canonical shape; digests,
// totals and fingerprints agree with a replay; the counterexamples fail as recorded and the near miss of a one-edit
// solution is the unedited run; edited actions, digests, totals, win tick, fingerprints, level, counterexamples,
// smaller count, difficulty, number and skipped are refused; newer and damaged stored forms are refused; `make` refuses
// a solution that does not win and a difficulty that is not the solution's. Explicit types, plain loops (CI type-check
// rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import ColorfallCanyonsCore

/// The generated levels and witnesses the tests share, built once.
struct ColorfallCanyonsWitnessFixtures: Sendable {
    /// Generated levels with their witnesses: level 1, the first band-1 levels needing one and two edits, level 21.
    let cases: [(generated: ColorfallCanyonsGenerated, witness: ColorfallCanyonsWitness)]
    /// The index in ``cases`` of a level whose smallest edit count is 1.
    let one: Int
    /// The index in ``cases`` of a level whose smallest edit count is at least 2.
    let many: Int

    static let shared: ColorfallCanyonsWitnessFixtures = make()

    private static func make() -> ColorfallCanyonsWitnessFixtures {
        var generated: [ColorfallCanyonsGenerated] = []
        var numbers: Set<Int> = []
        func add(_ entry: ColorfallCanyonsManifestEntry) -> ColorfallCanyonsGenerated {
            let level: ColorfallCanyonsGenerated
            do { level = try ColorfallCanyonsGenerator.generate(entry) } catch {
                preconditionFailure("level \(entry.number) does not generate: \(error)")
            }
            if numbers.insert(entry.number).inserted { generated.append(level) }
            return level
        }
        let entries: [ColorfallCanyonsManifestEntry] = ColorfallCanyonsManifest.entries
        _ = add(entries[0])
        var foundOne: Bool = false
        var foundMany: Bool = false
        for entry in entries where entry.band == 1 && !(foundOne && foundMany) {
            let level: ColorfallCanyonsGenerated = add(entry)
            if level.solution.smallest == 1 { foundOne = true } else { foundMany = true }
        }
        _ = add(entries[20])
        var cases: [(generated: ColorfallCanyonsGenerated, witness: ColorfallCanyonsWitness)] = []
        for level in generated {
            do { cases.append((level, try ColorfallCanyonsWitness.make(level))) } catch {
                preconditionFailure("level \(level.entry.number) has no witness: \(error)")
            }
        }
        let one: Int = cases.firstIndex { $0.generated.solution.smallest == 1 } ?? -1
        let many: Int = cases.firstIndex { $0.generated.solution.smallest >= 2 } ?? -1
        return ColorfallCanyonsWitnessFixtures(cases: cases, one: one, many: many)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct ColorfallCanyonsWitnessParts {
    var number: Int
    var level: ColorfallCanyonsLevel
    var actions: [ColorfallCanyonsAction]
    var winTick: Int
    var digests: [String]
    var totals: ColorfallCanyonsWitness.Totals
    var fingerprints: [String]
    var unedited: ColorfallCanyonsCounterexample
    var nearMiss: ColorfallCanyonsCounterexample
    var smaller: Int
    var difficulty: ColorfallCanyonsDifficulty
    var skipped: Int

    init(_ w: ColorfallCanyonsWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        winTick = w.winTick
        digests = w.digests
        totals = w.totals
        fingerprints = w.fingerprints
        unedited = w.unedited
        nearMiss = w.nearMiss
        smaller = w.smaller
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: ColorfallCanyonsWitness {
        ColorfallCanyonsWitness(number: number, level: level, actions: actions, winTick: winTick, digests: digests,
                                totals: totals, fingerprints: fingerprints, unedited: unedited, nearMiss: nearMiss,
                                smaller: smaller, difficulty: difficulty, skipped: skipped)
    }
}

@Suite("Colorfall Canyons witness")
struct ColorfallCanyonsWitnessTests {
    let fixtures: ColorfallCanyonsWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: ColorfallCanyonsWitness) -> ColorfallCanyonsError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> ColorfallCanyonsError? {
        do {
            _ = try ColorfallCanyonsWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: ColorfallCanyonsWitness,
                _ change: (inout ColorfallCanyonsWitnessParts) -> Void) -> ColorfallCanyonsWitness {
        var parts = ColorfallCanyonsWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: ColorfallCanyonsWitness, key: String, line: String?) -> Data {
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

    @Test("the fixtures cover one-edit and multi-edit levels and a tutorial")
    func fixturesCover() {
        #expect(fixtures.cases.count >= 3)
        #expect(fixtures.one >= 0)
        #expect(fixtures.many >= 0)
        #expect(fixtures.cases[0].generated.level.tutorial)
    }

    @Test("the stored form round-trips byte for byte with one trailing newline")
    func roundTripByteForByte() throws {
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: ColorfallCanyonsWitness = try ColorfallCanyonsWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            let text: String = String(decoding: data, as: UTF8.self)
            #expect(text.contains("\n  \"schema\" : 1,\n"))
        }
    }

    @Test("the actions are the solution's edits in solver order, then one step of the tick limit")
    func actionsAreCanonical() {
        for (generated, witness) in fixtures.cases {
            var expected: [ColorfallCanyonsAction] = []
            for edit in generated.solution.edits { expected.append(edit.action) }
            expected.append(.step(generated.level.tickLimit))
            #expect(witness.actions == expected)
            #expect(ColorfallCanyonsWitness.actions(for: generated.solution, level: generated.level) == expected)
            #expect(generated.solution.edits == generated.solution.edits.sorted())
            #expect(witness.number == generated.entry.number)
            #expect(witness.skipped == generated.skipped)
            #expect(witness.smaller == generated.solution.smaller)
            #expect(witness.difficulty == generated.difficulty)
        }
    }

    @Test("digests, totals, fingerprints and win tick agree with a replay")
    func partsAgreeWithReplay() throws {
        for (generated, witness) in fixtures.cases {
            #expect(witness.winTick == generated.solution.winTick)
            #expect(witness.digests.count == witness.winTick)
            for digest in witness.digests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
            var play = ColorfallCanyonsPlay(level: witness.level)
            try play.handle(.begin)
            if witness.level.tutorial { try play.handle(.dismissTutorial) }
            var fingerprints: [String] = [play.fingerprint]
            for action in witness.actions {
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
            }
            #expect(play.stage == .won)
            #expect(play.fluid.tick == witness.winTick)
            #expect(fingerprints == witness.fingerprints)
            #expect(witness.digests.last == ColorfallCanyonsWitness.digest(play.fluid))
            let totals: ColorfallCanyonsWitness.Totals = witness.totals
            #expect(totals == ColorfallCanyonsWitness.Totals(play.fluid))
            for c in 0..<3 { #expect(totals.released[c] == totals.held[c] + totals.spilled[c]) }
        }
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over two-byte big-endian masses")
    func digestLayout() {
        let level: ColorfallCanyonsLevel = fixtures.cases[0].generated.level
        let fluid = ColorfallCanyonsFluid(level: level)
        let zeros: [UInt8] = [UInt8](repeating: 0, count: level.cellCount * 6)
        #expect(ColorfallCanyonsWitness.digest(fluid) == String(StableHash.sha256Hex(zeros).prefix(16)))
    }

    @Test("the counterexamples fail as recorded")
    func counterexamplesFailAsRecorded() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.unedited.edits.isEmpty)
            #expect(witness.nearMiss.edits == Array(generated.solution.edits.dropLast()))
            for example in [witness.unedited, witness.nearMiss] {
                let run = ColorfallCanyonsSolver.run(witness.level, edits: example.edits)
                #expect(run?.verdict == .failed(example.reason))
                #expect(run?.tick == example.tick)
            }
        }
    }

    @Test("the near miss of a one-edit solution is the unedited counterexample")
    func nearMissOfOneEdit() {
        let one: ColorfallCanyonsWitness = fixtures.cases[fixtures.one].witness
        #expect(one.nearMiss == one.unedited)
        let many: ColorfallCanyonsWitness = fixtures.cases[fixtures.many].witness
        #expect(many.nearMiss.edits.count == many.actions.count - 2)
        #expect(!many.nearMiss.edits.isEmpty)
    }

    @Test("edited actions are refused")
    func editedActionsRefused() {
        let w: ColorfallCanyonsWitness = fixtures.cases[fixtures.many].witness
        let limit: Int = w.level.tickLimit
        let noStep = edited(w) { $0.actions.removeLast() }
        #expect(refusal(noStep) == .witness("actions"))
        if w.winTick < limit {
            let shorter = edited(w) { $0.actions[$0.actions.count - 1] = .step(limit - 1) }
            #expect(refusal(shorter) == .witness("actions"))
        }
        if w.actions[0] != w.actions[1] {
            let unsorted = edited(w) { $0.actions.swapAt(0, 1) }
            #expect(refusal(unsorted) == .witness("actions"))
        }
        let late = edited(w) { $0.actions.append($0.actions[0]) }
        #expect(refusal(late) == .witness("actions"))
        let missing = edited(w) { $0.actions.removeFirst() }
        #expect(refusal(missing) == .witness("replay"))
    }

    @Test("edited digests, totals and win tick are refused")
    func editedDigestsTotalsRefused() {
        let w: ColorfallCanyonsWitness = fixtures.cases[fixtures.one].witness
        let first: String = w.digests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.digests[0] = flipped }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.digests.removeLast() }) == .witness("digests"))
        let held: [Int] = w.totals.held
        let totals = ColorfallCanyonsWitness.Totals(released: w.totals.released, held: [held[0] + 1, held[1], held[2]],
                                                    spilled: w.totals.spilled)
        #expect(refusal(edited(w) { $0.totals = totals }) == .witness("totals"))
        #expect(refusal(edited(w) { $0.winTick += 1 }) == .witness("win-tick"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: ColorfallCanyonsWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
    }

    @Test("an edited level is refused")
    func editedLevelRefused() {
        let w: ColorfallCanyonsWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let rate: Int = w.level.flowRate
        let other: Int = rate == ColorfallCanyonsLevel.flowRates.upperBound ? rate - 1 : rate + 1
        let changed: String = text.replacingOccurrences(of: "\"flowRate\" : \(rate),",
                                                        with: "\"flowRate\" : \(other),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
    }

    @Test("edited counterexamples are refused")
    func editedCounterexamplesRefused() {
        let w: ColorfallCanyonsWitness = fixtures.cases[fixtures.many].witness
        let u: ColorfallCanyonsCounterexample = w.unedited
        let later = ColorfallCanyonsCounterexample(edits: u.edits, reason: u.reason, tick: u.tick + 1)
        #expect(refusal(edited(w) { $0.unedited = later }) == .witness("unedited"))
        let n: ColorfallCanyonsCounterexample = w.nearMiss
        let reason: ColorfallCanyonsFailure = n.reason == .time ? .overflow : .time
        let wrong = ColorfallCanyonsCounterexample(edits: n.edits, reason: reason, tick: n.tick)
        #expect(refusal(edited(w) { $0.nearMiss = wrong }) == .witness("near-miss"))
        let fewer = ColorfallCanyonsCounterexample(edits: [], reason: n.reason, tick: n.tick)
        #expect(refusal(edited(w) { $0.nearMiss = fewer }) == .witness("near-miss"))
    }

    @Test("edited difficulty, smaller count, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: ColorfallCanyonsWitness = fixtures.cases[fixtures.one].witness
        let d: ColorfallCanyonsDifficulty = w.difficulty
        let work = ColorfallCanyonsDifficulty(smallest: d.smallest, work: d.work + 1, winTick: d.winTick,
                                              springs: d.springs, basins: d.basins,
                                              protectedBasins: d.protectedBasins, carvableCells: d.carvableCells)
        #expect(refusal(edited(w) { $0.difficulty = work }) == .witness("difficulty"))
        let cells = ColorfallCanyonsDifficulty(smallest: d.smallest, work: d.work, winTick: d.winTick,
                                               springs: d.springs, basins: d.basins,
                                               protectedBasins: d.protectedBasins, carvableCells: d.carvableCells - 1)
        #expect(refusal(edited(w) { $0.difficulty = cells }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.smaller += 1 }) == .witness("smaller"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = ColorfallCanyonsGenerator.maximumCandidates }) == .witness("skipped"))
    }

    @Test("a winning edit set that is not the solver's first smallest one is refused")
    func notSmallestRefused() {
        let w: ColorfallCanyonsWitness = fixtures.cases[fixtures.one].witness
        guard case .carve(let cell) = w.actions[0] else { return }
        // Carving the winning cell twice may still win; then it is not the smallest set, and its near miss (the
        // one-edit solution) wins too.
        var actions: [ColorfallCanyonsAction] = [.carve(cell)]
        actions.append(contentsOf: w.actions)
        let doubled = edited(w) { $0.actions = actions }
        let error: ColorfallCanyonsError? = refusal(doubled)
        #expect(error != nil)
        if let run = ColorfallCanyonsSolver.run(w.level, edits: [.carve(cell), .carve(cell)]), run.verdict == .won {
            #expect(error == .witness("near-miss") || error == .witness("difficulty"))
        }
    }

    @Test("newer and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: ColorfallCanyonsWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .malformed("schema 0"))
        #expect(refusal(storedText(w, key: "smaller", line: nil)) == .malformed("unreadable"))
        #expect(refusal(storedText(w, key: "digests", line: "\"none\"")) == .malformed("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .malformed("unreadable"))
        #expect(refusal(Data()) == .malformed("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .malformed("unreadable"))
    }

    @Test("make refuses a solution that does not win and a difficulty that is not the solution's")
    func makeRefuses() {
        let g: ColorfallCanyonsGenerated = fixtures.cases[fixtures.one].generated
        let none = ColorfallCanyonsSolution(edits: [], work: g.solution.work, smaller: 0, winTick: g.solution.winTick)
        let losing = ColorfallCanyonsGenerated(entry: g.entry, level: g.level, planted: g.planted, solution: none,
                                               difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: ColorfallCanyonsError.witness("replay")) { try ColorfallCanyonsWitness.make(losing) }
        let d: ColorfallCanyonsDifficulty = g.difficulty
        let other = ColorfallCanyonsDifficulty(smallest: d.smallest, work: d.work, winTick: d.winTick,
                                               springs: d.springs, basins: d.basins + 1,
                                               protectedBasins: d.protectedBasins, carvableCells: d.carvableCells)
        let wrong = ColorfallCanyonsGenerated(entry: g.entry, level: g.level, planted: g.planted, solution: g.solution,
                                              difficulty: other, skipped: g.skipped)
        #expect(throws: ColorfallCanyonsError.witness("difficulty")) { try ColorfallCanyonsWitness.make(wrong) }
    }
}
