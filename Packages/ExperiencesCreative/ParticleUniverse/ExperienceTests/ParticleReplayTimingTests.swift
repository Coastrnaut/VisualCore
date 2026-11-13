// ParticleReplayTimingTests — feature 193 (UA-F07) T-U07-026 (clarification 3; SC-U07-011). A short replay of Particle
// Universe (10 simulated seconds) gives the replay's cost per step; the longest state that restores within the
// session's 10 s preparation limit follows from it by arithmetic. Tests are short (owner rule of 2026-11-13): long
// replays are measured on devices (T-U07-029).
import Foundation
import Testing
@testable import ParticleUniverseExperience
import VisualCoreExperience

@Suite struct ParticleReplayTimingTests {
    @Test func aShortReplayGivesTheCostPerStep() throws {
        let steps = 10 * 120
        let log = [ExperienceAction(control: "emitter.add", step: 10),
                   ExperienceAction(control: "force.place", values: [0.6, 0.4], step: 120),
                   ExperienceAction(control: "family", values: [3], step: 600)]
        let clock = ContinuousClock()
        let start = clock.now
        let core = try ParticleCore.replay(seed: 7, log: log, steps: steps)
        let elapsed = clock.now - start
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let perStep = seconds / Double(steps)
        let bound = perStep > 0 ? 10 / perStep / 120 / 60 : .infinity
        print("UA-F07 A04 replay: \(steps) steps in \(String(format: "%.3f", seconds)) s; "
              + "the 10 s limit holds about \(String(format: "%.1f", bound)) simulated minutes on this machine")
        #expect(core.steps == steps)
        #expect(core.simulation.liveCount > 0, "the replay ran the simulation")
        #expect(seconds < 10, "a 10-second replay took \(seconds) s")
    }
}
