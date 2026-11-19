// PassCountTests — feature 170 (A23-P05) T-A23-503 (FR-A23-502; SC-A23-502, SC-A23-506; clarification Q2; User Story
// 2; research D2; the manual's regression fixture "a simple graph gives expected pixels and avoids unnecessary
// passes"). Through the one app's session host, the passes run in one frame are counted by the pipeline's `runCount`
// (real `FieldPass.run` calls, so the schedule drawn, not only the schedule computed): Gradient (angle 30) into Output
// runs exactly 2 (gradient, output) and its inset matches the gradient reference (black to white, OperatorPixelTests)
// within 2 of 255; the same graph with an unconnected Noise and a Constant feeding nothing still runs 2 and draws the
// same pixels; the journey graph (`mixed-clouds`) runs 6 (noise, gradient, mix, blur-h, blur-v, output). Short runs
// only (no sleep, no wall-clock assertion).
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct PassCountTests {
    /// The side of the stills: 192 pixels, so the inset is 64 × 64.
    static let side = 192

    /// The gradient's angle, degrees.
    static let angle = 30.0

    /// Gradient (angle 30) into Output.
    static var ramp: VisualGraph {
        var build = GraphBuild()
        let ramp = build.add(.gradient, ["angle": angle])
        let output = build.add(.output)
        build.wire(ramp, to: output)
        return build.graph
    }

    /// ``ramp`` with an unconnected Noise and a Constant feeding nothing.
    static var rampWithUnusedNodes: VisualGraph {
        var build = GraphBuild()
        let ramp = build.add(.gradient, ["angle": angle])
        let output = build.add(.output)
        build.wire(ramp, to: output)
        build.add(.noise, ["scale": 9])
        build.add(.constant, ["red": 0.3, "green": 0.7, "blue": 0.1])
        return build.graph
    }

    /// The gradient reference at (`u`, `v`): black (the default start) to white (the default end) at 30 degrees.
    static func reference(_ u: Double, _ v: Double) -> SIMD3<Double> {
        OperatorPixelTests.gradient(u, v, degrees: angle, start: SIMD3(0, 0, 0), end: SIMD3(1, 1, 1))
    }

    /// Opens `graph` with the preview shown and returns the passes run by one more frame, the operators of the
    /// schedule, the preview's state and the inset of a still at frame time 0.
    static func measure(_ graph: VisualGraph) async throws
        -> (passes: Int, operators: [PassOperator], state: PreviewState, still: [UInt8]) {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session, graph: graph)
        let pipeline = shell.presenter.pipeline
        let before = pipeline.runCount
        try LabTest.draw(session)
        let passes = pipeline.runCount - before
        let operators = pipeline.schedule?.passes.map { $0.operator } ?? []
        let state = shell.presenter.previewState
        let still = try LabTest.still(session, width: side, height: side)
        let leaked = try #require(session.renderHost).resources.stats.leaked
        #expect(leaked == 0)
        return (passes, operators, state, still)
    }

    @Test func gradientIntoOutputRunsTwoPassesAndMatchesItsReference() async throws {
        let measured = try await Self.measure(Self.ramp)
        #expect(measured.state == .ready)
        #expect(measured.passes == 2, "one frame runs the gradient and the output (ran \(measured.passes))")
        #expect(measured.operators == [.gradient, .output])
        let error = LabTest.insetError(measured.still, width: Self.side, height: Self.side) { u, v in
            Self.reference(u, v)
        }
        #expect(error <= 2, "gradient within 2 of 255 (worst \(error))")
    }

    @Test func unusedNodesAddNoPassAndChangeNoPixel() async throws {
        let plain = try await Self.measure(Self.ramp)
        let unused = try await Self.measure(Self.rampWithUnusedNodes)
        #expect(unused.state == .ready, "a Noise and a Constant feeding nothing leave the graph valid")
        #expect(unused.passes == 2, "the unused nodes run no pass (ran \(unused.passes))")
        #expect(unused.operators == [.gradient, .output])
        let error = LabTest.insetError(unused.still, width: Self.side, height: Self.side) { u, v in
            Self.reference(u, v)
        }
        #expect(error <= 2, "the same gradient within 2 of 255 (worst \(error))")
        let plainInset = LabTest.inset(plain.still, width: Self.side, height: Self.side)
        let unusedInset = LabTest.inset(unused.still, width: Self.side, height: Self.side)
        #expect(unusedInset == plainInset, "the same pixels as without the unused nodes")
    }

    @Test func theJourneyGraphRunsSixPasses() async throws {
        let measured = try await Self.measure(LabLibraryTest.journey)
        #expect(measured.state == .ready)
        #expect(measured.passes == 6, "one frame of the journey runs 6 passes (ran \(measured.passes))")
        #expect(measured.operators == [.noise, .gradient, .mix, .blurH, .blurV, .output])
    }
}
