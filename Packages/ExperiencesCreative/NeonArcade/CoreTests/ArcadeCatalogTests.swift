// ArcadeCatalogTests — feature 075 (A10-P01) T-A10-103 (FR-A10-113; clarification 5; SC-A10-104). The bundled content
// catalog and its validating decoder, host-free and short: the bundled items (player `chevron`, hazards `spike-ball`
// and `bar`, orb `glow-orb` worth 10) with their size ranges inside the limits and author and license on every item;
// the sorted-key JSON round trip; a malformed JSON fixture with one item per refusal reason (missing-license,
// unsupported-license, unknown-shape, invalid-number), each refused by name while every valid item is kept; the checks
// on hand-built items; unreadable JSON refused as a whole.
import Foundation
import Testing
import NeonArcadeCore

@Suite struct ArcadeCatalogTests {
    private let catalog = ArcadeCatalog.bundled

    /// A malformed catalog: the four bundled items' layout plus one broken item per reason (two for invalid-number
    /// and unknown-shape), a repeated id and a non-object element.
    private static let malformedFixture = """
    {"items": [
      {"id": "chevron", "name": "Chevron", "role": "player", "shape": "chevron",
       "color": {"r": 0.2, "g": 0.95, "b": 1, "a": 1}, "glowColor": {"r": 0.1, "g": 0.7, "b": 1, "a": 0.6},
       "radiusRange": {"min": 0.4, "max": 0.4}, "value": 0, "author": "VisualCore project", "license": "MIT"},
      {"id": "no-license", "name": "No license", "role": "hazard", "shape": "spike-ball",
       "color": {"r": 1, "g": 0, "b": 0, "a": 1}, "glowColor": {"r": 1, "g": 0, "b": 0, "a": 1},
       "radiusRange": {"min": 0.4, "max": 0.5}, "value": 0, "author": "VisualCore project"},
      {"id": "other-license", "name": "Other license", "role": "orb", "shape": "glow-orb",
       "color": {"r": 1, "g": 1, "b": 0, "a": 1}, "glowColor": {"r": 1, "g": 1, "b": 0, "a": 1},
       "radiusRange": {"min": 0.25, "max": 0.25}, "value": 10, "author": "Someone", "license": "CC-BY-NC-4.0"},
      {"id": "star", "name": "Star", "role": "hazard", "shape": "star",
       "color": {"r": 1, "g": 1, "b": 1, "a": 1}, "glowColor": {"r": 1, "g": 1, "b": 1, "a": 1},
       "radiusRange": {"min": 0.3, "max": 0.4}, "value": 0, "author": "VisualCore project", "license": "MIT"},
      {"id": "orb-as-hazard", "name": "Orb as hazard", "role": "hazard", "shape": "glow-orb",
       "color": {"r": 1, "g": 1, "b": 1, "a": 1}, "glowColor": {"r": 1, "g": 1, "b": 1, "a": 1},
       "radiusRange": {"min": 0.3, "max": 0.4}, "value": 0, "author": "VisualCore project", "license": "MIT"},
      {"id": "huge-ball", "name": "Huge ball", "role": "hazard", "shape": "spike-ball",
       "color": {"r": 1, "g": 1, "b": 1, "a": 1}, "glowColor": {"r": 1, "g": 1, "b": 1, "a": 1},
       "radiusRange": {"min": 0.5, "max": 3.0}, "value": 0, "author": "VisualCore project", "license": "MIT"},
      {"id": "text-radius", "name": "Text radius", "role": "orb", "shape": "glow-orb",
       "color": {"r": 1, "g": 1, "b": 1, "a": 1}, "glowColor": {"r": 1, "g": 1, "b": 1, "a": 1},
       "radiusRange": {"min": "NaN", "max": 0.3}, "value": 5, "author": "VisualCore project", "license": "MIT"},
      {"id": "chevron", "name": "Second chevron", "role": "player", "shape": "chevron",
       "color": {"r": 1, "g": 1, "b": 1, "a": 1}, "glowColor": {"r": 1, "g": 1, "b": 1, "a": 1},
       "radiusRange": {"min": 0.4, "max": 0.4}, "value": 0, "author": "VisualCore project", "license": "MIT"},
      {"id": "bar", "name": "Bar", "role": "hazard", "shape": "bar",
       "color": {"r": 1, "g": 0.55, "b": 0.1, "a": 1}, "glowColor": {"r": 1, "g": 0.4, "b": 0.05, "a": 0.6},
       "radiusRange": {"min": 0.2, "max": 0.2}, "halfLengthRange": {"min": 0.6, "max": 1.0}, "value": 0,
       "author": "VisualCore project", "license": "MIT"},
      42
    ]}
    """

    @Test func theBundledCatalogHasThePlayerTwoHazardsAndTheOrb() throws {
        #expect(catalog.items.map(\.id) == ["chevron", "spike-ball", "bar", "glow-orb"])
        #expect(catalog.items.map(\.shape) == [.chevron, .spikeBall, .bar, .glowOrb])
        #expect(catalog.player?.id == "chevron")
        #expect(catalog.hazards.map(\.id) == ["spike-ball", "bar"])
        #expect(catalog.orbs.map(\.id) == ["glow-orb"])
        #expect(catalog.player?.radiusRange == SizeRange(exactly: 0.4))
        #expect(catalog.item(id: "spike-ball")?.radiusRange == SizeRange(min: 0.35, max: 0.6))
        let bar = try #require(catalog.item(id: "bar"))
        #expect(bar.radiusRange == SizeRange(exactly: 0.2))
        #expect(bar.halfLengthRange == SizeRange(min: 0.6, max: 1.0))
        let orb = try #require(catalog.orbs.first)
        #expect(orb.value == 10 && orb.radiusRange == SizeRange(exactly: 0.25))
        #expect(catalog.item(id: "no-such-item") == nil)
        for item in catalog.items {
            #expect(ArcadeCatalog.check(item) == nil, "\(item.id)")
            #expect(item.author == "VisualCore project" && item.license == "MIT")
            #expect(item.radiusRange.isValid(within: 0.1...1.0))
            #expect((item.halfLengthRange != nil) == (item.shape == .bar))
            #expect(item.shape.role == item.role)
        }
        #expect(Set(catalog.items.map(\.id)).count == catalog.items.count)
    }

    @Test func theJSONRoundTripKeepsEveryItem() throws {
        let data = catalog.encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"items\":["))
        #expect(text.contains("\"shape\":\"spike-ball\"") && text.contains("\"shape\":\"glow-orb\""))
        let (decoded, refused) = ArcadeCatalog.decode(data)
        #expect(refused.isEmpty)
        #expect(decoded == catalog)
        #expect(decoded.encoded() == data)
    }

    @Test func aMalformedFixtureNamesEveryRefusalReasonAndKeepsTheValidRest() throws {
        let (decoded, refused) = ArcadeCatalog.decode(Data(Self.malformedFixture.utf8))
        #expect(decoded.items.map(\.id) == ["chevron", "bar"])
        #expect(decoded.items == [catalog.items[0], catalog.items[2]])
        #expect(refused == [
            CatalogRefusal(id: "no-license", error: .missingLicense),
            CatalogRefusal(id: "other-license", error: .unsupportedLicense),
            CatalogRefusal(id: "star", error: .unknownShape),
            CatalogRefusal(id: "orb-as-hazard", error: .unknownShape),
            CatalogRefusal(id: "huge-ball", error: .invalidNumber),
            CatalogRefusal(id: "text-radius", error: .invalidNumber),
            CatalogRefusal(id: "chevron", error: .unknownShape),
            CatalogRefusal(id: "", error: .unknownShape),
        ])
        #expect(Set(refused.map(\.error)) == Set(CatalogError.allCases))
        #expect(CatalogError.allCases.map(\.rawValue).sorted()
                == ["invalid-number", "missing-license", "unknown-shape", "unsupported-license"])
    }

    @Test func handBuiltItemsAreCheckedInOrder() {
        var item = catalog.items[1]
        #expect(ArcadeCatalog.check(item) == nil)
        item.shape = .glowOrb
        #expect(ArcadeCatalog.check(item) == .unknownShape)
        item = catalog.items[1]; item.author = " "
        #expect(ArcadeCatalog.check(item) == .missingLicense)
        item = catalog.items[1]; item.license = "GPL-3.0"
        #expect(ArcadeCatalog.check(item) == .unsupportedLicense)
        item = catalog.items[1]; item.radiusRange = SizeRange(min: 0.6, max: 0.35)
        #expect(ArcadeCatalog.check(item) == .invalidNumber)
        item = catalog.items[1]; item.radiusRange = SizeRange(min: .nan, max: 0.5)
        #expect(ArcadeCatalog.check(item) == .invalidNumber)
        item = catalog.items[1]; item.color = RGBA(1.2, 0, 0)
        #expect(ArcadeCatalog.check(item) == .invalidNumber)
        item = catalog.items[1]; item.halfLengthRange = SizeRange(min: 0.6, max: 1.0)
        #expect(ArcadeCatalog.check(item) == .invalidNumber)
        var bar = catalog.items[2]; bar.halfLengthRange = nil
        #expect(ArcadeCatalog.check(bar) == .invalidNumber)
        bar = catalog.items[2]; bar.halfLengthRange = SizeRange(min: 0.2, max: 1.0)
        #expect(ArcadeCatalog.check(bar) == .invalidNumber)
        var orb = catalog.items[3]; orb.value = 0
        #expect(ArcadeCatalog.check(orb) == .invalidNumber)
    }

    @Test func unreadableJSONIsRefusedAsAWhole() {
        for text in ["not json", "[1, 2]", "{\"things\": []}"] {
            let (decoded, refused) = ArcadeCatalog.decode(Data(text.utf8))
            #expect(decoded.items.isEmpty)
            #expect(refused == [CatalogRefusal(id: "catalog", error: .unknownShape)])
        }
    }
}
