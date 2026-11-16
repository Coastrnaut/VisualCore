// SearchTests — feature 126 (A17-P03) T-A17-303 (FR-A17-301; SC-A17-301; clarification Q1). The structure search
// over content version 2: every name and synonym of every part finds that part first; case, accents and spaces are
// ignored; an empty query lists the 14 parts in order; a query that matches nothing gives none; "collateral" lists
// both collateral ligaments first; descriptions match only from 3 characters; the results are deterministic.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

@Suite struct SearchTests {
    /// The bundled knee and its 14 parts in inventory order.
    private static func searchRegion() throws -> (AnatomyRegion, [AnatomicalStructure]) {
        let region = try AnatomyContent.bundledRightKnee()
        return (region, region.structures.filter { $0.parent != nil })
    }

    @Test func contentVersionTwoCarriesTheCommonNames() throws {
        let (region, _) = try Self.searchRegion()
        #expect(region.contentVersion == 2)
        #expect(AnatomyContent.validate(region) == nil)
        #expect(region.structure("knee.femur")?.synonyms == ["Thigh bone"])
        #expect(region.structure("knee.tibia")?.synonyms == ["Shin bone"])
        #expect(region.structure("knee.fibula")?.synonyms == ["Calf bone"])
        #expect(region.structure("knee.patella")?.synonyms == ["Kneecap"])
    }

    @Test func everyNameAndSynonymFindsItsPartFirst() throws {
        let (region, parts) = try Self.searchRegion()
        for (index, part) in parts.enumerated() {
            for name in [part.englishName, part.standardName] + part.synonyms {
                let first = AnatomySearch.results(name, region: region).first
                #expect(first?.index == index, "\(name) finds \(part.id)")
                let shouted = AnatomySearch.results("  \(name.uppercased()) ", region: region).first
                #expect(shouted?.index == index, "\(name) in capitals finds \(part.id)")
            }
        }
    }

    @Test func caseAccentsSpacesAndWordPrefixesAreIgnored() throws {
        let (region, parts) = try Self.searchRegion()
        let acl = try #require(parts.firstIndex { $0.id == "knee.acl" })
        let acls = AnatomySearch.results("  acl ", region: region)
        #expect(acls.first == AnatomySearch.Result(index: acl, rank: 2, matched: "ACL"))
        let meniscus = try #require(parts.firstIndex { $0.id == "knee.medial-meniscus" })
        #expect(AnatomySearch.results("Méniscus  médialis", region: region).first?.index == meniscus)
        let patellar = try #require(parts.firstIndex { $0.id == "knee.patellar-ligament" })
        let tendon = AnatomySearch.results("patellar ten", region: region)
        #expect(tendon.first == AnatomySearch.Result(index: patellar, rank: 3, matched: "Patellar tendon"))
        let patella = try #require(parts.firstIndex { $0.id == "knee.patella" })
        #expect(AnatomySearch.results("kneecap", region: region).first?.rank == 2)
        #expect(AnatomySearch.results("kneecap", region: region).first?.index == patella)
    }

    @Test func anEmptyQueryListsEveryPartInOrder() throws {
        let (region, parts) = try Self.searchRegion()
        for query in ["", "   "] {
            let results = AnatomySearch.results(query, region: region)
            #expect(results.map(\.index) == Array(0..<14))
            #expect(results.map(\.matched) == parts.map(\.englishName))
            #expect(results.allSatisfy { $0.rank == 0 })
        }
    }

    @Test func aQueryThatMatchesNothingGivesNone() throws {
        let (region, _) = try Self.searchRegion()
        #expect(AnatomySearch.results("elbow", region: region).isEmpty)
        #expect(AnatomySearch.results("gr", region: region).isEmpty)
        let groove = AnatomySearch.results("gro", region: region)
        #expect(!groove.isEmpty)
        #expect(groove.allSatisfy { $0.rank == 4 })
    }

    @Test func collateralListsBothCollateralLigamentsFirst() throws {
        let (region, parts) = try Self.searchRegion()
        let mcl = try #require(parts.firstIndex { $0.id == "knee.mcl" })
        let lcl = try #require(parts.firstIndex { $0.id == "knee.lcl" })
        let results = AnatomySearch.results("Collateral", region: region)
        #expect(results.prefix(2).map(\.index) == [mcl, lcl])
        #expect(results.prefix(2).allSatisfy { $0.rank == 1 })
        #expect(results.dropFirst(2).allSatisfy { $0.rank > 1 })
    }

    @Test func resultsAreDeterministicOncePerPartAndBounded() throws {
        let (region, _) = try Self.searchRegion()
        for query in ["bone", "ligament", "the", "e", "knee"] {
            let first = AnatomySearch.results(query, region: region)
            let second = AnatomySearch.results(query, region: region)
            #expect(first == second, "\(query)")
            #expect(Set(first.map(\.index)).count == first.count, "\(query)")
            #expect(first.count <= AnatomySearch.maxResults, "\(query)")
            let keys = first.map { [$0.rank, $0.index] }
            #expect(keys == keys.sorted { ($0[0], $0[1]) < ($1[0], $1[1]) }, "\(query)")
        }
    }
}
