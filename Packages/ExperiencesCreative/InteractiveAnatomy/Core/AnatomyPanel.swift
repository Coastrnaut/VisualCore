// AnatomyPanel — feature 126 (A17-P03) T-A17-304 (FR-A17-303; SC-A17-302; clarification Q5; data-model
// "AnatomyPanel"; contracts/layers-search.md). The text of the description panel, built from the content so it is
// tested without a GPU: for the selected part its English name as the heading, its standard name, its layer in words,
// its description and each of its citations as "Title, edition, section (license)" in source order; with nothing
// selected the heading "Select a structure to read about it." and no other text. The review sentence of the manifest
// ("Not reviewed by a clinician." until a review is recorded) is always present.
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

    /// Creates panel text.
    public init(heading: String, standardName: String?, layerWords: String?, description: String?,
                citations: [String], reviewSentence: String) {
        self.heading = heading
        self.standardName = standardName
        self.layerWords = layerWords
        self.description = description
        self.citations = citations
        self.reviewSentence = reviewSentence
    }

    /// The panel for the part at inventory index `partIndex` of `region` (the structures with a parent, in content
    /// order); nil or an index outside the parts gives the empty panel.
    public static func make(partIndex: Int?, region: AnatomyRegion) -> AnatomyPanel {
        let parts = region.structures.filter { $0.parent != nil }
        let review = region.manifest.reviewSentence
        guard let partIndex, parts.indices.contains(partIndex) else {
            return AnatomyPanel(heading: emptyHeading, standardName: nil, layerWords: nil, description: nil,
                                citations: [], reviewSentence: review)
        }
        let part = parts[partIndex]
        return AnatomyPanel(heading: part.englishName, standardName: part.standardName,
                            layerWords: part.layer.map(words), description: part.description,
                            citations: citations(of: part, region: region), reviewSentence: review)
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
