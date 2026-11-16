// PanelTests — feature 126 (A17-P03) T-A17-304 (FR-A17-303; SC-A17-302; clarification Q5). The description panel:
// every part shows its names, its layer in words, its description and at least one citation with edition and
// section, in source order as "Title, edition, section (license)"; the review sentence is always present; with
// nothing selected the panel invites a selection.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

@Suite struct PanelTests {
    /// The bundled knee.
    private static func panelRegion() throws -> AnatomyRegion { try AnatomyContent.bundledRightKnee() }

    @Test func everyPartShowsItsNamesLayerDescriptionAndCitations() throws {
        let region = try Self.panelRegion()
        let parts = region.structures.filter { $0.parent != nil }
        #expect(parts.count == 14)
        for (index, part) in parts.enumerated() {
            let panel = AnatomyPanel.make(partIndex: index, region: region)
            #expect(panel.heading == part.englishName)
            #expect(panel.standardName == part.standardName)
            #expect(panel.layerWords == part.layer.map(AnatomyPanel.words))
            #expect(panel.description == part.description)
            #expect(panel.citations.count == part.sourceRefs.count, "\(part.id)")
            #expect(panel.reviewSentence == "Not reviewed by a clinician.")
            let cited = region.manifest.citations.filter { part.sourceRefs.contains($0.id) }
            let withEdition = cited.contains { !$0.edition.isEmpty && !$0.section.isEmpty }
            #expect(withEdition, "\(part.id) has a citation with edition and section")
        }
    }

    @Test func citationsReadTitleEditionSectionAndLicense() throws {
        let region = try Self.panelRegion()
        let femur = AnatomyPanel.make(partIndex: 0, region: region)
        #expect(femur.heading == "Femur")
        #expect(femur.layerWords == "bones")
        #expect(femur.citations == [
            "Anatomy of the Human Body, 20th (1918), Osteology: The Femur (public-domain)",
            "Terminologia Anatomica, 1998, Lower limb (facts)",
            "Interactive Anatomy descriptions, 1, All structures (original)",
        ])
        #expect(AnatomyPanel.words(.cartilage) == "cartilage and menisci")
        #expect(AnatomyPanel.words(.ligaments) == "ligaments and tendons")
    }

    @Test func nothingSelectedInvitesASelection() throws {
        let region = try Self.panelRegion()
        for index in [nil, -1, 14] as [Int?] {
            let panel = AnatomyPanel.make(partIndex: index, region: region)
            #expect(panel.heading == "Select a structure to read about it.")
            #expect(panel.standardName == nil)
            #expect(panel.layerWords == nil)
            #expect(panel.description == nil)
            #expect(panel.citations.isEmpty)
            #expect(panel.reviewSentence == region.manifest.reviewSentence)
        }
    }
}
