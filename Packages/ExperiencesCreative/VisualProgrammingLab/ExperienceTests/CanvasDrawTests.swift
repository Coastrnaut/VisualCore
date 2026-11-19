// CanvasDrawTests — feature 167 (A23-P02) T-A23-208 (FR-A23-201, FR-A23-204, FR-A23-206; SC-A23-203; clarification
// Q4). Through the one app's session host: the canvas grid, drawn off screen by VisualCore's full-screen scene inside
// the host's context, compiles without a diagnostic, is dark everywhere (the frame probe `canvas-dark`), and changes
// with pan and with zoom while the graph's digest does not; the same view gives the same picture. Short runs only.
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct CanvasDrawTests {
    @Test func theGridChangesWithPanAndZoomButNotTheGraph() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.open(session)
        let presenter = shell.presenter
        #expect(presenter.grid.errorMessage == nil, "\(presenter.grid.errorMessage ?? "")")
        #expect(presenter.drawnFrames >= 1)
        let digest = try LabTest.digest(shell)
        let start = presenter.view
        let base = try LabTest.still(session)
        #expect(base.count == LabTest.width * LabTest.height * 4)
        #expect(LabTest.allDark(base), "every grid colour is of the class dark")
        #expect(Set(base).count > 2, "the grid lines are drawn")
        #expect(shell.frameProbes.map(\.name) == ["canvas-dark"])

        presenter.view = start.panned(by: Vec2(9, 5))
        let panned = try LabTest.still(session)
        #expect(LabTest.differs(panned, base), "the pan moved the grid")

        presenter.view = start.pinched(by: 2, anchor: Vec2(10, 10))
        let zoomed = try LabTest.still(session)
        #expect(LabTest.differs(zoomed, base), "the zoom scaled the grid")
        #expect(LabTest.differs(zoomed, panned))
        #expect(LabTest.allDark(panned) && LabTest.allDark(zoomed))

        presenter.view = start
        #expect(try LabTest.still(session) == base, "the same view draws the same picture")
        #expect(try LabTest.digest(shell) == digest, "the view never changes the graph")
        #expect(session.renderHost?.resources.stats.leaked == 0)
    }
}

extension LabTest {
    /// Whether `a` and `b` differ in any byte.
    static func differs(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        a.count != b.count || a != b
    }
}
