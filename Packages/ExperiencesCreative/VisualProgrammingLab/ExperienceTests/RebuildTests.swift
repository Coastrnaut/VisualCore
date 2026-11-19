// RebuildTests — feature 167 (A23-P02) T-A23-208 (FR-A23-206; SC-A23-205; User Story 5; contracts/experience.md).
// Through the one app's session host, after Shader Studio's `RebuildTests`: an edited graph with a panned and zoomed
// view draws the same canvas off screen after each of 10 `recreateContext` calls (the presenter's `setup` builds the
// grid again from the same view state) and after a resize of the view and back, with the graph, the selection and the
// view unchanged and no GPU object leaked. Short runs only.
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct RebuildTests {
    @Test func theCanvasIsDrawnTheSameAfterContextLossesAndAResize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.open(session)
        let presenter = shell.presenter
        LabTest.accept(shell, "node.add", [4, 320, 240])
        LabTest.accept(shell, "node.select", [3])
        presenter.view = presenter.view.panned(by: Vec2(7, -3)).pinched(by: 1.5, anchor: Vec2(20, 20))
        try LabTest.draw(session)
        let view = presenter.view
        let core = try LabTest.core(shell)
        let before = try LabTest.still(session)

        let host = try #require(session.renderHost)
        for round in 1...10 {
            host.recreateContext()
            try LabTest.draw(session)
            #expect(presenter.grid.errorMessage == nil)
            #expect(try LabTest.still(session) == before, "the same picture after context loss \(round)")
        }

        let canvas = try #require(session.renderHost?.view)
        canvas.frame = CGRect(x: 0, y: 0, width: 96, height: 72)
        canvas.layoutIfNeeded()
        try LabTest.draw(session, frames: 2)
        canvas.frame = CGRect(x: 0, y: 0, width: 64, height: 48)
        canvas.layoutIfNeeded()
        try LabTest.draw(session)
        #expect(try LabTest.still(session) == before, "the same picture after the resize")
        #expect(presenter.view == view, "the view is unchanged")
        #expect(try LabTest.core(shell) == core, "the graph and the selection are unchanged")
        #expect(host.resources.stats.leaked == 0)
    }
}
