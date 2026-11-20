// AuroraLoomCatalogTests — feature 302 (R02-G01-02) T-R02G0102-006 (FR-R02G0102-001, 003, 004, 005; SC-R02G0102-001,
// 003, 004, 005; R2-G01-INV-06). The 100-level catalog: manifest shape, determinism, the pinned digest, the progression
// rule, band means, and the witness files in docs/games/aurora-loom/levels/ compared byte for byte. The files are written
// only when AURORA_LOOM_WRITE_WITNESSES=1 is set. Test data uses explicit types and plain loops (CI type-check rule).
@testable import AuroraLoomCore
import Foundation
import Testing
import VisualCoreSimulation

/// The catalog, generated once per test process.
private let generatedCatalog: Result<[AuroraLoomGenerated], any Error> = Result { try AuroraLoomGenerator.catalog() }

/// The repository's witness directory, found from this file.
private let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/aurora-loom/levels", isDirectory: true)

@Suite struct AuroraLoomCatalogTests {
    /// The pinned catalog digest; an intended rule or seed change re-pins it after review.
    static let pinnedDigest = "dc82c050cf90127a0c198f08433eecdd9c84c5d3e49ac9b45b9810f6ee5891d6"

    @Test func manifestHasOneHundredEntriesTwentyPerBand() {
        let entries: [AuroraLoomManifestEntry] = AuroraLoomManifest.entries
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
        #expect(entries[0].seed == 0x5120dc77933d0034)
    }

    @Test func catalogIsDeterministicAndMatchesThePinnedDigest() throws {
        let catalog = try generatedCatalog.get()
        #expect(catalog.count == 100)
        let again = try AuroraLoomGenerator.catalog()
        #expect(catalog == again)
        let digest = AuroraLoomGenerator.catalogDigest(catalog)
        #expect(digest == Self.pinnedDigest, "catalog digest \(digest)")
        #expect(Set(catalog.map(\.level.fingerprint)).count == 100)
    }

    @Test func everyLevelIsSolvableWithinItsAllowanceAndKeepsTheProgression() throws {
        let catalog = try generatedCatalog.get()
        var difficulties: [PuzzleDifficulty] = []
        var sumShortest: [Int] = [0, 0, 0, 0, 0]
        var sumWork: [Int] = [0, 0, 0, 0, 0]
        for generated in catalog {
            let level = generated.level
            #expect(!AuroraLoomHarmony.wins(level.startSteps, level: level))
            #expect(generated.solution.shortest <= level.allowance)
            let profile = try #require(AuroraLoomBandProfile.of(band: level.band))
            #expect(profile.shortest.contains(generated.solution.shortest))
            difficulties.append(generated.difficulty.puzzleDifficulty)
            sumShortest[level.band - 1] += generated.difficulty.shortest
            sumWork[level.band - 1] += generated.difficulty.work
        }
        #expect(ProgressionRule.standard.breach(difficulties) == nil)
        for band in 1..<5 {
            #expect(sumShortest[band] >= sumShortest[band - 1], "mean shortest falls at band \(band + 1)")
            #expect(sumWork[band] >= sumWork[band - 1], "mean work falls at band \(band + 1): \(sumWork)")
        }
    }

    @Test func witnessFilesMatchByteForByte() throws {
        let catalog = try generatedCatalog.get()
        let write: Bool = ProcessInfo.processInfo.environment["AURORA_LOOM_WRITE_WITNESSES"] == "1"
        if write {
            try FileManager.default.createDirectory(at: witnessDirectory, withIntermediateDirectories: true)
        }
        for generated in catalog {
            let witness = try AuroraLoomWitness(generated)
            let data: Data = witness.encoded()
            let name: String = String(AuroraLoomGenerator.levelID(generated.entry.number).suffix(3)) + ".witness.json"
            let url: URL = witnessDirectory.appendingPathComponent(name)
            if write { try data.write(to: url) }
            let stored: Data = try Data(contentsOf: url)
            #expect(stored == data, "\(name) differs from the regenerated witness")
            let decoded = try AuroraLoomWitness.decode(stored)
            #expect(decoded == witness)
            #expect(decoded.actions.count <= decoded.level.allowance)
            #expect(abs(decoded.counterexample.mismatch.residual) > decoded.level.tolerance)
        }
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: witnessDirectory.path)
            .filter { $0.hasSuffix(".witness.json") }
        #expect(names.count == 100)
    }

    /// The runtime catalog's content facts (feature 303, R02-G01-03): `Catalog/experiences.json` lists Aurora Loom with
    /// 100 levels and this catalog's pinned digest, so the two cannot drift apart.
    @Test func theRuntimeCatalogNamesTheseLevels() throws {
        let catalogURL: URL = witnessDirectory.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Catalog/experiences.json")
        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let entries = try #require(object["experiences"] as? [[String: Any]])
        var content: [String: Any]? = nil
        for entry in entries where entry["id"] as? String == "r02-g01.aurora-loom" { content = entry["content"] as? [String: Any] }
        let facts = try #require(content)
        #expect(facts["levels"] as? Int == AuroraLoomManifest.entries.count)
        #expect(facts["catalog_sha256"] as? String == Self.pinnedDigest)
    }

    /// R2-G01-INV-06 (content): every generated stage has a witness from the solver and its difficulty reflects the
    /// solver's actual work; a direct example plus seeded neighbouring entries, whose edited difficulty is refused.
    @Test func testAuroraLoomContentBoundary() throws {
        let catalog = try generatedCatalog.get()
        let first = catalog[0]
        let solved = try #require(AuroraLoomSolver.solve(first.level))
        #expect(solved == first.solution)
        #expect(first.difficulty.work == solved.work)
        #expect(first.difficulty.shortest == solved.moves.count)
        _ = try AuroraLoomWitness(first)
        var random = SeededRandom(seed: 2_301)
        for i in 0..<10 {
            let band: Int = i % 5 + 1
            let entry = AuroraLoomManifestEntry(number: i + 1, seed: random.next(), band: band, budget: band + 8)
            let generated = try AuroraLoomGenerator.generate(entry)
            let resolved = try #require(AuroraLoomSolver.solve(generated.level))
            #expect(generated.difficulty == AuroraLoomDifficulty(level: generated.level, solution: resolved))
            let data: Data = try AuroraLoomWitness(generated).encoded()
            var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            var difficulty = try #require(object["difficulty"] as? [String: Any])
            let shortest = try #require(difficulty["shortest"] as? Int)
            difficulty["shortest"] = shortest + 1
            object["difficulty"] = difficulty
            let edited: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            #expect(throws: AuroraLoomError.self) { try AuroraLoomWitness.decode(edited) }
        }
    }
}
