// RenderDeterminismTests — feature 012 T-A01-111 (FR-A01-106, SC-A01-101, SC-A01-103): every family renders non-blank,
// and the same document (also after a serialization round trip) renders the same image within tolerance.
import XCTest
import GenerativeArtStudioCore
import VisualCoreTestSupport
@testable import GenerativeArtStudioExperience

@MainActor
final class RenderDeterminismTests: XCTestCase {
    func testEveryFamilyRendersNonBlank() throws {
        for family in SceneFamilyID.allCases {
            let px = try ArtRender.pixels(ArtRender.document(family))
            let luminance = ImageStatistics.meanLuminance(px), colors = ImageStatistics.distinctColors(px)
            XCTAssertGreaterThanOrEqual(colors, 2, "\(family) distinct colors")
            XCTAssertTrue((0.02...0.98).contains(luminance), "\(family) mean luminance \(luminance)")
            print("SC-A01-101 \(family.rawValue): colors=\(colors) luminance=\(String(format: "%.3f", luminance))")
        }
    }

    func testSameDocumentAndRoundTripRenderIdenticallyWithinTolerance() throws {
        for family in SceneFamilyID.allCases {
            let doc = try ArtRender.document(family)
            let first = try ArtRender.pixels(doc)
            let second = try ArtRender.pixels(doc)
            let decoded = try ArtDocument.decode(doc.canonicalJSON()).document
            XCTAssertEqual(decoded, doc)
            let third = try ArtRender.pixels(decoded)
            for (label, other) in [("rerender", second), ("round trip", third)] {
                let d = ImageComparison.compare(first, other)
                XCTAssertGreaterThanOrEqual(d.fractionWithin(2), 0.99, "\(family) \(label)")
                XCTAssertLessThanOrEqual(d.meanAbsolute, 0.5, "\(family) \(label)")
                print("SC-A01-103 \(family.rawValue) \(label): within2=\(d.fractionWithin(2)) mean=\(d.meanAbsolute) max=\(d.maxAbsolute)")
            }
        }
    }
}
