// ProbeTests — feature 167 (A23-P02) T-A23-213 (FR-A23-206, FR-A23-207). The opening frame as the verification
// runner reads it: a 96 x 96-point surface, the presenter's default view (no touch has reported the canvas size), read
// back with `RenderHost.readPixels` and classified by `FrameChecks`. It is not blank (a first run of the runner found a
// flat frame when the grid's lines fell between pixel centres; the lines are now at least a pixel wide and a vignette
// adds a luma spread), and the probe `canvas-dark` sees the class dark. Short runs only.
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct ProbeTests {
    @Test func theOpeningFrameIsNotBlankAndDarkWhereItsProbeLooks() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.open(session, size: CGSize(width: 96, height: 96), keepDefaultView: true)
        #expect(shell.presenter.view.size == LabPresenter.defaultSize)
        try LabTest.draw(session, frames: 2)
        let host = try #require(session.renderHost)
        let pixels = host.readPixels()
        let size = host.pixelSize
        #expect(FrameChecks.isNonBlank(pixels, width: size.width, height: size.height), "the opening frame")
        let probe = try #require(shell.frameProbes.first)
        #expect(probe.name == "canvas-dark")
        #expect(FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height) == .dark)
    }
}
