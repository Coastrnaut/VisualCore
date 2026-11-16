// AnatomySearchSessionTests — feature 126 (A17-P03) T-A17-307 (FR-A17-301, FR-A17-303; SC-A17-301, SC-A17-302;
// clarifications Q1, Q5). Search and the description panel inside the one app's session host on the simulator, short
// runs only (each test well under 10 s, no wall-clock assertion): for every part the first `AnatomySearch` result for
// its English name, sent as `structure.select`, gives the same view and digest as selecting that part; the synonyms
// "ACL", "Kneecap" and "Shin bone" select the anterior cruciate ligament, the patella and the tibia; the panel of the
// selection has its heading, at least one citation and the manifest's review sentence.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Choosing search results through the session host.
@MainActor
final class AnatomySearchSessionTests: XCTestCase {
    /// Clears the selection and the framing and draws a frame.
    private func backToOpening(_ session: ExperienceSession, _ shell: ExperienceShell<AnatomyPresenter>) throws {
        AnatomyTest.accept(shell, "structure.clear")
        AnatomyTest.accept(shell, "view.reset")
        try AnatomyTest.frames(session, 1)
    }

    func testTheFirstResultForEachEnglishNameEqualsSelectingThePart() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let region = try AnatomyTest.core(shell).region
        let parts = try AnatomyTest.core(shell).scene.parts
        XCTAssertEqual(parts.count, 14)
        for (index, part) in parts.enumerated() {
            try backToOpening(session, shell)
            AnatomyTest.accept(shell, "structure.select", [Double(index)])
            let listed = try AnatomyTest.core(shell).view
            let listedDigest = try shell.engine.digest()

            try backToOpening(session, shell)
            let first = try XCTUnwrap(AnatomySearch.results(part.englishName, region: region).first, part.englishName)
            XCTAssertEqual(first.index, index, "\(part.englishName) finds itself first")
            XCTAssertEqual(first.rank, 0, "\(part.englishName): an exact name")
            AnatomyTest.accept(shell, "structure.select", [Double(first.index)])
            let searched = try AnatomyTest.core(shell).view
            let searchedDigest = try shell.engine.digest()
            XCTAssertEqual(searched, listed, "\(part.englishName): the search result equals the selection")
            XCTAssertEqual(searchedDigest, listedDigest, part.englishName)
            XCTAssertEqual(searched.selection, part.id)
        }
    }

    func testSynonymsSelectTheirParts() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let core = try AnatomyTest.core(shell)
        let cases: [(query: String, id: String)] = [("ACL", "knee.acl"), ("Kneecap", "knee.patella"),
                                                     ("Shin bone", "knee.tibia")]
        for item in cases {
            try backToOpening(session, shell)
            let first = try XCTUnwrap(AnatomySearch.results(item.query, region: core.region).first, item.query)
            XCTAssertEqual(core.scene.parts[first.index].id, item.id, item.query)
            AnatomyTest.accept(shell, "structure.select", [Double(first.index)])
            let selected = try AnatomyTest.core(shell)
            XCTAssertEqual(selected.view.selection, item.id, item.query)
            XCTAssertEqual(selected.selectedIndex, first.index, item.query)
            let lowered = try XCTUnwrap(AnatomySearch.results(item.query.lowercased(), region: core.region).first)
            XCTAssertEqual(lowered.index, first.index, "\(item.query): case does not matter")
        }
    }

    func testThePanelOfTheSelectionHasACitationAndTheReviewSentence() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let opening = try AnatomyTest.core(shell)
        XCTAssertNil(opening.selectedIndex)
        let empty = AnatomyPanel.make(partIndex: opening.selectedIndex, region: opening.region)
        XCTAssertEqual(empty.heading, AnatomyPanel.emptyHeading)
        XCTAssertTrue(empty.citations.isEmpty)
        XCTAssertFalse(empty.reviewSentence.isEmpty, "the review sentence is always present")
        for index in 0..<14 {
            AnatomyTest.accept(shell, "structure.select", [Double(index)])
            let core = try AnatomyTest.core(shell)
            let selected = try XCTUnwrap(core.selectedIndex)
            let panel = AnatomyPanel.make(partIndex: selected, region: core.region)
            let part = core.scene.parts[selected]
            XCTAssertEqual(panel.heading, part.englishName)
            XCTAssertEqual(panel.standardName, part.standardName)
            XCTAssertFalse(panel.citations.isEmpty, "\(part.englishName) has a citation")
            XCTAssertFalse(panel.reviewSentence.isEmpty, part.englishName)
            XCTAssertEqual(panel.reviewSentence, empty.reviewSentence, part.englishName)
            XCTAssertEqual(panel.reviewSentence, core.region.manifest.reviewSentence)
        }
    }
}
