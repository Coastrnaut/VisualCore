// BinaryGardensCatalogTests — feature 502 (R02-G21-02) T-R02G2102-006 (FR-R02G2102-001 … 008; SC-R02G2102-001 … 007;
// clarifications Q1 … Q5; research R13, R14). The 100-level catalog: manifest shape (20 levels per band), the pinned
// digest, R02-F24's standard progression rule on the witness length in manifest order and non-decreasing band means (1,
// 2, 3, 3, 4 by construction), adjacent levels whose ring radii and worlds are not both equal (the neighbour rule),
// every stored witness replayed to a win through the play within its budget, an independent enumeration on the two
// levels with the smallest move space in each band (ties by level number: every action sequence shorter than the plan
// through `BinaryGardensPuzzle` moves, with no visited set and no loss order, every arrangement reached judged by the
// kernel: none wins, the arrangements first reached at each length are the solver's counts, and the witness's own
// sequence wins), one fully re-verified decode per band, the named invariant tests `testBinaryGardensContentBoundary`
// (INV-06, in the 20 groups of 5 levels: every witness replays to a win within its budget and its difficulty's work
// and arrangements searched equal the solver's run; neighbouring input, seed 2_507: one seeded edit of one seeded
// witness per group — an action value, a digest character or a difficulty count — is refused `r02-g21.witness`) and `testBinaryGardensNoveltyBoundary` (INV-12: every witness is
// ring, phase, luminosity and tilt actions then `run`, decided by received flux; putting back any one changed control
// of the winning arrangement makes the run fail; neighbouring input, seed 2_507: dropping one seeded action of a
// sampled witness never wins), and the witness files in docs/games/binary-gardens/levels/ compared byte for byte with
// the regenerated witnesses in 20 groups of 5 levels (each level generated after the stored level before it, the
// neighbour rule's input, and cached per process in a thread-safe store). The files are written only when
// BINARY_GARDENS_WRITE_WITNESSES=1 is set, with `swift test --no-parallel` so the groups run in order. Stored files are
// read with the plain decoder except in the re-verified tests. Explicit types and plain loops (CI type-check rule).
// Modelled on MushroomWeatherCatalogTests (feature 492).
import Foundation
import Synchronization
@testable import BinaryGardensCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, BinaryGardens, the package,
/// Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/binary-gardens/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(BinaryGardensGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> BinaryGardensWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(BinaryGardensWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[BinaryGardensWitness], any Error> = Result {
    var result: [BinaryGardensWitness] = []
    for entry in BinaryGardensManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [BinaryGardensWitness] { try stored.get() }

/// The generated levels of this process, by number (each generated after the stored level before it).
private let generatedCache: Mutex<[Int: BinaryGardensGenerated]> = Mutex<[Int: BinaryGardensGenerated]>([:])

/// The generated level `number`, after the stored level `number − 1` (none for level 1), cached per process.
private func generatedLevel(_ number: Int) throws -> BinaryGardensGenerated {
    if let cached = generatedCache.withLock({ $0[number] }) { return cached }
    let previous: BinaryGardensLevel? = number > 1 ? try storedWitness(number - 1).level : nil
    let generated: BinaryGardensGenerated = try BinaryGardensGenerator.generate(
        BinaryGardensManifest.entries[number - 1], previous: previous)
    generatedCache.withLock { $0[number] = generated }
    return generated
}

/// The arrangement actions of a witness (its actions without the closing run).
private func changes(_ witness: BinaryGardensWitness) -> [BinaryGardensAction] {
    var result: [BinaryGardensAction] = []
    for action in witness.actions where action != .run { result.append(action) }
    return result
}

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: BinaryGardensLevel, _ actions: [BinaryGardensAction]) -> BinaryGardensPlay? {
    var play = BinaryGardensPlay(level: level)
    do {
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions {
            guard play.stage == .playing else { return nil }
            try play.apply(action, expecting: play.fingerprint)
        }
    } catch {
        return nil
    }
    return play
}

/// Every action sequence of length 0 … `maxLength` through the puzzle's moves (no visited set, no loss order): the
/// number of arrangements first reached at each length, each judged once by the kernel, and whether any wins.
private func enumerate(_ level: BinaryGardensLevel, maxLength: Int) -> (counts: [Int], anyWin: Bool) {
    let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
    var reached: Set<BinaryGardensArrangement> = []
    var counts: [Int] = []
    var anyWin: Bool = false
    var frontier: [BinaryGardensPuzzle.Position] = [rules.initialState]
    var length: Int = 0
    while length <= maxLength {
        var layer: Set<BinaryGardensArrangement> = []
        for position in frontier where !reached.contains(position.arrangement) { layer.insert(position.arrangement) }
        for arrangement in layer where BinaryGardensSky.report(level, arrangement: arrangement).wins { anyWin = true }
        reached.formUnion(layer)
        counts.append(layer.count)
        if length == maxLength { break }
        var next: [BinaryGardensPuzzle.Position] = []
        for position in frontier {
            for move in rules.moves(in: position) {
                if let child = rules.apply(move, to: position) { next.append(child) }
            }
        }
        frontier = next
        length += 1
    }
    return (counts, anyWin)
}

/// The two stored witnesses of `band` with the smallest move space (then the lowest number).
private func smallestMoveSpace(band: Int) throws -> [BinaryGardensWitness] {
    var candidates: [BinaryGardensWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort { ($0.difficulty.moveSpace, $0.number) < ($1.difficulty.moveSpace, $1.number) }
    return Array(candidates.prefix(2))
}

/// The arrangement a witness wins with: its level's start after its arrangement actions.
private func winningArrangement(_ witness: BinaryGardensWitness) -> BinaryGardensArrangement? {
    played(witness.level, changes(witness))?.arrangement
}

@Suite struct BinaryGardensCatalogTests {
    /// The pinned catalog digest: `BinaryGardensGenerator.catalogDigest` over the 100 levels in manifest order,
    /// measured on 2026-11-27 from the production generator. An intended rule, generator or seed change re-pins it
    /// after review.
    static let pinnedDigest = "adf594d6994ffa3f4af4d1035c4e99faecdedffecac96f4ddc21bdc983ce401f"

    /// The neighbouring-input seed of the invariant tests.
    static let neighbourSeed: UInt64 = 2_507

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [BinaryGardensManifestEntry] = BinaryGardensManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int] = [0, 0, 0, 0, 0]
        for (index, entry) in entries.enumerated() {
            #expect(entry.number == index + 1)
            #expect((1...5).contains(entry.band))
            #expect((8...19).contains(entry.budget))
            perBand[entry.band - 1] += 1
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        var seeds: Set<UInt64> = []
        for entry in entries { seeds.insert(entry.seed) }
        #expect(seeds.count == 100)
    }

    /// The digest over the stored levels (equal to the generated ones: see the group tests) is pinned; the ids follow
    /// the manifest; adjacent levels differ in ring radii or worlds (FR-R02G2102-007).
    @Test func catalogMatchesThePinnedDigestAndNeighboursDiffer() throws {
        let witnesses: [BinaryGardensWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [BinaryGardensLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == BinaryGardensGenerator.levelID(index + 1))
            if index > 0 {
                let before: BinaryGardensLevel = witnesses[index - 1].level
                let same: Bool = before.ringRadii == witness.level.ringRadii && before.worlds == witness.level.worlds
                #expect(!same, "\(witness.level.id) repeats its neighbour")
                #expect(before.fingerprint != witness.level.fingerprint)
            }
        }
        let digest: String = BinaryGardensGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        let identities: [String] = levels.map(\.fingerprint)
        #expect(digest == PuzzleCatalog<BinaryGardensPuzzle>.digest(id: "binary-gardens", identities: identities))
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's profile, R02-F24's standard progression rule on the witness length in
    /// manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [BinaryGardensWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumActions: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: BinaryGardensLevel = witness.level
            let entry: BinaryGardensManifestEntry = BinaryGardensManifest.entries[witness.number - 1]
            let count: Int = changes(witness).count
            #expect(witness.actions.last == .run)
            #expect(witness.actions.count == count + 1)
            #expect(count == witness.difficulty.actions)
            #expect(count >= 1)
            #expect(count <= level.budget)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.seed == entry.seed)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: BinaryGardensBandProfile = BinaryGardensBandProfile.of(band: level.difficulty)
            #expect(count == profile.plan, "\(level.id): \(count) actions, the band's plan is \(profile.plan)")
            #expect(level.phaseStep == profile.phaseStep)
            #expect(witness.difficulty.adjustable == profile.adjustable)
            #expect(profile.worlds.contains(level.worlds.count))
            #expect(profile.separation.contains(level.minimumSeparation))
            #expect(witness.counterexample.depth == count - 1)
            #expect(witness.difficulty.work <= BinaryGardensSolver.workBound)
            #expect((0..<BinaryGardensGenerator.maxCandidates).contains(witness.skipped))
            #expect(witness.report.outcome == "won")
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumActions[level.difficulty - 1] += count
            countPerBand[level.difficulty - 1] += 1
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        #expect(countPerBand == [20, 20, 20, 20, 20])
        // Twenty levels per band, so the sums order as the means do: 1, 2, 3, 3, 4 by construction.
        for band in 1..<5 {
            #expect(sumActions[band] >= sumActions[band - 1], "mean actions fall at band \(band + 1): \(sumActions)")
        }
        #expect(sumActions == [20, 40, 60, 60, 80])
    }

    /// SC-R02G2102-001 for all 100 levels: the witness actions replayed on a play, then the run, win within the budget;
    /// the actions alone leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: BinaryGardensLevel = witness.level
            let play: BinaryGardensPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == changes(witness).count)
            let before: BinaryGardensPlay? = played(level, changes(witness))
            #expect(before?.stage == .playing, "\(level.id) is not playing before its run")
            #expect(before?.report.wins == true, "\(level.id)")
        }
    }

    /// SC-R02G2102-002 on the two levels with the smallest move space in each band: the independent enumeration finds
    /// no win below the plan's length, its first-reached counts are the solver's, and the witness's sequence wins.
    @Test(arguments: [1, 2, 3, 4, 5])
    func noArrangementReachableWithFewerActionsWins(band: Int) throws {
        let witnesses: [BinaryGardensWitness] = try smallestMoveSpace(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let level: BinaryGardensLevel = witness.level
            let size: Int = witness.difficulty.actions
            let result: (counts: [Int], anyWin: Bool) = enumerate(level, maxLength: size - 1)
            #expect(!result.anyWin, "\(level.id) is won with fewer actions")
            let plan: BinaryGardensPlan = try #require(BinaryGardensSolver.plan(level, maxDepth: size))
            #expect(result.counts == plan.arrangementsByDepth, "\(level.id)")
            #expect(result.counts.reduce(0, +) == witness.difficulty.arrangementsSearched, "\(level.id)")
            #expect(result.counts.last == witness.counterexample.arrangements, "\(level.id)")
            let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
            var position: BinaryGardensPuzzle.Position = rules.initialState
            for action in changes(witness) {
                position = try #require(rules.apply(action, to: position), "\(level.id) \(action)")
            }
            #expect(rules.isSolved(position), "\(level.id) is not won with its actions")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: BinaryGardensWitness = try BinaryGardensWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == BinaryGardensManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// INV-06 (content), in group `group` (levels 5·group + 1 … 5·group + 5): every level has a witness that replays to
    /// a win within its budget, and its difficulty reflects the solver's actual work (work and arrangements searched
    /// equal the solver's run — the cached generation's when this process made it, else a fresh solver run — and its
    /// counterexample the solver's count at the depth below the plan). Neighbouring input, seed 2_507: one seeded witness
    /// of the group with one seeded edit — an action value, a digest character or a difficulty count — is refused
    /// `r02-g21.witness`.
    @Test(arguments: Array(0..<20))
    func testBinaryGardensContentBoundary(group: Int) throws {
        let all: [BinaryGardensWitness] = try storedWitnesses()
        let groupWitnesses: [BinaryGardensWitness] = Array(all[(5 * group)..<(5 * group + 5)])
        for witness in groupWitnesses {
            let level: BinaryGardensLevel = witness.level
            let play: BinaryGardensPlay? = played(level, witness.actions)
            #expect(play?.stage == .won && (play?.actionsSpent ?? Int.max) <= level.budget, "\(level.id)")
            let size: Int = BinaryGardensBandProfile.of(band: level.difficulty).plan
            let cached: BinaryGardensGenerated? = generatedCache.withLock { $0[witness.number] }
            let plan: BinaryGardensPlan = try #require(cached?.plan ?? BinaryGardensSolver.plan(level, maxDepth: size))
            #expect(plan.actions == changes(witness), "\(level.id)")
            #expect(witness.difficulty.work == plan.work, "\(level.id)")
            #expect(witness.difficulty.arrangementsSearched == plan.arrangementsByDepth.reduce(0, +), "\(level.id)")
            #expect(witness.counterexample.arrangements == plan.arrangementsByDepth[size - 1], "\(level.id)")
            #expect(witness.difficulty == BinaryGardensDifficulty(level: level, plan: plan), "\(level.id)")
        }
        // Neighbouring input: a seeded witness of the group, a seeded edit.
        var random = SeededRandom(seed: Self.neighbourSeed &+ UInt64(group))
        let witness: BinaryGardensWitness = groupWitnesses[random.index(below: groupWitnesses.count)]
        let kind: Int = random.index(below: 3)
        let edited: BinaryGardensWitness
        switch kind {
        case 0:
            // An action value: one seeded arrangement action set to another legal value of its control.
            var actions: [BinaryGardensAction] = changes(witness)
            let index: Int = random.index(below: actions.count)
            let (control, value): (BinaryGardensControl, Int) = try #require(BinaryGardensControl.of(actions[index]))
            var others: [Int] = []
            for other in control.values(in: witness.level) where other != value { others.append(other) }
            actions[index] = control.action(others[random.index(below: others.count)])
            edited = BinaryGardensWitness(number: witness.number, level: witness.level, actions: actions + [.run],
                                          digests: witness.digests, fingerprints: witness.fingerprints,
                                          report: witness.report, counterexample: witness.counterexample,
                                          difficulty: witness.difficulty, skipped: witness.skipped)
        case 1:
            // A digest character: one seeded hex character of one seeded digest replaced by another.
            var digests: [String] = witness.digests
            let index: Int = random.index(below: digests.count)
            var characters: [Character] = Array(digests[index])
            let position: Int = random.index(below: characters.count)
            characters[position] = characters[position] == "0" ? "1" : "0"
            digests[index] = String(characters)
            edited = BinaryGardensWitness(number: witness.number, level: witness.level, actions: witness.actions,
                                          digests: digests, fingerprints: witness.fingerprints,
                                          report: witness.report, counterexample: witness.counterexample,
                                          difficulty: witness.difficulty, skipped: witness.skipped)
        default:
            // A difficulty count: the work one higher.
            let d: BinaryGardensDifficulty = witness.difficulty
            var object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: witness.encoded())
                                                        as? [String: Any])
            var difficulty: [String: Any] = try #require(object["difficulty"] as? [String: Any])
            difficulty["work"] = d.work + 1
            object["difficulty"] = difficulty
            let data: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            edited = try JSONDecoder().decode(BinaryGardensWitness.self, from: data)
            #expect(edited.difficulty.work == d.work + 1)
        }
        #expect(edited != witness)
        do {
            _ = try BinaryGardensWitness.decode(edited.encoded())
            Issue.record("an edited witness of \(witness.level.id) (edit \(kind)) decodes")
        } catch {
            #expect(error.reasonCode == "r02-g21.witness", "\(witness.level.id) edit \(kind): \(error)")
        }
        #expect(try BinaryGardensWitness.decode(witness.encoded()) == witness)
    }

    /// INV-12 (novelty): the mechanic is checked, not its name. Every witness is ring, phase, luminosity and tilt
    /// actions then `run`, and putting back any one changed control of its winning arrangement (to the start's value)
    /// makes the run fail by the received flux. Neighbouring input, seed 2_507: dropping one seeded action of a sampled
    /// witness never wins.
    @Test func testBinaryGardensNoveltyBoundary() throws {
        let witnesses: [BinaryGardensWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        for witness in witnesses {
            let level: BinaryGardensLevel = witness.level
            for action in changes(witness) {
                var shaped: Bool = false
                switch action {
                case .ring, .phase, .luminosity, .tilt: shaped = true
                case .run: shaped = false
                }
                #expect(shaped, "\(level.id)")
            }
            #expect(witness.actions.last == .run)
            let winning: BinaryGardensArrangement = try #require(winningArrangement(witness), "\(level.id)")
            #expect(BinaryGardensSky.report(level, arrangement: winning).wins, "\(level.id)")
            var changed: Int = 0
            for control in BinaryGardensControl.allCases
                where control.value(of: winning) != control.value(of: level.start) {
                changed += 1
                let reduced: BinaryGardensArrangement = control.setting(control.value(of: level.start), in: winning)
                let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: reduced)
                #expect(!report.wins, "\(level.id): \(control) put back still wins")
            }
            #expect(changed >= 1 && changed <= changes(witness).count, "\(level.id)")
        }
        var random = SeededRandom(seed: Self.neighbourSeed)
        for _ in 0..<20 {
            let witness: BinaryGardensWitness = witnesses[random.index(below: witnesses.count)]
            var actions: [BinaryGardensAction] = changes(witness)
            actions.remove(at: random.index(below: actions.count))
            #expect(!BinaryGardensSolver.replayWins(witness.level, actions: actions),
                    "\(witness.level.id) wins with one action dropped")
        }
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte for
    /// byte (written only with BINARY_GARDENS_WRITE_WITNESSES=1). Each level is generated after the stored level before
    /// it, which its own group checks against its regeneration.
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["BINARY_GARDENS_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: BinaryGardensGenerated = try generatedLevel(number)
            #expect(generated.level.id == BinaryGardensGenerator.levelID(number))
            let witness: BinaryGardensWitness = try BinaryGardensWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(number))
            if write { try data.write(to: url) }
            let storedData: Data = try Data(contentsOf: url)
            #expect(storedData == data, "\(witnessName(number)) differs from the regenerated witness")
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let all: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
        var names: [String] = []
        for name in all where name.hasSuffix(".witness.json") { names.append(name) }
        #expect(names.count == 100)
        #expect(names.sorted().first == "001.witness.json")
        #expect(names.sorted().last == "100.witness.json")
    }
}
