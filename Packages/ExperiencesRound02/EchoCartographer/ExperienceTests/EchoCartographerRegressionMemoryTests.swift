// EchoCartographerRegressionMemoryTests — feature 408 (R02-G11-08) T-R02G1108-005 (FR-R02G1108-005; SC-R02G1108-004;
// clarification Q4). User Story 3. Through the one app's session host, 12 cycles of: open (seed 0, level 1), draw 3
// frames at tier 0, send a memory warning, draw 1 frame, close. The chamber scene's own GPU objects
// (`EchoCartographerChamberScene.liveObjectCount`) exist after drawing, are 0 after each memory warning (the presenter's
// `shedCaches`, which calls the scene's `release()`) and after each close (its `teardown`), and the next frame rebuilds
// them. The process footprint (`ProcessMemory.footprint()`) is read after each cycle; an unavailable reading fails with
// a named reason, and, when the class runs in a process of its own (`TEST_RUNNER_ECHO_CARTOGRAPHER_MEMORY_ISOLATED=1`),
// every reading of cycles 2 … 12 stays within 16 MB of cycle 1's; otherwise the readings are printed. A small view and
// the default 48 × 32 frames keep the run short. Modelled on `BackwardsAuroraRegressionMemoryTests` (feature 398).
// Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion.
#if os(iOS)
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct EchoCartographerRegressionMemoryTests {
    /// The number of open-draw-warn-close cycles.
    static let cycles: Int = 12
    /// The footprint bound of clarification Q4: 16 MB.
    static let bound: Int = 16 * 1_048_576
    /// Whether the footprint bound applies: only when this class runs in a process of its own (the regression command
    /// sets `TEST_RUNNER_ECHO_CARTOGRAPHER_MEMORY_ISOLATED=1`; xcodebuild passes it without the prefix); the footprint
    /// is process-wide, so other suites running in parallel move it (feature 309). The release checks always apply.
    static var isolated: Bool {
        let environment: [String: String] = ProcessInfo.processInfo.environment
        return environment["ECHO_CARTOGRAPHER_MEMORY_ISOLATED"] == "1"
            || environment["TEST_RUNNER_ECHO_CARTOGRAPHER_MEMORY_ISOLATED"] == "1"
    }

    /// The readings in MB with two decimals, for the issue messages.
    static func describe(_ readings: [Int]) -> String {
        var parts: [String] = []
        for (index, bytes) in readings.enumerated() {
            parts.append(String(format: "cycle %ld: %.2f MB", index + 1, Double(bytes) / 1_048_576))
        }
        return parts.joined(separator: ", ")
    }

    /// Twelve open-draw-warn-close cycles release the chamber scene's GPU objects after every warning and close,
    /// rebuild them on the next frame, and keep the footprint within 16 MB of the first cycle's when isolated.
    @Test func twelveCyclesReleaseTheSceneAndKeepTheFootprintBounded() async throws {
        var readings: [Int] = []
        for cycle in 1...Self.cycles {
            let session = ExperienceSession()
            defer { session.close() }
            let shell: EchoCartographerTest.Shell = try await EchoCartographerTest.open(session, seed: 0)
            let opened: Int = try EchoCartographerTest.core(shell).levelNumber
            #expect(opened == 1, "cycle \(cycle): level \(opened) is prepared, not level 1")
            let scene: EchoCartographerChamberScene = shell.presenter.scene
            EchoCartographerTest.pin(session, shell, tier: 0)
            try EchoCartographerTest.draw(session, frames: 3)
            #expect(scene.liveObjectCount > 0, "cycle \(cycle): no scene GPU objects after 3 frames")
            session.handleMemoryWarning()
            #expect(scene.liveObjectCount == 0,
                    "cycle \(cycle): \(scene.liveObjectCount) scene GPU objects after the memory warning")
            try EchoCartographerTest.draw(session, frames: 1)
            #expect(scene.liveObjectCount > 0, "cycle \(cycle): the frame after the warning did not rebuild")
            #expect(shell.presenter.fallbackReason == nil,
                    "cycle \(cycle): \(shell.presenter.fallbackReason ?? "")")
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
        print("echo-cartographer memory: \(Self.describe(readings))")
        #expect(readings.count == Self.cycles, "\(readings.count) readings: \(Self.describe(readings))")
        guard let first: Int = readings.first else { return }
        guard Self.isolated else {
            print("echo-cartographer memory: footprint bound not applied "
                  + "(not isolated; set TEST_RUNNER_ECHO_CARTOGRAPHER_MEMORY_ISOLATED=1)")
            return
        }
        for index in 1..<readings.count {
            let drift: Int = readings[index] - first
            let message: String = "cycle \(index + 1) is \(drift) bytes from cycle 1 (bound \(Self.bound)): "
                + Self.describe(readings)
            #expect(abs(drift) <= Self.bound, Comment(rawValue: message))
        }
    }

    /// The presenter's own memory-warning path (`shedCaches`) releases the scene, and the next frame rebuilds it.
    @Test func shedCachesReleasesAndTheNextFrameRebuilds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: EchoCartographerTest.Shell = try await EchoCartographerTest.open(session, seed: 0)
        let scene: EchoCartographerChamberScene = shell.presenter.scene
        EchoCartographerTest.pin(session, shell, tier: 0)
        try EchoCartographerTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "a drawn frame holds GPU objects")
        shell.presenter.shedCaches()
        #expect(scene.liveObjectCount == 0, "\(scene.liveObjectCount) GPU objects after shedCaches")
        try EchoCartographerTest.draw(session, frames: 1)
        #expect(scene.liveObjectCount > 0, "the next frame rebuilt the scene")
    }

    /// After a close the next session's first frame builds a fresh scene (the release left nothing behind).
    @Test func aClosedSceneRebuildsOnTheNextOpen() async throws {
        var scenes: [EchoCartographerChamberScene] = []
        for round in 1...2 {
            let session = ExperienceSession()
            defer { session.close() }
            let shell: EchoCartographerTest.Shell = try await EchoCartographerTest.open(session, seed: 0)
            let scene: EchoCartographerChamberScene = shell.presenter.scene
            #expect(scene.liveObjectCount > 0, "round \(round): the first frame built the scene")
            session.close()
            #expect(scene.liveObjectCount == 0, "round \(round): \(scene.liveObjectCount) GPU objects after close")
            scenes.append(scene)
        }
        #expect(scenes.count == 2 && scenes[0] !== scenes[1], "each open makes its own scene")
    }
}
#endif
