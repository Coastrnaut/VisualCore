// AnatomyProvenance — feature 127 (A17-P04) T-A17-404 (FR-A17-408; SC-A17-404; clarification Q5; data-model
// "AnatomyProvenance"; contracts/accessibility-pack.md). Where a region's content comes from, built from its manifest:
// the text and geometry licenses, each citation with its license, and the review status with its sentence.
//
// `problems` lists, in this order, one sentence for: an empty or disallowed text license, an empty or disallowed
// geometry license, each citation with an empty id or an empty or disallowed license, an empty review status, and an
// empty review sentence. It is empty when the provenance is complete.
import Foundation

/// The provenance of a region's content (see the file header).
public struct AnatomyProvenance: Equatable, Sendable {
    /// One citation and the license it is used under.
    public struct CitationLicense: Equatable, Sendable {
        /// The citation id.
        public let id: String
        /// The citation's license.
        public let license: String

        /// Creates a citation license.
        public init(id: String, license: String) {
            self.id = id
            self.license = license
        }
    }

    /// The license of the text.
    public let textLicense: String
    /// The license of the geometry.
    public let geometryLicense: String
    /// Each citation with its license, in manifest order.
    public let citations: [CitationLicense]
    /// The clinical review status (`ReviewStatus.notReviewed` or `ReviewStatus.reviewed`).
    public let reviewStatus: String
    /// The sentence shown with the content, for example "Not reviewed by a clinician.".
    public let reviewSentence: String

    /// Creates a provenance.
    public init(textLicense: String, geometryLicense: String, citations: [CitationLicense], reviewStatus: String,
                reviewSentence: String) {
        self.textLicense = textLicense
        self.geometryLicense = geometryLicense
        self.citations = citations
        self.reviewStatus = reviewStatus
        self.reviewSentence = reviewSentence
    }

    /// The provenance of `region`, from its manifest.
    public static func of(_ region: AnatomyRegion) -> AnatomyProvenance {
        let manifest = region.manifest
        return AnatomyProvenance(textLicense: manifest.textLicense, geometryLicense: manifest.geometryLicense,
                                 citations: manifest.citations.map { CitationLicense(id: $0.id, license: $0.license) },
                                 reviewStatus: manifest.review.status, reviewSentence: manifest.reviewSentence)
    }

    /// Every missing or invalid field as a sentence (see the file header); empty when complete.
    public var problems: [String] {
        var problems: [String] = []
        if let problem = Self.licenseProblem(textLicense, of: "The text") { problems.append(problem) }
        if let problem = Self.licenseProblem(geometryLicense, of: "The geometry") { problems.append(problem) }
        for citation in citations {
            if Self.isBlank(citation.id) { problems.append("A citation has an empty id.") }
            let subject = Self.isBlank(citation.id) ? "A citation" : "The citation \(citation.id)"
            if let problem = Self.licenseProblem(citation.license, of: subject) { problems.append(problem) }
        }
        if Self.isBlank(reviewStatus) { problems.append("The review status is empty.") }
        if Self.isBlank(reviewSentence) { problems.append("The review sentence is missing.") }
        return problems
    }

    /// The problem of `license` belonging to `subject`, or nil when it is allowed.
    private static func licenseProblem(_ license: String, of subject: String) -> String? {
        if isBlank(license) { return "\(subject) has an empty license." }
        if !ContentManifest.allowedLicenses.contains(license) {
            return "\(subject) has the license \(license), which is not allowed."
        }
        return nil
    }

    /// Whether `text` is empty after trimming whitespace.
    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
