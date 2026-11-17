// AnatomyPanel — feature 126 (A17-P03) T-A17-304 (FR-A17-303; SC-A17-302; clarification Q5; data-model
// "AnatomyPanel"; contracts/layers-search.md). The text of the description panel, built from the content so it is
// tested without a GPU: for the selected part its English name as the heading, its standard name, its layer in words,
// its description and each of its citations as "Title, edition, section (license)" in source order; with nothing
// selected the heading "Select a structure to read about it." and no other text. The review sentence of the manifest
// ("Not reviewed by a clinician." until a review is recorded) is always present.
// Feature 128 (A17-P05) T-A17-502 (FR-A17-503, FR-A17-504; clarification Q3; contracts/review.md): the panel also
// carries the model statement ("Schematic model for learning; shapes are simplified."), present whether or not a part
// is selected, and the selected part's review lines (`AnatomyReview.lines(partID:record:)`: the editorial line, then
// the clinical one); with nothing selected the review lines are empty. `make(partIndex:region:)` uses the bundled
// review record (`AnatomyReviewRecord.bundled(for:)`; a refused record counts as none, so only "Not reviewed by a
// clinician." is shown); `make(partIndex:region:record:)` takes the record explicitly.
import Foundation

/// The text of the description panel (see the file header).
public struct AnatomyPanel: Equatable, Sendable {
    /// The heading shown when nothing is selected.
    public static let emptyHeading = "Select a structure to read about it."

    /// The English name of the selected part, or ``emptyHeading``.
    public let heading: String
    /// The standard (Terminologia Anatomica) name, or nil with nothing selected.
    public let standardName: String?
    /// The layer in words ("bones", "cartilage and menisci", "ligaments and tendons"), or nil.
    public let layerWords: String?
    /// The plain-language description, or nil.
    public let description: String?
    /// Each citation of the part as "Title, edition, section (license)", in source order; empty with nothing selected.
    public let citations: [String]
    /// The manifest's review sentence.
    public let reviewSentence: String
    /// The model statement, ``AnatomyReview/modelStatement``, present whether or not a part is selected (feature 128).
    public let modelStatement: String
    /// The selected part's review lines (editorial, then clinical); empty with nothing selected (feature 128).
    public let reviewLines: [String]

    /// Creates panel text.
    public init(heading: String, standardName: String?, layerWords: String?, description: String?,
                citations: [String], reviewSentence: String,
                modelStatement: String = AnatomyReview.modelStatement, reviewLines: [String] = []) {
        self.heading = heading
        self.standardName = standardName
        self.layerWords = layerWords
        self.description = description
        self.citations = citations
        self.reviewSentence = reviewSentence
        self.modelStatement = modelStatement
        self.reviewLines = reviewLines
    }

    /// The panel for the part at inventory index `partIndex` of `region` (the structures with a parent, in content
    /// order) with the bundled review record (a refused record counts as none); nil or an index outside the parts
    /// gives the empty panel.
    public static func make(partIndex: Int?, region: AnatomyRegion) -> AnatomyPanel {
        make(partIndex: partIndex, region: region, record: try? AnatomyReviewRecord.bundled(for: region).get())
    }

    /// The panel for the part at inventory index `partIndex` of `region` with the review record `record` (nil: none,
    /// so the review lines are only "Not reviewed by a clinician."); nil or an index outside the parts gives the
    /// empty panel, whose review lines are empty.
    public static func make(partIndex: Int?, region: AnatomyRegion, record: AnatomyReviewRecord?) -> AnatomyPanel {
        let parts = region.structures.filter { $0.parent != nil }
        let review = region.manifest.reviewSentence
        guard let partIndex, parts.indices.contains(partIndex) else {
            return AnatomyPanel(heading: emptyHeading, standardName: nil, layerWords: nil, description: nil,
                                citations: [], reviewSentence: review)
        }
        let part = parts[partIndex]
        return AnatomyPanel(heading: part.englishName, standardName: part.standardName,
                            layerWords: part.layer.map(words), description: part.description,
                            citations: citations(of: part, region: region), reviewSentence: review,
                            reviewLines: AnatomyReview.lines(partID: part.id, record: record))
    }

    /// The words of `layer`: "bones", "cartilage and menisci", "ligaments and tendons".
    public static func words(_ layer: AnatomyLayer) -> String {
        switch layer {
        case .bones: return "bones"
        case .cartilage: return "cartilage and menisci"
        case .ligaments: return "ligaments and tendons"
        }
    }

    /// The citations `part` refers to, in source order, as "Title, edition, section (license)"; a reference that
    /// names no manifest citation is skipped (validation refuses such content).
    public static func citations(of part: AnatomicalStructure, region: AnatomyRegion) -> [String] {
        part.sourceRefs.compactMap { id in
            region.manifest.citations.first { $0.id == id }.map(text)
        }
    }

    /// One citation as "Title, edition, section (license)".
    public static func text(_ citation: Citation) -> String {
        "\(citation.title), \(citation.edition), \(citation.section) (\(citation.license))"
    }
}
