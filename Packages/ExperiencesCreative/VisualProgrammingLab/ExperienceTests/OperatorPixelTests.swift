// OperatorPixelTests — feature 168 (A23-P03) T-A23-305 (FR-A23-301, FR-A23-302; SC-A23-301, SC-A23-306; clarification
// Q4; research D6). Through the one app's session host, each operator drawn off screen at a fixed frame time and read
// back from the bottom-left inset, with references taken at each read pixel's centre in the inset's 0…1 coordinates:
// Gradient (with a Constant start colour), Mix at amounts 0, 0.5 and 1, and a flat colour (one Constant into both
// Gradient ends) within 2 of 255; Noise the same twice and different with another scale; Blur of a linear ramp equal
// to the ramp farther than its radius from the edges within 2 of 255; Output a copy of its input slot within 2 of
// 255. Short runs only (no sleep, no wall-clock assertion).
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct OperatorPixelTests {
    /// The side of the stills: 192 pixels, so the inset is 64 × 64.
    static let side = 192

    /// The still of `graph` at `time`, drawn in a session of its own, with the preview's state.
    static func picture(_ graph: VisualGraph, time: Double = 0,
                        side: Int = side) async throws -> (still: [UInt8], state: PreviewState) {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session, graph: graph)
        let still = try LabTest.still(session, width: side, height: side, time: time)
        return (still, shell.presenter.previewState)
    }

    /// The gradient's reference at (`u`, `v`): `mix(start, end, clamp(dot(uv − 0.5, (cos a, sin a)) + 0.5, 0, 1))`.
    nonisolated static func gradient(_ u: Double, _ v: Double, degrees: Double, start: SIMD3<Double>,
                         end: SIMD3<Double>) -> SIMD3<Double> {
        let a = degrees * .pi / 180
        let t = min(max((u - 0.5) * cos(a) + (v - 0.5) * sin(a) + 0.5, 0), 1)
        return start + (end - start) * t
    }

    @Test func gradientMatchesItsReference() async throws {
        var build = GraphBuild()
        let colour = build.add(.constant, ["red": 1, "green": 0.2, "blue": 0])
        let ramp = build.add(.gradient, ["angle": 30])
        let output = build.add(.output)
        build.wire(colour, "colour", to: ramp, "start")
        build.wire(ramp, to: output)
        let (still, state) = try await Self.picture(build.graph)
        #expect(state == .ready)
        let error = LabTest.insetError(still, width: Self.side, height: Self.side) { u, v in
            Self.gradient(u, v, degrees: 30, start: SIMD3(1, 0.2, 0), end: SIMD3(1, 1, 1))
        }
        #expect(error <= 2, "gradient within 2 of 255 (worst \(error))")
    }

    @Test(arguments: [0.0, 0.5, 1.0]) func mixMatchesItsReference(amount: Double) async throws {
        var build = GraphBuild()
        let across = build.add(.gradient, ["angle": 0])
        let up = build.add(.gradient, ["angle": 90])
        let mix = build.add(.mix, ["amount": amount])
        let output = build.add(.output)
        build.wire(across, to: mix, "a")
        build.wire(up, to: mix, "b")
        build.wire(mix, to: output)
        let (still, state) = try await Self.picture(build.graph)
        #expect(state == .ready)
        let error = LabTest.insetError(still, width: Self.side, height: Self.side) { u, v in
            let grey = u + (v - u) * amount
            return SIMD3(grey, grey, grey)
        }
        #expect(error <= 2, "mix \(amount) within 2 of 255 (worst \(error))")
    }

    @Test func aConstantIntoBothEndsIsAFlatColour() async throws {
        var build = GraphBuild()
        let colour = build.add(.constant, ["red": 0.2, "green": 0.6, "blue": 0.9])
        let ramp = build.add(.gradient, ["angle": 45])
        let output = build.add(.output)
        build.wire(colour, "colour", to: ramp, "start")
        build.wire(colour, "colour", to: ramp, "end")
        build.wire(ramp, to: output)
        let (still, state) = try await Self.picture(build.graph)
        #expect(state == .ready)
        let error = LabTest.insetError(still, width: Self.side, height: Self.side) { _, _ in SIMD3(0.2, 0.6, 0.9) }
        #expect(error <= 2, "flat colour within 2 of 255 (worst \(error))")
    }

    @Test func noiseIsDeterministicAndDependsOnItsScale() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session, graph: GraphBuild.single(.noise, ["scale": 4]))
        #expect(shell.presenter.previewState == .ready)
        let first = LabTest.inset(try LabTest.still(session, width: Self.side, height: Self.side), width: Self.side,
                                  height: Self.side)
        let second = LabTest.inset(try LabTest.still(session, width: Self.side, height: Self.side), width: Self.side,
                                   height: Self.side)
        #expect(first == second, "the same noise at the same time")
        #expect(Set(first).count > 8, "the noise is not flat")
        shell.presenter.graphOverride = GraphBuild.single(.noise, ["scale": 8])
        let scaled = LabTest.inset(try LabTest.still(session, width: Self.side, height: Self.side), width: Self.side,
                                   height: Self.side)
        #expect(shell.presenter.previewState == .ready)
        #expect(scaled != first, "another scale gives another noise")
    }

    @Test func blurOfARampEqualsTheRampAwayFromTheEdges() async throws {
        let radius = 4.0
        var build = GraphBuild()
        let ramp = build.add(.gradient, ["angle": 0])
        let blur = build.add(.blur, ["radius": radius])
        let output = build.add(.output)
        build.wire(ramp, to: blur)
        build.wire(blur, to: output)
        let (still, state) = try await Self.picture(build.graph)
        #expect(state == .ready)
        let margin = (radius + 2) / Double(PreviewPipeline.slotSide)
        let error = LabTest.insetError(still, width: Self.side, height: Self.side,
                                       include: { u, _ in u > margin && u < 1 - margin }) { u, _ in
            SIMD3(u, u, u)
        }
        #expect(error <= 2, "blurred ramp within 2 of 255 away from the edges (worst \(error))")
    }

    @Test func outputCopiesItsInput() async throws {
        // A 768-pixel still makes the inset 256 × 256, the slot's size, so each inset pixel samples one texel centre.
        let side = 3 * PreviewPipeline.slotSide
        var build = GraphBuild()
        let colour = build.add(.constant, ["red": 0.1, "green": 0.8, "blue": 0.4])
        let ramp = build.add(.gradient, ["angle": 120])
        let output = build.add(.output)
        build.wire(colour, "colour", to: ramp, "end")
        build.wire(ramp, to: output)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session, graph: build.graph)
        let still = try LabTest.still(session, width: side, height: side)
        let pipeline = shell.presenter.pipeline
        #expect(pipeline.state == .ready)
        let last = try #require(pipeline.schedule?.passes.last)
        #expect(last.operator == .output)
        let slot = try #require(last.inputs["u_image"])
        let source = pipeline.slots[slot].readPixels()
        let inset = LabTest.inset(still, width: side, height: side)
        #expect(source.count == inset.count)
        var worst = 0
        for i in 0..<min(source.count, inset.count) where i % 4 != 3 {
            worst = max(worst, abs(Int(source[i]) - Int(inset[i])))
        }
        #expect(worst <= 2, "the output copies its input within 2 of 255 (worst \(worst))")
    }
}
