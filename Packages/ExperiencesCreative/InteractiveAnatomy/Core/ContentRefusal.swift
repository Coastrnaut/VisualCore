// ContentRefusal — feature 124 (A17-P01) T-A17-107 (data-model "ContentRefusal"; contracts/core.md). Why region
// content was refused: one reason and one plain-English sentence that names the offending id, word or value and ends
// with a period. Refused content changes nothing.
import Foundation

/// A refusal of region content: the first problem found, with a sentence that names it.
public struct ContentRefusal: Error, Equatable, Sendable {
    /// The kinds of problem content can have; the raw values are the stable names.
    public enum Reason: String, CaseIterable, Sendable {
        /// Not JSON, a missing or malformed key, a schema below 1, or a root with a layer or meshes.
        case damaged
        /// A schema newer than this code reads.
        case newerVersion = "newer-version"
        /// More bytes than `AnatomyContent.maxBytes`.
        case tooLarge = "too-large"
        /// An id that does not resolve, a part without layer or meshes, a mesh owned by no structure, or two roots.
        case missingReference = "missing-reference"
        /// An id used twice, or a mesh owned twice.
        case duplicateID = "duplicate-id"
        /// No root, or a parent chain that returns to itself.
        case parentCycle = "parent-cycle"
        /// An empty name or description, or a description outside 1–3 sentences or over 400 characters.
        case emptyText = "empty-text"
        /// A structure without sources.
        case unsourced
        /// A licence outside `ContentManifest.allowedLicenses`.
        case badLicense = "bad-license"
        /// Non-finite or empty bounds.
        case nonFinite = "non-finite"
        /// A synonym equal to another structure's synonym or name.
        case collidingSynonym = "colliding-synonym"
        /// A description that uses a clinical word.
        case clinicalText = "clinical-text"
    }

    /// The kind of problem.
    public let reason: Reason
    /// The plain-English sentence that names the problem.
    public let sentence: String

    /// Creates a refusal.
    public init(_ reason: Reason, _ sentence: String) {
        self.reason = reason
        self.sentence = sentence
    }
}
