// LegendTests — feature 119 (A16-P03) T-A16-306 (FR-A16-320; SC-A16-305; clarification Q5). The legend's values equal
// the field's extremes for each family (v for reaction-diffusion, the height for the wave, the alive and dead counts
// for the automaton), the canvas description states the same numbers, the presenter's mirror carries them and the
// presenter offers the legend as the canvas overlay. No GPU except the overlay check.
import Foundation
import Testing
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct LegendTests {
    /// The core of `family` after 30 host steps.
    static func core(family: Double) -> SimulationCore {
        var core = SimulationCore(seed: 5)
        _ = core.apply(ExperienceAction(control: "sim.family", values: [family], step: 0))
        for step in 0..<30 { core.update(step: step) }
        return core
    }

    @Test func theValuesAreTheFieldsExtremes() {
        let reaction = Self.core(family: 1)
        let grid = reaction.model.field.current
        var v: [Float] = []
        for i in 0..<(grid.width * grid.height) { v.append(grid.values[i * 2 + 1]) }
        let values = SimulationLegendValues.of(reaction.model.field, kind: .reactionDiffusion)
        #expect(values.minimum == v.min() && values.maximum == v.max())
        #expect(reaction.canvasDescription.contains("v from \(SimulationCore.twoDecimals(values.minimum)) to "
                                                    + "\(SimulationCore.twoDecimals(values.maximum))"))

        let wave = Self.core(family: 2)
        let heights = wave.model.field.current.values
        let waveValues = SimulationLegendValues.of(wave.model.field, kind: .wave)
        #expect(waveValues.minimum == heights.min() && waveValues.maximum == heights.max())
        #expect(wave.canvasDescription.contains("height from \(SimulationCore.twoDecimals(waveValues.minimum))"))

        let automaton = Self.core(family: 0)
        let cells = SimulationLegendValues.of(automaton.model.field, kind: .automaton)
        let alive = AutomatonRule.liveCount(automaton.model.field.current)
        #expect(cells.alive == alive && cells.dead == 64 * 64 - alive)
        #expect(automaton.canvasDescription.contains("\(alive) of 4096 cells alive"))
        #expect(cells.words.contains("\(alive) alive"))
    }

    @Test @MainActor func thePresenterCarriesTheLegendAndOffersTheOverlay() throws {
        let presenter = SimulationPresenter(experienceID: try #require(SimulationLabExperience.id))
        let core = Self.core(family: 2)
        presenter.sync(core)
        #expect(presenter.mirror.legend == SimulationLegendValues.of(core.model.field, kind: .wave))
        #expect(presenter.mirror.timeStep == 0.5)
    }
}
