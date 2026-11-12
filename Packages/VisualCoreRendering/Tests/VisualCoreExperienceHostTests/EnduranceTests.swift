// EnduranceTests — feature 192 T-U06-029 (UA-F06; US5; FR-U06-050 to FR-U06-052; SC-U06-008). Ten minutes of
// experience time, drawn frame by frame as fast as the simulator draws them: 36,000 frames of 1/60 s are 72,000
// fixed steps. Every 600 frames one scripted action is sent and one resource sample is taken (60 samples); the
// growth rule must find nothing growing, and the state must equal the state of the same scenario run by the pure
// engine without rendering. A presenter that makes one small texture more in every frame must fail the rule.
// Simulator numbers are development signals, not device performance. Test-only.
//
// Frames and steps, as read in the sources:
// - `RenderHost.renderOneFrame(present:)` calls `renderFrame` with the delta 1/60 s; `FramePacing.clampedDelta`
//   leaves it unchanged (0…0.1 s).
// - `ExperienceShell.sceneRender` calls `engine.advance(frame: frame.delta)` while the state is active, then
//   `presenter.draw`.
// - `ExperienceEngine.advance(frame:)` asks `FixedStepClock.advance(by:)` for the number of steps:
//   floor((accumulator + 1e-9) / step), at most `maxStepsPerFrame` (8). The sample's step is 1/120 s, so a frame
//   of 1/60 s gives exactly 2 steps; the remainder is 0 or a rounding residue far below the tolerance, clamped
//   to 0 or more, so it never adds up to a step. 36,000 frames are exactly 72,000 steps.
// - `ExperienceSession.open` draws one frame itself, but the host has no surface before the test lays it out,
//   so that frame draws nothing and runs no step (testWithoutASurfaceTheSessionRunsAndDrawsAsSoonAsOneExists).
// - The host's display link fires on the main run loop only. The frame loops below are synchronous on the main
//   actor, and the state is read before the next suspension point, so no frame of the display link is mixed in.
import SwiftUI
import UIKit
import XCTest
import VisualCoreDiagnostics
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

// MARK: - A presenter that leaks

/// The sample presenter with a deliberate leak: every drawn frame creates one texture of 8 × 8 RGBA pixels
/// (256 bytes) and keeps it. `teardown` releases them all, so that the close itself reports no leak; the growth
/// is visible only while the experience runs.
@MainActor
private final class LeakingPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>

    /// The healthy presenter that does the real drawing.
    let base = SamplePresenter<NoFault>()
    /// Every texture made by a frame, still live.
    private(set) var leaked: [Texture] = []

    func setup(_ context: RenderContext) throws {
        try base.setup(context)
    }

    func resize(_ context: RenderContext) {
        base.resize(context)
    }

    func draw(_ core: SampleExperienceCore<NoFault>, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        try base.draw(core, tier: tier, context: context, frame: frame)
        leaked.append(try context.resources.makeTexture(width: 8, height: 8, label: "leak"))
    }

    func teardown(_ context: RenderContext) {
        for texture in leaked { context.resources.release(texture) }
        leaked.removeAll()
        base.teardown(context)
    }

    func shedCaches() {
        base.shedCaches()
    }

    func describe(_ core: SampleExperienceCore<NoFault>) -> String {
        base.describe(core)
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        base.makeControls(port)
    }
}

// MARK: - Tests

@MainActor
final class EnduranceTests: XCTestCase {
    /// The seed of both runs.
    private static let seed: UInt64 = 42

    /// The value the scripted action `tone` carries after block `k` (1…60); always inside 0…1, so always accepted.
    private static func tone(afterBlock k: Int) -> Double {
        Double(k % 10) / 10
    }

    /// Draws `count` frames without presenting them and returns how many were really drawn.
    private func draw(_ count: Int, on host: RenderHost) -> Int {
        var drawn = 0
        autoreleasepool {
            for _ in 0..<count where host.renderOneFrame(present: false) {
                drawn += 1
            }
        }
        return drawn
    }

    func testTenMinutesOfTheSampleDoNotGrow() async throws {
        let blocks = 60, framesPerBlock = 600, stepsPerFrame = 2
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest(seed: Self.seed)
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        let experience = try XCTUnwrap(session.experience)
        let presenter = try XCTUnwrap(probe.presenter)
        XCTAssertEqual(experience.diagnostics.stepIndex, 0, "no step before the first drawn frame")
        let drawsBefore = presenter.drawCalls

        // From here to the reading of the final state there is no suspension point.
        var samples: [ResourceSample] = []
        samples.reserveCapacity(blocks)
        var drawn = 0, accepted = 0
        for k in 1...blocks {
            drawn += draw(framesPerBlock, on: host)
            let action = experience.handle(control: "tone", values: [Self.tone(afterBlock: k)])
            if action.isAccepted { accepted += 1 }
            samples.append(ResourceSample(footprintBytes: ProcessMemory.footprint(),
                                          gpuBytes: host.resources.stats.totalBytes))
        }
        let diagnostics = experience.diagnostics
        let drawCalls = presenter.drawCalls - drawsBefore
        let sessionState = session.state

        XCTAssertEqual(sessionState, .running, "the session ran to the end")
        XCTAssertEqual(drawn, blocks * framesPerBlock, "36,000 frames were drawn")
        XCTAssertEqual(drawCalls, blocks * framesPerBlock, "the presenter drew every frame")
        XCTAssertEqual(accepted, blocks, "every scripted action was accepted")
        XCTAssertEqual(samples.count, blocks)
        XCTAssertEqual(diagnostics.stepIndex, blocks * framesPerBlock * stepsPerFrame, "72,000 fixed steps")
        XCTAssertGreaterThanOrEqual(diagnostics.stepIndex, 72_000)

        let verdict = GrowthRule.judge(samples)
        print("ENDURANCE verdict \(verdict)")
        if let first = samples.first, let last = samples.last {
            print("ENDURANCE first footprint \(first.footprintBytes ?? -1) gpu \(first.gpuBytes)")
            print("ENDURANCE last footprint \(last.footprintBytes ?? -1) gpu \(last.gpuBytes)")
        }
        XCTAssertTrue(verdict.passes, "nothing may grow in ten minutes: \(verdict)")
        XCTAssertEqual(verdict, .flat(footprintChecked: true), "the footprint was measured in every sample")

        // The close comes before the next suspension point, so that the display link cannot add a frame.
        session.close()
        assertHoldsNothing(session)
        assertClosedCleanly(session)

        // The same scenario on the pure engine: 1,200 steps, then the action, 60 times. The last action of the
        // session run comes after frame 36,000 (step 72,000), so no steps remain after it.
        let entries = (1...blocks).map { k in
            ExperienceScenario.Entry(steps: framesPerBlock * stepsPerFrame,
                                     action: ScriptedAction("tone", [Self.tone(afterBlock: k)]))
        }
        let scenario = ExperienceScenario(seed: Self.seed, entries: entries)
        XCTAssertTrue(scenario.isWithinLimits)
        let pure = await SampleEngine.runScenario(scenario, id: SampleExperience.id)
        XCTAssertNil(pure.error)
        XCTAssertEqual(pure.results, Array(repeating: ActionResult.accepted.code, count: blocks))
        XCTAssertEqual(pure.stepIndex, diagnostics.stepIndex)
        XCTAssertNotNil(diagnostics.digest)
        XCTAssertEqual(pure.digest, diagnostics.digest, "rendering does not change the state")
        print("ENDURANCE digest \(diagnostics.digest?.hex ?? "none") steps \(diagnostics.stepIndex)")
    }

    func testALeakingExperienceFailsTheGrowthRule() async throws {
        // 6,000 textures of 8 × 8 × 4 bytes are about 1.5 MiB, far below the default budget of 256 MiB.
        let blocks = 60, framesPerBlock = 100
        let presenter = LeakingPresenter()
        let shell = ExperienceShell(id: SampleExperience.id, presenter: presenter)
        let request = ExperienceOpenRequest(id: SampleExperience.id, seed: Self.seed) { shell }
        let session = ExperienceSession()
        defer { session.close() }
        let result = await session.open(request)
        XCTAssertEqual(result, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)

        var samples: [ResourceSample] = []
        samples.reserveCapacity(blocks)
        var drawn = 0
        for _ in 0..<blocks {
            drawn += draw(framesPerBlock, on: host)
            samples.append(ResourceSample(footprintBytes: ProcessMemory.footprint(),
                                          gpuBytes: host.resources.stats.totalBytes))
        }
        let sessionState = session.state
        let kept = presenter.leaked.count

        XCTAssertEqual(sessionState, .running, "the leak stays inside the budget, so the session keeps running")
        XCTAssertEqual(drawn, blocks * framesPerBlock)
        XCTAssertEqual(kept, blocks * framesPerBlock, "one texture more per drawn frame")
        XCTAssertEqual(samples.count, blocks)

        let verdict = GrowthRule.judge(samples)
        print("ENDURANCE leak verdict \(verdict)")
        if case .grew(let quantity, let by) = verdict {
            XCTAssertEqual(quantity, GrowthRule.gpuQuantity)
            XCTAssertEqual(quantity, "gpu_bytes")
            XCTAssertGreaterThan(by, 0)
        } else {
            XCTFail("the leak was not found: \(verdict)")
        }
        XCTAssertFalse(verdict.passes)

        // `teardown` releases what the frames kept, so the close itself is clean.
        session.close()
        assertHoldsNothing(session)
        assertClosedCleanly(session)
        XCTAssertTrue(presenter.leaked.isEmpty)
    }
}
