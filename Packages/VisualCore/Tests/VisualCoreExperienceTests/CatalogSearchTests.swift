// CatalogSearchTests — feature 187 T-U01-013 (FR-U01-023, FR-U01-024; SC-U01-004; data-model section 9).
// The expected ids were computed with an independent implementation of the folding rule over Catalog/experiences.json.
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct CatalogSearchTests {
    @Test func foldingIsLanguageIndependent() {
        let table: [(String, String)] = [
            ("Aurora Loom", "aurora loom"), ("AURORA", "aurora"), ("Géode Çà", "geode ca"), ("İstanbul", "istanbul"),
            ("ISTANBUL", "istanbul"), ("ıstanbul", "istanbul"), ("ｇｅｏｄｅ", "geode"), ("ﬁre", "fire"), ("Ångström", "angstrom"),
            ("  two\t\twords \n", "two words"), ("", ""), ("   ", ""), ("wave-mathematics", "wave-mathematics"), ("Crème Brûlée 3", "creme brulee 3"),
        ]
        for (text, expected) in table {
            #expect(CatalogSearch.fold(text) == expected, "fold(\(text.debugDescription))")
        }
    }

    @Test func searchTableOnTheCommittedCatalog() throws {
        let manifest = try CatalogFixture.manifest()
        func ids(_ text: String) -> [String] { manifest.search(text).map(\.id.rawValue) }
        let aurora = ["a21.aurora", "r02-g01.aurora-loom", "r02-g10.backwards-aurora", "r02-g19.microscopic-aurora", "r03-g23.aurora-geode"]
        let geode = ["r03-g23.aurora-geode", "r03-g25.geode-locksmith"]
        let table: [(String, [String])] = [
            ("aurora", aurora), ("AURORA", aurora), ("  Aurora   LOOM ", ["r02-g01.aurora-loom"]), ("loom aurora", ["r02-g01.aurora-loom"]),
            ("géode", geode), ("ｇｅｏｄｅ", geode), ("Geode", geode),
            // title matches first, then the family tag "acoustic-geometry", each group in catalog order
            ("geometry", ["a05.infinite-geometry", "r04-g10.candle-geometry", "r02-g12.harmonic-bridges", "r02-g13.acoustic-constellator",
                          "r04-g23.soundglass-observatory"]),
            ("fractal", ["a03.fractal-explorer"]),
            ("shader", ["a22.shader-studio", "a23.visual-programming-lab", "a25.effects-composer"]),
            ("light maze", ["a13.light-maze"]),
            ("orbital", ["r02-g18.apsides-workshop", "r02-g21.binary-gardens", "r04-g11.umbra-rings", "r04-g15.clockwave-harbor"]),
            ("zzzz", []), ("İSTANBUL", []), ("aurora zzzz", []),
        ]
        #expect(table.count >= 12)
        for (text, expected) in table {
            #expect(ids(text) == expected, "search(\(text.debugDescription))")
        }
        let crystal = ids("crystal solids")
        #expect(crystal.count == 12)
        #expect(Array(crystal.prefix(3)) == ["r02-g07.amethyst-escape", "r02-g08.faceted-forge", "r03-g23.aurora-geode"])
        #expect(ids("") == manifest.experiences.map(\.id.rawValue))
        #expect(ids("   \t ") == manifest.experiences.map(\.id.rawValue))
        #expect(ids("aurora") == ids("aurora"))
    }

    @Test func rankIsTheWeakestFieldAWordNeeded() throws {
        // Entry 0: the word is in the title. Entry 1: only in a tag. Entry 2: only in the summary. Entry 3: title and summary.
        let data = ManifestBuilder.changing { b in
            b.set(0, "title", "Prism Garden")
            b.set(1, "tags", ["wave-mathematics", "prism"])
            b.set(2, "summary", "A prism in every room")
            b.set(3, "title", "Prism"); b.set(3, "summary", "Rooms of light")
        }
        let manifest = try CatalogManifest(data: data)
        #expect(manifest.search("prism").map(\.order) == [1, 4, 2, 3])
        #expect(manifest.search("prism rooms").map(\.order) == [4])           // every word is required; "room" is not "rooms"
        #expect(manifest.search("prism room").map(\.order) == [3, 4])         // both need the summary for "room": rank 2, catalog order
        #expect(manifest.search("PRISM  garden").map(\.order) == [1])
    }

    @Test func languageAndRegionOfThisRun() {
        // The tests may read the language setting; the module never does. The line is quoted as evidence of the run
        // made with another language (T-U01-019).
        print("VisualCoreExperienceTests ran with language \(Locale.current.language.languageCode?.identifier ?? "?") region \(Locale.current.region?.identifier ?? "?")")
    }
}
