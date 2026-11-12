// CatalogLoadingTests — feature 187 T-U01-005 (FR-U01-010, FR-U01-013, FR-U01-020, FR-U01-021, FR-U01-030 to
// FR-U01-036; SC-U01-005; data-model sections 2, 3 and 8). One typed error per defect; never a partial catalog.
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct CatalogLoadingTests {
    private func load(_ data: Data) throws(CatalogError) -> CatalogManifest { try CatalogManifest(data: data) }

    private func expect(_ expected: CatalogError, _ change: (inout ManifestBuilder) -> Void, sourceLocation: SourceLocation = #_sourceLocation) {
        let data = ManifestBuilder.changing(change)
        #expect(throws: expected, sourceLocation: sourceLocation) { try CatalogManifest(data: data) }
    }

    @Test func validManifestLoadsEveryField() throws {
        let manifest = try load(ManifestBuilder().data)
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.catalogSHA256 == String(repeating: "a", count: 64))
        #expect(manifest.experiences.count == 100)
        let first = manifest.experiences[0]
        #expect(first.id.rawValue == "a01.e1" && first.code.text == "A01")
        #expect(first.title == "Experience 1" && first.summary == "Summary 1")
        #expect(first.kind == .creative && first.tier == .free && first.category == .create)
        #expect(first.family == "Wave mathematics" && first.tags == ["wave-mathematics"])
        #expect(first.order == 1 && first.tileSeed == 1 && first.palette.isEmpty && first.capabilities.isEmpty && first.qualityTiers.isEmpty)
        #expect(first.content == nil && !first.isAvailable)
        let last = manifest.experiences[99]
        #expect(last.code.text == "R04-G25" && last.kind == .game && last.tier == .premium && last.category == .puzzle)
        #expect(manifest.experience(first.id) == first)
        #expect(manifest.experience(code: last.code) == last)
        #expect(manifest.experiences(in: .puzzle).count == 75 && manifest.experiences(in: .create).count == 25)
        #expect(manifest.available.isEmpty)
        #expect(manifest.families(in: .puzzle) == ["Wave mathematics"])
    }

    @Test func registeredGameLoadsItsContentColorsAndLists() throws {
        let data = ManifestBuilder.changing { b in
            b.set(25, "content", ["levels": 100, "catalog_sha256": String(repeating: "0", count: 64)])
            b.set(25, "palette", ["#00A0B0", "#ff00aa"])
            b.set(25, "capabilities", ["export-image"])
            b.set(25, "quality_tiers", ["low", "high"])
            b.set(25, "available", true)
            b.set(25, "tile_seed", 4_294_967_295)
        }
        let game = try load(data).experiences[25]
        #expect(game.content == ExperienceContent(levels: 100, catalogSHA256: String(repeating: "0", count: 64)))
        #expect(game.palette == ["#00A0B0", "#ff00aa"] && game.capabilities == ["export-image"] && game.qualityTiers == ["low", "high"])
        #expect(game.isAvailable && game.tileSeed == 4_294_967_295)
        #expect(try load(data).available.map(\.id.rawValue) == ["r02-g01.e26"])
    }

    @Test func oversizedDataIsRefusedWithoutParsing() {
        let big = Data(repeating: UInt8(ascii: " "), count: CatalogManifest.maxBytes + 1)
        #expect(throws: CatalogError.tooLarge(bytes: 1_048_577, limit: 1_048_576)) { try CatalogManifest(data: big) }
        #expect(CatalogManifest.maxBytes == 1_048_576 && CatalogManifest.maxEntries == 400 && CatalogManifest.supportedSchema == 1)
    }

    @Test func unreadableDataIsATypedError() {
        for text in ["", "not json", "[1, 2]", "\"text\"", "{", "{\"schema\": }"] {
            do {
                _ = try CatalogManifest(data: Data(text.utf8))
                Issue.record("loaded \(text.debugDescription)")
            } catch {
                guard case .unreadable = error else { Issue.record("\(text.debugDescription) gave \(error)"); continue }
            }
        }        // Foundation's parser of this toolchain tolerates a trailing comma. Such a file is still refused by its shape.
        #expect(throws: CatalogError.missingField(entry: "manifest", field: "catalog_sha256")) {
            try CatalogManifest(data: Data("{\"schema\": 1,}".utf8))
        }
    }

    @Test func otherSchemaVersionsAreRefusedWithBothNumbers() {
        expect(.unsupportedSchema(found: 2, supported: 1)) { $0.root["schema"] = 2 }
        expect(.unsupportedSchema(found: 0, supported: 1)) { $0.root["schema"] = 0 }
        expect(.missingField(entry: "manifest", field: "schema")) { $0.root.removeValue(forKey: "schema") }
        expect(.wrongType(entry: "manifest", field: "schema")) { $0.root["schema"] = "1" }
    }

    @Test func topLevelShapeIsExact() {
        expect(.missingField(entry: "manifest", field: "catalog_sha256")) { $0.root.removeValue(forKey: "catalog_sha256") }
        expect(.missingField(entry: "manifest", field: "experiences")) { $0.root.removeValue(forKey: "experiences") }
        expect(.unknownField(entry: "manifest", field: "extra")) { $0.root["extra"] = 1 }
        expect(.wrongType(entry: "manifest", field: "experiences")) { $0.root["experiences"] = "none" }
        expect(.invalidValue(entry: "manifest", field: "catalog_sha256", reason: "64 lower-case hexadecimal digits")) { $0.root["catalog_sha256"] = "abc" }
        expect(.wrongType(entry: "#3", field: "experiences")) { b in
            var list = b.root["experiences"] as! [Any]
            list[3] = "text"
            b.root["experiences"] = list
        }
        expect(.tooManyEntries(count: 401, limit: 400)) { b in
            b.entries += (0..<301).map { ManifestBuilder.entry(code: String(format: "R05-G%02d", $0 % 25 + 1), order: 101 + $0) }
        }
    }

    @Test func everyKeyOfAnEntryIsRequiredAndNoOtherIsAllowed() {
        let keys = ["id", "code", "title", "summary", "kind", "tier", "category", "family", "tags", "order", "palette", "tile_seed",
                    "capabilities", "quality_tiers", "content", "available"]
        #expect(keys.count == 16)
        for key in keys where key != "id" {
            expect(.missingField(entry: "a03.e3", field: key)) { $0.remove(2, key) }
        }
        expect(.missingField(entry: "#2", field: "id")) { $0.remove(2, "id") }
        expect(.unknownField(entry: "a03.e3", field: "price")) { $0.set(2, "price", 1.99) }
    }

    @Test func wrongTypesAreNamed() {
        expect(.wrongType(entry: "a03.e3", field: "title")) { $0.set(2, "title", 7) }
        expect(.wrongType(entry: "a03.e3", field: "available")) { $0.set(2, "available", "yes") }
        expect(.wrongType(entry: "a03.e3", field: "available")) { $0.set(2, "available", 1) }
        expect(.wrongType(entry: "a03.e3", field: "order")) { $0.set(2, "order", true) }
        expect(.wrongType(entry: "a03.e3", field: "tags")) { $0.set(2, "tags", "wave-mathematics") }
        expect(.wrongType(entry: "a03.e3", field: "tags")) { $0.set(2, "tags", ["wave-mathematics", 3]) }
        expect(.wrongType(entry: "a03.e3", field: "content")) { $0.set(2, "content", "none") }
        expect(.wrongType(entry: "#2", field: "id")) { $0.set(2, "id", 3) }
    }

    @Test func invalidValuesAreNamed() {
        func invalid(_ index: Int, _ key: String, _ value: Any, sourceLocation: SourceLocation = #_sourceLocation) {
            let data = ManifestBuilder.changing { $0.set(index, key, value) }
            let name = ManifestBuilder().id(index)
            do {
                _ = try CatalogManifest(data: data)
                Issue.record("accepted \(key) = \(value)", sourceLocation: sourceLocation)
            } catch {
                guard case let .invalidValue(entry, field, reason) = error else {
                    Issue.record("\(key) = \(value) gave \(error)", sourceLocation: sourceLocation); return
                }
                #expect(entry == name && field == key && !reason.isEmpty, sourceLocation: sourceLocation)
            }
        }
        invalid(2, "tier", "trial"); invalid(2, "kind", "tool"); invalid(2, "category", "arcade")
        invalid(2, "code", "A04")
        invalid(2, "title", ""); invalid(2, "title", String(repeating: "t", count: 81))
        invalid(2, "summary", ""); invalid(2, "summary", String(repeating: "s", count: 301))
        invalid(2, "family", ""); invalid(2, "family", String(repeating: "f", count: 61))
        invalid(2, "tags", (0..<17).map { "wave-mathematics\($0)" }); invalid(2, "tags", ["other"]); invalid(2, "tags", ["wave-mathematics", ""])
        invalid(2, "palette", (0..<9).map { _ in "#000000" }); invalid(2, "palette", ["red"]); invalid(2, "palette", ["#12345G"])
        invalid(2, "capabilities", (0..<17).map { "c\($0)" }); invalid(2, "capabilities", [String(repeating: "c", count: 41)])
        invalid(2, "quality_tiers", (0..<9).map { "q\($0)" })
        invalid(2, "tags", ["wave-mathematics", String(repeating: "t", count: 61)])
        invalid(2, "quality_tiers", [String(repeating: "q", count: 41)])
        let atTheLimits = ManifestBuilder.changing {
            $0.set(2, "tags", ["wave-mathematics", String(repeating: "t", count: 60)])
            $0.set(2, "quality_tiers", [String(repeating: "q", count: 40)])
            $0.set(2, "capabilities", [String(repeating: "c", count: 40)])
        }
        #expect((try? CatalogManifest(data: atTheLimits)) != nil)
        invalid(2, "category", "puzzle")           // a creative experience is never a puzzle
        invalid(30, "category", "create")          // a game is always a puzzle
        invalid(2, "content", ["levels": 1, "catalog_sha256": String(repeating: "0", count: 64)])   // content belongs to games
        invalid(30, "content", ["levels": 1, "catalog_sha256": "short"])
        // a malformed id is named by its index, because the id itself cannot be trusted
        #expect(throws: CatalogError.self) { try CatalogManifest(data: ManifestBuilder.changing { $0.set(2, "id", "A03.E3") }) }
        let longTitle = ManifestBuilder.changing { $0.set(2, "title", String(repeating: "t", count: 80)); $0.set(2, "summary", String(repeating: "s", count: 300)) }
        #expect((try? CatalogManifest(data: longTitle)) != nil)
    }

    @Test func numbersMustBeFiniteWholeAndInRange() {
        func bad(_ index: Int, _ key: String, _ value: Any, sourceLocation: SourceLocation = #_sourceLocation) {
            let data = ManifestBuilder.changing { $0.set(index, key, value) }
            do {
                _ = try CatalogManifest(data: data)
                Issue.record("accepted \(key) = \(value)", sourceLocation: sourceLocation)
            } catch {
                guard case let .invalidNumber(entry, field, reason) = error else {
                    Issue.record("\(key) = \(value) gave \(error)", sourceLocation: sourceLocation); return
                }
                #expect(entry == ManifestBuilder().id(index) && field == key && !reason.isEmpty, sourceLocation: sourceLocation)
            }
        }
        bad(2, "order", 0); bad(2, "order", 10_000); bad(2, "order", 1.5); bad(2, "order", -3)
        bad(2, "tile_seed", -1); bad(2, "tile_seed", 4_294_967_296); bad(2, "tile_seed", 0.25)
        bad(30, "content", ["levels": 10_001, "catalog_sha256": String(repeating: "0", count: 64)] as [String: Any])
        bad(30, "content", ["levels": -1, "catalog_sha256": String(repeating: "0", count: 64)] as [String: Any])
        // A number too large for any finite value never becomes a catalog: the parser or the loader refuses it.
        let huge = String(decoding: ManifestBuilder().data, as: UTF8.self).replacingOccurrences(of: "\"order\":3,", with: "\"order\":1e400,")
        #expect(huge.contains("1e400"))
        do {
            _ = try CatalogManifest(data: Data(huge.utf8))
            Issue.record("accepted a non-finite number")
        } catch {
            switch error {
            case .invalidNumber(_, "order", _), .unreadable: break
            default: Issue.record("1e400 gave \(error)")
            }
        }
    }

    @Test func duplicatesAndOrderAreChecked() {
        expect(.duplicate(field: "id", value: "a03.e3")) { $0.set(3, "id", "a03.e3"); $0.set(3, "code", "A03") }
        expect(.duplicate(field: "code", value: "A03")) { $0.set(3, "id", "a03.other"); $0.set(3, "code", "A03") }
        expect(.duplicate(field: "order", value: "3")) { $0.set(3, "order", 3) }
        expect(.outOfOrder(entry: "a03.e3")) { $0.set(3, "order", 2); $0.set(1, "order", 4) }
    }

    @Test func theFirstDefectIsReportedAndNothingPartialIsReturned() {
        // Entry 1 has an unknown tier; entry 5 lacks its title; the top level has an extra key: the top level comes first.
        expect(.unknownField(entry: "manifest", field: "extra")) { $0.root["extra"] = 1; $0.set(1, "tier", "trial"); $0.remove(5, "title") }
        let data = ManifestBuilder.changing { $0.set(1, "tier", "trial"); $0.remove(5, "title") }
        do {
            _ = try CatalogManifest(data: data)
            Issue.record("loaded a damaged manifest")
        } catch {
            #expect(error == .invalidValue(entry: "a02.e2", field: "tier", reason: "free or premium"))
        }
    }

    @Test func loadingIsDeterministic() throws {
        let data = ManifestBuilder().data
        #expect(try CatalogManifest(data: data) == (try CatalogManifest(data: data)))
    }
}
