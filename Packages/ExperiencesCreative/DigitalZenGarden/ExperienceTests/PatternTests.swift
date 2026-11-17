// PatternTests — feature 146 (A20-P02) T-A20-205 (FR-A20-201, FR-A20-205; clarification Q3; contracts/experience.md
// "Patterns"). The four native "rake a pattern" strokes: each lies inside the tray and below the stroke's point cap,
// is sent as `stroke.begin`, `stroke.add` batches of twelve points (the last padded with its last point) and
// `stroke.end`, and commits exactly one stroke with the chosen rake and no gap larger than the spacing. Short runs.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience
import VisualCoreMath

@MainActor
@Suite struct PatternTests {
    @Test func everyPatternLiesInsideTheTrayBelowThePointCap() throws {
        #expect(StrokePatterns.names == ["rows", "circle", "wave", "spiral"])
        for index in StrokePatterns.names.indices {
            let points = StrokePatterns.points(index: index)
            #expect(points.count > 20, "\(StrokePatterns.names[index])")
            #expect(points.allSatisfy { TrayFit.isInside($0) }, "\(StrokePatterns.names[index])")
            let out = try StrokeResampler.resample(points).get()
            #expect(!out.capped, "\(StrokePatterns.names[index]) fits in one stroke")
        }
    }

    @Test func theAddBatchesCarryTwelvePointsPaddedWithTheLast() {
        let points = (0..<14).map { Vec2(Double($0) / 20, 0.5) }
        let batches = StrokePatterns.addValues(points)
        #expect(batches.count == 2)
        #expect(batches.allSatisfy { $0.count == GardenCore.pointsPerAdd * 2 })
        #expect(batches[0][0] == 0 && batches[0][22] == 11.0 / 20)
        #expect(batches[1][0] == 12.0 / 20 && batches[1][2] == 13.0 / 20)
        var index = 4
        while index < 24 {
            #expect(batches[1][index] == 13.0 / 20 && batches[1][index + 1] == 0.5, "pair \(index / 2) repeats")
            index += 2
        }
        #expect(StrokePatterns.addValues([]).isEmpty)
    }

    @Test func eachPatternCommitsOneStrokeThroughTheStrokeActions() async throws {
        for index in StrokePatterns.names.indices {
            let name = StrokePatterns.names[index]
            for rake in 0..<2 {
                let shell = try await GardenTest.shell()
                let results = StrokePatterns.send(StrokePatterns.points(index: index), rake: rake, port: shell.port)
                #expect(results.allSatisfy { $0 == .accepted }, "\(name) rake \(rake)")
                let core = try GardenTest.core(shell)
                #expect(core.document.strokes.count == 1 && !core.isRaking, "\(name) rake \(rake)")
                let stroke = try #require(core.document.strokes.first)
                #expect(stroke.rake == GardenPalette.rakes[rake].id, "\(name) rake \(rake)")
                #expect(!stroke.capped, "\(name) rake \(rake)")
                #expect(GardenTest.largestGap(stroke.points) <= StrokeResampler.spacing + 1e-9, "\(name)")
            }
        }
    }
}
