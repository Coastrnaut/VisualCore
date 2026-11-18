// ProbeTests — feature 160 (A22-P02) T-A22-212 (FR-A22-207). The frame probe the verification runner samples at
// launch: the presenter declares `warm-corner` (red, at x 0.95 and y 0.05 from the top) for the opening template only,
// and a drawn frame of Gradient is red there, read back the way the runner reads it (`RenderHost.readPixels`, rows
// bottom-up, classified by `FrameChecks`). Short runs only.
import CoreGraphics
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct ProbeTests {
    @Test func theOpeningTemplateIsRedWhereItsProbeLooks() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let core = try StudioTest.core(shell)
        let probes = shell.presenter.probes(core)
        let probe = try #require(probes.first)
        #expect(probes.count == 1 && probe.name == "warm-corner" && probe.expected == FrameColorClass.red.rawValue)
        try StudioTest.draw(session, frames: 2)
        let host = try #require(session.renderHost)
        let observed = FrameChecks.probe(probe, rgba: host.readPixels(), width: host.pixelSize.width,
                                         height: host.pixelSize.height)
        #expect(observed == .red)
    }

    @Test func otherTemplatesDeclareNoProbe() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        StudioTest.accept(shell, "template.select", [1])
        #expect(shell.presenter.probes(try StudioTest.core(shell)).isEmpty)
    }
}
