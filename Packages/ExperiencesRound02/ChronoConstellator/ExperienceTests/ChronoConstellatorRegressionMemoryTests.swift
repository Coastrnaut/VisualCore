// ChronoConstellatorRegressionMemoryTests — feature 358 (R02-G06-08) T-R02G0608-005 (FR-R02G0608-005; SC-R02G0608-004;
// clarification Q4). User Story 3. Through the one app's session host, 12 cycles of: open (seed 0, level 1), draw 3
// frames at tier 0, send a memory warning, draw 1 frame, close. The scene's own GPU objects
// (`ChronoConstellatorSkyScene.liveObjectCount`) exist after drawing, are 0 after each memory warning (the presenter's
// `shedCaches`) and after each close (its `teardown`), and the next frame rebuilds them. The process footprint
// (`ProcessMemory.footprint()`) is read after each cycle; an unavailable reading fails with a named reason, and, when
// the class runs in a process of its own, every reading of cycles 2 … 12 stays within 16 MB of cycle 1's; otherwise
// the readings are printed. A small view and the default 48 × 32 frames keep the run short. Modelled on
// `ColorfallCanyonsRegressionMemoryTests` (feature 348). Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion.
#if os(iOS)
import ChronoConstellatorCore
import Foundation
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct ChronoConstellatorRegressionMemoryTests {
    /// The number of open-draw-warn-close cycles.
    static let cycles = 12
    /// The footprint bound of clarification Q4: 16 MB.
    static let bound = 16 * 1_048_576
    /// Whether the footprint bound applies: only when this class runs in a process of its own (the regression command
    /// sets `TEST_RUNNER_CHRONO_CONSTELLATOR_MEMORY_ISOLATED=1`; xcodebuild passes it without the prefix); the
    /// footprint is process-wide, so other suites running in parallel move it (feature 309). The release checks always
    /// apply.
    static var isolated: Bool {
        let environment: [String: String] = ProcessInfo.processInfo.environment
        return environment["CHRONO_CONSTELLATOR_MEMORY_ISOLATED"] == "1"
            || environment["TEST_RUNNER_CHRONO_CONSTELLATOR_MEMORY_ISOLATED"] == "1"
    }

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
            let shell: ChronoConstellatorTest.Shell = try await ChronoConstellatorTest.open(session, seed: 0)
            let opened: Int = try ChronoConstellatorTest.core(shell).levelNumber
            #expect(opened == 1, "cycle \(cycle): level \(opened) is prepared, not level 1")
            let scene: ChronoConstellatorSkyScene = shell.presenter.scene
            ChronoConstellatorTest.pin(session, shell, tier: 0)
            try ChronoConstellatorTest.draw(session, frames: 3)
            #expect(scene.liveObjectCount > 0, "cycle \(cycle): no scene GPU objects after 3 frames")
            session.handleMemoryWarning()
            #expect(scene.liveObjectCount == 0,
                    "cycle \(cycle): \(scene.liveObjectCount) scene GPU objects after the memory warning")
            try ChronoConstellatorTest.draw(session, frames: 1)
            #expect(scene.liveObjectCount > 0, "cycle \(cycle): the frame after the warning did not rebuild")
            #expect(shell.presenter.fallbackReason == nil, "cycle \(cycle): \(shell.presenter.fallbackReason ?? "")")
            session.close()
            #expect(scene.liveObjectCount == 0,
                    "cycle \(cycle): \(scene.liveObjectCount) scene GPU objects after close")
            guard let footprint: Int = ProcessMemory.footprint() else {
                let message: String = "cycle \(cycle): ProcessMemory.footprint() gave no reading (task_info refused); "
                    + "readings so far: \(Self.describe(readings))"
                Issue.record(Comment(rawValue: message))
                return
            }
            readings.append(footprint)
        }
        print("chrono-constellator memory: \(Self.describe(readings))")
        #expect(readings.count == Self.cycles, "\(readings.count) readings: \(Self.describe(readings))")
        guard let first: Int = readings.first else { return }
        guard Self.isolated else {
            print("chrono-constellator memory: footprint bound not applied "
                  + "(not isolated; run scripts/chrono_constellator_regression.py)")
            return
        }
        for index in 1..<readings.count {
            let drift: Int = readings[index] - first
            let message: String = "cycle \(index + 1) is \(drift) bytes from cycle 1 (bound \(Self.bound)): "
                + Self.describe(readings)
            #expect(abs(drift) <= Self.bound, Comment(rawValue: message))
        }
    }

    @Test func aClosedSceneRebuildsOnTheNextOpen() async throws {
        // After a close the next session's first frame builds a fresh scene (the release left nothing behind).
        var scenes: [ChronoConstellatorSkyScene] = []
        for round in 1...2 {
            let session = ExperienceSession()
            defer { session.close() }
            let shell: ChronoConstellatorTest.Shell = try await ChronoConstellatorTest.open(session, seed: 0)
            let scene: ChronoConstellatorSkyScene = shell.presenter.scene
            #expect(scene.liveObjectCount > 0, "round \(round): the first frame built the scene")
            session.close()
            #expect(scene.liveObjectCount == 0, "round \(round): \(scene.liveObjectCount) GPU objects after close")
            scenes.append(scene)
        }
        #expect(scenes.count == 2 && scenes[0] !== scenes[1], "each open makes its own scene")
    }
}
#endif
