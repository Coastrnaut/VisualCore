// ApsidesWorkshopCatalogTests — feature 472 (R02-G18-02) T-R02G1802-006 (FR-R02G1802-001 … 007;
// SC-R02G1802-001 … 005; clarifications Q1 … Q5). The 100-level catalog: manifest shape (20 levels per band), the
// pinned digest, R02-F24's standard progression rule on the witness length in manifest order and non-decreasing band
// means, adjacent levels with different targets, every stored witness replayed to a win through the play within its
// budget, an independent enumeration on the two levels with the fewest planets in each band (ties by level number:
// every valid orbit that differs from the start in fewer levers than the plan, judged by the kernel's full report,
// never the solver's apsis shortcut: none wins, and one with exactly the plan's levers does), one fully re-verified
// decode per band, and the witness files in docs/games/apsides-workshop/levels/ compared byte for byte with the
// regenerated witnesses in 10 groups of 10 levels (each level generated after the stored level before it, the neighbour
// rule's input). The files are written only when APSIDES_WORKSHOP_WRITE_WITNESSES=1 is set, with `swift test
// --no-parallel` so the groups run in order (a group reads the level the group before it wrote). Stored files are read
// with the plain decoder except in the re-verified test. Explicit types and plain loops (CI type-check rule). Modelled
// on CelestialEclipseLabCatalogTests (feature 462).
import Foundation
@testable import ApsidesWorkshopCore
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, ApsidesWorkshop, the
/// package, Packages).
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/apsides-workshop/levels", isDirectory: true)

/// The file name of level `number`'s witness.
private func witnessName(_ number: Int) -> String {
    String(ApsidesWorkshopGenerator.levelID(number).suffix(3)) + ".witness.json"
}

/// The stored witness of level `number`, read with the plain decoder.
private func storedWitness(_ number: Int) throws -> ApsidesWorkshopWitness {
    let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
    return try JSONDecoder().decode(ApsidesWorkshopWitness.self, from: data)
}

/// The 100 stored witnesses, read once per test process.
private let stored: Result<[ApsidesWorkshopWitness], any Error> = Result {
    var result: [ApsidesWorkshopWitness] = []
    for entry in ApsidesWorkshopManifest.entries { result.append(try storedWitness(entry.number)) }
    return result
}

/// The 100 stored witnesses in manifest order.
private func storedWitnesses() throws -> [ApsidesWorkshopWitness] { try stored.get() }

/// The tunings of a witness (its actions without the closing play).
private func changes(_ witness: ApsidesWorkshopWitness) -> [ApsidesWorkshopAction] {
    var result: [ApsidesWorkshopAction] = []
    for action in witness.actions where action != .play { result.append(action) }
    return result
}

/// A fresh play of `level`, begun and past its tutorial, with `actions` applied; nil when the play refuses one.
private func played(_ level: ApsidesWorkshopLevel, _ actions: [ApsidesWorkshopAction])
    -> ApsidesWorkshopPlay? {
    var play = ApsidesWorkshopPlay(level: level)
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

/// Whether some valid orbit that differs from `level`'s start in at most `limit` levers (the knob, the size) wins,
/// judged by the kernel's full report (independent of the solver's order and apsis shortcut).
private func winsWithin(_ level: ApsidesWorkshopLevel, limit: Int) -> Bool {
    let start: ApsidesWorkshopOrbit = level.orbit
    for a in ApsidesWorkshopOrbit.sizes {
        for k in ApsidesWorkshopOrbit.eccentricities {
            for d in ApsidesWorkshopOrbit.directions {
                let orbit = ApsidesWorkshopOrbit(size: a, eccentricity: k, direction: d)
                guard orbit.isValid else { continue }
                var levers: Int = 0
                if a != start.size { levers += 1 }
                if k != start.eccentricity || d != start.direction { levers += 1 }
                guard levers <= limit else { continue }
                if ApsidesWorkshopSky.report(level, orbit: orbit).wins { return true }
            }
        }
    }
    return false
}

/// The two stored witnesses of `band` with the fewest planets (then the lowest number).
private func fewestPlanets(band: Int) throws -> [ApsidesWorkshopWitness] {
    var candidates: [ApsidesWorkshopWitness] = []
    for witness in try storedWitnesses() where witness.level.difficulty == band { candidates.append(witness) }
    candidates.sort { ($0.level.planets.count, $0.number) < ($1.level.planets.count, $1.number) }
    return Array(candidates.prefix(2))
}

@Suite struct ApsidesWorkshopCatalogTests {
    /// The pinned catalog digest: `PuzzleCatalog<ApsidesWorkshopRules>.digest(id: "apsides-workshop",
    /// identities:)` over the 100 level fingerprints in manifest order, computed on 2026-11-25 from the generated
    /// catalog. An intended rule, generator or seed change re-pins it after review.
    static let pinnedDigest = "73aef009a3044dde7ef6fd3ba29325aee3ab24115847b6338578494d69c0e87b"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [ApsidesWorkshopManifestEntry] = ApsidesWorkshopManifest.entries
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
    /// the ids follow the manifest; adjacent levels have different targets (FR-R02G1802-007).
    @Test func catalogMatchesThePinnedDigestAndNeighboursDiffer() throws {
        let witnesses: [ApsidesWorkshopWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [ApsidesWorkshopLevel] = []
        var fingerprints: Set<String> = []
        for (index, witness) in witnesses.enumerated() {
            levels.append(witness.level)
            fingerprints.insert(witness.level.fingerprint)
            #expect(witness.number == index + 1)
            #expect(witness.level.id == ApsidesWorkshopGenerator.levelID(index + 1))
            if index > 0 {
                #expect(witnesses[index - 1].level.targets != witness.level.targets, "\(witness.level.id) repeats")
            }
        }
        let digest: String = ApsidesWorkshopGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(fingerprints.count == 100)
    }

    /// Winnable within the budget, each band's plan range, R02-F24's standard progression rule on the witness length
    /// in manifest order and the band means (never falling) over the stored difficulties.
    @Test func everyLevelIsWinnableWithinItsBudgetAndKeepsTheProgression() throws {
        let witnesses: [ApsidesWorkshopWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumChanges: [Int] = [0, 0, 0, 0, 0]
        var countPerBand: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: ApsidesWorkshopLevel = witness.level
            let entry: ApsidesWorkshopManifestEntry = ApsidesWorkshopManifest.entries[witness.number - 1]
            let count: Int = changes(witness).count
            #expect(witness.actions.last == .play)
            #expect(witness.actions.count == count + 1)
            #expect(count == witness.difficulty.tunings)
            #expect(count >= 1)
            #expect(count <= level.budget)
            #expect(level.budget == entry.budget)
            #expect(level.difficulty == entry.band)
            #expect(level.tutorial == (witness.number <= 3))
            let profile: ApsidesWorkshopBandProfile = ApsidesWorkshopBandProfile.of(band: level.difficulty)
            #expect(profile.planRange.contains(count), "\(level.id): \(count) tunings outside the band's range")
            #expect(profile.planets.contains(level.planets.count))
            #expect(level.targets.count <= profile.targets.upperBound)
            #expect(profile.periods.contains(level.period))
            #expect(witness.counterexample.depth == count - 1)
            #expect(witness.difficulty.work <= ApsidesWorkshopSolver.workBound)
            #expect((0..<ApsidesWorkshopGenerator.maxCandidates).contains(witness.skipped))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumChanges[level.difficulty - 1] += count
            countPerBand[level.difficulty - 1] += 1
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        #expect(countPerBand == [20, 20, 20, 20, 20])
        // Twenty levels per band, so the sums order as the means do.
        for band in 1..<5 {
            #expect(sumChanges[band] >= sumChanges[band - 1], "mean tunings fall at band \(band + 1): \(sumChanges)")
        }
    }

    /// SC-R02G1802-001 for all 100 levels: the witness tunings replayed on a play, then the play, win within the
    /// budget; the tunings alone leave the play playing.
    @Test func everyStoredWitnessWins() throws {
        for witness in try storedWitnesses() {
            let level: ApsidesWorkshopLevel = witness.level
            let play: ApsidesWorkshopPlay? = played(level, witness.actions)
            #expect(play?.stage == .won, "\(level.id) is not won by its witness")
            #expect((play?.actionsLeft ?? -1) >= 0)
            #expect(play?.actionsSpent == changes(witness).count)
            let before: ApsidesWorkshopPlay? = played(level, changes(witness))
            #expect(before?.stage == .playing, "\(level.id) is not playing before its play")
        }
    }

    /// SC-R02G1802-002 on the two levels with the fewest planets in each band: the full-report enumeration finds no
    /// win with fewer tunings than the plan and a win with exactly its tunings.
    @Test(arguments: [1, 2, 3, 4, 5])
    func noOrbitWithFewerTuningsWins(band: Int) throws {
        let witnesses: [ApsidesWorkshopWitness] = try fewestPlanets(band: band)
        #expect(witnesses.count == 2)
        for witness in witnesses {
            let size: Int = witness.difficulty.tunings
            #expect(!winsWithin(witness.level, limit: size - 1), "\(witness.level.id) is won with fewer tunings")
            #expect(winsWithin(witness.level, limit: size), "\(witness.level.id) is not won with its tunings")
        }
    }

    /// One stored witness per band decodes with full re-verification.
    @Test(arguments: [2, 22, 42, 62, 82])
    func aStoredWitnessPerBandVerifiesFully(number: Int) throws {
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(witnessName(number)))
        let witness: ApsidesWorkshopWitness = try ApsidesWorkshopWitness.decode(data)
        #expect(witness.number == number)
        #expect(witness.level.difficulty == ApsidesWorkshopManifest.entries[number - 1].band)
        #expect(try storedWitness(number) == witness)
    }

    /// The witness files of group `group` (levels 10·group + 1 … 10·group + 10) equal the regenerated witnesses byte
    /// for byte (written only with APSIDES_WORKSHOP_WRITE_WITNESSES=1). Each level is generated after the level
    /// before it — the stored one for the group's first level, which its own group checks against its regeneration.
    @Test(arguments: Array(0..<10))
    func witnessFilesMatchByteForByte(group: Int) throws {
        let write: Bool = ProcessInfo.processInfo.environment["APSIDES_WORKSHOP_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        var previous: ApsidesWorkshopLevel? = nil
        if group > 0 { previous = try storedWitness(10 * group).level }
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(
                ApsidesWorkshopManifest.entries[number - 1], previous: previous)
            #expect(generated.level.id == ApsidesWorkshopGenerator.levelID(number))
            let witness: ApsidesWorkshopWitness = try ApsidesWorkshopWitness.make(generated)
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
