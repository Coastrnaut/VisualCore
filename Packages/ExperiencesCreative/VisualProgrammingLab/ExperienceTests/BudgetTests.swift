// BudgetTests — feature 168 (A23-P03) T-A23-306 (FR-A23-304; SC-A23-303, SC-A23-306; clarification Q2; User Story 3).
// Through the one app's session host: a graph at the limit of 6 slots compiles, the presenter holds exactly its 6
// render targets of 256 × 256 rgba8 and the bytes the schedule counts equal the render-target bytes the registry
// reports (`liveBytes[.framebuffer]`); a graph needing 7 is refused with "This graph needs 7 textures; the preview
// allows 6." before any allocation, with the registry's counts unchanged; a chain of 5 passes uses at most 2 slots.
// Short runs only.
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct BudgetTests {
    @Test func aGraphAtTheLimitCompilesAndItsBytesAreTheHostsBytes() async throws {
        let graph = GraphBuild.fan(5)
        guard case .success(let schedule) = GraphCompiler.compile(graph) else {
            Issue.record("the fan of 5 compiles")
            return
        }
        #expect(schedule.slotCount == PassSchedule.slotLimit)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session, graph: graph)
        let pipeline = shell.presenter.pipeline
        #expect(pipeline.state == .ready)
        #expect(pipeline.slots.count == 6)
        #expect(pipeline.slots.allSatisfy { $0.width == 256 && $0.height == 256 && $0.format == .rgba8 })
        #expect(schedule.bytes == 6 * 256 * 256 * 4)
        #expect(try LabTest.targetBytes(session) == schedule.bytes, "counted bytes equal the host's")
        _ = try LabTest.still(session)
        #expect(try LabTest.targetBytes(session) == schedule.bytes, "the still's own target is released again")
        #expect(session.renderHost?.resources.stats.leaked == 0)
    }

    @Test func aGraphOnePastTheLimitIsRefusedBeforeAnyAllocation() async throws {
        let graph = GraphBuild.fan(6)
        #expect(GraphCompiler.compile(graph) == .failure(.overBudget(slots: 7)))
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        let presenter = shell.presenter
        #expect(presenter.previewState == .ready)
        let host = try #require(session.renderHost)
        let before = host.resources.stats
        let runs = presenter.pipeline.runCount
        presenter.graphOverride = graph
        try LabTest.draw(session)
        #expect(presenter.previewState == .refused("This graph needs 7 textures; the preview allows 6."))
        #expect(presenter.mirror.preview.message == "This graph needs 7 textures; the preview allows 6.")
        let after = host.resources.stats
        #expect(after.liveCount == before.liveCount, "no object was made or released")
        #expect(after.liveBytes == before.liveBytes, "no byte was charged")
        #expect(presenter.pipeline.runCount == runs, "no pass is drawn from the refused graph")
    }

    @Test func aChainOfFivePassesUsesAtMostTwoSlots() async throws {
        var build = GraphBuild()
        let noise = build.add(.noise)
        let soft = build.add(.blur, ["radius": 2])
        let softer = build.add(.blur, ["radius": 3])
        let output = build.add(.output)
        build.wire(noise, to: soft)
        build.wire(soft, to: softer)
        build.wire(softer, to: output)
        guard case .success(let schedule) = GraphCompiler.compile(build.graph) else {
            Issue.record("the chain compiles")
            return
        }
        #expect(schedule.passes.filter { $0.operator != .output }.count == 5)
        #expect(schedule.slotCount <= 2)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session, graph: build.graph)
        #expect(shell.presenter.previewState == .ready)
        #expect(shell.presenter.pipeline.slots.count == schedule.slotCount)
        #expect(try LabTest.targetBytes(session) == schedule.bytes)
    }
}
