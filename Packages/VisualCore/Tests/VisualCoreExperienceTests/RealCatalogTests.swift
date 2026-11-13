// RealCatalogTests — feature 187 T-U01-012 (FR-U01-003, FR-U01-004, FR-U01-011, FR-U01-041; SC-U01-001, SC-U01-002,
// SC-U01-003, SC-U01-006, SC-U01-010). The committed catalog, read from the byte-identical copies under Fixtures/Catalog.
import Foundation
import Testing
@testable import VisualCoreExperience

enum CatalogFixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.resourceURL).appendingPathComponent("Fixtures/Catalog/\(name)")
        return try Data(contentsOf: url)
    }

    static func manifest() throws -> CatalogManifest { try CatalogManifest(data: data("experiences.json")) }

    static func goldenIDs() throws -> [String] {
        String(decoding: try data("experience-ids.golden.txt"), as: UTF8.self).split(separator: "\n").map(String.init)
    }
}

@Suite struct RealCatalogTests {
    @Test func committedManifestLoadsWithTheLaunchAllocation() throws {
        let manifest = try CatalogFixture.manifest()
        #expect(manifest.experiences.count == 100)
        #expect(manifest.experiences.map(\.code.text) == CatalogManifest.launchCodes)
        #expect(manifest.experiences.filter { $0.tier == .free }.count == 50)
        #expect(manifest.experiences.filter { $0.tier == .premium }.count == 50)
        #expect(manifest.experiences.map(\.order) == Array(1...100))
        #expect(manifest.catalogSHA256.count == 64)
    }

    @Test func noExperienceIsAvailableBeforeItsIntegrationGate() throws {
        // Today no gate X-<code> is pass in the migration ledger; the build tool is the only writer of this flag.
        #expect(try CatalogFixture.manifest().available.isEmpty)
    }

    @Test func everyIdIsInTheGoldenListAndWellFormed() throws {
        let golden = try CatalogFixture.goldenIDs()
        #expect(golden.count == 300)
        #expect(Set(golden).count == 300)
        for text in golden {
            #expect(ExperienceID(rawValue: text) != nil, "malformed golden id \(text)")
        }
        let manifest = try CatalogFixture.manifest()
        let listed = Set(golden)
        #expect(manifest.experiences.map(\.id.rawValue).filter { !listed.contains($0) } == [])
        #expect(Array(golden.prefix(100)) == manifest.experiences.map(\.id.rawValue))
        #expect(golden.first == "a01.generative-art-studio" && golden[25] == "r02-g01.aurora-loom")
    }

    @Test func changedIdIsCaughtByTheGoldenList() throws {
        let text = String(decoding: try CatalogFixture.data("experiences.json"), as: UTF8.self)
        let changed = text.replacingOccurrences(of: "\"a05.infinite-geometry\"", with: "\"a05.infinite-geometri\"")
        #expect(changed != text)
        let manifest = try CatalogManifest(data: Data(changed.utf8))
        let listed = Set(try CatalogFixture.goldenIDs())
        #expect(manifest.experiences.map(\.id.rawValue).filter { !listed.contains($0) } == ["a05.infinite-geometri"])
    }

    @Test func categoriesAndFamilyTags() throws {
        let manifest = try CatalogFixture.manifest()
        #expect(ExperienceCategory.allCases.map { manifest.experiences(in: $0).count } == [5, 4, 4, 4, 4, 4, 75])
        for entry in manifest.experiences {
            #expect(entry.tags.contains(ExperienceDescriptor.tag(forFamily: entry.family)), "\(entry.id) lacks its family tag")
            #expect((entry.kind == .game) == (entry.category == .puzzle))
            // An entry without a registration declares nothing; a registered one (from feature 193: A01) declares
            // its palette, capabilities and quality levels; only a game has content facts.
            let declares = !entry.palette.isEmpty || !entry.capabilities.isEmpty || !entry.qualityTiers.isEmpty
            if declares {
                #expect(!entry.palette.isEmpty && !entry.capabilities.isEmpty && !entry.qualityTiers.isEmpty,
                        "\(entry.id) declares only part of its registration")
            }
            #expect(entry.content == nil || entry.kind == .game)
        }
        #expect(manifest.experience(try ExperienceID("a05.infinite-geometry"))?.title == "Infinite Geometry")
        #expect(manifest.experience(code: try ExperienceCode("R03-G01"))?.id.rawValue == "r03-g01.harmonic-helix")
        #expect(manifest.families(in: .create) == ["Creative and visual"])
        let registered = manifest.experiences.filter { !$0.palette.isEmpty }.map(\.id.rawValue)
        #expect(registered == ["a01.generative-art-studio", "a02.fluid-art-playground", "a03.fractal-explorer",
                               "a04.particle-universe"],
                "the registrations of Catalog/registrations.json")
    }

    @Test func loadingTheCommittedManifestIsFast() throws {
        // A host figure (SC-U01-010), not a device claim: median of 20 loads under 50 ms.
        let data = try CatalogFixture.data("experiences.json")
        let clock = ContinuousClock()
        var times: [Duration] = []
        for _ in 0..<20 {
            let elapsed = try clock.measure { _ = try CatalogManifest(data: data) }
            times.append(elapsed)
        }
        let median = times.sorted()[10]
        #expect(median < .milliseconds(50), "median load time \(median)")
    }
}
