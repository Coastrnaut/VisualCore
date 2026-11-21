// HueCompassCatalogTests — feature 332 (R02-G04-02) T-R02G0402-006 (FR-R02G0402-001, 003, 004, 005;
// SC-R02G0402-001 … 005). The 100-level catalog: manifest shape, determinism, the pinned digest, the progression rule,
// band means and tolerances, an independent brute force on levels 1, 11, … 91, soundness of every stored witness and the
// witness files in docs/games/hue-compass/levels/ compared byte for byte, one test per band. The files are written only
// when HUE_COMPASS_WRITE_WITNESSES=1 is set. Test data uses explicit types and plain loops (CI type-check rule).
@testable import HueCompassCore
import Foundation
import Testing
import VisualCoreSimulation

/// The levels of one band (20 entries), generated in manifest order.
private func generateBand(_ band: Int) -> Result<[HueCompassGenerated], any Error> {
    Result {
        var result: [HueCompassGenerated] = []
        for entry in HueCompassManifest.entries where entry.band == band {
            result.append(try HueCompassGenerator.generate(entry))
        }
        return result
    }
}

// Each band is generated once per test process, on first use, so no single test waits for the whole catalog.
private let band1: Result<[HueCompassGenerated], any Error> = generateBand(1)
private let band2: Result<[HueCompassGenerated], any Error> = generateBand(2)
private let band3: Result<[HueCompassGenerated], any Error> = generateBand(3)
private let band4: Result<[HueCompassGenerated], any Error> = generateBand(4)
private let band5: Result<[HueCompassGenerated], any Error> = generateBand(5)

/// The generated levels of `band` (1 … 5).
private func generatedBand(_ band: Int) throws -> [HueCompassGenerated] {
    switch band {
    case 1: try band1.get()
    case 2: try band2.get()
    case 3: try band3.get()
    case 4: try band4.get()
    default: try band5.get()
    }
}

/// The generated level of manifest number `number`.
private func generatedLevel(_ number: Int) throws -> HueCompassGenerated {
    let entry: HueCompassManifestEntry = HueCompassManifest.entries[number - 1]
    for generated in try generatedBand(entry.band) where generated.entry.number == number { return generated }
    throw HueCompassError.generation(number)
}

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/hue-compass/levels", isDirectory: true)

/// The 100 stored witnesses, decoded (and so re-verified) once per test process, in manifest order.
private let stored: Result<[HueCompassWitness], any Error> = Result { try decodeStoredWitnesses() }

/// The 100 stored witnesses.
private func storedWitnesses() throws -> [HueCompassWitness] { try stored.get() }

/// Decodes the 100 stored witness files in manifest order.
private func decodeStoredWitnesses() throws -> [HueCompassWitness] {
    var result: [HueCompassWitness] = []
    for entry in HueCompassManifest.entries {
        let name: String = String(HueCompassGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        result.append(try HueCompassWitness.decode(Data(contentsOf: witnessDirectory.appendingPathComponent(name))))
    }
    return result
}

/// Whether one selection accepts every target of `targets` in `level` (an exhaustive scan of 96 bearings × 24 bands).
private func jointlyAcceptable(_ targets: [Int], _ level: HueCompassLevel) -> Bool {
    var bearingFound: Bool = false
    for bearing in 0..<HueCompassWheel.bearings where !bearingFound {
        var fits: Bool = true
        for t in targets where HueCompassWheel.bearingDistance(bearing, t) > level.bearingTolerance { fits = false }
        if fits { bearingFound = true }
    }
    var bandFound: Bool = false
    for band in 0..<HueCompassWheel.bands where !bandFound {
        var fits: Bool = true
        for t in targets where HueCompassWheel.bandDistance(band, level.band(of: t)) > level.bandTolerance { fits = false }
        if fits { bandFound = true }
    }
    return bearingFound && bandFound
}

/// The candidates of `level` grouped by their clues at `probes` (an independent re-implementation with a dictionary).
private func groups(_ level: HueCompassLevel, probes: [Int]) -> [[Int]] {
    var byKey: [[Int]: [Int]] = [:]
    var order: [[Int]] = []
    for t in 0..<HueCompassWheel.bearings where HueCompassWheel.bearingDistance(t, level.start) > level.bearingTolerance {
        var key: [Int] = []
        for p in probes {
            let clue: HueCompassClue = cluesFor(level, target: t, at: p)
            key.append(clue.hueGap)
            key.append(clue.depth)
        }
        if byKey[key] == nil { order.append(key) }
        byKey[key, default: []].append(t)
    }
    return order.map { byKey[$0] ?? [] }
}

/// The clue at `bearing` if the target were `target`: the level with only its target replaced.
private func cluesFor(_ level: HueCompassLevel, target: Int, at bearing: Int) -> HueCompassClue {
    var depth: Int = 0
    for inside in HueCompassWheel.arc(from: bearing, to: target) { depth += level.fog[inside] }
    return HueCompassClue(bearing: bearing, hueGap: HueCompassWheel.bandDistance(level.band(of: bearing),
                                                                                level.band(of: target)), depth: depth)
}

@Suite struct HueCompassCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "fcb10a906350344bf23c9126d1c9cd2fd26bde25458cdc2924edb75a0bae8b15"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [HueCompassManifestEntry] = HueCompassManifest.entries
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
        #expect(entries[0].seed == 0x447ee2e2cd7c508e)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the band tests) is pinned;
    /// three levels regenerate identically.
    @Test func catalogMatchesThePinnedDigestAndRegeneratesIdentically() throws {
        let witnesses: [HueCompassWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var levels: [HueCompassLevel] = []
        for witness in witnesses { levels.append(witness.level) }
        let digest: String = HueCompassGenerator.catalogDigest(levels)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(levels.map(\.fingerprint)).count == 100)
        for number in [1, 47, 100] {
            let generated: HueCompassGenerated = try HueCompassGenerator.generate(HueCompassManifest.entries[number - 1])
            #expect(generated.level == witnesses[number - 1].level)
        }
    }

    /// Deducible within the allowance, inside each band's range; the progression rule, the band means of the smallest
    /// count (never falling) and tolerances (never loosening) hold over the stored difficulties.
    @Test func everyLevelIsDeducibleWithinItsAllowanceAndKeepsTheProgression() throws {
        let witnesses: [HueCompassWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumSmallest: [Int] = [0, 0, 0, 0, 0]
        var loosest: [Int] = [0, 0, 0, 0, 0]
        var tightest: [Int] = [99, 99, 99, 99, 99]
        for witness in witnesses {
            let level: HueCompassLevel = witness.level
            var spent: Int = 0
            for action in witness.actions {
                if case .turn = action { continue }
                spent += 1
            }
            #expect(spent <= level.allowance)
            let profile: HueCompassBandProfile = HueCompassBandProfile.of(band: level.band)
            #expect(profile.smallest.contains(witness.difficulty.smallest))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumSmallest[level.band - 1] += witness.difficulty.smallest
            loosest[level.band - 1] = max(loosest[level.band - 1], level.bearingTolerance * 10 + level.bandTolerance)
            tightest[level.band - 1] = min(tightest[level.band - 1], level.bearingTolerance * 10 + level.bandTolerance)
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumSmallest[band] >= sumSmallest[band - 1], "mean smallest falls at band \(band + 1): \(sumSmallest)")
            #expect(loosest[band] <= tightest[band - 1], "tolerances loosen at band \(band + 1)")
        }
    }

    /// SC-R02G0402-001 for all 100 levels: after the witness probes every class of consistent candidates has one
    /// selection accepting all its members, and the witness selection is the true target's class's.
    @Test func everyStoredWitnessIsSound() throws {
        for witness in try storedWitnesses() {
            let level: HueCompassLevel = witness.level
            var probes: [Int] = []
            for clue in witness.clues { probes.append(clue.bearing) }
            for group in groups(level, probes: probes) {
                #expect(jointlyAcceptable(group, level), "\(level.id) class \(group) has no selection")
            }
        }
    }

    /// SC-R02G0402-002 on levels 1, 11, … 91: an independent brute force over probe sets finds the solver's smallest
    /// count and first settling set.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theSolverAgreesWithABruteForce(number: Int) throws {
        let generated: HueCompassGenerated = try generatedLevel(number)
        let level: HueCompassLevel = generated.level
        var sets: [[Int]] = [[]]
        for a in 0..<HueCompassWheel.bearings { sets.append([a]) }
        for a in 0..<HueCompassWheel.bearings {
            for b in (a + 1)..<HueCompassWheel.bearings { sets.append([a, b]) }
        }
        var found: [Int]? = nil
        for set in sets where found == nil {
            var settles: Bool = true
            for group in groups(level, probes: set) where !jointlyAcceptable(group, level) { settles = false }
            if settles { found = set }
        }
        #expect(found == generated.solution.probes)
    }

    /// The witness files of `band` equal the regenerated witnesses byte for byte (written only with
    /// HUE_COMPASS_WRITE_WITNESSES=1).
    @Test(arguments: [1, 2, 3, 4, 5])
    func witnessFilesMatchByteForByte(band: Int) throws {
        let catalog: [HueCompassGenerated] = try generatedBand(band)
        let write: Bool = ProcessInfo.processInfo.environment["HUE_COMPASS_WRITE_WITNESSES"] == "1"
        if write { try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true) }
        for generated in catalog {
            let witness: HueCompassWitness = try HueCompassWitness.make(generated)
            let data: Data = witness.encoded()
            let name: String = String(HueCompassGenerator.levelID(generated.entry.number).suffix(3)) + ".witness.json"
            let url: URL = witnessDirectory.appendingPathComponent(name)
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(name) differs from the regenerated witness")
            #expect(try HueCompassWitness.decode(stored) == witness)
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }
}
