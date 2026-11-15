// MaterialCatalogTests — feature 082 (A11-P01) T-A11-103 (FR-A11-114; clarification 3; SC-A11-106). The material
// catalog, host-free and short: the four bundled materials with their exact constants, author and license; the JSON
// round trip with sorted keys; each refusal reason (missing-license, unsupported-license, out-of-range,
// invalid-number, duplicate-id) named for a malformed record while the valid rest is kept; an unreadable document
// refused as a whole.
import Foundation
import Testing
import PhysicsPlaygroundCore

@Suite struct MaterialCatalogTests {
    private let catalog = MaterialCatalog.bundled

    /// The bundled catalog's JSON records, ready to be damaged.
    private func records() throws -> [[String: Any]] {
        let root = try #require(try JSONSerialization.jsonObject(with: catalog.encoded()) as? [String: Any])
        return try #require(root["materials"] as? [[String: Any]])
    }

    /// Decodes `records` as a catalog document.
    private func decode(_ records: [[String: Any]]) throws -> (catalog: MaterialCatalog, refused: [CatalogRefusal]) {
        MaterialCatalog.decode(try JSONSerialization.data(withJSONObject: ["materials": records]))
    }

    @Test func theBundledMaterialsHaveTheirConstantsAndProvenance() {
        #expect(catalog.materials.map(\.id) == ["rubber", "wood", "steel", "ice"])
        #expect(catalog.materials.map(\.name) == ["Rubber", "Wood", "Steel", "Ice"])
        #expect(catalog.materials.map(\.density) == [1.2, 0.6, 7.8, 0.9])
        #expect(catalog.materials.map(\.restitution) == [0.8, 0.4, 0.25, 0.1])
        #expect(catalog.materials.map(\.friction) == [0.9, 0.5, 0.4, 0.05])
        #expect(catalog.materials.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(catalog.materials.allSatisfy { MaterialCatalog.check($0) == nil })
        #expect(catalog.materials.allSatisfy { $0.fill.isInRange && $0.edge.isInRange && $0.fill != $0.edge })
        #expect(MaterialCatalog.allowedLicenses == ["MIT"])
        #expect(catalog.material(id: "steel")?.density == 7.8)
        #expect(catalog.material(id: "lead") == nil)
    }

    @Test func theJSONRoundTripIsExactAndSorted() throws {
        let data = catalog.encoded()
        let decoded = MaterialCatalog.decode(data)
        #expect(decoded.refused.isEmpty)
        #expect(decoded.catalog == catalog)
        #expect(decoded.catalog.encoded() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"materials\":[{\"author\":\"VisualCore project\",\"density\":1.2,\"edge\":"))
    }

    @Test func eachMalformedRecordIsRefusedWithItsReasonAndTheRestIsKept() throws {
        var list = try records()
        list[0]["license"] = nil                       // rubber: missing-license
        list[1]["license"] = "CC-BY-NC-4.0"            // wood: unsupported-license
        list[2]["density"] = 12.0                      // steel: out-of-range
        list[3]["friction"] = "slippery"               // ice: invalid-number
        var extra = try records()
        extra[1]["author"] = ""                        // wood again: missing-license (author)
        extra[0]["restitution"] = 1.5                  // rubber: out-of-range
        extra[2]["fill"] = ["r": 0.5, "g": 0.5]        // steel: invalid-number (colour component missing)
        extra[3]["edge"] = ["r": 0.5, "g": -0.1, "b": 0.5]  // ice: out-of-range (colour)
        var duplicate = try records()[3]
        duplicate["name"] = "Ice again"
        var keptIce = try records()[3]
        keptIce["id"] = "ice-2"
        let result = try decode(list + extra + [keptIce, duplicate])
        #expect(result.refused == [
            CatalogRefusal(id: "rubber", reason: .missingLicense),
            CatalogRefusal(id: "wood", reason: .unsupportedLicense),
            CatalogRefusal(id: "steel", reason: .outOfRange),
            CatalogRefusal(id: "ice", reason: .invalidNumber),
            CatalogRefusal(id: "rubber", reason: .outOfRange),
            CatalogRefusal(id: "wood", reason: .missingLicense),
            CatalogRefusal(id: "steel", reason: .invalidNumber),
            CatalogRefusal(id: "ice", reason: .outOfRange),
        ])
        #expect(result.catalog.materials.map(\.id) == ["ice-2", "ice"])
        let again = try decode(try records() + [try records()[0]])
        #expect(again.refused == [CatalogRefusal(id: "rubber", reason: .duplicateId)])
        #expect(again.catalog == catalog)
        #expect(Set(CatalogRefusalReason.allCases.map(\.rawValue))
                == ["missing-license", "unsupported-license", "out-of-range", "invalid-number", "duplicate-id"])
    }

    @Test func rangeEdgesAreAcceptedAndRecordLayoutErrorsAreInvalidNumbers() throws {
        var list = try records()
        list[0]["density"] = 0.1
        list[1]["density"] = 10.0
        list[2]["restitution"] = 0.0
        list[3]["friction"] = 1.0
        #expect(try decode(list).refused.isEmpty)
        var broken = try records()
        broken[0]["id"] = ""
        broken[1]["density"] = 0.09
        broken[2]["restitution"] = true
        let result = try decode(broken)
        #expect(result.refused == [CatalogRefusal(id: "", reason: .invalidNumber),
                                   CatalogRefusal(id: "wood", reason: .outOfRange),
                                   CatalogRefusal(id: "steel", reason: .invalidNumber)])
        #expect(result.catalog.materials.map(\.id) == ["ice"])
    }

    @Test func aNonFiniteHandBuiltMaterialIsInvalidAndAnUnreadableDocumentIsRefused() {
        var material = catalog.materials[0]
        material.density = .nan
        #expect(MaterialCatalog.check(material) == .invalidNumber)
        material.density = .infinity
        #expect(MaterialCatalog.check(material) == .invalidNumber)
        #expect(MaterialCatalog(materials: [material]).encoded().isEmpty)
        let unreadable = MaterialCatalog.decode(Data("{not json".utf8))
        #expect(unreadable.catalog.materials.isEmpty)
        #expect(unreadable.refused == [CatalogRefusal(id: "catalog", reason: .invalidNumber)])
        #expect(MaterialCatalog.decode(Data("{\"items\":[]}".utf8)).refused.count == 1)
    }
}
