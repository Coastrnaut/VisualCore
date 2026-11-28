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

    @Test func onlyExperiencesWithAPassingIntegrationGateAreAvailable() throws {
        // X-A01 to X-A25 and X-R02-G01 … G21 are pass in the migration ledger (2026-11-13 to 2026-11-26); the build tool
        // is the only writer of this flag.
        #expect(try CatalogFixture.manifest().available.map(\.id.rawValue) == ["a01.generative-art-studio", "a02.fluid-art-playground", "a03.fractal-explorer",
                         "a04.particle-universe", "a05.infinite-geometry", "a06.visualcore-music-lab",
                         "a07.audio-odyssey", "a08.oscilloscope-studio", "a09.digital-aquarium",
                         "a10.neon-arcade", "a11.physics-playground", "a12.tiny-worlds",
                         "a13.light-maze", "a14.solar-system-explorer",
                         "a15.molecular-explorer", "a16.simulation-lab",
                         "a17.interactive-anatomy", "a18.ambient-clock",
                         "a19.living-wallpapers",
                         "a20.digital-zen-garden",
                         "a21.aurora",
                         "a22.shader-studio",
                         "a23.visual-programming-lab",
                         "a24.graphics-benchmark-lab",
                         "a25.effects-composer",
                         "r02-g01.aurora-loom",
                         "r02-g02.lissajous-labyrinth",
                         "r02-g03.wave-knot-keeper",
                         "r02-g04.hue-compass",
                         "r02-g05.colorfall-canyons",
                         "r02-g06.chrono-constellator",
                         "r02-g07.amethyst-escape",
                         "r02-g08.faceted-forge",
                         "r02-g09.nocturne-garden",
                         "r02-g10.backwards-aurora",
                         "r02-g11.echo-cartographer",
                         "r02-g12.harmonic-bridges",
                         "r02-g13.acoustic-constellator",
                         "r02-g14.moonlit-mechanism",
                         "r02-g15.voxel-origami",
                         "r02-g16.starlit-cartouche",
                         "r02-g17.celestial-eclipse-lab",
                         "r02-g18.apsides-workshop",
                         "r02-g19.microscopic-aurora",
                         "r02-g20.mushroom-weather",
                         "r02-g21.binary-gardens"])
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
                               "a04.particle-universe", "a05.infinite-geometry",
                               // Feature 047 (A06-P01); integrated at X-A06.
                               "a06.visualcore-music-lab",
                               // Feature 054 (A07-P01); integrated at X-A07.
                               "a07.audio-odyssey",
                               // Feature 061 (A08-P01); integrated at X-A08.
                               "a08.oscilloscope-studio",
                               // Feature 068 (A09-P01); integrated at X-A09.
                               "a09.digital-aquarium",
                               // Feature 075 (A10-P01); integrated at X-A10.
                               "a10.neon-arcade",
                               // Feature 082 (A11-P01); integrated at X-A11.
                               "a11.physics-playground",
                               // Feature 089 (A12-P01); integrated at X-A12.
                               "a12.tiny-worlds",
                               // Feature 096 (A13-P01); integrated at X-A13.
                               "a13.light-maze",
                               // Feature 103 (A14-P01); integrated at X-A14.
                               "a14.solar-system-explorer",
                               // Feature 110 (A15-P01); integrated at X-A15.
                               "a15.molecular-explorer",
                               // Feature 117 (A16-P01); integrated at X-A16.
                               "a16.simulation-lab",
                               // Feature 125 (A17-P02); integrated at X-A17.
                               "a17.interactive-anatomy",
                               // Feature 132 (A18-P02); integrated at X-A18.
                               "a18.ambient-clock",
                               // Feature 139 (A19-P02); integrated at X-A19.
                               "a19.living-wallpapers",
                               // Feature 146 (A20-P02); integrated at X-A20.
                               "a20.digital-zen-garden",
                               // Feature 153 (A21-P02); integrated at X-A21.
                               "a21.aurora",
                               // Feature 160 (A22-P02); integrated at X-A22.
                               "a22.shader-studio",
                               // Feature 167 (A23-P02); integrated at X-A23.
                               "a23.visual-programming-lab",
                               // Feature 174 (A24-P02); integrated at X-A24.
                               "a24.graphics-benchmark-lab",
                               // Feature 181 (A25-P02); integrated at X-A25.
                               "a25.effects-composer",
                               // Feature 303 (R02-G01-03); integrated at X-R02-G01.
                               "r02-g01.aurora-loom",
                               // Feature 313 (R02-G02-03); integrated at X-R02-G02.
                               "r02-g02.lissajous-labyrinth",
                               // Feature 323 (R02-G03-03); integrated at X-R02-G03.
                               "r02-g03.wave-knot-keeper",
                               // Feature 333 (R02-G04-03); integrated at X-R02-G04.
                               "r02-g04.hue-compass",
                               // Feature 343 (R02-G05-03); integrated at X-R02-G05.
                               "r02-g05.colorfall-canyons",
                               // Feature 353 (R02-G06-03); integrated at X-R02-G06.
                               "r02-g06.chrono-constellator",
                               // Feature 363 (R02-G07-03); integrated at X-R02-G07.
                               "r02-g07.amethyst-escape",
                               // Feature 373 (R02-G08-03); integrated at X-R02-G08.
                               "r02-g08.faceted-forge",
                               // Feature 383 (R02-G09-03); integrated at X-R02-G09.
                               "r02-g09.nocturne-garden",
                               // Feature 393 (R02-G10-03); integrated at X-R02-G10.
                               "r02-g10.backwards-aurora",
                               // Feature 403 (R02-G11-03); integrated at X-R02-G11.
                               "r02-g11.echo-cartographer",
                               // Feature 413 (R02-G12-03); integrated at X-R02-G12.
                               "r02-g12.harmonic-bridges",
                               // Feature 423 (R02-G13-03); integrated at X-R02-G13.
                               "r02-g13.acoustic-constellator",
                               // Feature 433 (R02-G14-03); integrated at X-R02-G14.
                               "r02-g14.moonlit-mechanism",
                               // Feature 443 (R02-G15-03); integrated at X-R02-G15.
                               "r02-g15.voxel-origami",
                               // Feature 453 (R02-G16-03); integrated at X-R02-G16.
                               "r02-g16.starlit-cartouche",
                               // Feature 463 (R02-G17-03); integrated at X-R02-G17.
                               "r02-g17.celestial-eclipse-lab",
                               // Feature 473 (R02-G18-03); integrated at X-R02-G18.
                               "r02-g18.apsides-workshop",
                               // Feature 483 (R02-G19-03); integrated at X-R02-G19.
                               "r02-g19.microscopic-aurora",
                               // Feature 493 (R02-G20-03); integrated at X-R02-G20.
                               "r02-g20.mushroom-weather",
                               // Feature 503 (R02-G21-03); integrated at X-R02-G21.
                               "r02-g21.binary-gardens",
                               // Feature 513 (R02-G22-03); a registered candidate until X-R02-G22.
                               "r02-g22.mycelium-architect"],
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
