// MyceliumArchitectCatalogTests — feature 512 (R02-G22-02) T-R02G2202-007 (FR-R02G2202-001 … 008; SC-R02G2202-001
// … 005; clarifications Q2 … Q5). The 100-level catalog on the rule kernel of feature 511 (R02-G22-01): manifest shape
// (20 levels per band), the pinned catalog digest over the 100 fingerprints, R02-F24's standard progression rule on the
// witness length in manifest order and non-decreasing band means (1, 2, 3, 3, 4 by construction), no two consecutive
// levels on the same board (`MyceliumArchitectGenerator.sameBoard`, the neighbour rule), every stored witness replayed
// to a win through the play within its budget, one fully re-verified decode per band, the named invariant tests
// `testMyceliumArchitectContentBoundary` (INV-06, in the 20 groups of 5 levels: every witness replays to a win within
// its budget and its difficulty's work and arrangements searched below the plan equal the solver's run; neighbouring
// input, seed 2_517: one seeded edit of one seeded witness per group — an action, a digest character or a difficulty
// count — is refused `r02-g22.witness` or `r02-g22.malformed`) and `testMyceliumArchitectNoveltyBoundary` (INV-12:
// every witness is nutrient, blocker and seed actions then `run`, and removing any one action of the plan makes the
// run fail; neighbouring input, seed 2_517: dropping one seeded action of a sampled witness never wins), and the
// witness files in docs/games/mycelium-architect/levels/ compared byte for byte with the regenerated witnesses in 20
// groups of 5 levels (each level generated after the stored level before it, the neighbour rule's input, and cached
// per process in a thread-safe store). The files are written only when MYCELIUM_ARCHITECT_WRITE_WITNESSES=1 is set,
// with `swift test --no-parallel` so the groups run in order. Stored files are read with the plain decoder except in
// the re-verified tests (decode regenerates a candidate and re-runs the solver). Explicit types and plain loops (CI
// type-check rule). Modelled on BinaryGardensCatalogTests (feature 502).
import Foundation
import Synchronization
@testable import MyceliumArchitectCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, MyceliumArchitect, the
/// package, Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/mycelium-architect/levels", isDirectory: true)

/// The file name of level `number`'s witness, `NNN.witness.json`.
private func witnessName(_ number: Int) -> String {
    String(format: "%03d", number) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder (the level re-checked by its own rules).
private func storedWitness(_ number: Int) throws -> MyceliumArchitectWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(MyceliumArchitectWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[MyceliumArchitectWitness], any Error> = Result {
    var result: [MyceliumArchitectWitness] = []
    for entry in MyceliumArchitectManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [MyceliumArchitectWitness] { try stored.get() }

/// The generated levels of this process, by number (each generated after the stored level before it).
private let generatedCache: Mutex<[Int: MyceliumArchitectGeneratedLevel]> =
    Mutex<[Int: MyceliumArchitectGeneratedLevel]>([:])

/// The generated level `number`, after the stored level `number − 1` (none for level 1), cached per process.
private func generatedLevel(_ number: Int) throws -> MyceliumArchitectGeneratedLevel {
    if let cached = generatedCache.withLock({ $0[number] }) { return cached }
    let previous: MyceliumArchitectLevel? = number > 1 ? try storedWitness(number - 1).level : nil
    let generated: MyceliumArchitectGeneratedLevel = try MyceliumArchitectGenerator.generate(
        MyceliumArchitectManifest.entries[number - 1], previous: previous)
    generatedCache.withLock { $0[number] = generated }
    return generated
}

/// The plan of a witness: its actions without the closing run.
private func plan(_ witness: MyceliumArchitectWitness) -> [MyceliumArchitectAction] {
    var result: [MyceliumArchitectAction] = []
    for action in witness.actions where action != .run { result.append(action) }
    return result
}

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: MyceliumArchitectLevel, _ actions: [MyceliumArchitectAction]) -> MyceliumArchitectPlay? {
    var play: MyceliumArchitectPlay = MyceliumArchitectPlay(level: level)
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

/// Whether `actions` then `run` win `level` through the play.
private func winsWithRun(_ level: MyceliumArchitectLevel, _ actions: [MyceliumArchitectAction]) -> Bool {
    MyceliumArchitectGenerator.replayWins(level, actions + [.run])
}

@Suite struct MyceliumArchitectCatalogTests {
    /// The pinned catalog digest: `MyceliumArchitectGenerator.digest` over the 100 levels in manifest order, measured
    /// on 2026-11-27 from the production generator. An intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest: String = "3a2b82b6363ef37ad1678847640b07e33f58e2ac2127ef39e9a34ff32797b040"

    /// The neighbouring-input seed of the invariant tests.
    static let neighbourSeed: UInt64 = 2_517

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [MyceliumArchitectManifestEntry] = MyceliumArchitectManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int] = [0, 0, 0, 0, 0]
        var seeds: Set<UInt64> = []
        for (index, entry) in entries.enumerated() {
            #expect(entry.number == index + 1)
            #expect((1...5).contains(entry.band))
            #expect((8...19).contains(entry.budget))
            perBand[entry.band - 1] += 1
            seeds.insert(entry.plannedSeed)
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        #expect(seeds.count == 100)
    }

    /// The digest over the stored levels (equal to the generated ones: see the group tests) is pinned; the ids follow
    /// the manifest; no two consecutive levels share a board (FR-R02G2202-007).
    @Test func catalogMatchesThePinnedDigestAndNeighboursDiffer() throws {
        let witnesses: [MyceliumArchitectWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [MyceliumArchitectLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == String(format: "mycelium-architect-%03d", index + 1))
            #expect(witness.level.sites != nil, "\(witness.level.id) declares no sites")
            if index > 0 {
                let before: MyceliumArchitectLevel = witnesses[index - 1].level
                #expect(!MyceliumArchitectGenerator.sameBoard(before, witness.level),
                        "\(witness.level.id) repeats its neighbour's board")
            }
        }
        let digest: String = MyceliumArchitectGenerator.digest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        var identities: [String] = []
        for level in levels { identities.append(level.fingerprint) }
        #expect(digest == PuzzleCatalog<MyceliumArchitectPuzzle>.digest(id: "mycelium-architect",
                                                                         identities: identities))
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's plan length, R02-F24's standard progression rule on the witness length
    /// in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelKeepsItsBandAndTheProgression() throws {
        let witnesses: [MyceliumArchitectWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumActions: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: MyceliumArchitectLevel = witness.level
            let entry: MyceliumArchitectManifestEntry = MyceliumArchitectManifest.entries[witness.number - 1]
            let count: Int = plan(witness).count
            #expect(witness.actions.last == .run)
            #expect(witness.actions.count == count + 1)
            #expect(count == witness.difficulty.witnessLength)
            #expect(count >= 1)
            #expect(count <= level.budget)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.seed == entry.plannedSeed)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: MyceliumArchitectBandProfile = MyceliumArchitectBandProfile.band(level.difficulty)
            #expect(count == profile.plan, "\(level.id): \(count) actions, the band's plan is \(profile.plan)")
            #expect(witness.counterexample.depth == count - 1)
            #expect(witness.difficulty.work <= MyceliumArchitectSolver.workBound)
            #expect((0..<MyceliumArchitectGenerator.candidateBound).contains(witness.skipped))
            #expect(witness.report.outcome == "won")
            difficulties.append(PuzzleDifficulty(shortest: count, explored: witness.difficulty.work))
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

    /// SC-R02G2202-001 for all 100 levels: the witness actions replayed on a play, then the run, win within the budget;
    /// the plan alone leaves the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: MyceliumArchitectLevel = witness.level
            let play: MyceliumArchitectPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == plan(witness).count)
            let before: MyceliumArchitectPlay? = played(level, plan(witness))
            #expect(before?.stage == .playing, "\(level.id) is not playing before its run")
            #expect(before?.report.wins == true, "\(level.id)")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: MyceliumArchitectWitness = try MyceliumArchitectWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == MyceliumArchitectManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// INV-06 (content), in group `group` (levels 5·group + 1 … 5·group + 5): every level has a witness that replays to
    /// a win within its budget, and its difficulty reflects the solver's actual work (work and arrangements searched
    /// below the plan equal the solver's run — the cached generation's when this process made it, else a fresh solver
    /// run — and its counterexample the solver's count at the depth below the plan). Neighbouring input, seed 2_517:
    /// one seeded witness of the group with one seeded edit — an action, a digest character or a difficulty count — is
    /// refused `r02-g22.witness` or `r02-g22.malformed`.
    @Test(arguments: Array(0..<20))
    func testMyceliumArchitectContentBoundary(group: Int) throws {
        let all: [MyceliumArchitectWitness] = try storedWitnesses()
        let groupWitnesses: [MyceliumArchitectWitness] = Array(all[(5 * group)..<(5 * group + 5)])
        for witness in groupWitnesses {
            let level: MyceliumArchitectLevel = witness.level
            let play: MyceliumArchitectPlay? = played(level, witness.actions)
            #expect(play?.stage == .won && (play?.actionsSpent ?? Int.max) <= level.budget, "\(level.id)")
            let size: Int = MyceliumArchitectBandProfile.band(level.difficulty).plan
            let cached: MyceliumArchitectGeneratedLevel? = generatedCache.withLock { $0[witness.number] }
            let solution: MyceliumArchitectSolution = try #require(
                cached?.solution ?? MyceliumArchitectSolver.solve(level, maxDepth: size))
            #expect(solution.actions == witness.actions, "\(level.id)")
            #expect(witness.difficulty.work == solution.work, "\(level.id)")
            #expect(witness.difficulty.searchedBelow == solution.countsByDepth.reduce(0, +), "\(level.id)")
            #expect(witness.counterexample.arrangements == solution.countsByDepth[size - 1], "\(level.id)")
            #expect(witness.difficulty == MyceliumArchitectDifficulty(level: level, solution: solution),
                    "\(level.id)")
        }
        // Neighbouring input: a seeded witness of the group, a seeded edit.
        var random: SeededRandom = SeededRandom(seed: Self.neighbourSeed &+ UInt64(group))
        let witness: MyceliumArchitectWitness = groupWitnesses[random.index(below: groupWitnesses.count)]
        let kind: Int = random.index(below: 3)
        let edited: MyceliumArchitectWitness
        switch kind {
        case 0:
            // An action: one seeded plan action turned into another (a nutrient into a blocker on its cell, a blocker
            // into a nutrient, a seed into the next direction).
            var actions: [MyceliumArchitectAction] = plan(witness)
            let index: Int = random.index(below: actions.count)
            switch actions[index] {
            case .nutrient(let cell): actions[index] = .blocker(cell)
            case .blocker(let cell): actions[index] = .nutrient(cell)
            case .seed(let direction):
                let next: Int = (direction.rawValue + 1) % 8
                actions[index] = .seed(try #require(MyceliumArchitectDirection(rawValue: next)))
            case .clear, .unseed, .run:
                Issue.record("\(witness.level.id): a plan action that is not a nutrient, blocker or seed")
            }
            edited = MyceliumArchitectWitness(number: witness.number, level: witness.level, actions: actions + [.run],
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
            edited = MyceliumArchitectWitness(number: witness.number, level: witness.level, actions: witness.actions,
                                              digests: digests, fingerprints: witness.fingerprints,
                                              report: witness.report, counterexample: witness.counterexample,
                                              difficulty: witness.difficulty, skipped: witness.skipped)
        default:
            // A difficulty count: the work, the arrangements searched below or the move space, one higher.
            let d: MyceliumArchitectDifficulty = witness.difficulty
            let which: Int = random.index(below: 3)
            let changed: MyceliumArchitectDifficulty = MyceliumArchitectDifficulty(
                witnessLength: d.witnessLength, terminals: d.terminals, boardCells: d.boardCells, toxins: d.toxins,
                sites: d.sites, moveSpace: d.moveSpace + (which == 2 ? 1 : 0),
                searchedBelow: d.searchedBelow + (which == 1 ? 1 : 0), work: d.work + (which == 0 ? 1 : 0),
                nearestMiss: d.nearestMiss)
            edited = MyceliumArchitectWitness(number: witness.number, level: witness.level, actions: witness.actions,
                                              digests: witness.digests, fingerprints: witness.fingerprints,
                                              report: witness.report, counterexample: witness.counterexample,
                                              difficulty: changed, skipped: witness.skipped)
        }
        #expect(edited != witness)
        do {
            _ = try MyceliumArchitectWitness.decode(edited.encoded())
            Issue.record("an edited witness of \(witness.level.id) (edit \(kind)) decodes")
        } catch {
            let code: String = error.reasonCode
            #expect(code == "r02-g22.witness" || code == "r02-g22.malformed",
                    "\(witness.level.id) edit \(kind): \(error)")
        }
        #expect(try MyceliumArchitectWitness.decode(witness.encoded()) == witness)
    }

    /// INV-12 (novelty): the mechanic is checked, not its name. Every witness is nutrient, blocker and seed actions
    /// then `run`, and removing any one action of its plan makes the run fail. Neighbouring input, seed 2_517: dropping
    /// one seeded action of a sampled witness never wins.
    @Test func testMyceliumArchitectNoveltyBoundary() throws {
        let witnesses: [MyceliumArchitectWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        for witness in witnesses {
            let level: MyceliumArchitectLevel = witness.level
            let actions: [MyceliumArchitectAction] = plan(witness)
            #expect(actions.count == witness.actions.count - 1)
            for action in actions {
                var shaped: Bool = false
                switch action {
                case .nutrient, .blocker, .seed: shaped = true
                case .clear, .unseed, .run: shaped = false
                }
                #expect(shaped, "\(level.id): \(action)")
            }
            #expect(witness.actions.last == .run)
            #expect(winsWithRun(level, actions), "\(level.id)")
            for index in 0..<actions.count {
                var reduced: [MyceliumArchitectAction] = actions
                reduced.remove(at: index)
                #expect(!winsWithRun(level, reduced), "\(level.id) still wins without action \(index + 1)")
            }
        }
        var random: SeededRandom = SeededRandom(seed: Self.neighbourSeed)
        for _ in 0..<20 {
            let witness: MyceliumArchitectWitness = witnesses[random.index(below: witnesses.count)]
            var actions: [MyceliumArchitectAction] = plan(witness)
            actions.remove(at: random.index(below: actions.count))
            #expect(!winsWithRun(witness.level, actions), "\(witness.level.id) wins with one action dropped")
        }
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte for
    /// byte (written only with MYCELIUM_ARCHITECT_WRITE_WITNESSES=1). Each level is generated after the stored level
    /// before it, which its own group checks against its regeneration; every regenerated witness replays to a win
    /// within its budget.
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["MYCELIUM_ARCHITECT_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: MyceliumArchitectGeneratedLevel = try generatedLevel(number)
            #expect(generated.level.id == String(format: "mycelium-architect-%03d", number))
            let witness: MyceliumArchitectWitness = MyceliumArchitectWitness(generated: generated)
            let replayed: MyceliumArchitectPlay? = played(witness.level, witness.actions)
            #expect(replayed?.stage == .won && (replayed?.actionsLeft ?? -1) >= 0, "\(witness.level.id)")
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
