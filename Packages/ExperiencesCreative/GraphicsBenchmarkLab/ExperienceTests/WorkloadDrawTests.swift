// WorkloadDrawTests — feature 174 (A24-P02) T-A24-206 (SC-A24-201; FR-A24-201, FR-A24-202; clarification Q1). For
// each built-in case, workload frames 0 and 60 drawn off screen (128 × 96) are not blank (their luma spans at least 16
// of 255), differ from each other and are byte-identical on two separate render hosts. A quads case over the texture
// limit is refused before anything is allocated (the host's resource level is unchanged), and a texture size above
// the case cap is refused as an invalid case. At most two frames per host; no clock.
import Foundation
import Testing
import VisualCoreRendering
import GraphicsBenchmarkLabCore
@testable import GraphicsBenchmarkLabExperience

@MainActor
@Suite(.serialized) struct WorkloadDrawTests {
    /// The least luma spread of a picture that is not blank: 16 of 255.
    static let minimumSpread = 16

    @Test(arguments: BenchmarkCase.builtIn.map(\.id))
    func framesZeroAndSixtyAreDrawnDifferAndRepeatOnAnotherHost(_ id: String) throws {
        let benchmarkCase = WorkloadHarness.builtIn(id)
        let first = try WorkloadHarness.stills(benchmarkCase, frames: [0, 60])
        let second = try WorkloadHarness.stills(benchmarkCase, frames: [0, 60])
        try #require(first.count == 2 && second.count == 2)
        let expectedBytes = WorkloadHarness.width * WorkloadHarness.height * 4
        let zero = first[0], sixty = first[1]
        #expect(zero.count == expectedBytes, "\(id): frame 0 has \(zero.count) bytes")
        #expect(sixty.count == expectedBytes, "\(id): frame 60 has \(sixty.count) bytes")

        let spreadZero = WorkloadHarness.lumaSpread(zero)
        let spreadSixty = WorkloadHarness.lumaSpread(sixty)
        #expect(spreadZero >= Self.minimumSpread, "\(id): frame 0 luma spread \(spreadZero)")
        #expect(spreadSixty >= Self.minimumSpread, "\(id): frame 60 luma spread \(spreadSixty)")

        let changed = WorkloadHarness.differingBytes(zero, sixty)
        #expect(changed > 0, "\(id): frames 0 and 60 differ")

        let otherZero = WorkloadHarness.differingBytes(zero, second[0])
        let otherSixty = WorkloadHarness.differingBytes(sixty, second[1])
        #expect(otherZero == 0, "\(id): frame 0 on another host differs in \(otherZero) bytes")
        #expect(otherSixty == 0, "\(id): frame 60 on another host differs in \(otherSixty) bytes")
    }

    @Test func aQuadsCaseOverTheTextureLimitAllocatesNothing() throws {
        // The built-in quads texture is 256 texels; a limit of 128 stands in for a device whose
        // `maxTextureSize` is below the case (the registry's own limit is the host's, at least 4,096 here).
        let benchmarkCase = BenchmarkCase.quads
        let size = try #require(benchmarkCase.config.textureSize)
        let scene = WorkloadHarnessScene(benchmarkCase, textureLimit: size / 2)
        let host = try WorkloadHarness.makeHost(scene)
        defer { host.destroy() }
        let error = scene.setupError
        let before = try #require(scene.levelBeforeSetup)
        let after = try #require(scene.levelAfterSetup)
        let workloadMade = scene.workload != nil
        #expect(error == .overLimit(field: "textureSize", limit: size / 2), "refusal: \(String(describing: error))")
        #expect(!workloadMade, "no workload is built")
        #expect(after == before, "after the refusal: \(after) (before: \(before))")
        let leaked = WorkloadHarnessLevel(host.resources).leaked
        #expect(leaked == 0)
    }

    @Test func aTextureAboveTheCaseCapIsAnInvalidCaseAndAllocatesNothing() throws {
        var benchmarkCase = BenchmarkCase.quads
        benchmarkCase.id = "quads-huge"
        benchmarkCase.config.textureSize = 2_048
        let scene = WorkloadHarnessScene(benchmarkCase)
        let host = try WorkloadHarness.makeHost(scene)
        defer { host.destroy() }
        let error = scene.setupError
        let before = try #require(scene.levelBeforeSetup)
        let after = try #require(scene.levelAfterSetup)
        let expected = WorkloadError.invalidCase(String(describing: CaseError.outOfRange(field: "textureSize")))
        #expect(error == expected, "refusal: \(String(describing: error))")
        #expect(after == before, "after the refusal: \(after) (before: \(before))")
    }

    @Test func theHalfScaleCaseIsDrawnThroughTheScaledTarget() throws {
        let benchmarkCase = WorkloadHarness.halfScaleQuads
        let stills = try WorkloadHarness.stills(benchmarkCase, frames: [0, 60])
        try #require(stills.count == 2)
        let spread = WorkloadHarness.lumaSpread(stills[0])
        let changed = WorkloadHarness.differingBytes(stills[0], stills[1])
        #expect(spread >= Self.minimumSpread, "half scale: luma spread \(spread)")
        #expect(changed > 0, "half scale: frames 0 and 60 differ")
    }
}
