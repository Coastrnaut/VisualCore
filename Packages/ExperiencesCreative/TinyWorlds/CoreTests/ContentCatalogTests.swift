// ContentCatalogTests — feature 089 (A12-P01) T-A12-103 (FR-A12-113; clarification 5; G-CONTENTLICENSES; SC-A12-105).
// The content catalog, host-free and short: the three bundled presets and palettes with their ids, names, three
// colours, author and license; the JSON round trip with sorted keys; each refusal reason (missing-license,
// unsupported-license, out-of-range, invalid-number, duplicate-id) named for a malformed record while the valid rest is
// kept; an unreadable document refused as a whole.
//
// Feature 091 (A12-P03) T-A12-302 (FR-A12-301; clarification Q1): the four props and their prop palettes (same ids,
// three colours, "VisualCore project", "MIT"); malformed prop and prop palette records refused with their reasons;
// documents without the prop lists still read.
//
// Feature 092 (A12-P04) T-A12-402 (FR-A12-406; clarification Q2): the three packs (island, asteroid-garden,
// miniature-city) naming their presets, "VisualCore project", "MIT"; malformed pack records refused with their
// reasons; documents without the pack list still read; the sorted JSON now starts with the packs.
import Foundation
import Testing
import TinyWorldsCore

@Suite struct ContentCatalogTests {
    private let catalog = ContentCatalog.bundled
    private let ids = ["island", "asteroid-garden", "miniature-city"]

    /// The bundled catalog's JSON records of `key` ("palettes" or "presets"), ready to be damaged.
    private func records(_ key: String) throws -> [[String: Any]] {
        let root = try #require(try JSONSerialization.jsonObject(with: catalog.encoded()) as? [String: Any])
        return try #require(root[key] as? [[String: Any]])
    }

    /// Decodes a catalog document of `palettes` and `presets`.
    private func decode(palettes: [Any], presets: [Any]) throws
        -> (catalog: ContentCatalog, refused: [CatalogRefusal]) {
        ContentCatalog.decode(try JSONSerialization.data(withJSONObject: ["palettes": palettes, "presets": presets]))
    }

    @Test func theBundledContentHasItsRecordsAndProvenance() {
        #expect(catalog.presets.map(\.id) == ids && catalog.palettes.map(\.id) == ids)
        #expect(catalog.presets.map(\.name) == ["Island", "Asteroid garden", "Miniature city"])
        #expect(catalog.palettes.map(\.name) == ["Island", "Asteroid garden", "Miniature city"])
        #expect(catalog.presets.map(\.palette) == ids)
        #expect(catalog.palettes.allSatisfy { $0.colors.count == 3 && $0.colors.allSatisfy(\.isInRange) })
        #expect(catalog.palettes.allSatisfy { Set([$0.sea, $0.lowLand, $0.highLand].map { [$0.r, $0.g, $0.b] }).count == 3 })
        #expect(catalog.presets.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(catalog.palettes.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(catalog.palettes.allSatisfy { ContentCatalog.check($0) == nil })
        #expect(catalog.presets.allSatisfy { ContentCatalog.check($0) == nil })
        #expect(ContentCatalog.allowedLicenses == ["MIT"])
        #expect(catalog.palette(id: "island")?.sea == catalog.palettes[0].colors[0])
        #expect(catalog.palette(id: "lava") == nil && catalog.preset(id: "lava") == nil)
    }

    @Test func theBundledPropsHaveTheirPalettesAndProvenance() {
        let propIds = ["tree", "rock", "house", "lantern"]
        #expect(catalog.props.map(\.id) == propIds && catalog.propPalettes.map(\.id) == propIds)
        #expect(catalog.props.map(\.name) == ["Tree", "Rock", "House", "Lantern"])
        #expect(catalog.props.map(\.id) == PropKind.allCases.map(\.contentId))
        #expect(catalog.props.map(\.palette) == propIds)
        #expect(catalog.propPalettes.allSatisfy { ContentCatalog.check($0) == nil })
        #expect(catalog.props.allSatisfy { ContentCatalog.check($0) == nil })
        #expect(catalog.propPalettes.allSatisfy { Set($0.colors.map { [$0.r, $0.g, $0.b] }).count == 3 })
        #expect(catalog.props.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(catalog.propPalettes.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(catalog.propPalette(id: "lantern")?.colors.count == 3 && catalog.prop(id: "house")?.name == "House")
        #expect(catalog.prop(id: "island") == nil && catalog.propPalette(id: "island") == nil)
    }

    @Test func malformedPropRecordsAreRefusedAndDocumentsWithoutPropsStillRead() throws {
        var propPalettes = try records("propPalettes")
        propPalettes[0]["author"] = nil                                // tree: missing-license
        var colors = try #require(propPalettes[1]["colors"] as? [[String: Any]])
        colors[2]["r"] = -0.5
        propPalettes[1]["colors"] = colors                             // rock: out-of-range
        var props = try records("props")
        props[0]["license"] = "Proprietary"                            // tree: unsupported-license
        props[1]["palette"] = ""                                       // rock: invalid-number
        let duplicate = try records("props")[3]                        // lantern again: duplicate-id
        let data = try JSONSerialization.data(withJSONObject: [
            "palettes": try records("palettes"), "presets": try records("presets"),
            "propPalettes": propPalettes, "props": props + [duplicate]])
        let result = ContentCatalog.decode(data)
        #expect(result.refused == [
            CatalogRefusal(kind: .propPalette, id: "tree", reason: .missingLicense),
            CatalogRefusal(kind: .propPalette, id: "rock", reason: .outOfRange),
            CatalogRefusal(kind: .prop, id: "tree", reason: .unsupportedLicense),
            CatalogRefusal(kind: .prop, id: "rock", reason: .invalidNumber),
            CatalogRefusal(kind: .prop, id: "lantern", reason: .duplicateId),
        ])
        #expect(result.catalog.propPalettes.map(\.id) == ["house", "lantern"])
        #expect(result.catalog.props.map(\.id) == ["house", "lantern"])
        #expect(result.catalog.palettes == catalog.palettes && result.catalog.presets == catalog.presets)
        let old = try decode(palettes: try records("palettes"), presets: try records("presets"))
        #expect(old.refused.isEmpty && old.catalog.props.isEmpty && old.catalog.propPalettes.isEmpty)
        let notAList = ContentCatalog.decode(Data("{\"palettes\":[],\"presets\":[],\"props\":3}".utf8))
        #expect(notAList.refused == [CatalogRefusal(kind: .palette, id: "catalog", reason: .invalidNumber)])
        #expect(ContentKind.propPalette.rawValue == "prop-palette" && ContentKind.prop.rawValue == "prop")
    }

    @Test func theBundledPacksNameTheirPresetsAndProvenance() {
        #expect(catalog.packs.map(\.id) == ids && catalog.packs.map(\.preset) == ids)
        #expect(catalog.packs.map(\.name) == ["Island", "Asteroid garden", "Miniature city"])
        #expect(catalog.packs.map(\.id) == WorldPack.all.map(\.id))
        #expect(catalog.packs.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(catalog.packs.allSatisfy { ContentCatalog.check($0) == nil && catalog.preset(id: $0.preset) != nil })
        #expect(catalog.pack(id: "miniature-city")?.name == "Miniature city" && catalog.pack(id: "tree") == nil)
        #expect(ContentKind.pack.rawValue == "pack")
    }

    @Test func malformedPackRecordsAreRefusedAndDocumentsWithoutPacksStillRead() throws {
        var packs = try records("packs")
        packs[0]["license"] = "CC0-1.0"                                // island: unsupported-license
        packs[1]["preset"] = ""                                        // asteroid-garden: invalid-number
        let duplicate = try records("packs")[2]                        // miniature-city again: duplicate-id
        let data = try JSONSerialization.data(withJSONObject: [
            "palettes": try records("palettes"), "presets": try records("presets"),
            "propPalettes": try records("propPalettes"), "props": try records("props"), "packs": packs + [duplicate]])
        let result = ContentCatalog.decode(data)
        #expect(result.refused == [
            CatalogRefusal(kind: .pack, id: "island", reason: .unsupportedLicense),
            CatalogRefusal(kind: .pack, id: "asteroid-garden", reason: .invalidNumber),
            CatalogRefusal(kind: .pack, id: "miniature-city", reason: .duplicateId),
        ])
        #expect(result.catalog.packs.map(\.id) == ["miniature-city"])
        #expect(result.catalog.props == catalog.props && result.catalog.presets == catalog.presets)
        let old = ContentCatalog.decode(try JSONSerialization.data(withJSONObject: [
            "palettes": try records("palettes"), "presets": try records("presets"),
            "propPalettes": try records("propPalettes"), "props": try records("props")]))
        #expect(old.refused.isEmpty && old.catalog.packs.isEmpty && old.catalog.props == catalog.props)
        let notAList = ContentCatalog.decode(Data("{\"packs\":{},\"palettes\":[],\"presets\":[]}".utf8))
        #expect(notAList.refused == [CatalogRefusal(kind: .palette, id: "catalog", reason: .invalidNumber)])
        var pack = catalog.packs[0]
        pack.preset = ""
        #expect(ContentCatalog.check(pack) == .invalidNumber)
        pack.author = " "
        #expect(ContentCatalog.check(pack) == .missingLicense)
    }

    @Test func theJSONRoundTripIsExactAndSorted() throws {
        let data = catalog.encoded()
        let decoded = ContentCatalog.decode(data)
        #expect(decoded.refused.isEmpty)
        #expect(decoded.catalog == catalog)
        #expect(decoded.catalog.encoded() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"packs\":[{\"author\":\"VisualCore project\",\"id\":\"island\",\"license\":\"MIT\","
                               + "\"name\":\"Island\",\"preset\":\"island\"}"))
        #expect(text.contains("],\"palettes\":[{\"author\":\"VisualCore project\",\"colors\":[{\"a\":1,\"b\":"))
        #expect(text.contains("\"presets\":[{\"author\":\"VisualCore project\",\"id\":\"island\""))
        #expect(text.contains("],\"propPalettes\":[{\"author\":\"VisualCore project\",\"colors\":"))
        #expect(text.contains("],\"props\":[{\"author\":\"VisualCore project\",\"id\":\"tree\""))
    }

    @Test func eachMalformedRecordIsRefusedWithItsReasonAndTheRestIsKept() throws {
        var palettes = try records("palettes")
        palettes[0]["license"] = nil                                   // island: missing-license
        palettes[1]["license"] = "CC-BY-NC-4.0"                        // asteroid-garden: unsupported-license
        var colors = try #require(palettes[2]["colors"] as? [[String: Any]])
        colors[1]["g"] = 1.2
        palettes[2]["colors"] = colors                                 // miniature-city: out-of-range
        var presets = try records("presets")
        presets[0]["author"] = ""                                      // island: missing-license
        presets[1]["palette"] = 3                                      // asteroid-garden: invalid-number
        var shortPalette = try records("palettes")[0]
        shortPalette["id"] = "short"
        shortPalette["colors"] = Array(colors.prefix(2))               // short: invalid-number (two colours)
        var textColour = try records("palettes")[1]
        textColour["id"] = "text"
        var badColors = try #require(textColour["colors"] as? [[String: Any]])
        badColors[0]["a"] = "opaque"
        textColour["colors"] = badColors                               // text: invalid-number
        var kept = try records("palettes")[2]
        kept["id"] = "kept"
        let duplicate = try records("presets")[2]                      // miniature-city again: duplicate-id
        let result = try decode(palettes: palettes + [shortPalette, textColour, kept],
                                presets: presets + [duplicate])
        #expect(result.refused == [
            CatalogRefusal(kind: .palette, id: "island", reason: .missingLicense),
            CatalogRefusal(kind: .palette, id: "asteroid-garden", reason: .unsupportedLicense),
            CatalogRefusal(kind: .palette, id: "miniature-city", reason: .outOfRange),
            CatalogRefusal(kind: .palette, id: "short", reason: .invalidNumber),
            CatalogRefusal(kind: .palette, id: "text", reason: .invalidNumber),
            CatalogRefusal(kind: .preset, id: "island", reason: .missingLicense),
            CatalogRefusal(kind: .preset, id: "asteroid-garden", reason: .invalidNumber),
            CatalogRefusal(kind: .preset, id: "miniature-city", reason: .duplicateId),
        ])
        #expect(result.catalog.palettes.map(\.id) == ["kept"])
        #expect(result.catalog.presets.map(\.id) == ["miniature-city"])
        #expect(Set(CatalogRefusalReason.allCases.map(\.rawValue))
                == ["missing-license", "unsupported-license", "out-of-range", "invalid-number", "duplicate-id"])
    }

    @Test func rangeEdgesAreAcceptedAndRecordLayoutErrorsAreInvalidNumbers() throws {
        var palettes = try records("palettes")
        var colors = try #require(palettes[0]["colors"] as? [[String: Any]])
        colors[0] = ["r": 0.0, "g": 1.0, "b": 0.0, "a": 0.0]
        palettes[0]["colors"] = colors
        #expect(try decode(palettes: palettes, presets: try records("presets")).refused.isEmpty)
        var broken = try records("palettes")
        broken[0]["id"] = ""
        var negative = try #require(broken[1]["colors"] as? [[String: Any]])
        negative[2]["b"] = -0.01
        broken[1]["colors"] = negative
        var flag = try #require(broken[2]["colors"] as? [[String: Any]])
        flag[0]["r"] = true
        broken[2]["colors"] = flag
        let result = try decode(palettes: broken + ["not an object"], presets: [])
        #expect(result.refused == [CatalogRefusal(kind: .palette, id: "", reason: .invalidNumber),
                                   CatalogRefusal(kind: .palette, id: "asteroid-garden", reason: .outOfRange),
                                   CatalogRefusal(kind: .palette, id: "miniature-city", reason: .invalidNumber),
                                   CatalogRefusal(kind: .palette, id: "", reason: .missingLicense)])
        #expect(result.catalog.palettes.isEmpty && result.catalog.presets.isEmpty)
    }

    @Test func aNonFiniteHandBuiltRecordIsInvalidAndAnUnreadableDocumentIsRefused() {
        var palette = catalog.palettes[0]
        palette.colors[1].g = .nan
        #expect(ContentCatalog.check(palette) == .invalidNumber)
        palette.colors[1].g = .infinity
        #expect(ContentCatalog.check(palette) == .invalidNumber)
        #expect(ContentCatalog(palettes: [palette], presets: []).encoded().isEmpty)
        palette.colors = Array(catalog.palettes[0].colors.prefix(2))
        #expect(ContentCatalog.check(palette) == .invalidNumber)
        var preset = catalog.presets[0]
        preset.palette = ""
        #expect(ContentCatalog.check(preset) == .invalidNumber)
        preset.license = "GPL-3.0"
        #expect(ContentCatalog.check(preset) == .unsupportedLicense)
        let unreadable = ContentCatalog.decode(Data("{not json".utf8))
        #expect(unreadable.catalog.palettes.isEmpty && unreadable.catalog.presets.isEmpty)
        #expect(unreadable.refused == [CatalogRefusal(kind: .palette, id: "catalog", reason: .invalidNumber)])
        #expect(ContentCatalog.decode(Data("{\"palettes\":[]}".utf8)).refused.count == 1)
    }
}
