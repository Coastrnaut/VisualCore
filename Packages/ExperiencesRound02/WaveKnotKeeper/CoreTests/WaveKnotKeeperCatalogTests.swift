// WaveKnotKeeperCatalogTests — feature 322 (R02-G03-02) T-R02G0302-006 (FR-R02G0302-001, 003, 004, 005;
// SC-R02G0302-001 … 005). The 100-level catalog: manifest shape, determinism, the pinned digest, the
// progression rule, band means, a plain breadth-first search over the kernel's rules on levels 1, 11, … 91 and the witness
// files in docs/games/wave-knot-keeper/levels/ compared byte for byte, one test per band. The files are written only when
// WAVE_KNOT_KEEPER_WRITE_WITNESSES=1 is set. Test data uses explicit types and plain loops (CI type-check rule).
@testable import WaveKnotKeeperCore
import Foundation
import Testing
import VisualCoreSimulation

/// The levels of one band (20 entries), generated in manifest order.
private func generateBand(_ band: Int) -> Result<[WaveKnotKeeperGenerated], any Error> {
    Result {
        var result: [WaveKnotKeeperGenerated] = []
        for entry in WaveKnotKeeperManifest.entries where entry.band == band {
            result.append(try WaveKnotKeeperGenerator.generate(entry))
        }
        return result
    }
}

// Each band is generated once per test process, on first use, so no single test waits for the whole catalog (each test
// stays under 10 s; the catalog-wide checks read the witness files, which the band tests prove equal to the regenerated
// witnesses byte for byte).
private let band1: Result<[WaveKnotKeeperGenerated], any Error> = generateBand(1)
private let band2: Result<[WaveKnotKeeperGenerated], any Error> = generateBand(2)
private let band3: Result<[WaveKnotKeeperGenerated], any Error> = generateBand(3)
private let band4: Result<[WaveKnotKeeperGenerated], any Error> = generateBand(4)
private let band5: Result<[WaveKnotKeeperGenerated], any Error> = generateBand(5)

/// The generated levels of `band` (1 … 5).
private func generatedBand(_ band: Int) throws -> [WaveKnotKeeperGenerated] {
    switch band {
    case 1: try band1.get()
    case 2: try band2.get()
    case 3: try band3.get()
    case 4: try band4.get()
    default: try band5.get()
    }
}

/// The generated level of manifest number `number`.
private func generatedLevel(_ number: Int) throws -> WaveKnotKeeperGenerated {
    let entry: WaveKnotKeeperManifestEntry = WaveKnotKeeperManifest.entries[number - 1]
    let band: [WaveKnotKeeperGenerated] = try generatedBand(entry.band)
    for generated in band where generated.entry.number == number { return generated }
    throw WaveKnotKeeperError.generation(number)
}

/// The 100 stored witnesses, decoded (and so re-verified) in manifest order.
private func storedWitnesses() throws -> [WaveKnotKeeperWitness] {
    var result: [WaveKnotKeeperWitness] = []
    for entry in WaveKnotKeeperManifest.entries {
        let name: String = String(WaveKnotKeeperGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        result.append(try WaveKnotKeeperWitness.decode(Data(contentsOf: witnessDirectory.appendingPathComponent(name))))
    }
    return result
}

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/wave-knot-keeper/levels", isDirectory: true)

@Suite struct WaveKnotKeeperCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "12c8ecb8aae7135ff939d99b41a6dc8cf17fb4b7380fb5e4c18347ac5987933f"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [WaveKnotKeeperManifestEntry] = WaveKnotKeeperManifest.entries
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
        #expect(entries[0].seed == 0xee7ead064cea0a86)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the band tests) is pinned;
    /// three levels regenerate identically.
    @Test func catalogMatchesThePinnedDigestAndRegeneratesIdentically() throws {
        let witnesses: [WaveKnotKeeperWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var fingerprints: [String] = []
        for witness in witnesses { fingerprints.append(witness.level.fingerprint) }
        let digest: String = PuzzleCatalog<WaveKnotKeeperRules>.digest(id: WaveKnotKeeperGenerator.catalogID,
                                                                         identities: fingerprints)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(fingerprints).count == 100)
        for number in [1, 38, 100] {
            let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperGenerator.generate(
                WaveKnotKeeperManifest.entries[number - 1])
            #expect(generated.level == witnesses[number - 1].level)
            #expect(WaveKnotKeeperGenerator.catalogDigest([generated])
                == PuzzleCatalog<WaveKnotKeeperRules>.digest(id: WaveKnotKeeperGenerator.catalogID,
                                                                 identities: [witnesses[number - 1].level.fingerprint]))
        }
    }

    /// Solvable within the allowance, inside each band's range; the progression rule and the band means (shortest and
    /// point count never fall) hold over the stored difficulties.
    @Test func everyLevelIsSolvableWithinItsAllowanceAndKeepsTheProgression() throws {
        let witnesses: [WaveKnotKeeperWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumShortest: [Int] = [0, 0, 0, 0, 0]
        var sumPoints: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: WaveKnotKeeperLevel = witness.level
            #expect(witness.moves.count <= level.allowance)
            let profile: WaveKnotKeeperBandProfile = try #require(WaveKnotKeeperBandProfile.of(band: level.band))
            #expect(profile.shortest.contains(witness.difficulty.shortest))
            #expect(witness.difficulty.points == level.points.count && witness.difficulty.gates == level.gates.count)
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumShortest[level.band - 1] += witness.difficulty.shortest
            sumPoints[level.band - 1] += witness.difficulty.points
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumShortest[band] >= sumShortest[band - 1], "mean shortest falls at band \(band + 1): \(sumShortest)")
            #expect(sumPoints[band] >= sumPoints[band - 1], "mean points fall at band \(band + 1)")
        }
    }

    /// SC-R02G0302-002 on levels 1, 11, … 91: a plain breadth-first search over the kernel's `PuzzleRules` finds the
    /// solver's shortest length, and the solver's moves replay to a winning rope.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theSolverAgreesWithAPlainSearch(number: Int) throws {
        let generated: WaveKnotKeeperGenerated = try generatedLevel(number)
        let level: WaveKnotKeeperLevel = generated.level
        let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: level)
        var seen: Set<[WaveKnotKeeperPoint]> = [level.points]
        var frontier: [[WaveKnotKeeperPoint]] = [level.points]
        var depth: Int = 0
        var found: Int?
        while found == nil && !frontier.isEmpty && depth < WaveKnotKeeperSolver.maximumDepth {
            depth += 1
            var next: [[WaveKnotKeeperPoint]] = []
            for state in frontier {
                for move in rules.moves(in: state) {
                    guard let after = rules.apply(move, to: state), !seen.contains(after) else { continue }
                    seen.insert(after)
                    next.append(after)
                    if rules.isSolved(after) { found = depth }
                }
            }
            frontier = next
        }
        #expect(found == generated.solution.shortest)
        var rope: [WaveKnotKeeperPoint] = level.points
        for move in generated.solution.moves { rope = try #require(rules.apply(move, to: rope)) }
        #expect(rope == generated.solution.final && rules.isSolved(rope))
    }

    /// The witness files of `band` equal the regenerated witnesses byte for byte (written only with
    /// WAVE_KNOT_KEEPER_WRITE_WITNESSES=1).
    @Test(arguments: [1, 2, 3, 4, 5])
    func witnessFilesMatchByteForByte(band: Int) throws {
        let catalog: [WaveKnotKeeperGenerated] = try generatedBand(band)
        let write: Bool = ProcessInfo.processInfo.environment["WAVE_KNOT_KEEPER_WRITE_WITNESSES"] == "1"
        if write {
            try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true)
        }
        for generated in catalog {
            let witness: WaveKnotKeeperWitness = try WaveKnotKeeperWitness.make(generated)
            let data: Data = witness.encoded()
            let name: String = String(WaveKnotKeeperGenerator.levelID(generated.entry.number).suffix(3))
                + ".witness.json"
            let url: URL = witnessDirectory.appendingPathComponent(name)
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(name) differs from the regenerated witness")
            let decoded: WaveKnotKeeperWitness = try WaveKnotKeeperWitness.decode(stored)
            #expect(decoded == witness)
            #expect(decoded.moves.count <= generated.level.allowance)
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }

    /// Every generated level has a witness from the solver and its difficulty reflects the solver's actual result; a
    /// direct example plus seeded neighbouring entries, whose edited difficulty is refused.
    @Test func everyWitnessReflectsTheSolver() throws {
        let first: WaveKnotKeeperGenerated = try generatedLevel(1)
        let solved: WaveKnotKeeperSolution = try #require(WaveKnotKeeperSolver.solve(first.level,
                                                                                    depth: 1))
        #expect(solved == first.solution)
        #expect(first.difficulty.shortest == solved.moves.count && first.difficulty.work == solved.work)
        _ = try WaveKnotKeeperWitness.make(first)
        var random: SeededRandom = SeededRandom(seed: 2_322)
        for i in 0..<5 {
            let band: Int = i + 1
            let entry: WaveKnotKeeperManifestEntry = WaveKnotKeeperManifestEntry(
                number: i + 1, seed: random.next(), band: band, budget: band * 2 + 8)
            let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperGenerator.generate(entry)
            let data: Data = try WaveKnotKeeperWitness.make(generated).encoded()
            var object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            var difficulty: [String: Any] = try #require(object["difficulty"] as? [String: Any])
            let shortest: Int = try #require(difficulty["shortest"] as? Int)
            difficulty["shortest"] = shortest + 1
            object["difficulty"] = difficulty
            let edited: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            #expect(throws: WaveKnotKeeperError.self) { try WaveKnotKeeperWitness.decode(edited) }
        }
    }
}
