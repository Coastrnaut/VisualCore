// StarlitCartoucheCatalogTests — feature 452 (R02-G16-02) T-R02G1602-006 (FR-R02G1602-001 … 006;
// SC-R02G1602-001 … 005; clarifications Q1 … Q5). The 100-level catalog: manifest shape (20 levels per band), the
// pinned digest, R02-F24's standard progression rule on the witness leg count in manifest order and non-decreasing band
// means, every stored witness replayed to a win through the play within its budget, an independent depth-first
// enumeration on the two levels with the fewest stars in each band (every leg the chart neither refuses nor fails,
// applied through the play; a (star, beat, strokes) state already explored with at least as many legs left is not
// explored again, which loses no sequence because windows, hazards and the deadline are absolute beats; no sequence
// shorter than the plan wins, and one of exactly the plan's length does), one fully re-verified decode per band, and the
// witness files in docs/games/starlit-cartouche/levels/ compared byte for byte with the regenerated witnesses in 10
// groups of 10 levels (all 100 levels generate in about 0.3 s). The files are written only when
// STARLIT_CARTOUCHE_WRITE_WITNESSES=1 is set. Stored files are read with the plain decoder except in the re-verified
// test. Explicit types and plain loops (CI type-check rule). Modelled on VoxelOrigamiCatalogTests (feature 442).
import Foundation
@testable import StarlitCartoucheCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, StarlitCartouche, the
/// package, Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/starlit-cartouche/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(StarlitCartoucheGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> StarlitCartoucheWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(StarlitCartoucheWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[StarlitCartoucheWitness], any Error> = Result {
    var result: [StarlitCartoucheWitness] = []
    for entry in StarlitCartoucheManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [StarlitCartoucheWitness] { try stored.get() }

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: StarlitCartoucheLevel, _ actions: [StarlitCartoucheAction]) -> StarlitCartouchePlay? {
    var play = StarlitCartouchePlay(level: level)
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

/// A depth-first enumeration through the play: whether some sequence of at most `left` legs the play accepts, from
/// `play`, wins. Every other star is offered with every wait 0 … 8. A leg the chart refuses or fails is skipped
/// before it reaches the play (it could only end the play refused or failed, never won); the rest are applied through
/// the play, which decides the win.
/// A state already explored with at least as many legs left is skipped: every sequence from it was tried.
private func winsWithin(_ play: StarlitCartouchePlay, left: Int, explored: inout [[Int]: Int]) -> Bool {
    if play.stage == .won { return true }
    guard left > 0, play.stage == .playing else { return false }
    var key: [Int] = [play.star, play.beat]
    key.append(contentsOf: play.drawn.sorted())
    if let seen = explored[key], seen >= left { return false }
    explored[key] = left
    for destination in 0..<play.level.stars.count where destination != play.star {
        for wait in StarlitCartoucheChart.waits {
            guard let leg = try? StarlitCartoucheChart.leg(play.level, from: play.star, at: play.beat,
                                                           to: destination, wait: wait),
                  StarlitCartoucheChart.check(play.level, leg: leg) == nil else { continue }
            var copy: StarlitCartouchePlay = play
            do { try copy.apply(.leg(destination, wait), expecting: copy.fingerprint) } catch { continue }
            if winsWithin(copy, left: left - 1, explored: &explored) { return true }
        }
    }
    return false
}

/// Whether a sequence of at most `limit` legs wins `level`.
private func winsIn(_ level: StarlitCartoucheLevel, limit: Int) -> Bool {
    guard let start = played(level, []) else { return false }
    var explored: [[Int]: Int] = [:]
    return winsWithin(start, left: limit, explored: &explored)
}

/// The two stored witnesses of `band` with the fewest stars (then the lowest number).
private func fewestStars(band: Int) throws -> [StarlitCartoucheWitness] {
    var candidates: [StarlitCartoucheWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort { ($0.level.stars.count, $0.number) < ($1.level.stars.count, $1.number) }
    return Array(candidates.prefix(2))
}

@Suite struct StarlitCartoucheCatalogTests {
    /// The pinned catalog digest: `PuzzleCatalog<StarlitCartoucheRules>.digest(id: "starlit-cartouche",
    /// identities:)` over the 100 level fingerprints in manifest order, computed on 2026-11-24 from the generated
    /// catalog. An intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest = "ee022539220b64cf789b745adf2eaa9850a6d966f03ba3a669db140f717b969e"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [StarlitCartoucheManifestEntry] = StarlitCartoucheManifest.entries
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
        let witnesses: [StarlitCartoucheWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [StarlitCartoucheLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == StarlitCartoucheGenerator.levelID(index + 1))
        }
        let digest: String = StarlitCartoucheGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's plan range, R02-F24's standard progression rule on the witness leg
    /// count in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [StarlitCartoucheWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumActions: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: StarlitCartoucheLevel = witness.level
            let entry: StarlitCartoucheManifestEntry = StarlitCartoucheManifest.entries[witness.number - 1]
            let count: Int = witness.actions.count
            #expect(count == witness.difficulty.legs)
            #expect(count >= 1)
            #expect(count <= level.budget)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: StarlitCartoucheBandProfile = StarlitCartoucheBandProfile.of(band: level.difficulty)
            #expect(profile.planRange.contains(count), "\(level.id): \(count) legs outside the band's range")
            #expect(profile.stars.contains(level.stars.count))
            #expect(witness.counterexample.depth == count - 1)
            #expect(witness.difficulty.work <= StarlitCartoucheSolver.workBound)
            #expect((0..<StarlitCartoucheGenerator.maxCandidates).contains(witness.skipped))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumActions[level.difficulty - 1] += count
            countPerBand[level.difficulty - 1] += 1
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        #expect(countPerBand == [20, 20, 20, 20, 20])
        // Twenty levels per band, so the sums order as the means do.
        for band in 1..<5 {
            #expect(sumActions[band] >= sumActions[band - 1], "mean legs fall at band \(band + 1): \(sumActions)")
        }
    }

    /// SC-R02G1602-001 for all 100 levels: the witness legs replayed on a play win on the last one within the
    /// budget, and the legs before it leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: StarlitCartoucheLevel = witness.level
            let play: StarlitCartouchePlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == witness.actions.count)
            let short: StarlitCartouchePlay? = played(level, Array(witness.actions.dropLast()))
            #expect(short?.stage == .playing, "\(level.id) is not playing before its last leg")
        }
    }

    /// SC-R02G1602-002 on the two levels with the fewest stars in each band: the depth-first enumeration through the
    /// play finds no win in fewer legs than the plan and a win in exactly its legs.
    @Test(arguments: [1, 2, 3, 4, 5])
    func noShorterSequenceWins(band: Int) throws {
        let witnesses: [StarlitCartoucheWitness] = try fewestStars(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let size: Int = witness.difficulty.legs
            #expect(!winsIn(witness.level, limit: size - 1), "\(witness.level.id) is won in fewer legs")
            #expect(winsIn(witness.level, limit: size), "\(witness.level.id) is not won in its legs")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: StarlitCartoucheWitness = try StarlitCartoucheWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == StarlitCartoucheManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 10·group + 1 … 10·group + 10) equal the regenerated witnesses byte
    /// for byte (written only with STARLIT_CARTOUCHE_WRITE_WITNESSES=1).
    @Test(arguments: Array(0..<10))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["STARLIT_CARTOUCHE_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: StarlitCartoucheGenerated = try StarlitCartoucheGenerator.generate(
                StarlitCartoucheManifest.entries[number - 1])
            #expect(generated.level.id == StarlitCartoucheGenerator.levelID(number))
            let witness: StarlitCartoucheWitness = try StarlitCartoucheWitness.make(generated)
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
