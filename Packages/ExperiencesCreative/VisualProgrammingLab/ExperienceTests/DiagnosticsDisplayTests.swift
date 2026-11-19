// DiagnosticsDisplayTests — feature 169 (A23-P04) T-A23-408 (FR-A23-405; SC-A23-405; clarification Q5). Through the
// one app's session host: after each edit the presenter's mirror holds exactly the marks `GraphDiagnostics.byNode`
// gives for the core's graph, which the overlay (dashed outline, "!" badge, `node-diagnostic-<id>`) and the list form
// (`node-diagnostic-row-<id>`) draw. The starter graph marks nothing; removing the Output's source marks the Output;
// a Mix with one image input empty marks the Mix with "Input b is empty."; reconnecting clears the mark. Short runs
// only.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct DiagnosticsDisplayTests {
    /// The mirror's marks after the next frame.
    static func marks(_ session: ExperienceSession, _ shell: ExperienceShell<LabPresenter>) throws -> [NodeID: [String]] {
        try LabTest.draw(session)
        return shell.presenter.mirror.diagnostics
    }

    @Test func theMirrorHoldsTheCheckersMarksAfterEachEdit() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.open(session)
        #expect(try Self.marks(session, shell).isEmpty, "the starter graph is valid")

        LabTest.accept(shell, "edge.disconnect", [2, 0])
        let disconnected = try Self.marks(session, shell)
        #expect(disconnected == [NodeID(2): [GraphDiagnostics.outputDisconnected]])

        LabTest.accept(shell, "node.add", [4, 320, 240])   // Mix 3
        LabTest.accept(shell, "edge.connect", [1, 0, 3, 0])
        LabTest.accept(shell, "edge.connect", [3, 0, 2, 0])
        let mixMissingB = try Self.marks(session, shell)
        #expect(mixMissingB == [NodeID(3): [GraphDiagnostics.emptyInput("b")]])

        LabTest.accept(shell, "edge.connect", [1, 0, 3, 1])
        #expect(try Self.marks(session, shell).isEmpty, "reconnecting clears the mark")
        let core = try LabTest.core(shell)
        #expect(shell.presenter.mirror.diagnostics == GraphDiagnostics.byNode(core.check, in: core.graph))
    }
}
