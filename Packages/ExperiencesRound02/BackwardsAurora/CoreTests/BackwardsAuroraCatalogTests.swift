// BackwardsAuroraCatalogTests — feature 392 (R02-G10-02) T-R02G1002-006 (FR-R02G1002-001, 003, 004, 005;
// SC-R02G1002-001 … 005). The 100-level catalog: manifest shape, the pinned digest, the progression rule and band
// means, every stored witness replayed to a win through the play within its budget and with exactly its lower bound of
// reversals (and not won one reversal short), an independent check on two levels per band (the opening's bad bends
// recomputed from second differences of the stored samples, and no single reversal of the opening removing more than
// four of them), one fully re-verified decode per band, and the witness files in docs/games/backwards-aurora/levels/
// compared byte for byte with the regenerated witnesses in 20 groups of 5 levels. The files are written only when
// BACKWARDS_AURORA_WRITE_WITNESSES=1 is set. Stored files are read with the plain decoder (the level re-checked, the
// proof not re-run) except in the re-verified test. Test data uses explicit types and plain loops (CI type-check rule).
@testable import BackwardsAuroraCore
import Foundation
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/backwards-aurora/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(BackwardsAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder (the level re-checked; the proof not re-run).
private func storedWitness(_ number: Int) throws -> BackwardsAuroraWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(BackwardsAuroraWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[BackwardsAuroraWitness], any Error> = Result {
    var result: [BackwardsAuroraWitness] = []
    for entry in BackwardsAuroraManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [BackwardsAuroraWitness] { try stored.get() }

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied.
private func played(_ level: BackwardsAuroraLevel, _ actions: [BackwardsAuroraAction]) throws -> BackwardsAuroraPlay {
    var play = BackwardsAuroraPlay(level: level)
    try play.handle(.begin)
    if play.stage == .tutorial { try play.handle(.dismissTutorial) }
    for action in actions { try play.apply(action, expecting: play.fingerprint) }
    return play
}

/// The interior positions of `samples` whose second difference exceeds `limit` in magnitude (independent of the
/// kernel's bends).
private func badCount(_ samples: [Int], limit: Int) -> Int {
    var count: Int = 0
    var k: Int = 1
    while k + 1 < samples.count {
        let left: Int = samples[k] - samples[k - 1]
        let right: Int = samples[k + 1] - samples[k]
        if abs(right - left) > limit { count += 1 }
        k += 1
    }
    return count
}

@Suite struct BackwardsAuroraCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "6eb242e60a77f39d9ce23f4d28909b827608b19138329c4b18100eebe1e2d06e"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [BackwardsAuroraManifestEntry] = BackwardsAuroraManifest.entries
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
        #expect(entries[0].seed == 0xe72f66a4b871c4f6)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the group tests) is pinned;
    /// the ids follow the manifest.
    @Test func catalogMatchesThePinnedDigest() throws {
        let witnesses: [BackwardsAuroraWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [BackwardsAuroraLevel] = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == BackwardsAuroraGenerator.levelID(index + 1))
        }
        let digest: String = BackwardsAuroraGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(levels.map(\.fingerprint)).count == 100)
    }

    /// Winnable within the budget at the lower bound, inside each band's range; the progression rule and the band
    /// means of the smallest reversal count (never falling) hold over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [BackwardsAuroraWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumSmallest: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: BackwardsAuroraLevel = witness.level
            #expect(witness.actions.count == witness.difficulty.smallest)
            #expect(witness.actions.count == witness.bound.smallest)
            #expect(witness.actions.count <= level.budget)
            let profile: BackwardsAuroraBandProfile = BackwardsAuroraBandProfile.of(band: level.difficulty)
            #expect(profile.reversals.contains(witness.difficulty.smallest))
            #expect(profile.lengths.contains(level.count))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumSmallest[level.difficulty - 1] += witness.difficulty.smallest
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumSmallest[band] >= sumSmallest[band - 1],
                    "mean smallest falls at band \(band + 1): \(sumSmallest)")
        }
    }

    /// SC-R02G1002-001 and 005 for all 100 levels: the witness reversals replayed on a play win on the last one within
    /// the budget, and the witness one reversal short is not yet won, with bad bends left.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: BackwardsAuroraLevel = witness.level
            let play: BackwardsAuroraPlay = try played(level, witness.actions)
            #expect(play.stage == .won, "\(level.id) is not won by its witness")
            #expect(play.spent <= level.budget)
            let short: BackwardsAuroraPlay = try played(level, Array(witness.actions.dropLast()))
            #expect(short.stage == .playing, "\(level.id) is won one reversal short")
            let left: Int = badCount(short.wave.samples, limit: level.bendLimit)
            #expect(left == witness.nearMiss.badBends)
            #expect(left > 0)
        }
    }

    /// SC-R02G1002-002 on two levels per band (1, 11, 21, … 91): the opening's bad bends, recomputed from second
    /// differences of the stored samples, are exactly four per witness reversal, and no single reversal of the opening
    /// (any section, any length) removes more than four of them, so no shorter sequence can make the wave smooth.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theLowerBoundIsMetAndCheckedIndependently(number: Int) throws {
        let witness: BackwardsAuroraWitness = try storedWitness(number)
        let level: BackwardsAuroraLevel = witness.level
        let samples: [Int] = level.opening.samples
        let bad: Int = badCount(samples, limit: level.bendLimit)
        #expect(bad == witness.bound.badBends)
        #expect(bad == 4 * witness.actions.count, "\(level.id): \(bad) bad bends for \(witness.actions.count)")
        for start in 0..<(samples.count - 1) {
            for end in (start + 1)..<samples.count {
                var reversed: [Int] = samples
                var a: Int = start
                var b: Int = end
                while a < b {
                    reversed.swapAt(a, b)
                    a += 1
                    b -= 1
                }
                #expect(bad - badCount(reversed, limit: level.bendLimit) <= 4)
            }
        }
    }

    /// One stored witness per band decodes with full re-verification (replay, bound, near miss, solver).
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: BackwardsAuroraWitness = try BackwardsAuroraWitness.decode(data)
        #expect(witness.number == number)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 5·group + 1 … 5·group + 5) equal the regenerated witnesses byte for
    /// byte (written only with BACKWARDS_AURORA_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<20))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["BACKWARDS_AURORA_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: BackwardsAuroraGenerated = try BackwardsAuroraGenerator.generate(
                BackwardsAuroraManifest.entries[number - 1])
            let witness: BackwardsAuroraWitness = try BackwardsAuroraWitness.make(generated)
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
