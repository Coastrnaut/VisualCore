// LissajousLabyrinthCatalogTests — feature 312 (R02-G02-02) T-R02G0202-006 (FR-R02G0202-001, 003, 004, 005;
// SC-R02G0202-001 … 005; R2-G02-INV-06). The 100-level catalog: manifest shape, determinism, the pinned digest, the
// progression rule, band means, the kernel cross-check on levels 1, 11, … 91 and the witness files in
// docs/games/lissajous-labyrinth/levels/ compared byte for byte, one test per band. The files are written only when
// LISSAJOUS_LABYRINTH_WRITE_WITNESSES=1 is set. Test data uses explicit types and plain loops (CI type-check rule).
@testable import LissajousLabyrinthCore
import Foundation
import Testing
import VisualCoreSimulation

/// The levels of one band (20 entries), generated in manifest order.
private func generateBand(_ band: Int) -> Result<[LissajousLabyrinthGenerated], any Error> {
    Result {
        var result: [LissajousLabyrinthGenerated] = []
        for entry in LissajousLabyrinthManifest.entries where entry.band == band {
            result.append(try LissajousLabyrinthGenerator.generate(entry))
        }
        return result
    }
}

// Each band is generated once per test process, on first use, so no single test waits for the whole catalog (each test
// stays under 10 s; the catalog-wide checks read the witness files, which the band tests prove equal to the regenerated
// witnesses byte for byte).
private let band1: Result<[LissajousLabyrinthGenerated], any Error> = generateBand(1)
private let band2: Result<[LissajousLabyrinthGenerated], any Error> = generateBand(2)
private let band3: Result<[LissajousLabyrinthGenerated], any Error> = generateBand(3)
private let band4: Result<[LissajousLabyrinthGenerated], any Error> = generateBand(4)
private let band5: Result<[LissajousLabyrinthGenerated], any Error> = generateBand(5)

/// The generated levels of `band` (1 … 5).
private func generatedBand(_ band: Int) throws -> [LissajousLabyrinthGenerated] {
    switch band {
    case 1: try band1.get()
    case 2: try band2.get()
    case 3: try band3.get()
    case 4: try band4.get()
    default: try band5.get()
    }
}

/// The generated level of manifest number `number`.
private func generatedLevel(_ number: Int) throws -> LissajousLabyrinthGenerated {
    let entry: LissajousLabyrinthManifestEntry = LissajousLabyrinthManifest.entries[number - 1]
    let band: [LissajousLabyrinthGenerated] = try generatedBand(entry.band)
    for generated in band where generated.entry.number == number { return generated }
    throw LissajousLabyrinthError.generation(number)
}

/// The 100 stored witnesses, decoded (and so re-verified) in manifest order.
private func storedWitnesses() throws -> [LissajousLabyrinthWitness] {
    var result: [LissajousLabyrinthWitness] = []
    for entry in LissajousLabyrinthManifest.entries {
        let name: String = String(LissajousLabyrinthGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        result.append(try LissajousLabyrinthWitness.decode(Data(contentsOf: witnessDirectory.appendingPathComponent(name))))
    }
    return result
}

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/lissajous-labyrinth/levels", isDirectory: true)

@Suite struct LissajousLabyrinthCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "9c1d5652c1dc2badac0568fc25a79ef3a0a4683d2db290e1b1699b120430e96e"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [LissajousLabyrinthManifestEntry] = LissajousLabyrinthManifest.entries
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
        #expect(entries[0].seed == 0x85800cda80a90937)
    }

    /// The digest over the stored levels' fingerprints (equal to the generated ones: see the band tests) is pinned;
    /// three levels regenerate identically.
    @Test func catalogMatchesThePinnedDigestAndRegeneratesIdentically() throws {
        let witnesses: [LissajousLabyrinthWitness] = try storedWitnesses()
        #expect(witnesses.count == 100)
        var fingerprints: [String] = []
        for witness in witnesses { fingerprints.append(witness.level.fingerprint) }
        let digest: String = PuzzleCatalog<LissajousLabyrinthRules>.digest(id: LissajousLabyrinthGenerator.catalogID,
                                                                         identities: fingerprints)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(fingerprints).count == 100)
        for number in [1, 38, 100] {
            let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthGenerator.generate(
                LissajousLabyrinthManifest.entries[number - 1])
            #expect(generated.level == witnesses[number - 1].level)
            #expect(LissajousLabyrinthGenerator.catalogDigest([generated])
                == PuzzleCatalog<LissajousLabyrinthRules>.digest(id: LissajousLabyrinthGenerator.catalogID,
                                                                 identities: [witnesses[number - 1].level.fingerprint]))
        }
    }

    /// Solvable within the allowance, inside each band's range, positive clearance; the progression rule and the band
    /// means hold over the stored difficulties.
    @Test func everyLevelIsSolvableWithinItsAllowanceAndKeepsTheProgression() throws {
        let witnesses: [LissajousLabyrinthWitness] = try storedWitnesses()
        var difficulties: [PuzzleDifficulty] = []
        var sumShortest: [Int] = [0, 0, 0, 0, 0]
        var sumWinning: [Int] = [0, 0, 0, 0, 0]
        for witness in witnesses {
            let level: LissajousLabyrinthLevel = witness.level
            #expect(witness.actions.count <= level.allowance)
            #expect(witness.difficulty.clearance > 0)
            let profile: LissajousLabyrinthBandProfile = try #require(LissajousLabyrinthBandProfile.of(band: level.band))
            #expect(profile.shortest.contains(witness.difficulty.shortest))
            difficulties.append(witness.difficulty.puzzleDifficulty)
            sumShortest[level.band - 1] += witness.difficulty.shortest
            sumWinning[level.band - 1] += witness.difficulty.winningSettings
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumShortest[band] >= sumShortest[band - 1], "mean shortest falls at band \(band + 1)")
            #expect(sumWinning[band] <= sumWinning[band - 1], "mean winners rise at band \(band + 1): \(sumWinning)")
        }
    }

    /// SC-R02G0202-002 on levels 1, 11, … 91: every decided winner and 440 seeded settings agree with the kernel's
    /// verdict, and a plain breadth-first search over the decided winning set finds the same shortest length.
    @Test(arguments: [1, 11, 21, 31, 41, 51, 61, 71, 81, 91])
    func theSolverAgreesWithTheKernel(number: Int) throws {
        let generated: LissajousLabyrinthGenerated = try generatedLevel(number)
        let level: LissajousLabyrinthLevel = generated.level
        let winners: [LissajousLabyrinthDials] = LissajousLabyrinthSolver.winningSettings(level).settings
        #expect(winners.count == generated.solution.winningSettings)
        for dials in winners { #expect(LissajousLabyrinthLap.verdict(dials, level: level) == .won) }
        let winning: Set<LissajousLabyrinthDials> = Set(winners)
        let legal: [LissajousLabyrinthDials] = LissajousLabyrinthSolver.legalSettings()
        var random: SeededRandom = SeededRandom(seed: 2_312 + UInt64(number))
        for _ in 0..<440 {
            let dials: LissajousLabyrinthDials = legal[random.int(0...(legal.count - 1))]
            #expect((LissajousLabyrinthLap.verdict(dials, level: level) == .won) == winning.contains(dials))
        }
        // Plain breadth-first search over legal states.
        let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: level)
        var seen: Set<LissajousLabyrinthDials> = [level.start]
        var frontier: [LissajousLabyrinthDials] = [level.start]
        var depth: Int = 0
        var found: Int? = winning.contains(level.start) ? 0 : nil
        while found == nil && !frontier.isEmpty {
            depth += 1
            var next: [LissajousLabyrinthDials] = []
            for state in frontier {
                for move in rules.moves(in: state) {
                    guard let after = rules.apply(move, to: state), !seen.contains(after) else { continue }
                    seen.insert(after)
                    next.append(after)
                    if winning.contains(after) { found = depth }
                }
            }
            frontier = next
        }
        #expect(found == generated.solution.shortest)
    }

    /// The witness files of `band` equal the regenerated witnesses byte for byte (written only with
    /// LISSAJOUS_LABYRINTH_WRITE_WITNESSES=1).
    @Test(arguments: [1, 2, 3, 4, 5])
    func witnessFilesMatchByteForByte(band: Int) throws {
        let catalog: [LissajousLabyrinthGenerated] = try generatedBand(band)
        let write: Bool = ProcessInfo.processInfo.environment["LISSAJOUS_LABYRINTH_WRITE_WITNESSES"] == "1"
        if write {
            try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true)
        }
        for generated in catalog {
            let witness: LissajousLabyrinthWitness = try LissajousLabyrinthWitness.make(generated)
            let data: Data = witness.encoded()
            let name: String = String(LissajousLabyrinthGenerator.levelID(generated.entry.number).suffix(3))
                + ".witness.json"
            let url: URL = witnessDirectory.appendingPathComponent(name)
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(name) differs from the regenerated witness")
            let decoded: LissajousLabyrinthWitness = try LissajousLabyrinthWitness.decode(stored)
            #expect(decoded == witness)
            #expect(decoded.actions.count <= generated.level.allowance)
        }
    }

    @Test func thereAreOneHundredWitnessFiles() throws {
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }

    /// R2-G02-INV-06 (content): every generated stage has a witness from the solver and its difficulty reflects the
    /// solver's actual result; a direct example plus seeded neighbouring entries, whose edited difficulty is refused.
    @Test func testLissajousLabyrinthContentBoundary() throws {
        let first: LissajousLabyrinthGenerated = try generatedLevel(1)
        let solved: LissajousLabyrinthSolution = try #require(LissajousLabyrinthSolver.solve(first.level))
        #expect(solved == first.solution)
        #expect(first.difficulty.shortest == solved.actions.count && first.difficulty.work == solved.work)
        _ = try LissajousLabyrinthWitness.make(first)
        var random: SeededRandom = SeededRandom(seed: 2_316)
        for i in 0..<5 {
            let band: Int = i + 1
            let entry: LissajousLabyrinthManifestEntry = LissajousLabyrinthManifestEntry(
                number: i + 1, seed: random.next(), band: band, budget: band * 2 + 8)
            let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthGenerator.generate(entry)
            let data: Data = try LissajousLabyrinthWitness.make(generated).encoded()
            var object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            var difficulty: [String: Any] = try #require(object["difficulty"] as? [String: Any])
            let shortest: Int = try #require(difficulty["shortest"] as? Int)
            difficulty["shortest"] = shortest + 1
            object["difficulty"] = difficulty
            let edited: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            #expect(throws: LissajousLabyrinthError.self) { try LissajousLabyrinthWitness.decode(edited) }
        }
    }
}
