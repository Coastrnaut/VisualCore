// HistogramGateTests — feature 120 (A16-P04) T-A16-407 (FR-A16-420; SC-A16-402; clarification Q2). The presenter's
// histogram: over 60 running frames it updates at most 4 times and never on every step; a paint while paused updates
// it at the next frame; its counts plus the non-finite count equal 4,096 in every family.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class HistogramGateTests: XCTestCase {
    func testRunningUpdatesAtMostFourTimesInSixtyFrames() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(presenter.send("sim.family", [1], through: shell.port).isAccepted)
        try SimulationTest.frames(session, 1)
        let start = presenter.histogramUpdateCount
        let steps = try SimulationTest.core(shell).stepCount
        try SimulationTest.frames(session, 60)
        let updates = presenter.histogramUpdateCount - start
        XCTAssertGreaterThan(try SimulationTest.core(shell).stepCount - steps, 60, "many steps ran")
        XCTAssertGreaterThan(updates, 0)
        XCTAssertLessThanOrEqual(updates, 4, "at most once every 15 frames")
        session.close()
    }

    func testAPaintWhilePausedUpdatesAtTheNextFrameAndCountsSum() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        for family in 0..<3 {
            if family > 0 { XCTAssertTrue(presenter.send("sim.family", [Double(family)], through: shell.port).isAccepted) }
            try SimulationTest.pause(shell)
            try SimulationTest.frames(session, 1)
            let histogram = try XCTUnwrap(presenter.mirror.histogram)
            XCTAssertEqual(histogram.total, 4096, "family \(family)")
            let count = presenter.histogramUpdateCount
            XCTAssertTrue(presenter.send("sim.paint", [32, 32, 0], through: shell.port).isAccepted)
            try SimulationTest.frames(session, 1)
            XCTAssertEqual(presenter.histogramUpdateCount, count + 1, "family \(family): the next frame")
            XCTAssertEqual(presenter.mirror.histogram,
                           SimulationHistogram.of(try SimulationTest.core(shell).model.field,
                                                  kind: SimulationKind.allCases[family]))
            XCTAssertTrue(presenter.send("sim.run", through: shell.port).isAccepted)
        }
        session.close()
    }
}
