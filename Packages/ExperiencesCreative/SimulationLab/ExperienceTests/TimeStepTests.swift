// TimeStepTests — feature 119 (A16-P03) T-A16-302 (FR-A16-330; SC-A16-304; clarification Q4). The time-step action
// `sim.timestep [0.05…2.0]` of Simulation Lab, on the core without a GPU: reaction-diffusion accepts its limit 1.5625
// and refuses 1 % above it with `a16.unstable` and the sentence naming 1.5625; the wave (speed 1) accepts the Courant
// limit 1/√2 and refuses 1 % above it with the Courant sentence; a time step below the family's own range is refused
// with `a16.invalid-choice`; the cellular automaton refuses the action; a refusal changes nothing; an accepted time step
// keeps the field, the step count, running and speed. Through the engine, a value outside 0.05…2.0 is `outOfRange`.
import Foundation
import Testing
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience

@Suite struct TimeStepTests {
    static let unstable = "action.rule." + SimulationRule.unstable
    static let invalid = "action.rule." + SimulationRule.invalidChoice

    /// A core of `family` (1 reaction-diffusion, 2 wave) after 5 iterations.
    static func core(family: Double) -> SimulationCore {
        var core = SimulationCore(seed: 7)
        #expect(core.apply(ExperienceAction(control: "sim.family", values: [family], step: 0)).isAccepted)
        for step in 0..<20 { core.update(step: step) }
        return core
    }

    @Test func reactionDiffusionAcceptsItsLimitAndRefusesAbove() {
        var core = Self.core(family: 1)
        let before = core
        let above = SimulationSpec.reactionTimeStepLimit * 1.01
        #expect(core.apply(ExperienceAction(control: "sim.timestep", values: [above], step: 0)).code == Self.unstable)
        #expect(core == before, "a refusal changes nothing")
        #expect(core.timeStepRefusal(above) == .reactionStep)
        #expect(core.timeStepRefusal(above)?.sentence.contains("1.5625") == true)
        #expect(core.apply(ExperienceAction(control: "sim.timestep", values: [SimulationSpec.reactionTimeStepLimit], step: 0))
            .isAccepted)
        #expect(core.model.spec.timeStep == 1.5625)
        #expect(core.model.field == before.model.field, "the field is kept")
        #expect(core.stepCount == before.stepCount && core.isRunning == before.isRunning
                && core.speedIndex == before.speedIndex)
        #expect(core.preset == before.preset, "the preset is the parameters, unchanged")
        #expect(core.status.hasSuffix("time step 1.5625"))
    }

    @Test func theWaveAcceptsTheCourantLimitAndRefusesAbove() {
        var core = Self.core(family: 2)
        let before = core
        let limit = SimulationSpec.courantLimit
        #expect(core.model.spec.value(ParameterCatalog.speed.name) == 1)
        #expect(core.apply(ExperienceAction(control: "sim.timestep", values: [limit * 1.01], step: 0)).code == Self.unstable)
        #expect(core == before)
        #expect(core.timeStepRefusal(limit * 1.01)?.sentence
                == "The wave step is too large: the Courant number must stay at or below 0.707.")
        #expect(core.apply(ExperienceAction(control: "sim.timestep", values: [limit], step: 0)).isAccepted)
        #expect(core.model.field == before.model.field)
        #expect(core.stepCount == before.stepCount)
    }

    @Test func belowTheFamilyRangeAndTheAutomatonAreInvalidChoices() {
        var reaction = Self.core(family: 1)
        let before = reaction
        #expect(reaction.apply(ExperienceAction(control: "sim.timestep", values: [0.06], step: 0)).code == Self.invalid)
        #expect(reaction == before)
        #expect(reaction.timeStepRefusal(0.06)?.reason == .outOfRange)
        var automaton = SimulationCore(seed: 7)
        let start = automaton
        #expect(automaton.apply(ExperienceAction(control: "sim.timestep", values: [1], step: 0)).code == Self.invalid)
        #expect(automaton == start)
        #expect(automaton.timeStepRefusal(1) == SimulationCore.automatonTimeStepRefusal)
    }

    @Test func theEngineRefusesValuesOutsideTheDeclaredRange() async throws {
        var engine = ExperienceEngine<SimulationCore>(id: ExperienceID(rawValue: SimulationCore.experienceID)!)
        try await engine.prepare(seed: 7)
        try engine.activate()
        #expect(engine.handle(control: "sim.family", values: [1]).isAccepted)
        #expect(!engine.handle(control: "sim.timestep", values: [2.5]).isAccepted)
        #expect(engine.handle(control: "sim.timestep", values: [0.5]).isAccepted)
        #expect(engine.core?.model.spec.timeStep == 0.5)
    }
}
