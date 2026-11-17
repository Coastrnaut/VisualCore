// AnatomyListOnlyTests — feature 128 (A17-P05) T-A17-503 (FR-A17-503–505; SC-A17-503; clarifications Q3, Q5). The
// VoiceOver regression fixture through the one app's session host on the simulator, short runs only (each test well
// under 10 s; announcements are timed by the host's frame clock, so nothing waits on the wall clock): with every layer
// shown, each of the 14 parts is selected through the list's action alone (`structure.select [i]` through the
// presenter, as the list row sends it; no pointer event in that session). For each part the panel has its model
// statement first and its review lines after its citations, the "About this model" row carries the statement, the
// announcement is "<English name> selected.", and the view and digest equal those of a tap selection of the same part
// in a second session wherever the picker picks the part at its projected centre. The list row model (text, spoken
// label, enabled) is checked for every part. A refused review record leaves only "Not reviewed by a clinician." and
// is counted.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

/// Using Interactive Anatomy from the structure list alone.
@MainActor
final class AnatomyListOnlyTests: XCTestCase {
    /// Frames of 1/60 s that pass the 0.5 s announcement interval.
    private static let flushFrames = 32

    /// Clears the selection and the framing through the list's own buttons and draws a frame.
    private func backToOpening(_ session: ExperienceSession, _ shell: ExperienceShell<AnatomyPresenter>) throws {
        _ = shell.presenter.send("structure.clear", through: shell.port)
        _ = shell.presenter.send("view.reset", through: shell.port)
        try AnatomyTest.frames(session, 1)
    }

    func testEveryPartIsSelectedFromTheListAloneWithThePanelAndTheAnnouncementOfATap() async throws {
        let session = ExperienceSession()
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        presenter.announcementSink = { _ in }
        let opening = try AnatomyTest.core(shell)
        let region = opening.region
        let parts = opening.scene.parts
        XCTAssertEqual(parts.count, 14)
        XCTAssertEqual(opening.visibleLayers.count, 3, "every layer is shown")
        let record = try AnatomyReviewRecord.bundled(for: region).get()
        let identifier = shell.port.identifier(AnatomyControls.aboutModelName)
        XCTAssertEqual(identifier, "experience.a17.interactive-anatomy.about-model")
        XCTAssertEqual(AnatomyControls.aboutModelLabel, "About this model")
        var listed: [Int: (view: AnatomyViewState, digest: StateDigest)] = [:]
        for (index, part) in parts.enumerated() {
            try backToOpening(session, shell)
            let layer = try XCTUnwrap(part.layer)
            let sign = AnatomyLayerSign.of(layer)
            let row = presenter.mirror.parts[index]
            XCTAssertEqual(AnatomyControls.rowText(name: row.name, layer: row.layer), "\(sign.sign) \(part.englishName)")
            XCTAssertEqual(AnatomyControls.rowLabel(name: row.name, layer: row.layer), "\(part.englishName), \(sign.words)")
            let enabled = presenter.mirror.solid.contains(index)
            XCTAssertTrue(enabled, "\(part.englishName): the row is enabled")

            let result = presenter.send("structure.select", [Double(index)], through: shell.port)
            XCTAssertTrue(result.isAccepted, "\(part.englishName): \(result.code)")
            try AnatomyTest.frames(session, Self.flushFrames)
            let core = try AnatomyTest.core(shell)
            XCTAssertEqual(core.selectedIndex, index)
            XCTAssertEqual(core.view.selection, part.id)
            let lastAnnounced = presenter.announced.last
            XCTAssertEqual(lastAnnounced, "\(part.englishName) selected.")

            let panel = try XCTUnwrap(presenter.mirror.panel)
            let expected = AnatomyPanel.make(partIndex: index, region: region, record: record)
            XCTAssertEqual(panel, expected, part.englishName)
            XCTAssertEqual(panel.modelStatement, AnatomyReview.modelStatement)
            XCTAssertEqual(panel.reviewLines, ["Text checked against its sources by the lead engineer on 2026-11-16.",
                                               "Not reviewed by a clinician."], part.englishName)
            let lines = AnatomyControls.panelLines(panel, ghostsOff: false)
            XCTAssertEqual(lines.first, AnatomyReview.modelStatement, "the statement opens the panel")
            XCTAssertEqual(Array(lines.suffix(5)), panel.citations + panel.reviewLines,
                           "\(part.englishName): the review lines follow the citations")
            XCTAssertTrue(lines.contains(part.englishName))
            XCTAssertTrue(lines.contains(part.description))
            listed[index] = (core.view, try shell.engine.digest())
        }
        XCTAssertEqual(presenter.reviewRecordProblems, 0)
        try backToOpening(session, shell)
        let empty = try XCTUnwrap(presenter.mirror.panel)
        XCTAssertEqual(empty.modelStatement, AnatomyReview.modelStatement, "the statement stays without a selection")
        XCTAssertTrue(empty.reviewLines.isEmpty)
        XCTAssertEqual(AnatomyControls.panelLines(empty, ghostsOff: false).first, AnatomyReview.modelStatement)
        session.close()

        let tapSession = ExperienceSession()
        let tapShell = try await AnatomyTest.open(tapSession)
        var compared = 0
        for index in 0..<14 {
            try backToOpening(tapSession, tapShell)
            let center = try AnatomyTest.core(tapShell).scene.structureSphere(index).center
            let ndc = try AnatomyTest.projectedNDC(of: center, presenter: tapShell.presenter)
            guard try AnatomyTest.expectedPick(tapShell, at: ndc) == index else { continue }
            _ = tapShell.presenter.tap(atNDC: ndc, through: tapShell.port)
            let tapped = try AnatomyTest.core(tapShell).view
            let tappedDigest = try tapShell.engine.digest()
            let list = try XCTUnwrap(listed[index])
            XCTAssertEqual(list.view, tapped, "part \(index): the list selection equals the tap")
            XCTAssertEqual(list.digest, tappedDigest, "part \(index)")
            compared += 1
        }
        XCTAssertGreaterThan(compared, 0, "at least one part was compared with a tap")
        tapSession.close()
    }

    func testARefusedReviewRecordLeavesOnlyTheNotReviewedLineAndIsCounted() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.reviewRecordProblems, 0)
        presenter.reviewRecordLoader = { _ in .failure(ContentRefusal(.damaged, "The review record is damaged.")) }
        for index in [0, 9, 13] {
            AnatomyTest.accept(shell, "structure.select", [Double(index)])
            try AnatomyTest.frames(session, 1)
            let panel = try XCTUnwrap(presenter.mirror.panel)
            XCTAssertEqual(panel.reviewLines, ["Not reviewed by a clinician."], "part \(index)")
            XCTAssertEqual(panel.modelStatement, AnatomyReview.modelStatement)
            XCTAssertFalse(panel.citations.isEmpty, "part \(index): the content stays usable")
        }
        XCTAssertEqual(presenter.reviewRecordProblems, 1, "the refusal is counted once")
    }
}
