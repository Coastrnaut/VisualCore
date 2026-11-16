// ProvenanceTests — feature 127 (A17-P04) T-A17-404 (FR-A17-408; SC-A17-404; clarification Q5). Provenance,
// host-free and short: the bundled knee's provenance is complete (licenses, citations, review status, the sentence
// "Not reviewed by a clinician."); each empty or disallowed license and each missing review field is reported.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

/// A complete provenance to break one field at a time.
private func provenanceFixture(text: String = "original", geometry: String = "original",
                               citation: String = "public-domain", status: String = ReviewStatus.notReviewed,
                               sentence: String = "Not reviewed by a clinician.") -> AnatomyProvenance {
    AnatomyProvenance(textLicense: text, geometryLicense: geometry,
                      citations: [AnatomyProvenance.CitationLicense(id: "gray", license: citation)],
                      reviewStatus: status, reviewSentence: sentence)
}

@Suite struct ProvenanceTests {
    @Test func theBundledProvenanceIsComplete() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let provenance = AnatomyProvenance.of(region)
        #expect(provenance.problems.isEmpty)
        #expect(provenance.textLicense == "original")
        #expect(provenance.geometryLicense == "original")
        #expect(provenance.citations.count == region.manifest.citations.count)
        #expect(!provenance.citations.isEmpty)
        #expect(provenance.reviewStatus == ReviewStatus.notReviewed)
        #expect(provenance.reviewSentence == "Not reviewed by a clinician.")
    }

    @Test func eachMissingOrInvalidFieldIsReported() {
        #expect(provenanceFixture().problems.isEmpty)
        #expect(provenanceFixture(text: "").problems == ["The text has an empty license."])
        #expect(provenanceFixture(text: "cc-by").problems == ["The text has the license cc-by, which is not allowed."])
        #expect(provenanceFixture(geometry: " ").problems == ["The geometry has an empty license."])
        #expect(provenanceFixture(citation: "").problems == ["The citation gray has an empty license."])
        #expect(provenanceFixture(citation: "proprietary").problems.count == 1)
        #expect(provenanceFixture(status: "").problems == ["The review status is empty."])
        #expect(provenanceFixture(sentence: "").problems == ["The review sentence is missing."])
        #expect(provenanceFixture(text: "", sentence: "").problems.count == 2)
    }
}
