// LissajousLabyrinthRegressionMemoryTests — feature 318 (R02-G02-08) T-R02G0208-005 (FR-R02G0208-005;
// SC-R02G0208-004). Clarification Q4, User Story 3. Through the one app's session host, 12 cycles of: open (seed 0,
// level 1), draw 3 frames at tier 0, send a memory warning, draw 1 frame, close. The scene's own GPU objects
// (`LissajousLabyrinthThreadScene.liveObjectCount`, its renderers) exist after drawing, are 0 after each memory warning
// (the presenter's `shedCaches`) and after each close (its `teardown`), and the next frame rebuilds them. The process
// footprint (`ProcessMemory.footprint()`) is read after each cycle; an unavailable reading fails with a named reason,
// and, when the class runs in a process of its own, every reading of cycles 2 … 12 stays within 16 MB of cycle 1's;
// otherwise the readings are printed. A small view and the default 48 × 32 frames keep the run short. Modelled on
// `AuroraLoomRegressionMemoryTests` (feature 308). Synthetic data, explicit types, plain loops, no sleep, no wall-clock
// assertion.
#if os(iOS)
import Foundation
import Testing
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct LissajousLabyrinthRegressionMemoryTests {
    /// The number of open-draw-warn-close cycles.
    static let cycles = 12
    /// The footprint bound of clarification Q4: 16 MB.
    static let bound = 16 * 1_048_576
    /// Whether the footprint bound applies: only when this class runs in a process of its own (the regression command
    /// sets `TEST_RUNNER_LISSAJOUS_LABYRINTH_MEMORY_ISOLATED=1`; xcodebuild passes it without the prefix); the
    /// footprint is process-wide, so other suites running in parallel move it (feature 309). The release checks always
    /// apply.
    static var isolated: Bool { ProcessInfo.processInfo.environment["LISSAJOUS_LABYRINTH_MEMORY_ISOLATED"] == "1" }

    /// The readings in MB with two decimals, for the issue messages.
    static func describe(_ readings: [Int]) -> String {
        var parts: [String] = []
        for (index, bytes) in readings.enumerated() {
            parts.append(String(format: "cycle %ld: %.2f MB", index + 1, Double(bytes) / 1_048_576))
        }
        return parts.joined(separator: ", ")
    }

    @Test func twelveCyclesReleaseTheSceneAndKeepTheFootprintBounded() async throws {
        var readings: [Int] = []
        for cycle in 1...Self.cycles {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await LissajousLabyrinthTest.open(session, seed: 0)
            let scene: LissajousLabyrinthThreadScene = shell.presenter.scene
            LissajousLabyrinthTest.pin(session, shell, tier: 0)
            try LissajousLabyrinthTest.draw(session, frames: 3)
            #expect(scene.liveObjectCount > 0, "cycle \(cycle): no scene objects after 3 frames")
            session.handleMemoryWarning()
            #expect(scene.liveObjectCount == 0,
                    "cycle \(cycle): \(scene.liveObjectCount) scene objects after the memory warning")
            try LissajousLabyrinthTest.draw(session, frames: 1)
            #expect(scene.liveObjectCount > 0, "cycle \(cycle): the frame after the warning did not rebuild")
            session.close()
            #expect(scene.liveObjectCount == 0, "cycle \(cycle): \(scene.liveObjectCount) scene objects after close")
            guard let footprint: Int = ProcessMemory.footprint() else {
                let message: String = "cycle \(cycle): ProcessMemory.footprint() gave no reading (task_info refused); "
                    + "readings so far: \(Self.describe(readings))"
                Issue.record(Comment(rawValue: message))
                return
            }
            readings.append(footprint)
        }
        print("lissajous-labyrinth memory: \(Self.describe(readings))")
        #expect(readings.count == Self.cycles, "\(readings.count) readings: \(Self.describe(readings))")
        guard let first: Int = readings.first else { return }
        guard Self.isolated else {
            print("lissajous-labyrinth memory: footprint bound not applied "
                  + "(not isolated; run scripts/lissajous_labyrinth_regression.py)")
            return
        }
        for index in 1..<readings.count {
            let drift: Int = readings[index] - first
            let message: String = "cycle \(index + 1) is \(drift) bytes from cycle 1 (bound \(Self.bound)): "
                + Self.describe(readings)
            #expect(abs(drift) <= Self.bound, Comment(rawValue: message))
        }
    }
}
#endif
