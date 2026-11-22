// NocturneGardenCatalogTests — feature 382 (R02-G09-02) T-R02G0902-006 (FR-R02G0902-001, 003, 004, 005;
// SC-R02G0902-001 … 005). The 100-level catalog: manifest shape, the pinned digest, the progression rule and band
// means, every stored witness replayed to a win through the play within its budget and with exactly its lower bound of
// moves (and not won one move short), an independent check on two levels per band (the single-plant cover recomputed by
// brute force through the kernel's own bloom cells and the needed count recomputed from the match, giving the same
// lower bound), one fully re-verified decode per band, and the witness files in docs/games/nocturne-garden/levels/
// compared byte for byte with the regenerated witnesses in 20 groups of 5 levels. The files are written only when
// NOCTURNE_GARDEN_WRITE_WITNESSES=1 is set. Stored files are read with the plain decoder (the level re-checked, the
// proof not re-run) except in the re-verified test, so no test re-solves the whole catalog. Test data uses explicit
// types and plain loops (CI type-check rule).
@testable import NocturneGardenCore
import Foundation
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/nocturne-garden/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(NocturneGardenGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder (the level re-checked; the proof not re-run).
private func storedWitness(_ number: Int) throws -> NocturneGardenWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(NocturneGardenWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[NocturneGardenWitness], any Error> = Result {
    var result: [NocturneGardenWitness] = []
    for entry in NocturneGardenManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [NocturneGardenWitness] { try stored.get() }

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied.
private func played(_ level: NocturneGardenLevel, _ actions: [NocturneGardenAction]) throws -> NocturneGardenPlay {
    var play = NocturneGardenPlay(level: level)
    try play.handle(.begin)
    if play.stage == .tutorial { try play.handle(.dismissTutorial) }
    for action in actions { try play.apply(action, expecting: play.fingerprint) }
    return play
}

@Suite struct NocturneGardenCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "ce13750aa652c528fe9655fbf4b8fac374bc4782059391b27db5c2cdcbfc52dd"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [NocturneGardenManifestEntry] = NocturneGardenManifest.entries
        #expect(entries.count == 100)
        var perBand: [Int] = [0, 0, 0, 0, 0]
        for (index, entry) in entries.enumerated() {
            #expect(entry.number == index + 1)
            #expect((1...5).contains(entry.band))
            #expect((8...19).contains(entry.budget))
            perBand[entry.band - 1] += 1
        }
        #expect(perBand == [20, 20, 20, 20, 20])
        #expect(Set(entries.map(\.seed)).count == 100)
        #expect(entries[0].seed == 0x5674e2b4cafcef9e)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the group tests) is pinned;
    /// the ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [NocturneGardenWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [NocturneGardenLevel] = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == NocturneGardenGenerator.levelID(index + 1))
        }
        let digest: String = NocturneGardenGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(levels.map(\.fingerprint)).count == 100)
    }

    /// Winnable within the budget at the lower bound, inside each band's range; the progression rule and the band
    /// means of the smallest move count (never falling) hold over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [NocturneGardenWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumSmallest: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: NocturneGardenLevel = witness.level
            #expect(witness.actions.count == witness.difficulty.smallest)
            #expect(witness.actions.count == witness.bound.smallest)
            #expect(witness.actions.count <= level.budget)
            let profile: NocturneGardenBandProfile = NocturneGardenBandProfile.of(band: level.difficulty)
            #expect(profile.smallest.contains(witness.difficulty.smallest))
            #expect(level.width == profile.width && level.height == profile.height)
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumSmallest[level.difficulty - 1] += witness.difficulty.smallest
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumSmallest[band] >= sumSmallest[band - 1],
                    "mean smallest falls at band \(band + 1): \(sumSmallest)")
        }
    }

    /// SC-R02G0902-001 and 005 for all 100 levels: the witness actions replayed on a play win on the last action within
    /// the budget, and the witness one action short is not yet won, its shared cells short of the need.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: NocturneGardenLevel = witness.level
            let play: NocturneGardenPlay = try played(level, witness.actions)
            #expect(play.stage == .won, "\(level.id) is not won by its witness")
            #expect(play.moves <= level.budget)
            let short: NocturneGardenPlay = try played(level, Array(witness.actions.dropLast()))
            #expect(short.stage == .playing, "\(level.id) is won one move short")
            #expect(short.match.shared == witness.nearMiss.shared)
            #expect(witness.nearMiss.shared < witness.nearMiss.needed)
        }
    }

    /// SC-R02G0902-002 on two levels per band (1, 11, 21, … 91): the needed count from the match and the single-plant
    /// cover at every allowed elevation, recomputed by brute force over every plant with the kernel's own bloom cells
    /// (not the solver's stamps), give a lower bound equal to the witness's length.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theLowerBoundIsMetAndCheckedIndependently(number: Int) throws {
        let witness: NocturneGardenWitness = try storedWitness(number)
        let level: NocturneGardenLevel = witness.level
        let p: Int = level.required.numerator
        let q: Int = level.required.denominator
        var needed: Int = 0
        while needed * q < p * level.target.count { needed += 1 }
        var best: Int = Int.max
        for elevation in level.elevations.sorted() {
            var cover: Int = 0
            for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 {
                for size in level.sizes.sorted() {
                    for row in 0..<level.height {
                        for column in 0..<level.width {
                            let bloom = NocturneGardenBloom(kind: kind, column: column, row: row, size: size)
                            let cells: Set<Int> = bloom.cells(elevation: elevation, width: level.width,
                                                              height: level.height)
                            guard cells.intersection(level.forbidden).count <= level.leakAllowance else { continue }
                            cover = max(cover, cells.intersection(level.target).count)
                        }
                    }
                }
            }
            guard cover > 0 else { continue }
            let value: Int = (elevation == level.sun ? 0 : 1) + (needed + cover - 1) / cover
            best = min(best, value)
        }
        #expect(needed == witness.bound.needed)
        #expect(best == witness.actions.count, "\(level.id): brute-force bound \(best)")
    }

    /// One stored witness per band decodes with full re-verification (provenance, replay, bound, near miss).
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: NocturneGardenWitness = try NocturneGardenWitness.decode(data)
        #expect(witness.number == number)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte for
    /// byte (written only with NOCTURNE_GARDEN_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["NOCTURNE_GARDEN_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: NocturneGardenGenerated = try NocturneGardenGenerator.generate(
                NocturneGardenManifest.entries[number - 1])
            let witness: NocturneGardenWitness = try NocturneGardenWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(number))
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(witnessName(number)) differs from the regenerated witness")
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }
}
