// CategoryListTests — feature 187 T-U01-013 (FR-U01-022; data-model section 4).
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct CategoryListTests {
    private func data(_ change: (inout [String: Any]) -> Void = { _ in }) -> Data {
        var root: [String: Any] = ["schema": 1, "categories": ExperienceCategory.allCases.map { ["id": $0.rawValue, "title": $0.rawValue.capitalized] }]
        change(&root)
        return try! JSONSerialization.data(withJSONObject: root)
    }

    private func refused(_ change: (inout [String: Any]) -> Void) -> CatalogError? {
        do { _ = try CategoryList(data: data(change)); return nil } catch { return error }
    }

    @Test func committedListHoldsTheSevenCategoriesInLauncherOrder() throws {
        let list = try CategoryList(data: CatalogFixture.data("categories.json"))
        #expect(list.categories.map(\.id) == ExperienceCategory.allCases)
        #expect(list.categories.map(\.id.rawValue) == ["create", "audio", "play", "learn", "ambient", "tools", "puzzle"])
        #expect(list.title(of: .create) == "Create" && list.title(of: .puzzle) == "Puzzles")
        #expect(list.categories.allSatisfy { (1...40).contains($0.title.count) })
        let manifest = try CatalogManifest(data: CatalogFixture.data("experiences.json"), categories: list)
        #expect(manifest.experiences.count == 100)
    }

    @Test func damagedListsAreRefusedWithTypedErrors() {
        #expect(refused { $0["schema"] = 2 } == .unsupportedSchema(found: 2, supported: 1))
        #expect(refused { $0["extra"] = true } == .unknownField(entry: "categories", field: "extra"))
        #expect(refused { $0.removeValue(forKey: "categories") } == .missingField(entry: "categories", field: "categories"))
        #expect(refused { $0["categories"] = "none" } == .wrongType(entry: "categories", field: "categories"))
        func entries(_ change: (inout [[String: Any]]) -> Void) -> CatalogError? {
            refused { root in
                var list = root["categories"] as! [[String: Any]]
                change(&list)
                root["categories"] = list
            }
        }
        guard case .invalidValue("categories", "categories", _)? = entries({ $0.removeLast() }) else { Issue.record("six entries accepted"); return }
        guard case .invalidValue("categories", "categories", _)? = entries({ $0.swapAt(0, 1) }) else { Issue.record("wrong order accepted"); return }
        guard case .invalidValue("#2", "id", _)? = entries({ $0[2]["id"] = "arcade" }) else { Issue.record("unknown id accepted"); return }
        guard case .invalidValue("#2", "title", _)? = entries({ $0[2]["title"] = "" }) else { Issue.record("empty title accepted"); return }
        guard case .invalidValue("#2", "title", _)? = entries({ $0[2]["title"] = String(repeating: "t", count: 41) }) else { Issue.record("long title accepted"); return }
        #expect(entries { $0[2]["color"] = "#000000" } == .unknownField(entry: "#2", field: "color"))
        #expect(entries { $0[2].removeValue(forKey: "title") } == .missingField(entry: "#2", field: "title"))
        #expect((try? CategoryList(data: Data(repeating: 32, count: CatalogManifest.maxBytes + 1))) == nil)
        #expect(throws: CatalogError.tooLarge(bytes: 1_048_577, limit: 1_048_576)) {
            try CategoryList(data: Data(repeating: 32, count: CatalogManifest.maxBytes + 1))
        }
    }

    @Test func manifestEntryOfACategoryMissingFromTheListIsRefused() throws {
        let full = try CategoryList(data: data())
        let withoutPuzzle = CategoryList(entries: full.categories.filter { $0.id != .puzzle })
        #expect(throws: CatalogError.invalidValue(entry: "r02-g01.e26", field: "category", reason: "not in the category list")) {
            try CatalogManifest(data: ManifestBuilder().data, categories: withoutPuzzle)
        }
        #expect((try? CatalogManifest(data: ManifestBuilder().data, categories: full)) != nil)
    }
}
