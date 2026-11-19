// CompileQueueTests — feature 168 (A23-P03) T-A23-307 (FR-A23-305; SC-A23-304, SC-A23-306; clarification Q3; User
// Story 4). Through the one app's session host: edits sent through the port compile nothing by themselves; N edits
// before a frame give exactly one compile at that frame; a frame with no change compiles nothing; a change of the view
// (pan, zoom, a resize of the canvas) and a selection compile nothing. Short runs only.
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct CompileQueueTests {
    @Test func severalEditsBeforeAFrameGiveOneCompile() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let pipeline = shell.presenter.pipeline
        let opening = pipeline.compileCount
        #expect(opening == 1, "the opening frame compiled the starter graph once")
        try LabTest.draw(session, frames: 2)
        #expect(pipeline.compileCount == opening, "an unchanged graph is not compiled again")

        // Gradient 3 and Mix 4 (kinds 3 and 4), Noise 1 into Mix a, Gradient into Mix b, Mix into Output 2.
        LabTest.accept(shell, "node.add", [3, 40, 300])
        LabTest.accept(shell, "node.add", [4, 240, 200])
        LabTest.accept(shell, "edge.connect", [1, 0, 4, 0])
        LabTest.accept(shell, "edge.connect", [3, 0, 4, 1])
        LabTest.accept(shell, "edge.disconnect", [2, 0])
        LabTest.accept(shell, "edge.connect", [4, 0, 2, 0])
        #expect(pipeline.compileCount == opening, "no compile from a control")
        try LabTest.draw(session)
        #expect(pipeline.compileCount == opening + 1, "six edits, one compile at the next frame")
        #expect(shell.presenter.previewState == .ready)
        #expect(pipeline.schedule?.passes.map { $0.operator } == [.noise, .gradient, .mix, .output])
        try LabTest.draw(session, frames: 2)
        #expect(pipeline.compileCount == opening + 1)
    }

    @Test func aViewChangeOrASelectionCompilesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let presenter = shell.presenter
        let count = presenter.pipeline.compileCount
        presenter.view = presenter.view.panned(by: Vec2(12, -8))
        try LabTest.draw(session)
        presenter.view = presenter.view.pinched(by: 1.5, anchor: Vec2(20, 20))
        try LabTest.draw(session)
        presenter.noteCanvasSize(Vec2(120, 90))
        try LabTest.draw(session)
        LabTest.accept(shell, "node.select", [1])
        try LabTest.draw(session)
        _ = try LabTest.still(session)
        #expect(presenter.pipeline.compileCount == count, "the view and the selection never compile")
        #expect(presenter.previewState == .ready)
    }
}
