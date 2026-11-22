// FacetedForgeWitnessTests — feature 372 (R02-G08-02) T-R02G0802-005 (FR-R02G0802-004; SC-R02G0802-003, 005;
// clarification Q4). Witnesses of generated catalog levels 1, 21 and 41 (level 1 has a tutorial), built once per
// process. The stored form round-trips byte for byte with one trailing newline; the cuts are the solver's; digests and
// fingerprints agree with a replay; the near miss replays as recorded (not won, one piece short); edited cuts, digests,
// fingerprints, level, solver values, near miss, difficulty, number and skipped are refused naming the part; newer and
// damaged stored forms are refused; `make` refuses a solution that does not win and a difficulty that is not the
// solution's. Explicit types, plain loops (CI type-check rule), short runs, no wall-clock asserts.
import Foundation
import Testing
import VisualCoreMath
@testable import FacetedForgeCore

/// The generated levels and witnesses the tests share, built once.
struct FacetedForgeWitnessFixtures: Sendable {
    /// Generated levels with their witnesses, in manifest order.
    let cases: [(generated: FacetedForgeGenerated, witness: FacetedForgeWitness)]

    static let shared: FacetedForgeWitnessFixtures = make()

    private static func make() -> FacetedForgeWitnessFixtures {
        let entries: [FacetedForgeManifestEntry] = FacetedForgeManifest.entries
        var cases: [(generated: FacetedForgeGenerated, witness: FacetedForgeWitness)] = []
        for index in [0, 20, 40] {
            let generated: FacetedForgeGenerated
            do { generated = try FacetedForgeGenerator.generate(entries[index]) } catch {
                preconditionFailure("level \(entries[index].number) does not generate: \(error)")
            }
            do { cases.append((generated, try FacetedForgeWitness.make(generated))) } catch {
                preconditionFailure("level \(generated.entry.number) has no witness: \(error)")
            }
        }
        return FacetedForgeWitnessFixtures(cases: cases)
    }
}

/// A witness with some stored values changed, through the unchecked initializer.
struct FacetedForgeWitnessParts {
    var number: Int
    var level: FacetedForgeLevel
    var actions: [FacetedForgeAction]
    var digests: [String]
    var fingerprints: [String]
    var smallest: Int
    var lowerBound: Int
    var nearMiss: FacetedForgeCounterexample
    var difficulty: FacetedForgeDifficulty
    var skipped: Int

    init(_ w: FacetedForgeWitness) {
        number = w.number
        level = w.level
        actions = w.actions
        digests = w.digests
        fingerprints = w.fingerprints
        smallest = w.smallest
        lowerBound = w.lowerBound
        nearMiss = w.nearMiss
        difficulty = w.difficulty
        skipped = w.skipped
    }

    var witness: FacetedForgeWitness {
        FacetedForgeWitness(number: number, level: level, actions: actions, digests: digests,
                            fingerprints: fingerprints, smallest: smallest, lowerBound: lowerBound,
                            nearMiss: nearMiss, difficulty: difficulty, skipped: skipped)
    }
}

@Suite("Faceted Forge witness")
struct FacetedForgeWitnessTests {
    let fixtures: FacetedForgeWitnessFixtures = .shared

    /// The refusal of decoding `witness`'s stored form, or nil when it decodes.
    func refusal(_ witness: FacetedForgeWitness) -> FacetedForgeError? {
        refusal(witness.encoded())
    }

    /// The refusal of decoding `data`, or nil when it decodes.
    func refusal(_ data: Data) -> FacetedForgeError? {
        do {
            _ = try FacetedForgeWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// `witness` with `change` applied to its parts.
    func edited(_ witness: FacetedForgeWitness,
                _ change: (inout FacetedForgeWitnessParts) -> Void) -> FacetedForgeWitness {
        var parts = FacetedForgeWitnessParts(witness)
        change(&parts)
        return parts.witness
    }

    /// The stored form of `witness` with the top-level line of `key` replaced by `line` (nil removes it).
    func storedText(_ witness: FacetedForgeWitness, key: String, line: String?) -> Data {
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

    /// A play of `level` after `begin` (and `dismissTutorial`).
    func started(_ level: FacetedForgeLevel) throws -> FacetedForgePlay {
        var play = FacetedForgePlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The play after replaying `actions` on `level` from `begin` (and `dismissTutorial`).
    func played(_ level: FacetedForgeLevel, _ actions: [FacetedForgeAction]) throws -> FacetedForgePlay {
        var play: FacetedForgePlay = try started(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// A winning sequence of `level`'s lower-bound length other than `avoid`, found in the solver's order within
    /// `bound` cut evaluations, or nil.
    func otherWin(_ level: FacetedForgeLevel, avoid: [FacetedForgeAction], bound: Int) -> [FacetedForgeAction]? {
        var work: Int = 0
        var actions: [FacetedForgeAction] = []
        let crystal: FacetedForgeFraction = level.crystal.volume
        func search(_ pieces: [FacetedForgePiece], _ left: Int) -> Bool {
            if left == 0 {
                return actions != avoid && FacetedForgeSolver.matches(pieces, level.target, crystal: crystal)
            }
            for index in pieces.indices {
                for direction in FacetedForgeDirection.all.indices {
                    for depth in FacetedForgeSolver.crossingDepths(pieces[index], direction: direction) {
                        guard work < bound else { return false }
                        work += 1
                        guard let halves = try? pieces[index].cut(direction: direction, depth: depth),
                              let below = try? halves.below.volume.dividing(by: crystal),
                              let above = try? halves.above.volume.dividing(by: crystal),
                              !(below < level.sliver), !(above < level.sliver) else { continue }
                        var rest: [FacetedForgePiece] = pieces
                        rest.remove(at: index)
                        let next: [FacetedForgePiece] = FacetedForgePiece.canonical(rest + [halves.below, halves.above])
                        guard FacetedForgeSolver.canPartition(next, into: level.target, crystal: crystal) else {
                            continue
                        }
                        actions.append(.cut(index, direction, depth))
                        if search(next, left - 1) { return true }
                        actions.removeLast()
                    }
                }
            }
            return false
        }
        return search([level.crystal], FacetedForgeSolver.lowerBound(level)) ? actions : nil
    }

    @Test("the fixtures cover three bands and a tutorial")
    func fixturesCover() {
        #expect(fixtures.cases.count == 3)
        #expect(fixtures.cases[0].generated.level.tutorial)
        var bands: Set<Int> = []
        for (generated, _) in fixtures.cases { bands.insert(generated.entry.band) }
        #expect(bands.count == 3)
    }

    @Test("the stored form round-trips byte for byte with one trailing newline")
    func roundTripByteForByte() throws {
        for (_, witness) in fixtures.cases {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: FacetedForgeWitness = try FacetedForgeWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            let text: String = String(decoding: data, as: UTF8.self)
            #expect(text.contains("\n  \"schema\" : 1,\n"))
            #expect(text.hasPrefix("{\n  \"actions\" : "))
        }
    }

    @Test("the witness carries the solver's cuts, lower bound, difficulty and provenance")
    func partsAreTheSolvers() {
        for (generated, witness) in fixtures.cases {
            #expect(witness.number == generated.entry.number)
            #expect(witness.level == generated.level)
            #expect(witness.level.id == FacetedForgeGenerator.levelID(generated.entry.number))
            #expect(witness.actions == generated.solution.actions)
            #expect(witness.smallest == generated.solution.smallest)
            #expect(witness.smallest == witness.actions.count)
            #expect(witness.lowerBound == witness.level.target.count - 1)
            #expect(witness.smallest == witness.lowerBound)
            #expect(FacetedForgeBandProfile.of(band: generated.entry.band).cuts.contains(witness.smallest))
            #expect(witness.difficulty == generated.difficulty)
            #expect(witness.skipped == generated.skipped)
        }
    }

    @Test("digests and fingerprints agree with a replay that wins on the last cut")
    func partsAgreeWithReplay() throws {
        for (_, witness) in fixtures.cases {
            #expect(witness.digests.count == witness.smallest)
            #expect(witness.fingerprints.count == witness.smallest + 1)
            for digest in witness.digests {
                #expect(digest.count == 16)
                #expect(digest.allSatisfy { "0123456789abcdef".contains($0) })
            }
            var play: FacetedForgePlay = try started(witness.level)
            var fingerprints: [String] = [play.fingerprint]
            var digests: [String] = []
            for action in witness.actions {
                #expect(play.stage == .playing)
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(FacetedForgeWitness.digest(play.pieces))
            }
            #expect(play.stage == .won)
            #expect(play.cuts == witness.smallest)
            #expect(play.cuts <= witness.level.budget)
            #expect(fingerprints == witness.fingerprints)
            #expect(digests == witness.digests)
        }
    }

    @Test("the digest is the first 16 hex characters of SHA-256 over the canonical corners")
    func digestLayout() throws {
        let crystal: FacetedForgePiece = fixtures.cases[0].witness.level.crystal
        var text: String = ""
        for (i, corner) in crystal.corners.enumerated() {
            if i > 0 { text += ";" }
            text += corner.x.text + "," + corner.y.text + "," + corner.z.text
        }
        #expect(FacetedForgeWitness.digest([crystal]) == String(StableHash.sha256Hex(Array(text.utf8)).prefix(16)))
        let halves: (below: FacetedForgePiece, above: FacetedForgePiece) = try crystal.cut(direction: 0, depth: 0)
        let pieces: [FacetedForgePiece] = [halves.below, halves.above]
        #expect(FacetedForgeWitness.digest(pieces) == FacetedForgeWitness.digest(pieces.reversed()))
        #expect(FacetedForgeWitness.digest(pieces) != FacetedForgeWitness.digest([crystal]))
        let other: (below: FacetedForgePiece, above: FacetedForgePiece) = try crystal.cut(direction: 1, depth: 0)
        #expect(FacetedForgeWitness.digest(pieces) != FacetedForgeWitness.digest([other.below, other.above]))
    }

    @Test("the near miss replays as recorded: not won, one piece short")
    func nearMissReplays() throws {
        for (_, witness) in fixtures.cases {
            let n: FacetedForgeCounterexample = witness.nearMiss
            #expect(n.actions == Array(witness.actions.dropLast()))
            #expect(n.outcome == "open")
            #expect(n.cut == witness.smallest - 1)
            let near: FacetedForgePlay = try played(witness.level, n.actions)
            #expect(near.stage == .playing)
            #expect(near.cuts == n.cut)
            #expect(near.pieces.count == witness.level.target.count - 1)
            #expect(near.fingerprint == witness.fingerprints[witness.smallest - 1])
        }
    }

    @Test("edited cuts are refused")
    func editedActionsRefused() {
        let w: FacetedForgeWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.actions.removeLast() }) == .witness("replay"))
        #expect(refusal(edited(w) { $0.actions.append(.cut(0, 0, 0)) }) == .witness("replay"))
        // Another winning sequence of the same length is not the solver's first one.
        guard let other = otherWin(w.level, avoid: w.actions, bound: 50_000) else {
            Issue.record("no second winning sequence of level \(w.number)")
            return
        }
        #expect(FacetedForgeGenerator.wins(w.level, actions: other))
        #expect(refusal(edited(w) { $0.actions = other }) == .witness("actions"))
    }

    @Test("edited digests are refused")
    func editedDigestsRefused() {
        let w: FacetedForgeWitness = fixtures.cases[0].witness
        let first: String = w.digests[0]
        let flipped: String = (first.first == "0" ? "1" : "0") + String(first.dropFirst())
        #expect(refusal(edited(w) { $0.digests[0] = flipped }) == .witness("digests"))
        #expect(refusal(edited(w) { $0.digests.removeLast() }) == .witness("digests"))
    }

    @Test("edited fingerprints are refused")
    func editedFingerprintsRefused() {
        let w: FacetedForgeWitness = fixtures.cases[0].witness
        #expect(refusal(edited(w) { $0.fingerprints.swapAt(0, 1) }) == .witness("fingerprints"))
        #expect(refusal(edited(w) { $0.fingerprints.removeLast() }) == .witness("fingerprints"))
    }

    @Test("an edited level is refused")
    func editedLevelRefused() throws {
        let w: FacetedForgeWitness = fixtures.cases[0].witness
        let text: String = String(decoding: w.encoded(), as: UTF8.self)
        let budget: Int = w.level.budget
        let changedBudget: Int = budget == FacetedForgeLevel.budgets.upperBound ? budget - 1 : budget + 1
        let changed: String = text.replacingOccurrences(of: "\"budget\" : \(budget),",
                                                        with: "\"budget\" : \(changedBudget),")
        #expect(changed != text)
        #expect(refusal(Data(changed.utf8)) == .witness("level"))
        // A re-fingerprinted level that is not the generator's candidate.
        let l: FacetedForgeLevel = w.level
        let other = try FacetedForgeLevel(id: l.id, seed: l.seed, difficulty: l.difficulty, planes: l.planes,
                                          budget: changedBudget, sliver: l.sliver, target: l.target,
                                          tutorial: l.tutorial)
        #expect(refusal(edited(w) { $0.level = other }) == .witness("candidate"))
    }

    @Test("edited solver values and near miss are refused")
    func editedSolverValuesRefused() {
        let w: FacetedForgeWitness = fixtures.cases[1].witness
        #expect(refusal(edited(w) { $0.smallest += 1 }) == .witness("smallest"))
        #expect(refusal(edited(w) { $0.lowerBound -= 1 }) == .witness("lower-bound"))
        let n: FacetedForgeCounterexample = w.nearMiss
        let later = FacetedForgeCounterexample(actions: n.actions, outcome: n.outcome, cut: n.cut + 1)
        #expect(refusal(edited(w) { $0.nearMiss = later }) == .witness("near-miss"))
        let budget = FacetedForgeCounterexample(actions: n.actions, outcome: "budget", cut: n.cut)
        #expect(refusal(edited(w) { $0.nearMiss = budget }) == .witness("near-miss"))
        let shorter = FacetedForgeCounterexample(actions: Array(n.actions.dropLast()), outcome: "open", cut: n.cut - 1)
        #expect(refusal(edited(w) { $0.nearMiss = shorter }) == .witness("near-miss"))
    }

    @Test("edited difficulty, number and skipped are refused")
    func editedDifficultyRefused() {
        let w: FacetedForgeWitness = fixtures.cases[0].witness
        let d: FacetedForgeDifficulty = w.difficulty
        let work = FacetedForgeDifficulty(smallest: d.smallest, directions: d.directions, diagonals: d.diagonals,
                                          crystalFaces: d.crystalFaces, pieces: d.pieces, work: d.work + 1)
        #expect(refusal(edited(w) { $0.difficulty = work }) == .witness("difficulty"))
        let faces = FacetedForgeDifficulty(smallest: d.smallest, directions: d.directions, diagonals: d.diagonals,
                                           crystalFaces: d.crystalFaces + 1, pieces: d.pieces, work: d.work)
        #expect(refusal(edited(w) { $0.difficulty = faces }) == .witness("difficulty"))
        #expect(refusal(edited(w) { $0.number = 101 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.number = w.number + 1 }) == .witness("number"))
        #expect(refusal(edited(w) { $0.skipped = FacetedForgeGenerator.maxCandidates }) == .witness("skipped"))
        #expect(refusal(edited(w) { $0.skipped = w.skipped + 1 }) == .witness("candidate"))
    }

    @Test("newer and damaged stored forms are refused")
    func newerAndDamagedRefused() {
        let w: FacetedForgeWitness = fixtures.cases[0].witness
        #expect(refusal(storedText(w, key: "schema", line: "2")) == .newerSchema(2))
        #expect(refusal(storedText(w, key: "schema", line: "0")) == .malformed("schema"))
        #expect(refusal(storedText(w, key: "skipped", line: nil)) == .malformed("unreadable"))
        #expect(refusal(storedText(w, key: "smallest", line: "\"none\"")) == .malformed("unreadable"))
        let data: Data = w.encoded()
        #expect(refusal(data.prefix(data.count / 2)) == .malformed("unreadable"))
        #expect(refusal(Data()) == .malformed("unreadable"))
        #expect(refusal(Data("[]".utf8)) == .malformed("unreadable"))
        #expect(FacetedForgeError.witness("unreadable").reasonCode == "r02-g08.witness")
    }

    @Test("make refuses a solution that does not win and a difficulty that is not the solution's")
    func makeRefuses() {
        let g: FacetedForgeGenerated = fixtures.cases[0].generated
        let s: FacetedForgeSolution = g.solution
        let short = FacetedForgeSolution(smallest: s.smallest, actions: Array(s.actions.dropLast()), work: s.work)
        let losing = FacetedForgeGenerated(entry: g.entry, level: g.level, solution: short, difficulty: g.difficulty,
                                           skipped: g.skipped)
        #expect(throws: FacetedForgeError.witness("replay")) { try FacetedForgeWitness.make(losing) }
        let d: FacetedForgeDifficulty = g.difficulty
        let other = FacetedForgeDifficulty(smallest: d.smallest, directions: d.directions, diagonals: d.diagonals,
                                           crystalFaces: d.crystalFaces, pieces: d.pieces, work: d.work + 1)
        let wrong = FacetedForgeGenerated(entry: g.entry, level: g.level, solution: s, difficulty: other,
                                          skipped: g.skipped)
        #expect(throws: FacetedForgeError.witness("difficulty")) { try FacetedForgeWitness.make(wrong) }
    }
}
