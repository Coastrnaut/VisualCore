// MoonlitMechanismCatalogTests — feature 432 (R02-G14-02) T-R02G1402-006 (FR-R02G1402-001 … 006;
// SC-R02G1402-001 … 006; clarifications Q3 … Q5). The 100-level catalog: manifest shape (20 levels per band), the pinned
// digest, R02-F24's standard progression rule on the witness action count in manifest order and non-decreasing band
// means, every stored witness replayed to a win through the play within its budget (actions at most budget − 1 before
// the run), an independent breadth-first search on the two levels with the fewest gears in each band (every action the
// play accepts — turns, re-seats of every gear but the driver, lamp steps in range — applied through the play, states
// merged by phases and lamp height; no set-up reached in fewer actions than the plan wins, and one reached in exactly
// the plan's count does), one fully re-verified decode per band, and the witness files in
// docs/games/moonlit-mechanism/levels/ compared byte for byte with the regenerated witnesses in 5 groups of 20 levels.
// The files are written only when MOONLIT_MECHANISM_WRITE_WITNESSES=1 is set. Generated levels are cached per process.
// Stored files are read with the plain decoder except in the re-verified test. Explicit types and plain loops (CI
// type-check rule).
import Foundation
@testable import MoonlitMechanismCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, MoonlitMechanism, the package,
/// Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/moonlit-mechanism/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(MoonlitMechanismGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> MoonlitMechanismWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(MoonlitMechanismWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[MoonlitMechanismWitness], any Error> = Result {
    var result: [MoonlitMechanismWitness] = []
    for entry in MoonlitMechanismManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [MoonlitMechanismWitness] { try stored.get() }

/// The generated levels of this test process, by manifest number (each entry generated at most once).
private final class GeneratedCache: @unchecked Sendable {
    private let lock: NSLock = NSLock()
    private var levels: [Int: MoonlitMechanismGenerated] = [:]

    /// The generated level of manifest number `number` (generation is deterministic, so a rare concurrent duplicate
    /// is harmless; the lock guards only the table).
    func generated(_ number: Int) throws -> MoonlitMechanismGenerated {
        lock.lock()
        let cached: MoonlitMechanismGenerated? = levels[number]
        lock.unlock()
        if let cached { return cached }
        let generated: MoonlitMechanismGenerated = try MoonlitMechanismGenerator.generate(
            MoonlitMechanismManifest.entries[number - 1])
        lock.lock()
        levels[number] = generated
        lock.unlock()
        return generated
    }
}

private let generatedCache: GeneratedCache = GeneratedCache()

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: MoonlitMechanismLevel, _ actions: [MoonlitMechanismAction]) -> MoonlitMechanismPlay? {
    var play = MoonlitMechanismPlay(level: level)
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

/// Every action the play could be offered before a run, in a fixed order: turns −1, +1; re-seats of every gear but the
/// driver, −1 then +1; lamp steps −1, +1.
private func setUpActions(_ level: MoonlitMechanismLevel) -> [MoonlitMechanismAction] {
    var actions: [MoonlitMechanismAction] = [.turn(-1), .turn(1)]
    for gear in 1..<level.gears.count {
        actions.append(.reseat(gear, -1))
        actions.append(.reseat(gear, 1))
    }
    actions.append(.lamp(-1))
    actions.append(.lamp(1))
    return actions
}

/// A breadth-first search through the play: the depth (actions before the run) of the first set-up reached whose run
/// wins, searching at most `limit` actions, with states merged by phases and lamp height; nil when none within the
/// limit.
private func shortestWin(_ level: MoonlitMechanismLevel, limit: Int) -> Int? {
    guard let start = played(level, []) else { return nil }
    var seen: Set<[Int]> = [start.phases + [start.height]]
    var frontier: [MoonlitMechanismPlay] = [start]
    var depth: Int = 0
    while depth <= limit {
        for play in frontier where level.run(phases: play.phases, height: play.height).outcome == .won { return depth }
        if depth == limit { return nil }
        var next: [MoonlitMechanismPlay] = []
        for play in frontier {
            for action in setUpActions(level) {
                var copy: MoonlitMechanismPlay = play
                do { try copy.apply(action, expecting: copy.fingerprint) } catch { continue }
                guard copy.stage == .playing || copy.stage == .failed else { continue }
                let key: [Int] = copy.phases + [copy.height]
                if seen.insert(key).inserted { next.append(copy) }
            }
        }
        frontier = next
        depth += 1
    }
    return nil
}

/// The two stored witnesses of `band` with the fewest gears (then the lowest number).
private func fewestGears(band: Int) throws -> [MoonlitMechanismWitness] {
    var candidates: [MoonlitMechanismWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort { ($0.level.gears.count, $0.number) < ($1.level.gears.count, $1.number) }
    return Array(candidates.prefix(2))
}

@Suite struct MoonlitMechanismCatalogTests {
    /// The pinned catalog digest: `PuzzleCatalog<MoonlitMechanismRules>.digest(id: "moonlit-mechanism", identities:)`
    /// over the 100 level fingerprints in manifest order, computed on 2026-11-24 from the generated catalog. An
    /// intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest = "7de6360319ce24f0874ac9d14907ab2ade7f0da0c365815070da258d183c9744"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [MoonlitMechanismManifestEntry] = MoonlitMechanismManifest.entries
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
        let witnesses: [MoonlitMechanismWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [MoonlitMechanismLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == MoonlitMechanismGenerator.levelID(index + 1))
        }
        let digest: String = MoonlitMechanismGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's plan range, R02-F24's standard progression rule on the witness action
    /// count in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [MoonlitMechanismWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumActions: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: MoonlitMechanismLevel = witness.level
            let entry: MoonlitMechanismManifestEntry = MoonlitMechanismManifest.entries[witness.number - 1]
            let count: Int = witness.actions.count - 1
            #expect(witness.actions.last == .run)
            #expect(count == witness.difficulty.actions)
            #expect(count >= 1)
            #expect(count <= level.budget - 1)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: MoonlitMechanismBandProfile = MoonlitMechanismBandProfile.of(band: level.difficulty)
            #expect(profile.planRange.contains(count), "\(level.id): \(count) actions outside the band's range")
            #expect(profile.gears.contains(level.gears.count))
            #expect(witness.counterexample.norm == count - 1)
            #expect(witness.difficulty.work <= MoonlitMechanismSolver.workBound)
            #expect((0..<MoonlitMechanismGenerator.maxCandidates).contains(witness.skipped))
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

    /// SC-R02G1402-001 for all 100 levels: the witness actions replayed on a play win on the last one (the run) within
    /// the budget, and the actions before it leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: MoonlitMechanismLevel = witness.level
            let play: MoonlitMechanismPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == witness.actions.count)
            let short: MoonlitMechanismPlay? = played(level, Array(witness.actions.dropLast()))
            #expect(short?.stage == .playing, "\(level.id) is not playing before its run")
        }
    }

    /// SC-R02G1402-002 on the two levels with the fewest gears in each band: the breadth-first search through the play
    /// finds its first winning set-up at exactly the plan's action count.
    @Test(arguments: [1, 2, 3, 4, 5])
    func noShorterSequenceWins(band: Int) throws {
        let witnesses: [MoonlitMechanismWitness] = try fewestGears(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let size: Int = witness.difficulty.actions
            let first: Int? = shortestWin(witness.level, limit: size)
            #expect(first == size, "\(witness.level.id): the first win is at \(String(describing: first))")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: MoonlitMechanismWitness = try MoonlitMechanismWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == MoonlitMechanismManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 20·group + 1 … 20·group + 20) equal the regenerated witnesses byte
    /// for byte (written only with MOONLIT_MECHANISM_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<5))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["MOONLIT_MECHANISM_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (20 * group + 1)...(20 * group + 20) {
            let generated: MoonlitMechanismGenerated = try generatedCache.generated(number)
            #expect(generated.level.id == MoonlitMechanismGenerator.levelID(number))
            let witness: MoonlitMechanismWitness = try MoonlitMechanismWitness.make(generated)
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
