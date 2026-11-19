// PreviewRebuildTests — feature 168 (A23-P03) T-A23-307 (FR-A23-306, FR-A23-307; SC-A23-305, SC-A23-306;
// clarifications Q4, Q5; User Story 5; research D7; Edge Case "Time"). Through the one app's session host: a journey
// graph (Time into Noise, Noise and Gradient into Mix, Blur, Output) draws a byte-identical still after each of 10
// `recreateContext` calls (programs and slots rebuilt from the same schedule, no compile) and after a resize there and
// back (the slots stay 256 × 256), with no GPU object leaked; two stills at the same frame time are equal and at
// another time differ (Noise fed by Time); after a frame with the inset the next frame's grid covers the whole
// drawable again. Short runs only.
import CoreGraphics
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct PreviewRebuildTests {
    /// The side of the stills: 192 pixels (a 64-pixel inset).
    static let side = 192

    /// Time into Noise, Noise and Gradient into Mix, Mix into Blur, Blur into Output.
    static var journey: VisualGraph {
        var build = GraphBuild()
        let time = build.add(.time, ["rate": 1])
        let noise = build.add(.noise, ["scale": 6, "speed": 0.5])
        let ramp = build.add(.gradient, ["angle": 60])
        let mix = build.add(.mix, ["amount": 0.4])
        let blur = build.add(.blur, ["radius": 3])
        let output = build.add(.output)
        build.wire(time, "time", to: noise, "time")
        build.wire(noise, to: mix, "a")
        build.wire(ramp, to: mix, "b")
        build.wire(mix, to: blur)
        build.wire(blur, to: output)
        return build.graph
    }

    @Test func thePreviewIsTheSameAfterContextLossesAndAResize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session, graph: Self.journey)
        let presenter = shell.presenter
        #expect(presenter.previewState == .ready)
        let compiles = presenter.pipeline.compileCount
        let slotCount = presenter.pipeline.slots.count
        let before = try LabTest.still(session, width: Self.side, height: Self.side, time: 1.25)
        let host = try #require(session.renderHost)
        for round in 1...10 {
            host.recreateContext()
            try LabTest.draw(session)
            #expect(presenter.previewState == .ready)
            #expect(try LabTest.still(session, width: Self.side, height: Self.side, time: 1.25) == before,
                    "the same preview after context loss \(round)")
        }
        #expect(presenter.pipeline.compileCount == compiles, "a rebuild restores the schedule without a compile")
        #expect(presenter.pipeline.slots.count == slotCount)

        let canvas = try #require(session.renderHost?.view)
        canvas.frame = CGRect(x: 0, y: 0, width: 144, height: 120)
        canvas.layoutIfNeeded()
        try LabTest.draw(session, frames: 2)
        #expect(presenter.pipeline.slots.allSatisfy { $0.width == 256 && $0.height == 256 }, "slots stay 256 × 256")
        canvas.frame = CGRect(x: 0, y: 0, width: 96, height: 96)
        canvas.layoutIfNeeded()
        try LabTest.draw(session)
        #expect(try LabTest.still(session, width: Self.side, height: Self.side, time: 1.25) == before,
                "the same preview after the resize")
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func stillsAtTheSameTimeAreEqualAndAtAnotherTimeDiffer() async throws {
        var build = GraphBuild()
        let time = build.add(.time, ["rate": 1])
        let noise = build.add(.noise, ["speed": 2])
        let output = build.add(.output)
        build.wire(time, "time", to: noise, "time")
        build.wire(noise, to: output)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session, graph: build.graph)
        #expect(shell.presenter.previewState == .ready)
        let first = LabTest.inset(try LabTest.still(session, width: Self.side, height: Self.side, time: 2),
                                  width: Self.side, height: Self.side)
        let again = LabTest.inset(try LabTest.still(session, width: Self.side, height: Self.side, time: 2),
                                  width: Self.side, height: Self.side)
        let later = LabTest.inset(try LabTest.still(session, width: Self.side, height: Self.side, time: 3),
                                  width: Self.side, height: Self.side)
        #expect(first == again, "the same frame time gives the same picture")
        #expect(first != later, "another frame time moves the noise")
    }

    @Test func afterAnInsetFrameTheNextGridCoversTheWholeDrawable() async throws {
        // The reference: the same view drawn with the preview hidden from the start.
        let reference: [UInt8]
        do {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await LabTest.open(session, size: CGSize(width: 96, height: 96), preview: false)
            shell.presenter.view = shell.presenter.view.panned(by: Vec2(11, 6))
            try LabTest.draw(session)
            reference = try #require(session.renderHost).readPixels()
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LabTest.openPreview(session)
        #expect(shell.presenter.previewState == .ready)
        try LabTest.draw(session)
        let runs = shell.presenter.pipeline.runCount
        #expect(runs > 0, "a frame with the inset was drawn")
        shell.presenter.view = shell.presenter.view.panned(by: Vec2(11, 6))
        shell.presenter.setPreviewVisible(false)
        try LabTest.draw(session)
        let pixels = try #require(session.renderHost).readPixels()
        #expect(!pixels.isEmpty)
        #expect(pixels == reference, "the grid of the next frame covers the whole drawable")
        #expect(LabTest.allDark(pixels))
    }
}
