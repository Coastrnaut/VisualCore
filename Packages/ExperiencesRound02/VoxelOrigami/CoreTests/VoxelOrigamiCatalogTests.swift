// VoxelOrigamiCatalogTests — feature 442 (R02-G15-02) T-R02G1502-006 (FR-R02G1502-001 … 006; SC-R02G1502-001 … 006;
// clarifications Q3 … Q5). The 100-level catalog: manifest shape (20 levels per band), the pinned digest, R02-F24's
// standard progression rule on the witness turn count in manifest order and non-decreasing band means, every stored
// witness replayed to a win through the play within its budget, an independent depth-first enumeration on the two levels
// with the fewest cubes in each band (every turn the play accepts, applied through the play; a pair of state and turns
// left already explored is not explored again, which loses no sequence; no sequence shorter than the plan wins, and one
// of exactly the plan's length does), one fully re-verified decode per band, and the witness files in
// docs/games/voxel-origami/levels/ compared byte for byte with the regenerated witnesses in 10 groups of 10 levels (20 levels of band 5, generated and
// re-solved, took about 13 s in a debug build; 10 stay under 10 s). The
// files are written only when VOXEL_ORIGAMI_WRITE_WITNESSES=1 is set. Generated levels are cached per process. Stored
// files are read with the plain decoder except in the re-verified test. Explicit types and plain loops (CI type-check
// rule). Modelled on VoxelOrigamiCatalogTests (feature 432).
import Foundation
@testable import VoxelOrigamiCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, VoxelOrigami, the package,
/// Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/voxel-origami/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(VoxelOrigamiGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> VoxelOrigamiWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(VoxelOrigamiWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[VoxelOrigamiWitness], any Error> = Result {
    var result: [VoxelOrigamiWitness] = []
    for entry in VoxelOrigamiManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [VoxelOrigamiWitness] { try stored.get() }

/// The generated levels of this test process, by manifest number (each entry generated at most once).
private final class GeneratedCache: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var levels: [Int: VoxelOrigamiGenerated] = [:]

    /// The generated level of manifest number `number` (generation is deterministic, so a rare concurrent duplicate
    /// is harmless; the lock guards only the table).
    func generated(_ number: Int) throws -> VoxelOrigamiGenerated {
        lock.lock()
        let cached: VoxelOrigamiGenerated? = levels[number]
        lock.unlock()
        if let cached { return cached }
        let generated: VoxelOrigamiGenerated = try VoxelOrigamiGenerator.generate(
            VoxelOrigamiManifest.entries[number - 1])
        lock.lock()
        levels[number] = generated
        lock.unlock()
        return generated
    }
}

private let generatedCache: GeneratedCache = GeneratedCache()

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: VoxelOrigamiLevel, _ actions: [VoxelOrigamiAction]) -> VoxelOrigamiPlay? {
    var play = VoxelOrigamiPlay(level: level)
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

/// Every turn the play could be offered, in a fixed order: hinges ascending, −1 then +1.
private func turnActions(_ level: VoxelOrigamiLevel) -> [VoxelOrigamiAction] {
    var actions: [VoxelOrigamiAction] = []
    for hinge in 1..<level.cubes.count {
        actions.append(.turn(hinge, -1))
        actions.append(.turn(hinge, 1))
    }
    return actions
}

/// A depth-first enumeration through the play: whether some sequence of at most `left` turns the play accepts, from
/// `play`, wins. A (quarter turns, turns left) pair already explored is skipped: the sequences from it were all tried.
private func winsWithin(_ play: VoxelOrigamiPlay, left: Int, actions: [VoxelOrigamiAction],
                        explored: inout Set<[Int]>) -> Bool {
    if play.stage == .won { return true }
    guard left > 0, play.stage == .playing else { return false }
    guard explored.insert(play.turns + [left]).inserted else { return false }
    for action in actions {
        var copy: VoxelOrigamiPlay = play
        do { try copy.apply(action, expecting: copy.fingerprint) } catch { continue }
        if winsWithin(copy, left: left - 1, actions: actions, explored: &explored) { return true }
    }
    return false
}

/// Whether a sequence of at most `limit` turns wins `level`.
private func winsIn(_ level: VoxelOrigamiLevel, limit: Int) -> Bool {
    guard let start = played(level, []) else { return false }
    var explored: Set<[Int]> = []
    return winsWithin(start, left: limit, actions: turnActions(level), explored: &explored)
}

/// The two stored witnesses of `band` with the fewest cubes (then the lowest number).
private func fewestCubes(band: Int) throws -> [VoxelOrigamiWitness] {
    var candidates: [VoxelOrigamiWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort { ($0.level.cubes.count, $0.number) < ($1.level.cubes.count, $1.number) }
    return Array(candidates.prefix(2))
}

@Suite struct VoxelOrigamiCatalogTests {
    /// The pinned catalog digest: `PuzzleCatalog<VoxelOrigamiRules>.digest(id: "voxel-origami", identities:)`
    /// over the 100 level fingerprints in manifest order, computed on 2026-11-24 from the generated catalog. An
    /// intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest = "b02e58ecabf2a0ff47050b17f42b7d0dc9a49a3ccb68af604c12a0610edff611"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [VoxelOrigamiManifestEntry] = VoxelOrigamiManifest.entries
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

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the group tests) is pinned;
    /// the ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [VoxelOrigamiWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [VoxelOrigamiLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == VoxelOrigamiGenerator.levelID(index + 1))
        }
        let digest: String = VoxelOrigamiGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's plan range, R02-F24's standard progression rule on the witness turn
    /// count in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [VoxelOrigamiWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumActions: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: VoxelOrigamiLevel = witness.level
            let entry: VoxelOrigamiManifestEntry = VoxelOrigamiManifest.entries[witness.number - 1]
            let count: Int = witness.actions.count
            #expect(count == witness.difficulty.turns)
            #expect(count >= 1)
            #expect(count <= level.budget)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.orientations == entry.orientations)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: VoxelOrigamiBandProfile = VoxelOrigamiBandProfile.of(band: level.difficulty)
            #expect(profile.planRange.contains(count), "\(level.id): \(count) turns outside the band's range")
            #expect(profile.cubes.contains(level.cubes.count))
            #expect(witness.counterexample.depth == count - 1)
            #expect(witness.difficulty.work <= VoxelOrigamiSolver.workBound)
            #expect((0..<VoxelOrigamiGenerator.maxCandidates).contains(witness.skipped))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumActions[level.difficulty - 1] += count
            countPerBand[level.difficulty - 1] += 1
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        #expect(countPerBand == [20, 20, 20, 20, 20])
        // Twenty levels per band, so the sums order as the means do.
        for band in 1..<5 {
            #expect(sumActions[band] >= sumActions[band - 1], "mean actions fall at band \(band + 1): \(sumActions)")
        }
    }

    /// SC-R02G1502-001 for all 100 levels: the witness turns replayed on a play win on the last one within the budget,
    /// and the turns before it leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: VoxelOrigamiLevel = witness.level
            let play: VoxelOrigamiPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == witness.actions.count)
            let short: VoxelOrigamiPlay? = played(level, Array(witness.actions.dropLast()))
            #expect(short?.stage == .playing, "\(level.id) is not playing before its last turn")
        }
    }

    /// SC-R02G1502-002 on the two levels with the fewest cubes in each band: the depth-first enumeration through the play
    /// finds no win in fewer turns than the plan and a win in exactly its turns.
    @Test(arguments: [1, 2, 3, 4, 5])
    func noShorterSequenceWins(band: Int) throws {
        let witnesses: [VoxelOrigamiWitness] = try fewestCubes(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let size: Int = witness.difficulty.turns
            #expect(!winsIn(witness.level, limit: size - 1), "\(witness.level.id) is won in fewer turns")
            #expect(winsIn(witness.level, limit: size), "\(witness.level.id) is not won in its turns")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: VoxelOrigamiWitness = try VoxelOrigamiWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == VoxelOrigamiManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 10·group + 1 … 10·group + 10) equal the regenerated witnesses byte
    /// for byte (written only with VOXEL_ORIGAMI_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<10))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["VOXEL_ORIGAMI_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: VoxelOrigamiGenerated = try generatedCache.generated(number)
            #expect(generated.level.id == VoxelOrigamiGenerator.levelID(number))
            let witness: VoxelOrigamiWitness = try VoxelOrigamiWitness.make(generated)
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
    }
}
