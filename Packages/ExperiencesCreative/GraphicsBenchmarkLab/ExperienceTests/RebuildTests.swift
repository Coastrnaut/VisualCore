// RebuildTests — feature 174 (A24-P02) T-A24-209, first half (SC-A24-204; FR-A24-202; clarification Q1). For each
// built-in case and the half-scale quads case: ten `RenderHost.recreateContext()` calls, each followed by the same
// workload frame drawn off screen, and a resize there and back (a still at another size, then at the first size
// again) give a byte-identical picture, with the workload set up again on every new context and `leaked` 0 in the
// host's resource ledger throughout. (The run-interrupted half of T-A24-209 is in RecorderTests.)
import Foundation
import Testing
import VisualCoreRendering
import GraphicsBenchmarkLabCore
@testable import GraphicsBenchmarkLabExperience

@MainActor
@Suite(.serialized) struct RebuildTests {
    /// The context recreations per case: 10.
    static let recreations = 10
    /// The workload frame compared: 30.
    static let frame = 30

    /// The ids of the cases rebuilt: the built-in cases and the half-scale quads case.
    nonisolated static let caseIDs = BenchmarkCase.builtIn.map(\.id) + ["quads-half"]

    /// The case with `id` among the built-in cases and ``WorkloadHarness/halfScaleQuads``.
    static func benchmarkCase(_ id: String) -> BenchmarkCase {
        id == "quads-half" ? WorkloadHarness.halfScaleQuads : WorkloadHarness.builtIn(id)
    }

    @Test(arguments: caseIDs)
    func tenRecreationsGiveTheSamePictureWithNothingLeaked(_ id: String) throws {
        let scene = WorkloadHarnessScene(Self.benchmarkCase(id))
        let host = try WorkloadHarness.makeHost(scene)
        defer { host.destroy() }
        let setupError = scene.setupError
        #expect(setupError == nil, "\(id): \(String(describing: setupError))")
        let reference = try WorkloadHarness.still(host, scene, frame: Self.frame)
        let spread = WorkloadHarness.lumaSpread(reference)
        #expect(spread >= 16, "\(id): the reference is drawn (luma spread \(spread))")
        let firstGeneration = host.generation

        for round in 1...Self.recreations {
            host.recreateContext()
            let picture = try WorkloadHarness.still(host, scene, frame: Self.frame)
            let differing = WorkloadHarness.differingBytes(reference, picture)
            let leaked = WorkloadHarnessLevel(host.resources).leaked
            #expect(differing == 0, "\(id): after recreation \(round), \(differing) bytes differ")
            #expect(leaked == 0, "\(id): after recreation \(round), leaked \(leaked)")
        }
        let generations = host.generation - firstGeneration
        let setups = scene.setupCount
        let teardowns = scene.teardownCount
        #expect(generations >= Self.recreations, "\(id): \(generations) new context generations")
        #expect(setups == Self.recreations + 1, "\(id): set up \(setups) times")
        #expect(teardowns == Self.recreations, "\(id): torn down \(teardowns) times")
    }

    @Test(arguments: caseIDs)
    func aResizeThereAndBackGivesTheSamePicture(_ id: String) throws {
        let scene = WorkloadHarnessScene(Self.benchmarkCase(id))
        let host = try WorkloadHarness.makeHost(scene)
        defer { host.destroy() }
        let reference = try WorkloadHarness.still(host, scene, frame: Self.frame)
        let other = try WorkloadHarness.still(host, scene, frame: Self.frame, width: 72, height: 120)
        let back = try WorkloadHarness.still(host, scene, frame: Self.frame)
        let otherBytes = other.count
        let differing = WorkloadHarness.differingBytes(reference, back)
        let level = WorkloadHarnessLevel(host.resources)
        #expect(otherBytes == 72 * 120 * 4, "\(id): the other size is drawn")
        #expect(differing == 0, "\(id): there and back, \(differing) bytes differ")
        #expect(level.leaked == 0, "\(id): leaked \(level.leaked)")
    }
}
