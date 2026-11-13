// FamilyDistinctnessTests — feature 012 T-A01-111 (FR-A01-107, SC-A01-104): the four families are genuinely different,
// and the seed changes a family's image.
import XCTest
import GenerativeArtStudioCore
import VisualCoreTestSupport
@testable import GenerativeArtStudioExperience

@MainActor
final class FamilyDistinctnessTests: XCTestCase {
    func testFamiliesArePairwiseDistinct() throws {
        var images: [SceneFamilyID: [UInt8]] = [:]
        for family in SceneFamilyID.allCases { images[family] = try ArtRender.pixels(ArtRender.document(family, seed: 1234)) }
        let ids = SceneFamilyID.allCases
        var pairs = 0
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                let d = ImageComparison.compare(images[ids[i]]!, images[ids[j]]!)
                XCTAssertGreaterThanOrEqual(d.meanAbsolute, 20, "\(ids[i]) vs \(ids[j])")
                print("SC-A01-104 \(ids[i].rawValue) vs \(ids[j].rawValue): mean=\(d.meanAbsolute)")
                pairs += 1
            }
        }
        XCTAssertEqual(pairs, 6)
    }

    func testSeedChangesTheImage() throws {
        for family in SceneFamilyID.allCases {
            let a = try ArtRender.pixels(ArtRender.document(family, seed: 1)), b = try ArtRender.pixels(ArtRender.document(family, seed: 2))
            let d = ImageComparison.compare(a, b)
            XCTAssertGreaterThanOrEqual(d.meanAbsolute, 2, "\(family) seeds 1 vs 2")
            print("SC-A01-104 \(family.rawValue) seed 1 vs 2: mean=\(d.meanAbsolute)")
        }
    }
}
