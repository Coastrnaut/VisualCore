// PreviewStateTests — feature 168 (A23-P03) T-A23-306 (FR-A23-303, FR-A23-307; SC-A23-302, SC-A23-306; clarification
// Q5; User Story 2; Edge Cases "The preview hidden", "A graph whose compile fails"). Through the one app's session
// host: every invalid-graph fixture gives `invalid(message)` with the checker's status line, no schedule, no slot and
// no pass run; disconnecting the Output through the port says "Output not connected" and reconnecting brings the
// picture back; the preview switched off draws no pass and leaves the graph's digest unchanged; an operator whose text
// does not build (the pipeline's test seam) gives `failed(message)` while the canvas keeps drawing. Short runs only.
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct PreviewStateTests {
    /// The invalid fixtures: no Output, a disconnected Output, an empty Mix input, an empty Blur input and two Outputs.
    static var invalidFixtures: [(name: String, graph: VisualGraph)] {
        var disconnected = GraphBuild()
        disconnected.add(.noise)
        disconnected.add(.output)
        var noOutput = GraphBuild()
        noOutput.add(.gradient)
        var emptyMix = GraphBuild()
        let noise = emptyMix.add(.noise)
        let mix = emptyMix.add(.mix)
        let output = emptyMix.add(.output)
        emptyMix.wire(noise, to: mix, "a")
        emptyMix.wire(mix, to: output)
        var emptyBlur = GraphBuild()
        let blur = emptyBlur.add(.blur)
        let out = emptyBlur.add(.output)
        emptyBlur.wire(blur, to: out)
        var twoOutputs = GraphBuild()
        let source = twoOutputs.add(.noise)
        let first = twoOutputs.add(.output)
        twoOutputs.add(.output)
        twoOutputs.wire(source, to: first)
        return [("disconnected output", disconnected.graph), ("no output", noOutput.graph),
                ("empty mix input", emptyMix.graph), ("empty blur input", emptyBlur.graph),
                ("two outputs", twoOutputs.graph)]
    }

    @Test func everyInvalidGraphShowsItsMessageAndDrawsNoPass() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let fixtures = Self.invalidFixtures
        let shell = try await LabTest.openPreview(session, graph: fixtures[0].graph)
        let presenter = shell.presenter
        for fixture in fixtures {
            presenter.graphOverride = fixture.graph
            try LabTest.draw(session, frames: 2)
            _ = try LabTest.still(session)
            let expected = EditMessages.status(for: GraphChecker.check(fixture.graph), in: fixture.graph)
            #expect(expected != "Ready", "\(fixture.name) is invalid")
            #expect(presenter.previewState == .invalid(expected), "\(fixture.name)")
            #expect(presenter.mirror.preview.message == expected, "\(fixture.name): the inset shows the message")
            #expect(presenter.pipeline.schedule == nil, "\(fixture.name): no schedule")
        }
        #expect(PreviewState.invalid(EditMessages.status(for: GraphChecker.check(fixtures[0].graph),
                                                         in: fixtures[0].graph)) == .invalid("Output not connected"))
        #expect(presenter.pipeline.runCount == 0, "no pass of an invalid graph ran")
        #expect(presenter.pipeline.slots.isEmpty, "nothing was allocated")
        #expect(try LabTest.targetBytes(session) == 0)
        #expect(presenter.grid.errorMessage == nil)
    }

    @Test func aDisconnectedOutputSaysSoAndReconnectingRestoresThePicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let presenter = shell.presenter
        #expect(presenter.previewState == .ready)
        #expect(presenter.pipeline.runCount > 0, "the starter graph is drawn")
        LabTest.accept(shell, "edge.disconnect", [2, 0])
        try LabTest.draw(session)
        #expect(presenter.previewState == .invalid("Output not connected"))
        let runs = presenter.pipeline.runCount
        try LabTest.draw(session, frames: 2)
        #expect(presenter.pipeline.runCount == runs, "no pass is drawn from the invalid graph")
        LabTest.accept(shell, "edge.connect", [1, 0, 2, 0])
        try LabTest.draw(session)
        #expect(presenter.previewState == .ready, "the picture returns")
        #expect(presenter.mirror.preview == .ready)
        #expect(presenter.pipeline.runCount > runs)
    }

    @Test func theHiddenPreviewDrawsNoPassAndKeepsTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let presenter = shell.presenter
        let digest = try LabTest.digest(shell)
        let fingerprint = try LabTest.fingerprint(shell)
        let shown = try LabTest.still(session)
        presenter.setPreviewVisible(false)
        #expect(presenter.previewState == .hidden)
        #expect(presenter.mirror.preview == .hidden && !presenter.mirror.previewVisible)
        let runs = presenter.pipeline.runCount
        try LabTest.draw(session, frames: 2)
        let hidden = try LabTest.still(session)
        #expect(presenter.pipeline.runCount == runs, "no preview pass while hidden")
        #expect(LabTest.allDark(hidden), "only the grid is drawn")
        #expect(LabTest.differs(hidden, shown))
        #expect(try LabTest.digest(shell) == digest, "the switch never changes the digest")
        #expect(try LabTest.fingerprint(shell) == fingerprint, "or the graph")
        presenter.setPreviewVisible(true)
        #expect(try LabTest.still(session) == shown, "shown again, the same picture")
        #expect(presenter.pipeline.runCount > runs)
    }

    @Test func aFailingOperatorShowsItsFailureAndTheCanvasKeepsDrawing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let presenter = shell.presenter
        presenter.pipeline.fragmentOverrides["noise"] = """
        precision highp float;
        out vec4 color;
        void main() { color = vec4(undefinedSymbol, 1.0); }
        """
        let host = try #require(session.renderHost)
        host.recreateContext()
        let frames = presenter.drawnFrames
        try LabTest.draw(session, frames: 2)
        guard case .failed(let message) = presenter.previewState else {
            Issue.record("expected failed, got \(presenter.previewState)")
            return
        }
        #expect(!message.isEmpty)
        #expect(presenter.mirror.preview.message?.isEmpty == false, "the inset shows the failure")
        #expect(presenter.drawnFrames == frames + 2, "the canvas keeps drawing")
        #expect(presenter.grid.errorMessage == nil)
        let still = try LabTest.still(session)
        #expect(LabTest.allDark(still), "no pass of the graph is drawn, the grid is")
        LabTest.accept(shell, "node.select", [1])
        #expect(try LabTest.core(shell).selection == NodeID(1), "the canvas keeps working")
    }
}
