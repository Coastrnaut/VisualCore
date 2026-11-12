// ExperienceIDTests — feature 187 T-U01-003 (FR-U01-001, FR-U01-002, FR-U01-005; data-model section 1).
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct ExperienceIDTests {
    @Test func validCodesParseAndPrintIdentically() throws {
        for text in ["A01", "A25", "A99", "R02-G01", "R04-G25", "R12-G25", "R99-G99"] {
            let code = try ExperienceCode(text)
            #expect(code.text == text)
            #expect(code.description == text)
            #expect(code.integrationGate == "X-" + text)
        }
        let original = try ExperienceCode("A05")
        #expect(original.isOriginal && original.round == nil && original.number == 5)
        let game = try ExperienceCode("R02-G17")
        #expect(!game.isOriginal && game.round == 2 && game.number == 17)
    }

    @Test func malformedCodesAreRejectedWithAReason() {
        let bad = ["", "A", "A1", "A001", "A00", "a05", "B05", "A0x", "R01-G01", "R02-G00", "R2-G01", "R02-G1", "R02G01",
                   "R02-g01", "r02-g01", "R02-G001", " A05", "A05 ", "A٠5", "R02_G01"]
        for text in bad {
            do {
                _ = try ExperienceCode(text)
                Issue.record("accepted the malformed code \(text.debugDescription)")
            } catch {
                guard case let .malformed(found, reason) = error else { continue }
                #expect(found == text)
                #expect(!reason.isEmpty)
            }
        }
    }

    @Test func validIdsParseAndPrintIdentically() throws {
        for text in ["a05.infinite-geometry", "r02-g01.aurora-loom", "a21.aurora", "r12-g25.x9", "a01.a-b-c-1"] {
            let id = try ExperienceID(text)
            #expect(id.rawValue == text)
            #expect(id.description == text)
            #expect(ExperienceID(rawValue: text) == id)
        }
        let id = try ExperienceID("r02-g01.aurora-loom")
        #expect(id.code == (try ExperienceCode("R02-G01")))
        #expect(id.slug == "aurora-loom")
        #expect(try ExperienceID("a05.\(String(repeating: "a", count: 60))").slug.count == 60)
    }

    @Test func malformedIdsAreRejectedWithAReason() {
        let bad = ["", "a05", "a05.", ".infinite-geometry", "A05.infinite-geometry", "a05.Infinite-geometry", "a05.infinite.geometry",
                   "a05.-geometry", "a05.geometry-", "a05.infinite--geometry", "a05.infinite_geometry", "a5.geometry", "a00.geometry",
                   "r01-g01.x", "r02-g00.x", "R02-G01.aurora-loom", " a05.geometry", "a05.geometry ", "a05.géométrie",
                   "a05.\(String(repeating: "a", count: 61))", "x05.geometry"]
        for text in bad {
            #expect(ExperienceID(rawValue: text) == nil, "accepted \(text.debugDescription)")
            do {
                _ = try ExperienceID(text)
                Issue.record("accepted the malformed id \(text.debugDescription)")
            } catch {
                guard case let .malformed(found, reason) = error else { continue }
                #expect(found == text)
                #expect(!reason.isEmpty)
            }
        }
        #expect(bad.count >= 12)
    }

    @Test func derivedNamesAreFunctionsOfTheIdAlone() throws {
        let id = try ExperienceID("a05.infinite-geometry")
        #expect(id.integrationGate == "X-A05")
        #expect(id.storageNamespace == "a05.infinite-geometry")
        #expect(id.evidenceName == "a05.infinite-geometry")
        #expect(id.accessibilityPrefix == "experience.a05.infinite-geometry")
        #expect(try ExperienceID("r03-g01.harmonic-helix").integrationGate == "X-R03-G01")
    }

    @Test func idsAreHashableComparableAndCodableAsText() throws {
        let a = try ExperienceID("a05.infinite-geometry"), b = try ExperienceID("r02-g01.aurora-loom")
        #expect(a < b)
        #expect(Set([a, b, a]).count == 2)
        #expect([b, a].sorted() == [a, b])
        #expect((try ExperienceCode("A05")) < (try ExperienceCode("R02-G01")))
        let data = try JSONEncoder().encode([a, b])
        #expect(String(decoding: data, as: UTF8.self) == #"["a05.infinite-geometry","r02-g01.aurora-loom"]"#)
        #expect(try JSONDecoder().decode([ExperienceID].self, from: data) == [a, b])
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([ExperienceID].self, from: Data(#"["A05.x"]"#.utf8)) }
    }
}
