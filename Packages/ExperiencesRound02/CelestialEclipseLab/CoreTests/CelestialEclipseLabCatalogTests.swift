// CelestialEclipseLabCatalogTests — feature 462 (R02-G17-02) T-R02G1702-006 (FR-R02G1702-001 … 007;
// SC-R02G1702-001 … 005; clarifications Q1 … Q5). The 100-level catalog: manifest shape (20 levels per band), the
// pinned digest, R02-F24's standard progression rule on the witness length in manifest order and non-decreasing band
// means, adjacent levels with different target sequences, every stored witness replayed to a win through the play
// within its budget, an independent enumeration on the two levels with the fewest bodies in each band (every phase
// vector that differs from the start on fewer movable bodies than the plan, judged by the kernel's whole-sky timeline,
// never the solver's pair table: none wins, and the plan's setting does), one fully re-verified decode per band, and
// the witness files in docs/games/celestial-eclipse-lab/levels/ compared byte for byte with the regenerated witnesses
// in 10 groups of 10 levels (each level generated after the stored level before it, the neighbour rule's input). The
// files are written only when CELESTIAL_ECLIPSE_LAB_WRITE_WITNESSES=1 is set, with `swift test --no-parallel` so the
// groups run in order (a group reads the level the group before it wrote). Stored files are read with the plain
// decoder except in the re-verified test. Explicit types and plain loops (CI type-check rule). Modelled on
// StarlitCartoucheCatalogTests (feature 452).
import Foundation
@testable import CelestialEclipseLabCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, CelestialEclipseLab, the
/// package, Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/celestial-eclipse-lab/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(CelestialEclipseLabGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> CelestialEclipseLabWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(CelestialEclipseLabWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[CelestialEclipseLabWitness], any Error> = Result {
    var result: [CelestialEclipseLabWitness] = []
    for entry in CelestialEclipseLabManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [CelestialEclipseLabWitness] { try stored.get() }

/// The phase changes of a witness (its actions without the closing run).
private func changes(_ witness: CelestialEclipseLabWitness) -> [CelestialEclipseLabAction] {
    var result: [CelestialEclipseLabAction] = []
    for action in witness.actions where action != .run { result.append(action) }
    return result
}

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: CelestialEclipseLabLevel, _ actions: [CelestialEclipseLabAction])
    -> CelestialEclipseLabPlay? {
    var play = CelestialEclipseLabPlay(level: level)
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

/// Whether some phase vector that differs from `level`'s start on at most `limit` movable bodies wins, judged by the
/// kernel's whole-sky timeline (independent of the solver's pair table).
private func winsWithin(_ level: CelestialEclipseLabLevel, limit: Int) -> Bool {
    let movable: [Int] = level.bodies.indices.filter { !level.bodies[$0].fixed }
    var phases: [Int] = level.phases
    func search(_ from: Int, _ left: Int) -> Bool {
        if CelestialEclipseLabSky.timeline(level, phases: phases).wins { return true }
        guard left > 0 else { return false }
        var index: Int = from
        while index < movable.count {
            let body: Int = movable[index]
            let start: Int = phases[body]
            for offset in 0..<level.bodies[body].period where offset != start {
                phases[body] = offset
                if search(index + 1, left - 1) {
                    phases[body] = start
                    return true
                }
            }
            phases[body] = start
            index += 1
        }
        return false
    }
    return search(0, limit)
}

/// The two stored witnesses of `band` with the fewest bodies (then the lowest number).
private func fewestBodies(band: Int) throws -> [CelestialEclipseLabWitness] {
    var candidates: [CelestialEclipseLabWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort { ($0.level.bodies.count, $0.number) < ($1.level.bodies.count, $1.number) }
    return Array(candidates.prefix(2))
}

@Suite struct CelestialEclipseLabCatalogTests {
    /// The pinned catalog digest: `PuzzleCatalog<CelestialEclipseLabRules>.digest(id: "celestial-eclipse-lab",
    /// identities:)` over the 100 level fingerprints in manifest order, computed on 2026-11-25 from the generated
    /// catalog. An intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest = "c74bf277d3c1f0e5f6a8adad504ffe8922bde6964fe5f7e7c289034ef942c6e8"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [CelestialEclipseLabManifestEntry] = CelestialEclipseLabManifest.entries
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
    /// the ids follow the manifest; adjacent levels have different target sequences (FR-R02G1702-007).
    @Test func catalogMatchesThePinnedDigestAndNeighboursDiffer() throws {
        let witnesses: [CelestialEclipseLabWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [CelestialEclipseLabLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == CelestialEclipseLabGenerator.levelID(index + 1))
            if index > 0 {
                let before: [[Int]] = CelestialEclipseLabGenerator.pairs(witnesses[index - 1].level)
                #expect(before != CelestialEclipseLabGenerator.pairs(witness.level), "\(witness.level.id) repeats")
            }
        }
        let digest: String = CelestialEclipseLabGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's plan range, R02-F24's standard progression rule on the witness length
    /// in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [CelestialEclipseLabWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumChanges: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: CelestialEclipseLabLevel = witness.level
            let entry: CelestialEclipseLabManifestEntry = CelestialEclipseLabManifest.entries[witness.number - 1]
            let count: Int = changes(witness).count
            #expect(witness.actions.last == .run)
            #expect(witness.actions.count == count + 1)
            #expect(count == witness.difficulty.changes)
            #expect(count >= 1)
            #expect(count <= level.budget)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: CelestialEclipseLabBandProfile = CelestialEclipseLabBandProfile.of(band: level.difficulty)
            #expect(profile.planRange.contains(count), "\(level.id): \(count) changes outside the band's range")
            #expect(profile.bodies.contains(level.bodies.count))
            #expect(profile.targets.contains(level.target.count))
            #expect(profile.horizon.contains(level.horizon))
            #expect(witness.counterexample.depth == count - 1)
            #expect(witness.difficulty.work <= CelestialEclipseLabSolver.workBound)
            #expect((0..<CelestialEclipseLabGenerator.maxCandidates).contains(witness.skipped))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumChanges[level.difficulty - 1] += count
            countPerBand[level.difficulty - 1] += 1
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        #expect(countPerBand == [20, 20, 20, 20, 20])
        // Twenty levels per band, so the sums order as the means do.
        for band in 1..<5 {
            #expect(sumChanges[band] >= sumChanges[band - 1], "mean changes fall at band \(band + 1): \(sumChanges)")
        }
    }

    /// SC-R02G1702-001 for all 100 levels: the witness phase changes replayed on a play, then the run, win within the
    /// budget; the changes alone leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: CelestialEclipseLabLevel = witness.level
            let play: CelestialEclipseLabPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == changes(witness).count)
            let before: CelestialEclipseLabPlay? = played(level, changes(witness))
            #expect(before?.stage == .playing, "\(level.id) is not playing before its run")
        }
    }

    /// SC-R02G1702-002 on the two levels with the fewest bodies in each band: the whole-sky enumeration finds no win
    /// with fewer phase changes than the plan and a win with exactly its changes.
    @Test(arguments: [1, 2, 3, 4, 5])
    func noSettingWithFewerChangesWins(band: Int) throws {
        let witnesses: [CelestialEclipseLabWitness] = try fewestBodies(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let size: Int = witness.difficulty.changes
            #expect(!winsWithin(witness.level, limit: size - 1), "\(witness.level.id) is won with fewer changes")
            #expect(winsWithin(witness.level, limit: size), "\(witness.level.id) is not won with its changes")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: CelestialEclipseLabWitness = try CelestialEclipseLabWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == CelestialEclipseLabManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 10·group + 1 … 10·group + 10) equal the regenerated witnesses byte
    /// for byte (written only with CELESTIAL_ECLIPSE_LAB_WRITE_WITNESSES=1). Each level is generated after the level
    /// before it — the stored one for the group's first level, which its own group checks against its regeneration.
    @Test(arguments: Array(0..<10))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["CELESTIAL_ECLIPSE_LAB_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        var previous: CelestialEclipseLabLevel? = nil
        if group > 0 { previous = try storedWitness(10 * group).level }
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(
                CelestialEclipseLabManifest.entries[number - 1], previous: previous)
            #expect(generated.level.id == CelestialEclipseLabGenerator.levelID(number))
            let witness: CelestialEclipseLabWitness = try CelestialEclipseLabWitness.make(generated)
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
