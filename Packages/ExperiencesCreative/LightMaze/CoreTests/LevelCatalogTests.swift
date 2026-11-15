// LevelCatalogTests — feature 096 (A13-P01) T-A13-103 (FR-A13-112–114; clarification Q4; research D4; SC-A13-103).
// The level catalog, host-free and short: twenty levels `lm-01` … `lm-20` with names, author and license; every level
// valid, unsolved in its starting orientations and solved by its recorded solution (proved with the tracer); the tiers
// (levels 1–5 one or two mirrors, 6–15 more mirrors and walls, 16–20 a prism and two targets); the JSON round trip with
// sorted keys; each refusal reason (missing-license, unsupported-license, invalid-number, out-of-range, invalid-board,
// duplicate-id) named for a damaged level while the valid rest is kept; an unreadable document refused as a whole.
import Foundation
import LightMazeCore
import Testing

@Suite struct LevelCatalogTests {
    private let catalog = LevelCatalog.bundled

    /// The bundled catalog's JSON level records, ready to be damaged.
    private func records() throws -> [[String: Any]] {
        let root = try #require(try JSONSerialization.jsonObject(with: catalog.encoded()) as? [String: Any])
        return try #require(root["levels"] as? [[String: Any]])
    }

    /// Decodes a schema-1 document of `levels`.
    private func decode(_ levels: [Any]) throws -> (catalog: LevelCatalog, refused: [LevelRefusal]) {
        LevelCatalog.decode(try JSONSerialization.data(withJSONObject: ["levels": levels, "schema": 1]))
    }

    @Test func thereAreTwentyLevelsWithProvenance() {
        #expect(catalog.levels.count == 20)
        var ids: [String] = []
        for number in 1...20 { ids.append(number < 10 ? "lm-0\(number)" : "lm-\(number)") }
        #expect(catalog.levels.map(\.id) == ids)
        #expect(Set(catalog.levels.map(\.name)).count == 20)
        #expect(catalog.levels.allSatisfy { !$0.name.isEmpty })
        #expect(catalog.levels[0].name == "First light")
        #expect(catalog.levels.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(LevelCatalog.allowedLicenses == ["MIT"] && LevelCatalog.projectAuthor == "VisualCore project")
        #expect(catalog.level(id: "lm-07")?.name == catalog.levels[6].name)
        #expect(catalog.level(id: "lm-21") == nil && catalog.level(at: 20) == nil && catalog.level(at: -1) == nil)
    }

    @Test func everyLevelIsValidUnsolvedAtStartAndSolvedByItsSolution() throws {
        let levels: [Level] = catalog.levels
        for level in levels {
            #expect(level.board.problem == nil, "\(level.id) is valid")
            #expect(LevelCatalog.check(level) == nil, "\(level.id) passes the catalog checks")
            #expect(level.solution.count == level.turnableCount, "\(level.id) solution length")
            let start = BeamTracer.trace(level.board)
            #expect(!start.isSolved, "\(level.id) is not solved at start")
            let solved = BeamTracer.trace(try #require(level.solvedBoard, "\(level.id)"))
            #expect(solved.isSolved, "\(level.id) is solved by its solution")
            #expect(Set(solved.litTargets) == Set(level.board.targetCells), "\(level.id) lights every target")
            #expect(level.startOrientations != level.solution, "\(level.id)")
        }
    }

    @Test func theLevelsFollowTheirTiers() {
        for (index, level) in catalog.levels.enumerated() {
            let kinds: [TileKind] = level.board.tiles.map(\.kind)
            let mirrors = kinds.filter { $0 == .mirror }.count
            let prisms = kinds.filter { $0 == .prism }.count
            let walls = kinds.filter { $0 == .wall }.count
            let targets = kinds.filter { $0 == .target }.count
            switch index {
            case 0..<5:
                #expect((1...2).contains(mirrors) && prisms == 0 && targets == 1, "\(level.id)")
            case 5..<15:
                #expect(mirrors >= 3 && walls >= 3 && prisms == 0 && targets == 1, "\(level.id)")
            default:
                #expect(prisms >= 1 && targets == 2 && walls >= 2, "\(level.id)")
            }
        }
        let first = catalog.levels[0]
        #expect(first.board.tiles.filter { $0.kind == .mirror }.count == 1)
        #expect(first.board.tiles.contains { $0.kind == .wall })
    }

    @Test func theJSONRoundTripIsExactAndSorted() throws {
        let data = catalog.encoded()
        let decoded = LevelCatalog.decode(data)
        #expect(decoded.refused.isEmpty)
        #expect(decoded.catalog == catalog)
        #expect(decoded.catalog.encoded() == data)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix(#"{"levels":[{"author":"VisualCore project","height":5,"id":"lm-01","license":"MIT","#))
        #expect(text.hasSuffix(#"],"schema":1}"#))
        #expect(text.contains(#"{"column":0,"direction":"east","kind":"emitter","row":2}"#))
    }

    @Test func eachDamagedLevelIsRefusedWithItsReasonWhileTheRestIsKept() throws {
        let base = try records()
        var damaged: [[String: Any]] = []
        var expected: [LevelRefusal] = []
        func add(_ index: Int, _ reason: LevelRefusalReason, _ change: (inout [String: Any]) -> Void) {
            var record = base[index]
            change(&record)
            damaged.append(record)
            expected.append(LevelRefusal(id: (record["id"] as? String) ?? "", reason: reason))
        }
        add(0, .missingLicense) { $0["license"] = "" }
        add(1, .missingLicense) { $0.removeValue(forKey: "author") }
        add(2, .unsupportedLicense) { $0["license"] = "GPL-3.0" }
        add(3, .invalidNumber) { $0["width"] = 6.5 }
        add(4, .invalidNumber) { $0["height"] = "six" }
        add(5, .invalidNumber) { $0["id"] = "" }
        add(6, .invalidNumber) { record in
            var tiles = record["tiles"] as? [[String: Any]] ?? []
            tiles[0]["kind"] = "lamp"
            record["tiles"] = tiles
        }
        add(7, .invalidNumber) { $0["solution"] = ["sideways"] }
        add(8, .outOfRange) { $0["width"] = 13 }
        add(9, .outOfRange) { $0["height"] = 3 }
        add(10, .invalidBoard) { record in
            var tiles = record["tiles"] as? [[String: Any]] ?? []
            tiles.append(["column": 0, "direction": "east", "kind": "emitter", "row": 99])
            record["tiles"] = tiles
        }
        add(11, .invalidBoard) { record in
            var solution = record["solution"] as? [String] ?? []
            solution.append("slash")
            record["solution"] = solution
        }
        add(12, .invalidBoard) { record in
            let tiles = record["tiles"] as? [[String: Any]] ?? []
            record["tiles"] = tiles.filter { ($0["kind"] as? String) != "target" }
        }
        var valid = base[19]
        damaged.append(valid)
        valid["name"] = "Copy"
        damaged.append(valid)
        expected.append(LevelRefusal(id: "lm-20", reason: .duplicateId))
        damaged.append(["not": "a level"])
        expected.append(LevelRefusal(id: "", reason: .missingLicense))
        let result = try decode(damaged)
        #expect(result.refused == expected)
        #expect(result.catalog.levels == [catalog.levels[19]])
        #expect(LevelRefusalReason.allCases.map(\.rawValue) == ["missing-license", "unsupported-license",
                                                               "invalid-number", "out-of-range", "duplicate-id",
                                                               "invalid-board"])
    }

    @Test func anUnreadableDocumentIsRefusedAsAWhole() throws {
        let refusal = [LevelRefusal(id: "catalog", reason: .invalidNumber)]
        let documents: [Data] = [
            Data("not json".utf8),
            Data(#"{"levels":[]}"#.utf8),
            Data(#"{"levels":[],"schema":2}"#.utf8),
            Data(#"{"levels":{},"schema":1}"#.utf8),
            Data("[]".utf8),
        ]
        for data in documents {
            let result = LevelCatalog.decode(data)
            #expect(result.catalog.levels.isEmpty && result.refused == refusal)
        }
        let empty = LevelCatalog.decode(Data(#"{"levels":[],"schema":1}"#.utf8))
        #expect(empty.catalog.levels.isEmpty && empty.refused.isEmpty)
    }

    @Test func theInMemoryCheckNamesTheFirstProblem() {
        var level = catalog.levels[0]
        level.author = " "
        #expect(LevelCatalog.check(level) == .missingLicense)
        level = catalog.levels[0]
        level.license = "CC0-1.0"
        #expect(LevelCatalog.check(level) == .unsupportedLicense)
        level = catalog.levels[0]
        level.board.width = 20
        #expect(LevelCatalog.check(level) == .outOfRange)
        level = catalog.levels[0]
        level.solution = []
        #expect(LevelCatalog.check(level) == .invalidBoard)
        level = catalog.levels[0]
        level.board.tiles.append(.emitter(4, 4, .west))
        #expect(LevelCatalog.check(level) == .invalidBoard)
    }
}
