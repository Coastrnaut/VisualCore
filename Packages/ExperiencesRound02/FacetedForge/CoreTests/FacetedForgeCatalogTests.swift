// FacetedForgeCatalogTests — feature 372 (R02-G08-02) T-R02G0802-006 (FR-R02G0802-001, 003, 004, 005;
// SC-R02G0802-001 … 005). The 100-level catalog: manifest shape, the pinned digest, the progression rule and band
// means, every stored witness replayed to a win through the play within its budget and with exactly its lower bound of
// cuts, an independent check on two levels per band (the pieces recounted after a fresh replay, the lower bound met,
// and for two-cut band-1 levels every single cut tried without a win), one fully re-verified decode per band, and the
// witness files in docs/games/faceted-forge/levels/ compared byte for byte with the regenerated witnesses in 20 groups
// of 5 levels. The files are written only when FACETED_FORGE_WRITE_WITNESSES=1 is set. Stored files are read with the
// plain decoder (the level re-checked, the proof not re-run) except in the re-verified test, so no test re-solves the
// whole catalog. Test data uses explicit types and plain loops (CI type-check rule).
@testable import FacetedForgeCore
import Foundation
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/faceted-forge/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(FacetedForgeGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder (the level re-checked; the proof not re-run).
private func storedWitness(_ number: Int) throws -> FacetedForgeWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(FacetedForgeWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[FacetedForgeWitness], any Error> = Result {
    var result: [FacetedForgeWitness] = []
    for entry in FacetedForgeManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [FacetedForgeWitness] { try stored.get() }

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied.
private func played(_ level: FacetedForgeLevel, _ actions: [FacetedForgeAction]) throws -> FacetedForgePlay {
    var play = FacetedForgePlay(level: level)
    try play.handle(.begin)
    if play.stage == .tutorial { try play.handle(.dismissTutorial) }
    for action in actions { try play.apply(action, expecting: play.fingerprint) }
    return play
}

@Suite struct FacetedForgeCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "ceb59042752490ceef76b62163e9f05414950788c74d2a95d80ef337a28a924c"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [FacetedForgeManifestEntry] = FacetedForgeManifest.entries
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
        #expect(entries[0].seed == 0x84906690be4d2b00)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the group tests) is pinned;
    /// the ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [FacetedForgeWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [FacetedForgeLevel] = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == FacetedForgeGenerator.levelID(index + 1))
        }
        let digest: String = FacetedForgeGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(levels.map(\.fingerprint)).count == 100)
    }

    /// Winnable within the budget at the lower bound, inside each band's cut range; the progression rule and the band
    /// means of the smallest cut count (never falling) hold over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [FacetedForgeWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumSmallest: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: FacetedForgeLevel = witness.level
            #expect(witness.actions.count == witness.difficulty.smallest)
            #expect(witness.actions.count == FacetedForgeSolver.lowerBound(level))
            #expect(witness.actions.count <= level.budget)
            let profile: FacetedForgeBandProfile = FacetedForgeBandProfile.of(band: level.difficulty)
            #expect(profile.cuts.contains(witness.difficulty.smallest))
            #expect(level.sliver == FacetedForgeGenerator.sliver)
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumSmallest[level.difficulty - 1] += witness.difficulty.smallest
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumSmallest[band] >= sumSmallest[band - 1],
                    "mean smallest falls at band \(band + 1): \(sumSmallest)")
        }
    }

    /// SC-R02G0802-001 and 005 for all 100 levels: the witness cuts replayed on a play win on the last cut within the
    /// budget, and the witness one cut short is not yet won.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: FacetedForgeLevel = witness.level
            let play: FacetedForgePlay = try played(level, witness.actions)
            #expect(play.stage == .won, "\(level.id) is not won by its witness")
            #expect(play.cuts <= level.budget)
            let short: FacetedForgePlay = try played(level, Array(witness.actions.dropLast()))
            #expect(short.stage == .playing, "\(level.id) is won one cut short")
            #expect(short.pieces.count == level.target.count - 1)
        }
    }

    /// SC-R02G0802-002 on two levels per band (1, 11, 21, … 91): a fresh replay recounts the pieces and their shares
    /// independently of the solver, the count meets the lower bound, and for band-1 levels of two cuts every single cut
    /// of the crystal is tried and none wins.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theLowerBoundIsMetAndCheckedIndependently(number: Int) throws {
        let witness: FacetedForgeWitness = try storedWitness(number)
        let level: FacetedForgeLevel = witness.level
        let play: FacetedForgePlay = try played(level, witness.actions)
        #expect(play.pieces.count == level.target.count)
        #expect(play.pieces.count == witness.actions.count + 1, "each cut adds exactly one piece")
        var have: [FacetedForgeTargetPiece] = []
        var total: FacetedForgeFraction = .zero
        for piece in play.pieces {
            let share: FacetedForgeFraction = try piece.volume.dividing(by: level.crystal.volume)
            have.append(FacetedForgeTargetPiece(share: share, faces: piece.faceCount))
            total = try total.adding(share)
        }
        #expect(have.sorted() == level.target)
        #expect(total == .one)
        guard witness.actions.count == 2 else { return }
        for direction in FacetedForgeDirection.all.indices {
            for depth in FacetedForgeHalfSpace.depths
            where level.crystal.isCrossed(direction: direction, depth: depth) {
                let halves = try level.crystal.cut(direction: direction, depth: depth)
                let pieces: [FacetedForgePiece] = [halves.below, halves.above]
                #expect(!FacetedForgeSolver.matches(pieces, level.target, crystal: level.crystal.volume))
            }
        }
    }

    /// One stored witness per band decodes with full re-verification (replay, solver, counterexample).
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: FacetedForgeWitness = try FacetedForgeWitness.decode(data)
        #expect(witness.number == number)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte for
    /// byte (written only with FACETED_FORGE_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["FACETED_FORGE_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: FacetedForgeGenerated = try FacetedForgeGenerator.generate(
                FacetedForgeManifest.entries[number - 1])
            let witness: FacetedForgeWitness = try FacetedForgeWitness.make(generated)
            let data: Data = witness.encoded()
            let url: URL = witnessDirectory.appendingPathComponent(witnessName(number))
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(witnessName(number)) differs from the regenerated witness")
        }
    }

    /// Feature 373 (R02-G08-03): the adapter's table of certified candidates equals the witnesses' `skipped`, and the
    /// level it certifies directly from that candidate is each stored witness's level, with the same solution (levels
    /// 10·group + 1 … 10·group + 10, in 10 parallel groups).
    @Test(arguments: Array(0..<10))
    func theAdapterCertifiesTheStoredLevelsFromTheirCandidates(group: Int) throws {
        #expect(FacetedForgeExperienceCore.certifiedCandidates.count == 100)
        for number in (10 * group + 1)...(10 * group + 10) {
            let witness: FacetedForgeWitness = try storedWitness(number)
            #expect(FacetedForgeExperienceCore.certifiedCandidates[number - 1] == witness.skipped, "level \(number)")
            let generated: FacetedForgeGenerated = try FacetedForgeExperienceCore.generated(number: number)
            #expect(generated.level == witness.level && generated.skipped == witness.skipped, "level \(number)")
            #expect(generated.solution.actions == witness.actions, "level \(number)")
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }
}
