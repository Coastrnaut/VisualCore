// InspectorWordsTests — feature 120 (A16-P04) T-A16-405 (FR-A16-410, FR-A16-411). The approximation label's three
// sentences, the inspector's rows per family (name, value, unit and range, the time step with its limit) and the
// spoken state in the description (running or paused, the step and the parameter values).
import Foundation
import Testing
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience

@Suite struct InspectorWordsTests {
    @Test func theApproximationLabels() {
        #expect(SimulationCore.approximationWords(.automaton)
                == "Approximation: 64 × 64 cells, exact states (0 or 1), wrap boundary.")
        #expect(SimulationCore.approximationWords(.reactionDiffusion)
                == "Approximation: 64 × 64 cells, half-precision values, wrap boundary, explicit Euler step.")
        #expect(SimulationCore.approximationWords(.wave)
                == "Approximation: 64 × 64 cells, half-precision values, fixed zero boundary, leapfrog step.")
    }

    @Test @MainActor func theInspectorRows() {
        #expect(SimulationControls.inspectorRows(.standard(.reactionDiffusion))
                == ["Feed: 0.035 (range 0 to 0.1)", "Kill: 0.065 (range 0 to 0.1)",
                    "Time step: 1 time units (limit 1.5625)"])
        #expect(SimulationControls.inspectorRows(.standard(.wave))
                == ["Wave speed: 1 cells per time unit (range 0.1 to 2)", "Damping: 0.002 per step (range 0 to 0.05)",
                    "Time step: 0.5 time units (Courant number 0.5, limit 0.707)"])
        #expect(SimulationControls.inspectorRows(.standard(.automaton))
                == ["Rule: 0 (range 0 to 2)", "Time step: one generation per step"])
    }

    @Test func theDescriptionSpeaksTheState() {
        var core = SimulationCore(seed: 1)
        _ = core.apply(ExperienceAction(control: "sim.family", values: [1], step: 0))
        _ = core.apply(ExperienceAction(control: "sim.pause", values: [], step: 0))
        let words = core.canvasDescription
        #expect(words.contains("paused"))
        #expect(words.contains("step 0"))
        #expect(words.contains("feed 0.035, kill 0.065, time step 1"))
    }
}
