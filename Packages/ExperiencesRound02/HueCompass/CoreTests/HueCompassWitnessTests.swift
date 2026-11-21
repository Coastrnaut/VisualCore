// HueCompassWitnessTests — feature 332 (R02-G04-02) T-R02G0402-005 (FR-R02G0402-004; SC-R02G0402-005; clarifications
// Q2, Q4). Witnesses of three hand-built levels (varied fog with loose tolerances, settled by one probe; the same with a
// tutorial; uniform fog with tight tolerances, settled by two probes), each with a hand-made solution found in the test
// by brute force over target levels (one level per candidate target, so clues and acceptance come from the kernel, not
// from the witness's deduction). The stored form round-trips byte for byte with one trailing newline; the actions have
// the canonical shape; edited actions, fingerprints, level, clues, counts, near miss, ambiguity, difficulty, number and
// skipped are refused; newer and damaged stored forms are refused; the near miss fails when played; the ambiguity holds;
// `make` refuses a missing ambiguity, an unsettling probe set and a probe set that is not the first settling one.
// Seed 2_332. Explicit types, plain loops (CI type-check rule), short runs.
import Foundation
import Testing
@testable import HueCompassCore

/// A hand-made solution found by brute force: the first settling probe set, its work, the best single probe and the
/// ambiguity of the smaller set.
struct HueCompassBruteForce {
    let level: HueCompassLevel
    /// Candidate targets, ascending.
    let candidates: [Int]
    /// The level with target t (same everything else), for every candidate t.
    let targetLevels: [Int: HueCompassLevel]

    init(_ level: HueCompassLevel) throws {
        self.level = level
        var candidates: [Int] = []
        var targetLevels: [Int: HueCompassLevel] = [:]
        for t in 0..<96 where HueCompassWheel.bearingDistance(t, level.start) > level.bearingTolerance {
            candidates.append(t)
            targetLevels[t] = try HueCompassLevel(id: level.id, seed: level.seed, band: level.band,
                                                  offset: level.offset, fog: level.fog, target: t, start: level.start,
                                                  bearingTolerance: level.bearingTolerance,
                                                  bandTolerance: level.bandTolerance, allowance: level.allowance,
                                                  tutorial: level.tutorial)
        }
        self.candidates = candidates
        self.targetLevels = targetLevels
    }

    /// The clues of target `t` at `probes`.
    func clues(_ t: Int, _ probes: [Int]) -> [HueCompassClue] {
        var result: [HueCompassClue] = []
        for p in probes { result.append(targetLevels[t]!.clue(at: p)) }
        return result
    }

    /// Whether some bearing accepts every member's bearing and some band every member's band (checked separately).
    func acceptable(_ members: [Int]) -> Bool {
        var bearingOK: Bool = false
        for b in 0..<96 {
            var all: Bool = true
            for m in members where !targetLevels[m]!.accepts(bearing: b, band: targetLevels[m]!.targetBand) {
                all = false
                break
            }
            if all {
                bearingOK = true
                break
            }
        }
        guard bearingOK else { return false }
        for k in 0..<24 {
            var all: Bool = true
            for m in members where !targetLevels[m]!.accepts(bearing: m, band: k) {
                all = false
                break
            }
            if all { return true }
        }
        return false
    }

    /// Whether no single selection accepts both targets.
    func noJointSelection(_ a: Int, _ b: Int) -> Bool {
        for bearing in 0..<96 {
            for band in 0..<24 {
                if targetLevels[a]!.accepts(bearing: bearing, band: band)
                    && targetLevels[b]!.accepts(bearing: bearing, band: band) { return false }
            }
        }
        return true
    }

    /// The candidates grouped by their clues at `probes`.
    func classes(_ probes: [Int]) -> [[Int]] {
        var groups: [[HueCompassClue]: [Int]] = [:]
        var order: [[HueCompassClue]] = []
        for c in candidates {
            let key: [HueCompassClue] = clues(c, probes)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(c)
        }
        var result: [[Int]] = []
        for key in order { result.append(groups[key]!) }
        return result
    }

    func settles(_ probes: [Int]) -> Bool {
        for members in classes(probes) where !acceptable(members) { return false }
        return true
    }

    /// The first settling set (empty, singles, pairs in lexicographic order) and the sets tried.
    func firstSettling() -> (probes: [Int], work: Int)? {
        var work: Int = 1
        if settles([]) { return ([], work) }
        for a in 0..<96 {
            work += 1
            if settles([a]) { return ([a], work) }
        }
        for a in 0..<95 {
            for b in (a + 1)..<96 {
                work += 1
                if settles([a, b]) { return ([a, b], work) }
            }
        }
        return nil
    }

    /// The single bearing with the smallest largest class (lowest on a tie) and that size.
    func bestSingle() -> (bearing: Int, largest: Int) {
        var best: (bearing: Int, largest: Int) = (0, Int.max)
        for b in 0..<96 {
            var largest: Int = 0
            for members in classes([b]) { largest = max(largest, members.count) }
            if largest < best.largest { best = (b, largest) }
        }
        return best
    }

    /// The first pair of candidates (lexicographic) sharing every clue at `probes` with no joint selection.
    func ambiguity(_ probes: [Int]) -> HueCompassAmbiguity? {
        for members in classes(probes) {
            for i in 0..<members.count {
                for j in (i + 1)..<max(i + 1, members.count) where noJointSelection(members[i], members[j]) {
                    return HueCompassAmbiguity(probes: probes, targets: [members[i], members[j]])
                }
            }
        }
        return nil
    }

    /// The generated level of this brute-force solution.
    func generated(number: Int, skipped: Int) throws -> HueCompassGenerated {
        let first: (probes: [Int], work: Int) = try #require(firstSettling())
        let smaller: [Int] = first.probes.count == 2 ? [0] : []
        let best: (bearing: Int, largest: Int) = bestSingle()
        let solution = HueCompassSolution(probes: first.probes, work: first.work, bestSingle: best.bearing,
                                          largestAfterBestSingle: best.largest, ambiguity: ambiguity(smaller))
        let difficulty = HueCompassDifficulty(smallest: first.probes.count, largestAfterBestSingle: best.largest,
                                              bearingTolerance: level.bearingTolerance,
                                              bandTolerance: level.bandTolerance,
                                              clearShare: HueCompassBandProfile.of(band: level.band).clearShare,
                                              work: first.work)
        let entry = HueCompassManifestEntry(number: number, seed: level.seed, band: level.band,
                                            budget: level.allowance)
        return HueCompassGenerated(entry: entry, level: level, solution: solution, difficulty: difficulty,
                                   skipped: skipped)
    }
}

@Suite struct HueCompassWitnessTests {
    /// The test seed.
    static let seed: UInt64 = 2_332

    /// Varied fog (1 … 9, seeded), loose tolerances (4, 2), band 1.
    static func varied(tutorial: Bool) throws -> HueCompassLevel {
        var random = HueCompassRandom(seed: seed)
        var fog: [Int] = []
        for _ in 0..<96 { fog.append(random.int(1...9)) }
        let id: String = tutorial ? "varied-tutorial" : "varied"
        return try HueCompassLevel(id: id, seed: seed, band: 1, offset: 5, fog: fog, target: 30,
                                   start: 70, bearingTolerance: 4, bandTolerance: 2, allowance: 9, tutorial: tutorial)
    }

    /// Uniform fog (every density 1), tight tolerances (1, 0), band 4.
    static func uniform() throws -> HueCompassLevel {
        try HueCompassLevel(id: "uniform", seed: seed, band: 4, offset: 0, fog: Array(repeating: 1, count: 96),
                            target: 40, start: 10, bearingTolerance: 1, bandTolerance: 0, allowance: 12)
    }

    /// The three hand-made generated levels: varied, varied with a tutorial, uniform.
    static let generated: [HueCompassGenerated] = {
        do {
            let v: HueCompassGenerated = try HueCompassBruteForce(try varied(tutorial: false))
                .generated(number: 7, skipped: 2)
            let t: HueCompassGenerated = try HueCompassBruteForce(try varied(tutorial: true))
                .generated(number: 1, skipped: 0)
            let u: HueCompassGenerated = try HueCompassBruteForce(try uniform()).generated(number: 70, skipped: 5)
            return [v, t, u]
        } catch {
            preconditionFailure("hand-made levels are valid: \(error)")
        }
    }()

    static func witnesses() throws -> [HueCompassWitness] {
        var result: [HueCompassWitness] = []
        for g in generated { result.append(try HueCompassWitness.make(g)) }
        return result
    }

    /// The stored JSON of `witness` edited by `edit`.
    static func edited(_ witness: HueCompassWitness, _ edit: (inout [String: Any]) -> Void) throws -> Data {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: witness.encoded()) as? [String: Any])
        edit(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    static func refusal(_ data: Data) -> HueCompassError? {
        do {
            _ = try HueCompassWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    @Test func handMadeSolutionsHaveTheExpectedProbeCounts() throws {
        var smallest: [Int] = []
        for g in Self.generated {
            smallest.append(g.solution.smallest)
            #expect(g.solution.ambiguity != nil)
        }
        #expect(smallest == [1, 1, 2])
    }

    @Test func witnessesRoundTripByteForByte() throws {
        for witness in try Self.witnesses() {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: HueCompassWitness = try HueCompassWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            let text: String = try #require(String(data: data, encoding: .utf8))
            #expect(text.contains("\"actions\" : ["))
            #expect(text.range(of: "\"actions\"")!.lowerBound < text.range(of: "\"ambiguity\"")!.lowerBound)
        }
    }

    @Test func actionsHaveTheCanonicalShape() throws {
        let witnesses: [HueCompassWitness] = try Self.witnesses()
        for index in witnesses.indices {
            let witness: HueCompassWitness = witnesses[index]
            let g: HueCompassGenerated = Self.generated[index]
            let level: HueCompassLevel = witness.level
            #expect(HueCompassWitness.actions(for: g.solution, level: level) == witness.actions)
            // Expected by hand: shortest turns and probes, then the smallest acceptable selection of the target's class.
            let brute = try HueCompassBruteForce(level)
            var expected: [HueCompassAction] = []
            var bearing: Int = level.start
            for p in g.solution.probes {
                let turn: Int = HueCompassFixtures.shortestTurn(from: bearing, to: p)
                if turn != 0 { expected.append(.turn(turn)) }
                expected.append(.probe)
                bearing = p
            }
            var members: [Int] = []
            let targetClues: [HueCompassClue] = brute.clues(level.target, g.solution.probes)
            for c in brute.candidates where brute.clues(c, g.solution.probes) == targetClues {
                members.append(c)
            }
            var selected: HueCompassAction?
            search: for b in 0..<96 {
                for k in 0..<24 {
                    var all: Bool = true
                    for m in members where !brute.targetLevels[m]!.accepts(bearing: b, band: k) {
                        all = false
                        break
                    }
                    if all {
                        selected = .select(bearing: b, band: k)
                        break search
                    }
                }
            }
            expected.append(try #require(selected))
            #expect(witness.actions == expected)
            #expect(witness.fingerprints.count == witness.actions.count + 1)
            #expect(witness.clues.count == g.solution.smallest)
            #expect(witness.counts.count == g.solution.smallest)
            #expect(witness.counts.last == members.count)
            for i in g.solution.probes.indices {
                #expect(witness.clues[i] == level.clue(at: g.solution.probes[i]))
                if i > 0 { #expect(witness.counts[i] <= witness.counts[i - 1]) }
            }
            #expect(witness.number == g.entry.number && witness.skipped == g.skipped)
            #expect(witness.difficulty == g.difficulty)
            // The fingerprints are the play's after begin (and the tutorial) and after each action; the play wins.
            var play = HueCompassPlay(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            var prints: [String] = [play.fingerprint]
            for action in witness.actions {
                try play.apply(action, expecting: play.fingerprint)
                prints.append(play.fingerprint)
            }
            #expect(prints == witness.fingerprints)
            #expect(play.stage == .won)
        }
    }

    @Test func theNearMissFailsWhenPlayed() throws {
        for witness in try Self.witnesses() {
            let level: HueCompassLevel = witness.level
            #expect(witness.nearMiss.bearing == (level.target + level.bearingTolerance + 1) % 96)
            #expect(witness.nearMiss.band == level.targetBand)
            var play = HueCompassPlay(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            for action in witness.actions.dropLast() { try play.apply(action, expecting: play.fingerprint) }
            try play.apply(.select(bearing: witness.nearMiss.bearing, band: witness.nearMiss.band),
                           expecting: play.fingerprint)
            #expect(play.stage == .failed)
            #expect(play.failure == .selection)
        }
    }

    @Test func theAmbiguityHolds() throws {
        for witness in try Self.witnesses() {
            let brute = try HueCompassBruteForce(witness.level)
            let a: Int = witness.ambiguity.targets[0]
            let b: Int = witness.ambiguity.targets[1]
            #expect(witness.ambiguity.probes.count == witness.difficulty.smallest - 1)
            #expect(brute.candidates.contains(a) && brute.candidates.contains(b) && a < b)
            #expect(brute.clues(a, witness.ambiguity.probes) == brute.clues(b, witness.ambiguity.probes))
            #expect(brute.noJointSelection(a, b))
            #expect(!brute.settles(witness.ambiguity.probes))
        }
    }

    @Test func schemaAndDamageRefusals() throws {
        let witness: HueCompassWitness = try #require(try Self.witnesses().first)
        #expect(Self.refusal(try Self.edited(witness) { $0["schema"] = 2 }) == .newerSchema(2))
        #expect(Self.refusal(try Self.edited(witness) { $0["schema"] = 0 }) == .malformed("schema 0"))
        #expect(Self.refusal(witness.encoded().prefix(40)) == .malformed("unreadable"))
        #expect(Self.refusal(try Self.edited(witness) { $0.removeValue(forKey: "counts") }) == .malformed("unreadable"))
        #expect(Self.refusal(Data("not json".utf8)) == .malformed("unreadable"))
        #expect(HueCompassError.witness("replay").reasonCode == "r02-g04.witness")
    }

    @Test func editedPartsAreRefused() throws {
        let witnesses: [HueCompassWitness] = try Self.witnesses()
        for witness in witnesses {
            let select: Data = try Self.edited(witness) { object in
                var actions: [[String: Any]] = object["actions"] as! [[String: Any]]
                var value: [String: Any] = actions[actions.count - 1]["select"] as! [String: Any]
                value["bearing"] = ((value["bearing"] as! Int) + 1) % 96
                actions[actions.count - 1] = ["select": value]
                object["actions"] = actions
            }
            #expect(Self.refusal(select) == .witness("actions"))

            let extra: Data = try Self.edited(witness) { object in
                var actions: [[String: Any]] = object["actions"] as! [[String: Any]]
                actions.insert(["turn": ["_0": -1]], at: 0)
                actions.insert(["turn": ["_0": 1]], at: 0)
                object["actions"] = actions
            }
            #expect(Self.refusal(extra) == .witness("actions"))

            let fingerprint: Data = try Self.edited(witness) { object in
                var fingerprints: [String] = object["fingerprints"] as! [String]
                fingerprints[fingerprints.count - 1] = String(repeating: "0", count: 64)
                object["fingerprints"] = fingerprints
            }
            #expect(Self.refusal(fingerprint) == .witness("fingerprints"))

            let levelEdit: Data = try Self.edited(witness) { object in
                var value: [String: Any] = object["level"] as! [String: Any]
                value["allowance"] = (value["allowance"] as! Int) + 1
                object["level"] = value
            }
            #expect(Self.refusal(levelEdit) == .witness("level"))

            let clue: Data = try Self.edited(witness) { object in
                var clues: [[String: Any]] = object["clues"] as! [[String: Any]]
                clues[0]["depth"] = (clues[0]["depth"] as! Int) + 1
                object["clues"] = clues
            }
            #expect(Self.refusal(clue) == .witness("clues"))

            let count: Data = try Self.edited(witness) { object in
                var counts: [Int] = object["counts"] as! [Int]
                counts[0] += 1
                object["counts"] = counts
            }
            #expect(Self.refusal(count) == .witness("counts"))

            let near: Data = try Self.edited(witness) { object in
                var value: [String: Any] = object["nearMiss"] as! [String: Any]
                value["bearing"] = ((value["bearing"] as! Int) + 1) % 96
                object["nearMiss"] = value
            }
            #expect(Self.refusal(near) == .witness("near-miss"))

            // Two targets one selection accepts together: the target and its neighbour.
            let joint: Data = try Self.edited(witness) { object in
                var value: [String: Any] = object["ambiguity"] as! [String: Any]
                let t: Int = witness.level.target
                value["targets"] = [min(t, (t + 1) % 96), max(t, (t + 1) % 96)]
                object["ambiguity"] = value
            }
            #expect(Self.refusal(joint) == .witness("ambiguity"))

            let probes: Data = try Self.edited(witness) { object in
                var value: [String: Any] = object["ambiguity"] as! [String: Any]
                value["probes"] = [0, 1, 2]
                object["ambiguity"] = value
            }
            #expect(Self.refusal(probes) == .witness("ambiguity"))

            let keys: [String] = ["smallest", "largestAfterBestSingle", "bearingTolerance", "bandTolerance",
                                  "clearShare", "work"]
            for key in keys {
                let data: Data = try Self.edited(witness) { object in
                    var value: [String: Any] = object["difficulty"] as! [String: Any]
                    value[key] = (value[key] as! Int) + 1
                    object["difficulty"] = value
                }
                #expect(Self.refusal(data) == .witness("difficulty"), "difficulty.\(key)")
            }

            #expect(Self.refusal(try Self.edited(witness) { $0["number"] = 0 }) == .witness("number"))
            #expect(Self.refusal(try Self.edited(witness) { $0["skipped"] = 64 }) == .witness("skipped"))
        }
    }

    @Test func aReFingerprintedLevelDoesNotReplay() throws {
        let witness: HueCompassWitness = try #require(try Self.witnesses().first)
        let old: HueCompassLevel = witness.level
        let other = try HueCompassLevel(id: old.id, seed: old.seed, band: old.band, offset: old.offset, fog: old.fog,
                                        target: old.target, start: old.start, bearingTolerance: old.bearingTolerance,
                                        bandTolerance: old.bandTolerance, allowance: old.allowance + 1,
                                        tutorial: old.tutorial)
        let replacement: Any = try JSONSerialization.jsonObject(with: other.encoded())
        let data: Data = try Self.edited(witness) { $0["level"] = replacement }
        #expect(Self.refusal(data) == .witness("fingerprints"))
    }

    @Test func makeRefusesABadSolution() throws {
        for g in Self.generated {
            let s: HueCompassSolution = g.solution
            let bare = HueCompassSolution(probes: s.probes, work: s.work, bestSingle: s.bestSingle,
                                          largestAfterBestSingle: s.largestAfterBestSingle, ambiguity: nil)
            let noAmbiguity = HueCompassGenerated(entry: g.entry, level: g.level, solution: bare,
                                                  difficulty: g.difficulty, skipped: g.skipped)
            #expect(throws: HueCompassError.witness("ambiguity")) { try HueCompassWitness.make(noAmbiguity) }

            let short = HueCompassSolution(probes: Array(s.probes.dropLast()), work: s.work, bestSingle: s.bestSingle,
                                           largestAfterBestSingle: s.largestAfterBestSingle, ambiguity: s.ambiguity)
            let unsettled = HueCompassGenerated(entry: g.entry, level: g.level, solution: short,
                                                difficulty: g.difficulty, skipped: g.skipped)
            // No selection for the target's class (no win) or another class without one (unsound).
            let refusals: [HueCompassError] = [.witness("replay"), .witness("soundness")]
            var refusal: HueCompassError?
            do { _ = try HueCompassWitness.make(unsettled) } catch { refusal = error }
            #expect(refusal.map { refusals.contains($0) } == true)
        }
        // A settling single bearing that is not the first one.
        let g: HueCompassGenerated = Self.generated[0]
        let brute = try HueCompassBruteForce(g.level)
        var later: Int?
        for b in (g.solution.probes[0] + 1)..<96 where brute.settles([b]) {
            later = b
            break
        }
        let laterBearing: Int = try #require(later)
        let s: HueCompassSolution = g.solution
        let notFirst = HueCompassSolution(probes: [laterBearing], work: s.work, bestSingle: s.bestSingle,
                                          largestAfterBestSingle: s.largestAfterBestSingle, ambiguity: s.ambiguity)
        let generated = HueCompassGenerated(entry: g.entry, level: g.level, solution: notFirst,
                                            difficulty: g.difficulty, skipped: g.skipped)
        #expect(throws: HueCompassError.witness("difficulty")) { try HueCompassWitness.make(generated) }
    }
}
