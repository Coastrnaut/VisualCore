// PassIsolationTests — feature 118 (A16-P02) T-A16-204 (FR-A16-203; SC-A16-203; clarification Q5). Pass isolation of
// the running automaton inside the one app's session host: `FieldPass.runObserver` records every field-pass run of 10
// frames at speed ×4; no run's output texture is among its input textures, every frame draws the automaton display
// once into the framebuffer, and the step runs alternate between the two targets of the pair, each reading what the
// one before wrote. `FieldPass` itself refuses a step whose input is its output (`inputIsOutput`). The observer is
// restored to nil afterwards. Ten frames of a 64 × 64 grid: far under 10 s.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// No pass of the running automaton samples the texture it writes.
@MainActor
final class PassIsolationTests: XCTestCase {
    override func tearDown() {
        MainActor.assumeIsolated { FieldPass.runObserver = nil }
        super.tearDown()
    }

    func testNoPassSamplesItsOutputOverTenFrames() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "sim.speed", values: [4]).isAccepted, "×4: about 2 steps in 3 frames")
        XCTAssertTrue(try SimulationTest.core(shell).isRunning, "the automaton runs")
        try SimulationTest.frames(session, 1)
        let steps = presenter.gpuStepCount

        var runs: [FieldPass.Run] = []
        FieldPass.runObserver = { runs.append($0) }
        try SimulationTest.frames(session, 10)
        FieldPass.runObserver = nil

        let violations = runs.filter { !$0.outputIsFramebuffer && $0.inputs.values.contains($0.output) }
        XCTAssertEqual(violations.count, 0, "no run samples its output: \(violations)")
        let displays = runs.filter { $0.label == "a16.automaton.display" }
        XCTAssertEqual(displays.count, 10, "one automaton display per frame")
        XCTAssertTrue(displays.allSatisfy(\.outputIsFramebuffer), "the display draws into the framebuffer")

        let stepRuns = runs.filter { $0.label == AutomatonGPU.stepLabel }
        XCTAssertEqual(stepRuns.count, presenter.gpuStepCount - steps, "every GPU step was observed")
        XCTAssertGreaterThanOrEqual(stepRuns.count, 4, "the running automaton stepped")
        XCTAssertEqual(runs.count, displays.count + stepRuns.count, "no other pass ran")
        XCTAssertEqual(Set(stepRuns.map(\.output)).count, 2, "the steps write the two targets of the pair")
        for i in stepRuns.indices {
            let run = stepRuns[i]
            XCTAssertFalse(run.outputIsFramebuffer, "step \(i) writes a target")
            let input = try XCTUnwrap(run.inputs[AutomatonGPU.fieldInput], "step \(i) reads the field")
            XCTAssertNotEqual(input, run.output, "step \(i) reads one target and writes the other")
            if i > 0 {
                XCTAssertNotEqual(run.output, stepRuns[i - 1].output, "step \(i) alternates")
                XCTAssertEqual(input, stepRuns[i - 1].output, "step \(i) reads what step \(i - 1) wrote")
            }
        }
        let automaton = try XCTUnwrap(presenter.automaton)
        let last = try XCTUnwrap(stepRuns.last)
        XCTAssertEqual(automaton.current.colorTexture, last.output, "the display samples the last written target")

        // FieldPass refuses a step that would read its own output (right after a frame, the context is current).
        XCTAssertThrowsError(try automaton.pass.run(output: .target(automaton.current),
                                                    inputs: [AutomatonGPU.fieldInput: automaton.current])) {
            XCTAssertEqual($0 as? FieldPassError, .inputIsOutput(AutomatonGPU.fieldInput))
        }
        session.close()
    }
}
