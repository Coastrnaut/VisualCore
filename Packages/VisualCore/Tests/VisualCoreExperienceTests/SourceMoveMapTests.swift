// SourceMoveMapTests — feature 187 T-U01-015 (FR-U01-046; data-model section 6).
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct SourceMoveMapTests {
    private func data(moves: [[String: Any]], schema: Int = 1, extra: Bool = false) -> Data {
        var root: [String: Any] = ["schema": schema, "moves": moves]
        if extra { root["note"] = "x" }
        return try! JSONSerialization.data(withJSONObject: root)
    }

    private let move: [String: Any] = ["from": "Apps/GenerativeArtStudio/Core", "to": "Packages/ExperiencesCreative/GenerativeArtStudio/Core",
                                        "gate": "UA-F07", "commit": "abc1234"]

    @Test func committedMapHasNoMovesYet() throws {
        #expect(try SourceMoveMap(data: CatalogFixture.data("path-map.json")).moves.isEmpty)
    }

    @Test func movesAreRead() throws {
        let map = try SourceMoveMap(data: data(moves: [move]))
        #expect(map.moves == [SourceMoveMap.Move(from: "Apps/GenerativeArtStudio/Core", to: "Packages/ExperiencesCreative/GenerativeArtStudio/Core",
                                                 gate: "UA-F07", commit: "abc1234")])
    }

    @Test func damagedMapsAreRefusedWithTypedErrors() {
        func refused(_ data: Data) -> CatalogError? { do { _ = try SourceMoveMap(data: data); return nil } catch { return error } }
        #expect(refused(data(moves: [], schema: 2)) == .unsupportedSchema(found: 2, supported: 1))
        #expect(refused(data(moves: [], extra: true)) == .unknownField(entry: "path-map", field: "note"))
        var missing = move; missing.removeValue(forKey: "gate")
        #expect(refused(data(moves: [missing])) == .missingField(entry: "#0", field: "gate"))
        var unknown = move; unknown["by"] = "someone"
        #expect(refused(data(moves: [unknown])) == .unknownField(entry: "#0", field: "by"))
        var long = move; long["to"] = String(repeating: "p", count: 301)
        guard case .invalidValue("#0", "to", _)? = refused(data(moves: [long])) else { Issue.record("a path of 301 characters was accepted"); return }
        var empty = move; empty["from"] = ""
        guard case .invalidValue("#0", "from", _)? = refused(data(moves: [empty])) else { Issue.record("an empty path was accepted"); return }
        #expect(refused(data(moves: Array(repeating: move, count: 5_001))) == .tooManyEntries(count: 5_001, limit: 5_000))
        #expect(refused(Data("[]".utf8)) == .unreadable(reason: "the top level is not an object"))
        #expect(refused(Data(repeating: 32, count: CatalogManifest.maxBytes + 1)) == .tooLarge(bytes: 1_048_577, limit: 1_048_576))
    }
}
