// MicroscopicAuroraCatalogTests — feature 482 (R02-G19-02) T-R02G1902-006 (FR-R02G1902-001 … 007; SC-R02G1902-001 …
// 005; clarifications Q1 … Q5). The 100-level catalog: manifest shape (20 levels per band), the pinned digest,
// R02-F24's standard progression rule on the witness length in manifest order and non-decreasing band means, adjacent
// levels with different stencils, every stored witness replayed to a win through the play within its budget, an
// independent enumeration on the two levels with the fewest sites, then fewest swimmers, in each band (ties by level
// number: every set of wells on distinct sites with fewer wells than the plan, judged by the kernel's swim without the
// solver's loss order: none wins, and one with exactly the plan's wells does), one fully re-verified decode per band,
// and the witness files in docs/games/microscopic-aurora/levels/ compared byte for byte with the regenerated witnesses
// in 20 groups of 5 levels (each level generated after the stored level before it, the neighbour rule's input). The
// files are written only when MICROSCOPIC_AURORA_WRITE_WITNESSES=1 is set, with `swift test --no-parallel` so the
// groups run in order (a group reads the level the group before it wrote). Stored files are read with the plain decoder
// except in the re-verified test. Explicit types and plain loops (CI type-check rule). Modelled on
// MicroscopicAuroraCatalogTests (feature 472).
import Foundation
@testable import MicroscopicAuroraCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, MicroscopicAurora, the
/// package, Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/microscopic-aurora/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(MicroscopicAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> MicroscopicAuroraWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(MicroscopicAuroraWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[MicroscopicAuroraWitness], any Error> = Result {
    var result: [MicroscopicAuroraWitness] = []
    for entry in MicroscopicAuroraManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [MicroscopicAuroraWitness] { try stored.get() }

/// The placements of a witness (its actions without the closing play).
private func changes(_ witness: MicroscopicAuroraWitness) -> [MicroscopicAuroraAction] {
    var result: [MicroscopicAuroraAction] = []
    for action in witness.actions where action != .play { result.append(action) }
    return result
}

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: MicroscopicAuroraLevel, _ actions: [MicroscopicAuroraAction])
    -> MicroscopicAuroraPlay? {
    var play = MicroscopicAuroraPlay(level: level)
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

/// Whether some set of at most `limit` wells on distinct sites of `level` wins, judged by the kernel's swim (an
/// enumeration of its own, independent of the solver's order and loss).
private func winsWithin(_ level: MicroscopicAuroraLevel, limit: Int) -> Bool {
    let sites: [MicroscopicAuroraCell] = level.sites ?? []
    var current: [MicroscopicAuroraWell] = []
    func search(from start: Int) -> Bool {
        if MicroscopicAuroraDish.report(level, wells: current).wins { return true }
        if current.count == limit { return false }
        var site: Int = start
        while site < sites.count {
            for strength in 1...4 {
                for sense in [MicroscopicAuroraSense.counterclockwise, MicroscopicAuroraSense.clockwise] {
                    current.append(MicroscopicAuroraWell(cell: sites[site], strength: strength, sense: sense))
                    let found: Bool = search(from: site + 1)
                    current.removeLast()
                    if found { return true }
                }
            }
            site += 1
        }
        return false
    }
    return search(from: 0)
}

/// The two stored witnesses of `band` with the fewest sites, then the fewest swimmers (then the lowest number).
private func fewestSites(band: Int) throws -> [MicroscopicAuroraWitness] {
    var candidates: [MicroscopicAuroraWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort {
        ($0.level.sites?.count ?? 0, $0.level.swimmers.count, $0.number)
            < ($1.level.sites?.count ?? 0, $1.level.swimmers.count, $1.number)
    }
    return Array(candidates.prefix(2))
}

@Suite struct MicroscopicAuroraCatalogTests {
    /// The pinned catalog digest: `PuzzleCatalog<MicroscopicAuroraPuzzle>.digest(id: "microscopic-aurora",
    /// identities:)` over the 100 level fingerprints in manifest order, computed on 2026-11-26 from the generated
    /// catalog. An intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest = "03c1dc197f26f838811878aa6a1b0e5ca8c8a82704c10ba01738dea106bd3329"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [MicroscopicAuroraManifestEntry] = MicroscopicAuroraManifest.entries
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
    /// the ids follow the manifest; adjacent levels have different stencils (FR-R02G1902-007).
    @Test func catalogMatchesThePinnedDigestAndNeighboursDiffer() throws {
        let witnesses: [MicroscopicAuroraWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [MicroscopicAuroraLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == MicroscopicAuroraGenerator.levelID(index + 1))
            if index > 0 {
                #expect(witnesses[index - 1].level.stencil != witness.level.stencil, "\(witness.level.id) repeats")
            }
        }
        let digest: String = MicroscopicAuroraGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's plan range, R02-F24's standard progression rule on the witness length
    /// in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [MicroscopicAuroraWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumPlacements: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: MicroscopicAuroraLevel = witness.level
            let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[witness.number - 1]
            let count: Int = changes(witness).count
            #expect(witness.actions.last == .play)
            #expect(witness.actions.count == count + 1)
            #expect(count == witness.difficulty.placements)
            #expect(count >= 1)
            #expect(count <= level.budget)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: MicroscopicAuroraBandProfile = MicroscopicAuroraBandProfile.of(band: level.difficulty)
            #expect(count == profile.plan, "\(level.id): \(count) placements, the band's plan is \(profile.plan)")
            #expect(level.sites?.count == profile.sites)
            #expect(profile.swarm.contains(level.swimmers.count))
            #expect(profile.stencil.contains(level.stencil.count))
            #expect(profile.coverage.contains(level.coverage))
            #expect(profile.lengths.contains(level.length))
            #expect(level.placedWells.isEmpty)
            #expect(witness.counterexample.depth == count - 1)
            #expect(witness.difficulty.work <= MicroscopicAuroraSolver.workBound)
            #expect((0..<MicroscopicAuroraGenerator.maxCandidates).contains(witness.skipped))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumPlacements[level.difficulty - 1] += count
            countPerBand[level.difficulty - 1] += 1
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        #expect(countPerBand == [20, 20, 20, 20, 20])
        // Twenty levels per band, so the sums order as the means do.
        for band in 1..<5 {
            #expect(sumPlacements[band] >= sumPlacements[band - 1],
                    "mean placements fall at band \(band + 1): \(sumPlacements)")
        }
    }

    /// SC-R02G1902-001 for all 100 levels: the witness placements replayed on a play, then the play, win within the
    /// budget; the placements alone leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: MicroscopicAuroraLevel = witness.level
            let play: MicroscopicAuroraPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == changes(witness).count)
            let before: MicroscopicAuroraPlay? = played(level, changes(witness))
            #expect(before?.stage == .playing, "\(level.id) is not playing before its play")
        }
    }

    /// SC-R02G1902-002 on the two levels with the fewest sites, then swimmers, in each band: the independent
    /// enumeration finds no win with fewer wells than the plan and a win with exactly its wells.
    @Test(arguments: [1, 2, 3, 4, 5])
    func noSetWithFewerWellsWins(band: Int) throws {
        let witnesses: [MicroscopicAuroraWitness] = try fewestSites(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let size: Int = witness.difficulty.placements
            #expect(!winsWithin(witness.level, limit: size - 1), "\(witness.level.id) is won with fewer wells")
            #expect(winsWithin(witness.level, limit: size), "\(witness.level.id) is not won with its wells")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: MicroscopicAuroraWitness = try MicroscopicAuroraWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == MicroscopicAuroraManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte
    /// for byte (written only with MICROSCOPIC_AURORA_WRITE_WITNESSES=1). Each level is generated after the level
    /// before it — the stored one for the group's first level, which its own group checks against its regeneration.
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["MICROSCOPIC_AURORA_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        var previous: MicroscopicAuroraLevel? = nil
        if group > 0 { previous = try storedWitness(5 * group).level }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: MicroscopicAuroraGenerated = try MicroscopicAuroraGenerator.generate(
                MicroscopicAuroraManifest.entries[number - 1], previous: previous)
            #expect(generated.level.id == MicroscopicAuroraGenerator.levelID(number))
            let witness: MicroscopicAuroraWitness = try MicroscopicAuroraWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(number))
            if write { try data.write(to: url) }
            let storedData: Data = try Data(contentsOf: url)
            #expect(storedData == data, "\(witnessName(number)) differs from the regenerated witness")
            previous = generated.level
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let all: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
        var names: [String] = []
        for name in all where name.hasSuffix(".witness.json") { names.append(name) }
        #expect(names.count == 100)
    }
}
